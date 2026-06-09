import math
from types import SimpleNamespace


def my_python_function():
    print("Just a dummy message from Python")
    x = 10
    while (x > 0):
        print(f"Counting down: {x}")
        x -= 1
    return "my_python_function called"


globalBoolean = True
globalNumber = 42.4242
globalString = "hello from Python"
globalArray = [1, 2, 3]
globalObject = SimpleNamespace(
    name="global object",
    enabled=True,
    values=[10, 20, 30],
)
globalStringNumberMap = {
    "one": 1,
    "two": 2,
    "answer": 42,
}


def lookup(lat, long):
    return SimpleNamespace(
        coordinates=[long, lat],
        name="Space Needle",
        city="Seattle",
        category="Landmark",
    )


class Shape:
    def area(self):
        raise Exception("Shape.area must be implemented by subclasses")

    def perimeter(self):
        raise Exception("Shape.perimeter must be implemented by subclasses")


class Circle(Shape):
    def __init__(self, radius):
        self.radius = radius

    def getRadius(self):
        return self.radius

    def area(self):
        return math.pi * self.radius ** 2

    def perimeter(self):
        return 2 * math.pi * self.radius


class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def getWidth(self):
        return self.width

    def getHeight(self):
        return self.height

    def area(self):
        return self.width * self.height

    def perimeter(self):
        return 2 * (self.width + self.height)


class Triangle(Shape):
    def __init__(self, base, height):
        self.base = base
        self.height = height

    def getBase(self):
        return self.base

    def getHeight(self):
        return self.height

    def area(self):
        return 0.5 * self.base * self.height

    def perimeter(self):
        return 3 * self.base


circle = Circle(5)
rectangle = Rectangle(4, 6)
triangle = Triangle(3, 4)


def createRectangle():
    return Rectangle(12, 13)
