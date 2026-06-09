package extern_with_modules

import interop_python.*
import std.math.*
import std.collection.ArrayList


class AssertionFailedException <: Exception {

    public init(message: String) {
        super(message)
    }
}

func assert(condition: Bool, message: String) {
    if (!condition) {
        throw AssertionFailedException(message)
    }
}

func distance(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Float64 {
    sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
}

func area_rectangle(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Float64 {
    abs(x1 - x2) * abs(y1 - y2)
}

func perimeter_rectangle(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Float64 {
    abs(x1 - x2) * 2.0 + abs(y1 - y2) * 2.0
}

func area_circle(x: Float64, y: Float64, radius: Float64): Float64 {
    Float64.getPI() * radius * radius
}

func perimeter_circle(x: Float64, y: Float64, radius: Float64): Float64 {
    2.0 * Float64.getPI() * radius
}

func area_triangle(x1: Float64, y1: Float64, x2: Float64, y2: Float64, x3: Float64, y3: Float64): Float64 {
    let s = (x1 * y2 - x1 * y3 + x2 * y3 - x2 * y1 + x3 * y1 - x3 * y2) / 2.0
    abs(s)
}

func perimeter_triangle(x1: Float64, y1: Float64, x2: Float64, y2: Float64, x3: Float64, y3: Float64): Float64 {
    let a = distance(x1, y1, x2, y2)
    let b = distance(x2, y2, x3, y3)
    let c = distance(x3, y3, x1, y1)
    a + b + c
}

public func testExternWithModules() {
    let module: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/shape.py")

    // ---- Point ----
    let point1 = Point(module, 10.0, 20.0)
    println("Point 1: ${point1.x}, ${point1.y}")
    assert(point1.x == 10.0, "Point 1 x should be 10.0")
    assert(point1.y == 20.0, "Point 1 y should be 20.0")

    point1.x = 30.0
    println("Point 1 after setting x: ${point1.x}, ${point1.y}")
    assert(point1.x == 30.0, "Point 1 x should be 30.0")
    assert(point1.y == 20.0, "Point 1 y should be 20.0")

    let point2 = Point(module, point1)
    println("Point 2: ${point2.x}, ${point2.y}")
    assert(point2.x == 30.0, "Point 2 x should be 30.0")
    assert(point2.y == 20.0, "Point 2 y should be 20.0")

    point1.y = 40.0
    println("Point 1 after setting y: ${point1.x}, ${point1.y}")
    println("Point 2 after setting y: ${point2.x}, ${point2.y}")
    assert(point1.x == 30.0, "Point 1 x should be 30.0")
    assert(point1.y == 40.0, "Point 1 y should be 40.0")
    assert(point2.x == 30.0, "Point 2 x should be 30.0")
    assert(point2.y == 20.0, "Point 2 y should be 20.0")

    let point3 = Point(point1.blob)
    println("Point 3: ${point3.x}, ${point3.y}")
    point3.x = 40.0
    println("Point 1 after setting x: ${point1.x}, ${point1.y}")
    println("Point 2 after setting x: ${point2.x}, ${point2.y}")
    println("Point 3 after setting x: ${point3.x}, ${point3.y}")
    assert(point1.x == point3.x && point1.y == point3.y, "Point 1 should be equal to Point 3")
    assert(point2.x == 30.0, "Point 2 x should be 30.0")
    assert(point2.y == 20.0, "Point 2 y should be 20.0")

    println("Distance between point1 and point2: ${point1.distanceTo(point2)}")
    let distance12 = distance(point1.x, point1.y, point2.x, point2.y)
    assert(point1.distanceTo(point2) == distance12, "Distance between point1 and point2 should be ${distance12}")
    
    println("Distance between point1 and point3: ${point1.distanceTo(point3)}")
    let distance13 = distance(point1.x, point1.y, point3.x, point3.y)
    assert(point1.distanceTo(point3) == distance13, "Distance between point1 and point3 should be ${distance13}")
    
    println("Distance between point2 and point3: ${point2.distanceTo(point3)}")
    let distance23 = distance(point2.x, point2.y, point3.x, point3.y)
    assert(point2.distanceTo(point3) == distance23, "Distance between point2 and point3 should be ${distance23}")

    let point4 = Point(module, 0.0, 0.0)
    println("Point 4: ${point4.x}, ${point4.y}")
    assert(point4.x == 0.0 && point4.y == 0.0, "Point 4 should be (0.0, 0.0)")
    
    println("Distance between point1 and point4: ${point1.distanceTo(point4)}")
    let distance14 = distance(point1.x, point1.y, point4.x, point4.y)
    assert(point1.distanceTo(point4) == distance14, "Distance between point1 and point4 should be ${distance14}")

    let rectangle1 = Rectangle(module, point1, point4)
    println("Rectangle 1: (${rectangle1.topLeft.x}, ${rectangle1.topLeft.y}), (${rectangle1.bottomRight.x}, ${rectangle1.bottomRight.y})")
    assert(rectangle1.topLeft.x == point1.x &&
           rectangle1.topLeft.y == point1.y &&
           rectangle1.bottomRight.x == point4.x &&
           rectangle1.bottomRight.y == point4.y, "Rectangle 1 should be (${point1.x}, ${point1.y}), (${point4.x}, ${point4.y})")

    println("Rectangle 1 area: ${rectangle1.area()}")
    let area1 = area_rectangle(point1.x, point1.y, point4.x, point4.y)
    assert(rectangle1.area() == area1, "Rectangle 1 area should be ${area1}")
    
    println("Rectangle 1 perimeter: ${rectangle1.perimeter()}")
    let perimeter1 = perimeter_rectangle(point1.x, point1.y, point4.x, point4.y)
    assert(rectangle1.perimeter() == perimeter1, "Rectangle 1 perimeter should be ${perimeter1}")

    let point5 = rectangle1.topLeft
    println("Point 5: ${point5.x}, ${point5.y}")
    assert(point5.x == point1.x && point5.y == point1.y, "Point 5 should be (${point1.x}, ${point1.y})")

    let point6 = rectangle1.bottomRight
    println("Point 6: ${point6.x}, ${point6.y}")
    assert(point6.x == point4.x && point6.y == point4.y, "Point 6 should be (${point4.x}, ${point4.y})")


    rectangle1.topLeft.x = 12345.0
    println("Rectangle 1 after setting topLeft x: ${rectangle1.topLeft.x}, ${rectangle1.topLeft.y}")

    println("Point 1 after setting topLeft x: ${point1.x}, ${point1.y}")
    assert(point1.x == 12345.0, "Point 1 x should be 12345.0")
    assert(point1.y == 40.0, "Point 1 y should be 40.0")
    println("Point 5 after setting topLeft x: ${point5.x}, ${point5.y}")
    assert(point5.x == 12345.0, "Point 5 x should be 12345.0")
    assert(point5.y == 40.0, "Point 5 y should be 40.0")

    point1.y = 4321.0
    println("Point 1 after setting y: ${point1.x}, ${point1.y}")
    assert(point1.x == 12345.0, "Point 1 x should be 12345.0")
    assert(point1.y == 4321.0, "Point 1 y should be 4321.0")
    println("Point 5 after setting y: ${point5.x}, ${point5.y}")
    assert(point5.x == 12345.0, "Point 5 x should be 12345.0")
    assert(point5.y == 4321.0, "Point 5 y should be 4321.0")

    let circle1 = Circle(module, point1, 10.0)
    println("Circle 1: (${circle1.center.x}, ${circle1.center.y}), radius: ${circle1.radius}")
    assert(circle1.center.x == point1.x && circle1.center.y == point1.y, "Circle 1 center should be (${point1.x}, ${point1.y})")
    assert(circle1.radius == 10.0, "Circle 1 radius should be 10.0")

    println("Circle 1 area: ${circle1.area()}")
    let circle_area = area_circle(circle1.center.x, circle1.center.y, circle1.radius)
    assert(circle1.area() == circle_area, "Circle 1 area should be ${circle_area}")

    println("Circle 1 perimeter: ${circle1.perimeter()}")
    let circle_perimeter = perimeter_circle(circle1.center.x, circle1.center.y, circle1.radius)
    assert(circle1.perimeter() == circle_perimeter, "Circle 1 perimeter should be ${circle_perimeter}")


    let p1 = Point(module, 0.0, 0.0)
    let p2 = Point(module, 10.0, 0.0)
    let p3 = Point(module, 5.0, 5.0)
    
    let triangle1 = Triangle(module, p1, p2, p3)
    println("Triangle 1: (${triangle1.a.x}, ${triangle1.a.y}), (${triangle1.b.x}, ${triangle1.b.y}), (${triangle1.c.x}, ${triangle1.c.y})")
    assert(triangle1.a.x == p1.x && triangle1.a.y == p1.y, "Triangle 1 a should be (${p1.x}, ${p1.y})")
    assert(triangle1.b.x == p2.x && triangle1.b.y == p2.y, "Triangle 1 b should be (${p2.x}, ${p2.y})")
    assert(triangle1.c.x == p3.x && triangle1.c.y == p3.y, "Triangle 1 c should be (${p3.x}, ${p3.y})")

    println("Triangle 1 area: ${triangle1.area()}")
    let triangle_area = area_triangle(triangle1.a.x, triangle1.a.y, triangle1.b.x, triangle1.b.y, triangle1.c.x, triangle1.c.y)
    assert(abs(triangle1.area() - triangle_area) < 1e-6, "Triangle 1 area should be ${triangle_area}")

    println("Triangle 1 perimeter: ${triangle1.perimeter()}")
    let triangle_perimeter = perimeter_triangle(triangle1.a.x, triangle1.a.y, triangle1.b.x, triangle1.b.y, triangle1.c.x, triangle1.c.y)
    assert(abs(triangle1.perimeter() - triangle_perimeter) < 1e-6, "Triangle 1 perimeter should be ${triangle_perimeter}")

    let shapes = ArrayList<Shape>([rectangle1, circle1, triangle1])
    print_all_shapes(shapes)

}


func print_all_shapes(shapes: ArrayList<Shape>) {
    for (shape in shapes) {
        println("Shape: ${shape.name()}, area: ${shape.area()}, perimeter: ${shape.perimeter()}")
    }
}
