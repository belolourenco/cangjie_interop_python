package extern_with_modules

import interop_python.*

public class Point {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, x: Float64, y: Float64) {
        println("Point constructor called with x: ${x}, y: ${y}")
        // blob = module.Point(x, y)
        // ->
        let pointConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Point")
        blob = PythonRuntime.functionCall(pointConstructor, [x, y])
    }

    // Shallow copy constructor!
    public init(extern: Extern<PythonRuntime>) {
        println("Point extern constructor called")
        blob = extern
    }

    // Deep copy constructor!
    public init(module: Extern<PythonRuntime>, other: Point) {
        println("Point copy constructor called with x: ${other.x}, y: ${other.y}")
        // blob = module.Point(other.x, other.y)
        // ->
        let pointConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Point")
        blob = PythonRuntime.functionCall(pointConstructor, [other.x, other.y])
    }

    public mut prop x: Float64 {
        get() {
            // blob.x
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "x")
            PythonRuntime.fromExtern<Float64>(value)
        }
        set(value) {
            // blob.x = value
            // ->
            PythonRuntime.memberUpdate(blob, "x", value)
        }
    }

    public mut prop y: Float64 {
        get() {
            // blob.y
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "y")
            PythonRuntime.fromExtern<Float64>(value)
        }
        set(value) {
            // blob.y = value
            // ->
            PythonRuntime.memberUpdate(blob, "y", value)
        }
    }

    public func distanceTo(other: Point): Float64 {
        // blob.distanceTo(other.blob)
        // ->
        let distanceToMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "distanceTo")
        let result: Extern<PythonRuntime> = PythonRuntime.functionCall(distanceToMethod, [other.blob])
        PythonRuntime.fromExtern<Float64>(result)
    }
}

public interface Shape {

    func getBlob(): Extern<PythonRuntime>

    func name(): String {
        // getBlob().name()
        // ->
        let nameMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(getBlob(), "name")
        let result: Extern<PythonRuntime> = PythonRuntime.functionCall(nameMethod, [])
        PythonRuntime.fromExtern<String>(result)
    }

    func area(): Float64 {
        // getBlob().area()
        // ->
        let areaMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(getBlob(), "area")
        let result: Extern<PythonRuntime> = PythonRuntime.functionCall(areaMethod, [])
        PythonRuntime.fromExtern<Float64>(result)
    }

    func perimeter(): Float64 {
        // getBlob().perimeter()
        // ->
        let perimeterMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(getBlob(), "perimeter")
        let result: Extern<PythonRuntime> = PythonRuntime.functionCall(perimeterMethod, [])
        PythonRuntime.fromExtern<Float64>(result)
    }
}

public class Rectangle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, topLeft: Point, bottomRight: Point) {
        println("Rectangle constructor called with topLeft: ${topLeft.x}, ${topLeft.y} and bottomRight: ${bottomRight.x}, ${bottomRight.y}")
        // blob = module.Rectangle(topLeft.blob, bottomRight.blob)
        // ->
        let rectangleConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Rectangle")
        blob = PythonRuntime.functionCall(rectangleConstructor, [topLeft.blob, bottomRight.blob])
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop topLeft: Point {
        get() {
            // Point(blob.topLeft)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "topLeft")
            Point(value)
        }
        set(value) {
            // blob.topLeft = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "topLeft", value.blob)
        }
    }

    public mut prop bottomRight: Point {
        get() {
            // Point(blob.bottomRight)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "bottomRight")
            Point(value)
        }
        set(value) {
            // blob.bottomRight = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "bottomRight", value.blob)
        }
    }

    public mut prop width: Float64 {
        get() {
            // blob.width
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "width")
            PythonRuntime.fromExtern<Float64>(value)
        }
        set(value) {
            // blob.width = value
            // ->
            PythonRuntime.memberUpdate(blob, "width", value)
        }
    }

    public mut prop height: Float64 {
        get() {
            // blob.height
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "height")
            PythonRuntime.fromExtern<Float64>(value)
        }
        set(value) {
            // blob.height = value
            // ->
            PythonRuntime.memberUpdate(blob, "height", value)
        }
    }
}

public class Circle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, center: Point, radius: Float64) {
        // blob = module.Circle(center.blob, radius)
        // ->
        let circleConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Circle")
        blob = PythonRuntime.functionCall(circleConstructor, [center.blob, radius])
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop center: Point {
        get() {
            // Point(blob.center)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "center")
            Point(value)
        }
        set(value) {
            // blob.center = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "center", value.blob)
        }
    }

    public mut prop radius: Float64 {
        get() {
            // blob.radius
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "radius")
            PythonRuntime.fromExtern<Float64>(value)
        }
        set(value) {
            // blob.radius = value
            // ->
            PythonRuntime.memberUpdate(blob, "radius", value)
        }
    }
}

public class Triangle <: Shape {
    public let blob: Extern<PythonRuntime>

    public init(module: Extern<PythonRuntime>, a: Point, b: Point, c: Point) {
        // blob = module.Triangle(a.blob, b.blob, c.blob)
        // ->
        let triangleConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Triangle")
        blob = PythonRuntime.functionCall(triangleConstructor, [a.blob, b.blob, c.blob])
    }

    public init(extern: Extern<PythonRuntime>) {
        blob = extern
    }

    public func getBlob(): Extern<PythonRuntime> {
        blob
    }

    public mut prop a: Point {
        get() {
            // Point(blob.a)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "a")
            Point(value)
        }
        set(value) {
            // blob.a = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "a", value.blob)
        }
    }

    public mut prop b: Point {
        get() {
            // Point(blob.b)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "b")
            Point(value)
        }
        set(value) {
            // blob.b = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "b", value.blob)
        }
    }

    public mut prop c: Point {
        get() {
            // Point(blob.c)
            // ->
            let value: Extern<PythonRuntime> = PythonRuntime.memberAccess(blob, "c")
            Point(value)
        }
        set(value) {
            // blob.c = value.blob
            // ->
            PythonRuntime.memberUpdate(blob, "c", value.blob)
        }
    }
}
