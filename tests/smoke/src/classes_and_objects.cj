package smoke

import interop_python.*

func runClassesAndObjectsSmoke(): Int64 {
    let objectResult: Extern<PythonRuntime> = PythonRuntime.evalScript("__import__('types').SimpleNamespace(name='Space Needle', active=True, coordinates=[-122.3493, 47.6205], nested=[[1, 2]])")

    let name: Extern<PythonRuntime> = PythonRuntime.memberAccess(objectResult, "name")
    if (PythonRuntime.fromExtern<String>(name) != "Space Needle") {
        println("unexpected object property value")
        return 1
    }

    PythonRuntime.memberUpdate(objectResult, "name", "Seattle Center")
    let updatedName: Extern<PythonRuntime> = PythonRuntime.memberAccess(objectResult, "name")
    if (PythonRuntime.fromExtern<String>(updatedName) != "Seattle Center") {
        println("object property write failed")
        return 2
    }

    let coordinatesValue: Extern<PythonRuntime> = PythonRuntime.memberAccess(objectResult, "coordinates")
    let longitude: Extern<PythonRuntime> = PythonRuntime.indexedAccess(coordinatesValue, 0)
    if (PythonRuntime.fromExtern<Float64>(longitude) != -122.3493) {
        println("unexpected array element")
        return 3
    }

    PythonRuntime.indexedUpdate(coordinatesValue, 0, -123.0)
    let updatedLongitude: Extern<PythonRuntime> = PythonRuntime.indexedAccess(coordinatesValue, 0)
    if (PythonRuntime.fromExtern<Float64>(updatedLongitude) != -123.0) {
        println("array index write failed")
        return 4
    }

    try {
        let _ = PythonRuntime.indexedAccess(coordinatesValue, 2)
        println("out-of-range array index unexpectedly succeeded")
        return 5
    } catch (_: ExternIndexedAccessException) {
        ()
    }

    PythonRuntime.evalScript("class Rectangle:\n    def __init__(self, width, height):\n        self.width = width\n        self.height = height\n    def area(self):\n        return self.width * self.height\n")
    let classValue: Extern<PythonRuntime> = PythonRuntime.globalAccess("Rectangle")
    let instance: Extern<PythonRuntime> = PythonRuntime.functionCall(classValue, [Int32(4), Int32(5)])

    let widthValue: Extern<PythonRuntime> = PythonRuntime.memberAccess(instance, "width")
    if (PythonRuntime.fromExtern<Float64>(widthValue) != 4.0) {
        println("constructor did not assign width")
        return 6
    }

    let areaMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(instance, "area")
    let area: Extern<PythonRuntime> = PythonRuntime.functionCall(areaMethod, [])
    if (PythonRuntime.fromExtern<Float64>(area) != 20.0) {
        println("constructed class method call failed")
        return 7
    }

    checkCompoundAssignments()

    println("classes_and_objects ok")
    return 0
}

private func checkCompoundAssignments(): Unit {
    var total: Extern<PythonRuntime> = 2
    total += 3

    let target = PythonRuntime.evalScript("__import__('types').SimpleNamespace(value=7, items=[10])")
    target.value -= total

    let indexCalls = Box(0)
    let nextIndex = { =>
        indexCalls.value += 1
        0
    }
    target.items[nextIndex()] += total

    if (PythonRuntime.fromExtern<Int64>(total) != 5 ||
        PythonRuntime.fromExtern<Int64>(-total) != -5 ||
        PythonRuntime.fromExtern<Int64>(target.value) != 2 ||
        PythonRuntime.fromExtern<Int64>(target.items[0]) != 15 ||
        indexCalls.value != 1) {
        throw Exception("dynamic operator or compound assignment failed")
    }

    let mapping = PythonRuntime.evalScript("{'items': 'item value'}")
    let key: Extern<PythonRuntime> = "items"
    let item = mapping[key]
    mapping.items()
    if (PythonRuntime.fromExtern<String>(item) != "item value") {
        throw Exception("Python item access failed")
    }
}
