import math


class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def distanceTo(self, other):
        return math.sqrt((self.x - other.x) ** 2 + (self.y - other.y) ** 2)


class Shape:
    def name(self):
        return "Shape"

    def area(self):
        raise Exception("Shape.area must be implemented by subclasses")

    def perimeter(self):
        raise Exception("Shape.perimeter must be implemented by subclasses")


class Rectangle(Shape):
    def __init__(self, topLeft, bottomRight):
        if isinstance(topLeft, (int, float)) and isinstance(bottomRight, (int, float)):
            self.topLeft = Point(0, 0)
            self.bottomRight = Point(float(topLeft), float(bottomRight))
        else:
            self.topLeft = topLeft
            self.bottomRight = bottomRight

    def name(self):
        return "Rectangle"

    @property
    def width(self):
        return self.bottomRight.x - self.topLeft.x

    @width.setter
    def width(self, value):
        self.bottomRight.x = self.topLeft.x + value

    @property
    def height(self):
        return self.bottomRight.y - self.topLeft.y

    @height.setter
    def height(self, value):
        self.bottomRight.y = self.topLeft.y + value

    def getWidth(self):
        return self.width

    def getHeight(self):
        return self.height

    def area(self):
        return abs(self.width) * abs(self.height)

    def perimeter(self):
        return abs(self.width) * 2.0 + abs(self.height) * 2.0


class Circle(Shape):
    def __init__(self, center, radius):
        self.center = center
        self.radius = radius

    def name(self):
        return "Circle"

    def area(self):
        radius = abs(self.radius)
        return math.pi * radius * radius

    def perimeter(self):
        return math.pi * abs(self.radius) * 2.0


class Triangle(Shape):
    def __init__(self, a, b, c):
        self.a = a
        self.b = b
        self.c = c

    def name(self):
        return "Triangle"

    def area(self):
        ab = self.a.distanceTo(self.b)
        bc = self.b.distanceTo(self.c)
        ca = self.c.distanceTo(self.a)
        s = (ab + bc + ca) / 2.0
        return math.sqrt(max(0.0, s * (s - ab) * (s - bc) * (s - ca)))

    def perimeter(self):
        return self.a.distanceTo(self.b) + self.b.distanceTo(self.c) + self.c.distanceTo(self.a)
