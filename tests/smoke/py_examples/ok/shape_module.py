import random
from types import SimpleNamespace


moduleMarker = random.random()


def lookup(lat, long):
    return SimpleNamespace(
        name="Space Needle",
        coordinates=[long, lat],
    )


class Rectangle:
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height
