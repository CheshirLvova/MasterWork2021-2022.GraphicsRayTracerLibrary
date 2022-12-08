#########################################################################
#########################################################################
##########   Розкодування бібліотеки для рендеру зображень     ##########
##########             в режимі реального часу                 ##########
##########                                                     ##########
##########       Виконала: Ковальчук Софія, студентка          ##########
##########           кафедри Інформаційних систем              ##########
##########   факультету Прикладної математики та інформатики   ##########
##########       Львівського національного університету        ##########
##########                імені Івана Франка                   ##########
##########                    Львів, 2022                      ##########
#########################################################################
#########################################################################
import sys
import math
import shutil
import tempfile
from multiprocessing import Process, Value
from pathlib import Path


class Vector:
    """Означення вектора"""

    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = x
        self.y = y
        self.z = z

    def __str__(self):
        return "({}, {}, {})".format(self.x, self.y, self.z)

    def dot_product(self, other):
        return self.x * other.x + self.y * other.y + self.z * other.z

    def magnitude(self):
        return math.sqrt(self.dot_product(self))

    def normalize(self):
        return self / self.magnitude()

    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other):
        return Vector(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, other):
        assert not isinstance(other, Vector)
        return Vector(self.x * other, self.y * other, self.z * other)

    def __rmul__(self, other):
        return self.__mul__(other)

    def __truediv__(self, other):
        assert not isinstance(other, Vector)
        return Vector(self.x / other, self.y / other, self.z / other)


class Image:
    """ Означення зображення на противагу використання Pillow """
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.pixels = [[None for _ in range(width)] for _ in range(height)]

    def set_pixel(self, x, y, col):
        self.pixels[y][x] = col

    def write_ppm(self, img_fileobj):
        Image.write_ppm_header(img_fileobj, height=self.height, width=self.width)
        self.write_ppm_raw(img_fileobj)

    @staticmethod
    def write_ppm_header(img_fileobj, height=None, width=None):
        """Ініціалізація заголовку PPM файлу"""
        img_fileobj.write("P3 {} {}\n255\n".format(width, height))

    def write_ppm_raw(self, img_fileobj):
        """
        PPM - скорочено від portable pixel map.
        Це розширення файлу, в якому визначаємо P3 як формат зображення, прописуємо кількість стовпців та рядків нашої колірної матриці.
        В наступному рядку задаємо максимальне значення кольору - 255 для RGB (колірної системи, під яку прописуватимемо матрицю).
        В третьому рядку додаємо колірне значення кожного пікселя у форматі (R G B)
        Наприклад:
        P3 3 2
        255
        255  0  0     0 255   0    0   0 255
        255 255 0   255 255 255    0   0   0
        У прикладі отримала палітру з шести кольорів, які відображаю у 3 стовпцях та 2 рядках:
        червоний зелений синій
        жовтий   білий   чорний
        """

        def to_byte(c):
            return round(max(min(c * 255, 255), 0))

        for row in self.pixels:
            for color in row:
                img_fileobj.write(
                    "{} {} {} ".format(
                        to_byte(color.x), to_byte(color.y), to_byte(color.z)
                    )
                )
            img_fileobj.write("\n")


class Color(Vector):
    """Тут колір тривимірної моделі передаватимемо, як значення вектора у форматі RGB.
    Сутність вектора."""

    @classmethod
    def from_hex(cls, hexcolor="#000000"):
        x = int(hexcolor[1:3], 16) / 255.0
        y = int(hexcolor[3:5], 16) / 255.0
        z = int(hexcolor[5:7], 16) / 255.0
        return cls(x, y, z)


class Point(Vector):
    """Точка відображається у тривимірній множині координат. Сутність вектора"""
    pass


class Ray:
    """Модель променю у тривимірному декартовому просторі.
       Промінь - це шлях з оригінальним та нормалізованим напрямом (промінь від глядача до предмету) """

    def __init__(self, origin, direction):
        self.origin = origin
        self.direction = direction.normalize()


class Intersection:
    """ Означення точки або прямої перетину променя крізь об'єкт """
    def __init__(self, point, distance, normal, obj):
        self.point = point
        self.distance = distance
        self.normal = normal
        self.obj = obj


class Scene:
    """Сцена міститиме інформацію, яка необхідна для опрацювання методу трасування променів"""

    def __init__(self, camera, objects, lights, width, height):
        # Модель променевого емітера - камера
        self.camera = camera
        self.objects = objects
        self.lights = lights
        self.width = width
        self.height = height


class Triangle:
    """Полігон-трикутник - найпростіше відображення низькополігонального зображення"""

    def __init__(self, a=Vector(), b=Vector(), c=Vector()):
        self.a = a
        self.b = b
        self.c = c

    @classmethod
    def calculate_area(cls):
        s = (cls.a + cls.b + cls.c) / 2
        return float((s * (s - cls.a) * (s - cls.b) * (s - cls.c))) ** 0.5

    def get_area(self):
        return self.area


class Sphere:
    """Сфера містить необхідну інформацію про центр об'єкту, радіус та матеріал, з якого виготовлена"""

    def __init__(self, center, radius, material):
        self.center = center
        self.radius = radius
        self.material = material

    def intersects(self, ray):
        """ Тут відбувається перевірка перетину сфери променем.
        Якщо немає перетину - повертаємо None, інакще - відстань перетину
        (дистанцію або точну в залежності від випадку) """
        sphere_to_ray = ray.origin - self.center
        # a = 1
        b = 2 * ray.direction.dot_product(sphere_to_ray)
        c = sphere_to_ray.dot_product(sphere_to_ray) - self.radius * self.radius
        discriminant = b * b - 4 * c

        if discriminant >= 0:
            dist = (-b - math.sqrt(discriminant)) / 2
            if dist > 0:
                return dist
        return None

    def normal(self, surface_point):
        """Тут повертаємо нормаль поверхні до точки на поверхні сфери"""
        return (surface_point - self.center).normalize()


class Material:
    """Матеріал надає інформацію про те, як об'єкт реагуватиме на світло"""

    def __init__(self, color=Color.from_hex("#FFFFFF"), ambient=0.05, diffuse=1.0, specular=1.0, reflection=0.5):
        self.color = color  # інформація про базовий колір
        self.ambient = ambient  # інформація про наявність відбиття від навколишнього освітлення, якщо немає джерела
        self.diffuse = diffuse  # інформація про відбиття розсіяного джерела світла
        self.specular = specular  # інформація про наявне дзеркальне підсвічування
        self.reflection = reflection

    def color_at(self, position):
        return self.color


class ChequeredMaterial:
    """Матеріал для прикладу шахової дошки - мітсить інформацію про два базові кольори поділу"""

    def __init__(
            self,
            color1=Color.from_hex("#FFFFFF"),
            color2=Color.from_hex("#000000"),
            ambient=0.05,
            diffuse=1.0,
            specular=1.0,
            reflection=0.5,
    ):
        self.color1 = color1
        self.color2 = color2
        self.ambient = ambient
        self.diffuse = diffuse
        self.specular = specular
        self.reflection = reflection

    def color_at(self, position):
        if int((position.x + 5.0) * 3.0) % 2 == int(position.z * 3.0) % 2:
            return self.color1
        else:
            return self.color2


class Cylinder(object):
    """Циліндр містить необхідну інформацію про висоту, радіус та матеріал, з якого виготовлений"""
    def __init__(self, startpoint=Vector(), endpoint=Vector(), radius=0.1, material=Material()):
        self.startpoint = startpoint
        self.endpoint = endpoint
        self.radius = radius
        self.material = material

    def intersection(self, l):
        q = l.d.dot(l.o - self.c) ** 2 - (l.o - self.c).dot(l.o - self.c) + self.radius ** 2
        if q < 0:
            return Intersection(Vector(0, 0, 0), -1, Vector(0, 0, 0), self)
        else:
            d = -l.d.dot(l.o - self.c)
            d1 = d - math.sqrt(q)
            d2 = d + math.sqrt(q)
            if 0 < d1 and (d1 < d2 or d2 < 0):
                return Intersection(l.o + l.d * d1, d1, self.normal(l.o + l.d * d1), self)
            elif 0 < d2 and (d2 < d1 or d1 < 0):
                return Intersection(l.o + l.d * d2, d2, self.normal(l.o + l.d * d2), self)
            else:
                return Intersection(Vector(0, 0, 0), -1, Vector(0, 0, 0), self)

    def normal(self, b):
        return (b - self.c).normal()


class Plane:
    """Площина містить необхідну інформацію про напрям, центр об'єкту та матеріал, з якого виготовлена"""
    def __init__(self, point: object = Vector(), normal: object = Vector(), material: object = Material()) -> object:
        self.normal = normal
        self.point = point
        self.material = material

    def intersection(self, l):
        d = l.d.dot(self.normal)
        if d == 0:
            return Intersection(Vector(0, 0, 0), -1, Vector(0, 0, 0), self)
        else:
            d = (self.point - l.o).dot(self.normal) / d
            return Intersection(l.o + l.d * d, d, self.normal, self)


class Rectangle(Plane):
    """Нащадок площини, в якого можемо вирахувати площу"""

    def __init__(self, point, normal, material):
        Plane.__init__(self, point, normal, material)

    def intersection(self, ray):
        destination = ray.dest.dot(self.normal)
        if destination == 0:
            return Intersection(Vector(0, 0, 0), -1, Vector(0, 0, 0), self)
        else:
            destination = (self.point - ray.orig).dot(self.normal) / destination
            return Intersection(ray.orig + ray.desti * destination, destination, self.normal, self)


class Light:
    """Світло надає перетворення кольору при взаємодії з об'єктом"""

    def __init__(self, position, color=Color.from_hex("#FFFFFF")):
        self.position = position  # інформація про позицію джерела світла
        self.color = color  # інформація про колір освітлення (тепле, холодне тощо)


class RenderEngine:
    """Рендер 3D сцени в 2D зображнення з використанням методу трасування променів"""

    MAX_DEPTH = 5
    MIN_DISPLACE = 0.0001

    def render_multiprocess(self, scene, process_count, img_fileobj):
        def split_range(count, parts):
            d, r = divmod(count, parts)
            return [
                (i * d + min(i, r), (i + 1) * d + min(i + 1, r)) for i in range(parts)
            ]

        width = scene.width
        height = scene.height
        ranges = split_range(height, process_count)
        temp_dir = Path(tempfile.mkdtemp())
        temp_file_tmpl = "kovalchuk-part-{}.temp"
        processes = []
        try:
            rows_done = Value("i", 0)
            for hmin, hmax in ranges:
                part_file = temp_dir / temp_file_tmpl.format(hmin)
                processes.append(
                    Process(
                        target=self.render,
                        args=(scene, hmin, hmax, part_file, rows_done),
                    )
                )
            # Стартуємо всі процеси
            for process in processes:
                process.start()
            # Чекаємо на закінчення усіх процесів
            for process in processes:
                process.join()
            # Будуємо зображення на основі додання отриманих частин
            Image.write_ppm_header(img_fileobj, height=height, width=width)
            for hmin, _ in ranges:
                part_file = temp_dir / temp_file_tmpl.format(hmin)
                img_fileobj.write(open(part_file, "r").read())
        finally:
            shutil.rmtree(temp_dir)

    def render(self, scene, hmin, hmax, part_file, rows_done):
        width = scene.width
        height = scene.height
        aspect_ratio = float(width) / height
        x0 = -1.0
        x1 = +1.0
        xstep = (x1 - x0) / (width - 1)
        y0 = -1.0 / aspect_ratio
        y1 = +1.0 / aspect_ratio
        ystep = (y1 - y0) / (height - 1)

        camera = scene.camera
        pixels = Image(width, hmax - hmin)

        for j in range(hmin, hmax):
            y = y0 + j * ystep
            for i in range(width):
                x = x0 + i * xstep
                ray = Ray(camera, Point(x, y) - camera)
                pixels.set_pixel(i, j - hmin, self.ray_trace(ray, scene))
            # Update progress bar
            if rows_done:
                with rows_done.get_lock():
                    rows_done.value += 1
                    # відсоткове відображення процесу рендеру
                    sys.stdout.write("{:3.0f}%".format(float(rows_done.value) / float(height) * 100) + "\r")
        with open(part_file, "w") as part_fileobj:
            pixels.write_ppm_raw(part_fileobj)

    def ray_trace(self, ray, scene, depth=0):
        color = Color(0, 0, 0)
        # шукаємо найближчий об'єкт, якого досягає промінь в даній сцені
        dist_hit, obj_hit = self.find_nearest(ray, scene)
        if obj_hit is None:
            return color
        hit_pos = ray.origin + ray.direction * dist_hit
        hit_normal = obj_hit.normal(hit_pos)
        color += self.color_at(obj_hit, hit_pos, hit_normal, scene)
        if depth < self.MAX_DEPTH:
            new_ray_pos = hit_pos + hit_normal * self.MIN_DISPLACE
            new_ray_dir = (
                    ray.direction - 2 * ray.direction.dot_product(hit_normal) * hit_normal
            )
            new_ray = Ray(new_ray_pos, new_ray_dir)
            # Послабляємо відбитий промінь на коефіцієнт відбиття
            color += (
                    self.ray_trace(new_ray, scene, depth + 1) * obj_hit.material.reflection
            )
        return color

    def find_nearest(self, ray, scene):
        dist_min = None
        obj_hit = None
        for obj in scene.objects:
            dist = obj.intersects(ray)
            if dist is not None and (obj_hit is None or dist < dist_min):
                dist_min = dist
                obj_hit = obj
        return (dist_min, obj_hit)

    def color_at(self, obj_hit, hit_pos, normal, scene):
        material = obj_hit.material
        obj_color = material.color_at(hit_pos)
        to_cam = scene.camera - hit_pos
        specular_k = 50
        color = material.ambient * Color.from_hex("#FFFFFF")
        # Обрахунок світла
        for light in scene.lights:
            to_light = Ray(hit_pos, light.position - hit_pos)
            # інформація про відбиття розсіяного джерела світла та тінь (за Ламбертом)
            color += (
                    obj_color
                    * material.diffuse
                    * max(normal.dot_product(to_light.direction), 0)
            )
            # інформація про наявне дзеркальне підсвічування ( за Blinn-Phong)
            half_vector = (to_light.direction + to_cam).normalize()
            color += (
                    light.color
                    * material.specular
                    * max(normal.dot_product(half_vector), 0) ** specular_k
            )
        return color
