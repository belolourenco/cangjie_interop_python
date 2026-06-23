package extern_with_modules

import interop_python.PythonRuntime

public class Point {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, x: Float64, y: Float64) {
        println("Point constructor called with x: ${x}, y: ${y}")
        blob = module.Point(x, y)
    }

    // Shallow copy constructor!
    public init(extern: Extern<PythonRuntime>) {
        println("Point extern constructor called")
        blob = extern
    }

    // Deep copy constructor!
    public init(module: Extern<PythonRuntime>, other: Point) {
        println("Point copy constructor called with x: ${other.x}, y: ${other.y}")
        blob = module.Point(other.x, other.y)
    }

    public mut prop x: Float64 {
        get() {
            (Float64)blob.x
        }
        set(value) {
            blob.x = value
        }
    }

    public mut prop y: Float64 {
        get() {
            (Float64)blob.y
        }
        set(value) {
            blob.y = value
        }
    }

    public func distanceTo(other: Point): Float64 {
        (Float64)blob.distanceTo(other.blob)
    }
}

public interface Shape {

    func getBlob(): Extern<PythonRuntime>

    func name(): String {
        (String)getBlob().name()
    }

    func area(): Float64 {
        (Float64)getBlob().area()
    }

    func perimeter(): Float64 {
        (Float64)getBlob().perimeter()
    }
}

public class Rectangle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, topLeft: Point, bottomRight: Point) {
        println("Rectangle constructor called with topLeft: ${topLeft.x}, ${topLeft.y} and bottomRight: ${bottomRight.x}, ${bottomRight.y}")
        blob = module.Rectangle(topLeft.blob, bottomRight.blob)
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop topLeft: Point {
        get() {
            Point(blob.topLeft)
        }
        set(value) {
            blob.topLeft = value.blob
        }
    }

    public mut prop bottomRight: Point {
        get() {
            Point(blob.bottomRight)
        }
        set(value) {
            blob.bottomRight = value.blob
        }
    }

    public mut prop width: Float64 {
        get() {
            (Float64)blob.width
        }
        set(value) {
            blob.width = value
        }
    }

    public mut prop height: Float64 {
        get() {
            (Float64)blob.height
        }
        set(value) {
            blob.height = value
        }
    }
}

public class Circle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, center: Point, radius: Float64) {
        blob = module.Circle(center.blob, radius)
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop center: Point {
        get() {
            Point(blob.center)
        }
        set(value) {
            blob.center = value.blob
        }
    }

    public mut prop radius: Float64 {
        get() {
            (Float64)blob.radius
        }
        set(value) {
            blob.radius = value
        }
    }
}

public class Triangle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, a: Point, b: Point, c: Point) {
        blob = module.Triangle(a.blob, b.blob, c.blob)
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop a: Point {
        get() {
            Point(blob.a)
        }
        set(value) {
            blob.a = value.blob
        }
    }

    public mut prop b: Point {
        get() {
            Point(blob.b)
        }
        set(value) {
            blob.b = value.blob
        }
    }

    public mut prop c: Point {
        get() {
            Point(blob.c)
        }
        set(value) {
            blob.c = value.blob
        }
    }
}
