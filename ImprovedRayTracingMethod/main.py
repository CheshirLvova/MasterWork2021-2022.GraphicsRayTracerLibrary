import platform
import unittest
import pathlib as pl
import argparse
import importlib
import os
from multiprocessing import cpu_count

from rtlibrary import Vector, Image, Color, Point, Scene
from rtlibrary import Triangle, Sphere, Material, ChequeredMaterial, Light
from rtlibrary import RenderEngine


class Tests(unittest.TestCase):
    def setUp(self) -> None:
        # оголошення констант
        self.WIDTH = 960
        self.HEIGHT = 540
        self.RENDERED_IMG = "3balls.ppm"
        self.CAMERA = Vector(0, -0.35, -1)
        self.OBJECTS = [
            # Ground Plane
            Sphere(
                Point(0, 10000.5, 1),
                10000.0,
                ChequeredMaterial(
                    color1=Color.from_hex("#420500"),
                    color2=Color.from_hex("#e6b87d"),
                    ambient=0.2,
                    reflection=0.2,
                ),
            ),
            # Blue ball
            Sphere(Point(0.75, -0.1, 1), 0.6, Material(Color.from_hex("#b3b2ab"))),  # 0000FF
            # Pink ball
            Sphere(Point(-0.75, -0.1, 2.25), 0.6, Material(Color.from_hex("#59996a"))),   # 803980
            # Metalic Gold ball
            Sphere(Point(-0.8, -0.1, 0.9), 0.3, Material(Color.from_hex("#D4AF37"))),
        ]
        self.LIGHTS = [
            Light(Point(1.5, -0.5, -10), Color.from_hex("#FFFFFF")),
            Light(Point(-0.5, -10.5, 0), Color.from_hex("#E6E6E6")),
        ]

        # тестування функцій над фігурами
        self.v1 = Vector(1.0, -2.0, -2.0)
        self.v2 = Vector(3.0, 6.0, 9.0)
        self.v3 = Vector(0.0, 4.5, 2.0)
        self.t1 = Triangle(self.v1, self.v2, self.v3)

        # тестування функцій над роботою з кольором
        self.im = Image(3, 2)
        self.red = Color(x=1, y=0, z=0)
        self.green = Color(x=0, y=1, z=0)
        self.blue = Color(x=0, y=0, z=1)

        # тестування рендеру сфери
        self.camera = Vector(0, 0, -1)
        self.objects = [Sphere(Point(0, 0, 0), 0.5, Material(Color.from_hex("#FF0000")))]
        self.lights = [Light(Point(1.5, -0.5, -10.0), Color.from_hex("#FFFFFF"))]
        self.engine = RenderEngine()

    def test_magnitude(self):
        self.assertEqual(self.v1.magnitude(), 3.0)

    def test_addition(self):
        sum = self.v1 + self.v2
        self.assertEqual(getattr(sum, "x"), 4.0)

    def test_multiplication(self):
        sum = self.v1 * 2
        self.assertEqual(getattr(sum, "x"), 2.0)

    def test_pixelssetred(self):
        self.assertIsNone(self.im.set_pixel(0, 0, self.red))

    def test_pixelssetgreen(self):
        self.assertIsNone(self.im.set_pixel(0, 0, self.green))

    def test_pixelssetblue(self):
        self.assertIsNone(self.im.set_pixel(0, 0, self.blue))

    def test_setpixelfromhex(self):
        check = Color.from_hex("#b3b2ab")
        self.assertIsNotNone(check)

    def test_ppmcreation(self):
        self.scene = Scene(self.camera, self.objects, self.lights, self.WIDTH, self.HEIGHT)
        self.im.set_pixel(0, 0, self.red)
        self.im.set_pixel(1, 0, self.green)
        self.im.set_pixel(2, 0, self.blue)

        self.im.set_pixel(0, 1, self.red + self.green)
        self.im.set_pixel(1, 1, self.red + self.blue + self.green)
        self.im.set_pixel(2, 1, self.red * 0.001)

        with open("test.ppm", "w") as img_file:
            self.im.write_ppm(img_file)

        img_file.close()

        PATH = pl.Path("test.ppm")
        self.assertEqual((str(PATH), PATH.is_file()), (str(PATH), True))

    def test_rendersphere(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("rtlibrary", help="Path to scene file (without .py extension)")
        parser.add_argument(
            "-p",
            "--processes",
            action="store",
            type=int,
            dest="processes",
            default=0,
            help="Number of processes (0=auto)",
        )
        args = parser.parse_args(["rtlibrary"])
        if args.processes == 0:
            process_count = cpu_count()
        else:
            process_count = args.processes

        self.scene = Scene(self.CAMERA, self.OBJECTS, self.LIGHTS, self.WIDTH, self.HEIGHT)

        os.chdir(os.path.dirname(os.path.abspath(__file__)))

        with open(self.RENDERED_IMG, "w") as img_fileobj:
            self.engine.render_multiprocess(self.scene, process_count, img_fileobj)
            img_fileobj.close()

        PATH = pl.Path("2balls.ppm")
        self.assertEqual((str(PATH), PATH.is_file()), (str(PATH), True))


if __name__ == '__main__':
    # бібліотеку було створено та тестування проведено на базі версії Python 3.9.13
    print("Поточна Версія Python {}".format(platform.python_version()))
    # unittest.main()

    parser = argparse.ArgumentParser()
    parser.add_argument("imageout", help="Path to rendered image")
    args = parser.parse_args()
    WIDTH = 320
    HEIGHT = 200
    camera = Vector(0, 0, -1)
    objects = [Sphere(Point(0, 0, 0), 0.5, Material(Color.from_hex("#FF0000")))]
    lights = [Light(Point(1.5, -0.5, -10.0), Color.from_hex("#FFFFFF"))]
    scene = Scene(camera, objects, lights, WIDTH, HEIGHT)
    engine = RenderEngine()
    image = engine.render(scene)

    with open(args.imageout, "w") as img_file:
        image.write_ppm(img_file)

    WIDTH = 960
    HEIGHT = 540
    RENDERED_IMG = "2balls.ppm"
    CAMERA = Vector(0, -0.35, -1)
    OBJECTS = [
        # Ground Plane
        Sphere(
            Point(0, 10000.5, 1),
            10000.0,
            ChequeredMaterial(
                color1=Color.from_hex("#420500"),
                color2=Color.from_hex("#e6b87d"),
                ambient=0.2,
                reflection=0.2,
            ),
        ),
        # Blue ball
        Sphere(Point(0.75, -0.1, 1), 0.6, Material(Color.from_hex("#0000FF"))),
        # Pink ball
        Sphere(Point(-0.75, -0.1, 2.25), 0.6, Material(Color.from_hex("#803980"))),
    ]
    LIGHTS = [
        Light(Point(1.5, -0.5, -10), Color.from_hex("#FFFFFF")),
        Light(Point(-0.5, -10.5, 0), Color.from_hex("#E6E6E6")),
    ]
    parser = argparse.ArgumentParser()
    parser.add_argument("scene", help="Path to scene file (without .py extension)")
    parser.add_argument(
        "-p",
        "--processes",
        action="store",
        type=int,
        dest="processes",
        default=0,
        help="Number of processes (0=auto)",
    )
    args = parser.parse_args()
    if args.processes == 0:
        process_count = cpu_count()
    else:
        process_count = args.processes
        print("no")

    mod = importlib.import_module(args.scene)
    scene = Scene(mod.CAMERA, mod.OBJECTS, mod.LIGHTS, mod.WIDTH, mod.HEIGHT)
    engine = RenderEngine()

    os.chdir(os.path.dirname(os.path.abspath(mod.__file__)))
    with open(mod.RENDERED_IMG, "w") as img_fileobj:
        engine.render_multiprocess(scene, process_count, img_fileobj)
        print("yes")
