package smoke

import interop_python.*

func runLoadModulesSmoke(): Int64 {
    PythonRuntime.enableStdModule()
    PythonRuntime.enableStdModule()

    let module: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/ok/shape_module.py")

    let lookup: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "lookup")
    let siteValue: Extern<PythonRuntime> = PythonRuntime.functionCall(lookup, [47.6205, -122.3493])
    let siteName: Extern<PythonRuntime> = PythonRuntime.memberAccess(siteValue, "name")
    if (PythonRuntime.fromExtern<String>(siteName) != "Space Needle") {
        println("module function returned unexpected object")
        return 1
    }

    let coordinatesValue: Extern<PythonRuntime> = PythonRuntime.memberAccess(siteValue, "coordinates")
    let longitude: Extern<PythonRuntime> = PythonRuntime.indexAccess(coordinatesValue, 0)
    if (PythonRuntime.fromExtern<Float64>(longitude) != -122.3493) {
        println("module function returned unexpected longitude")
        return 2
    }

    let rectangleClass: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "Rectangle")
    let instance: Extern<PythonRuntime> = PythonRuntime.functionCall(rectangleClass, [Int32(6), Int32(7)])
    let areaMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(instance, "area")
    let area: Extern<PythonRuntime> = PythonRuntime.functionCall(areaMethod, [])
    if (PythonRuntime.fromExtern<Float64>(area) != 42.0) {
        println("module class export did not work")
        return 3
    }

    let marker: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "moduleMarker")
    let cachedModule: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/ok/shape_module.py")
    let cachedMarker: Extern<PythonRuntime> = PythonRuntime.memberAccess(cachedModule, "moduleMarker")
    if (PythonRuntime.fromExtern<Float64>(marker) != PythonRuntime.fromExtern<Float64>(cachedMarker)) {
        println("module cache did not preserve evaluated namespace")
        return 4
    }

    try {
        let nonFunction: Extern<PythonRuntime> = PythonRuntime.memberAccess(module, "moduleMarker")
        let unexpected: Extern<PythonRuntime> = PythonRuntime.functionCall(nonFunction, [])
        println("module call unexpectedly accepted a non-function")
        return 5
    } catch (_) {
        ()
    }

    println("load_modules ok")
    return 0
}
