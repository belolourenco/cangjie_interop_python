package smoke

import interop_python.*

func runErrorsAndLifecycleSmoke(): Int64 {
    PythonRuntime.evalScript("def fail():\n    raise Exception('function failed')\n")
    let throwingFunction: Extern<PythonRuntime> = PythonRuntime.globalAccess("fail")
    try {
        let unexpected: Extern<PythonRuntime> = PythonRuntime.functionCall(throwingFunction, [])
        println("throwing function unexpectedly succeeded")
        return 1
    } catch (e: Exception) {
        if (!e.toString().contains("function failed")) {
            println("throwing function error message was not preserved")
            return 2
        }
    }

    PythonRuntime.evalScript("class Broken:\n    def __init__(self):\n        raise Exception('constructor failed')\n")
    let throwingConstructor: Extern<PythonRuntime> = PythonRuntime.globalAccess("Broken")
    try {
        let unexpected: Extern<PythonRuntime> = PythonRuntime.functionCall(throwingConstructor, [])
        println("throwing constructor unexpectedly succeeded")
        return 3
    } catch (e: Exception) {
        if (!e.toString().contains("constructor failed")) {
            println("throwing constructor error message was not preserved")
            return 4
        }
    }

    try {
        let unexpected: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/nok/missing_module.py")
        println("missing module unexpectedly loaded")
        return 5
    } catch (e: Exception) {
        if (!e.toString().contains("failed to read Python module file")) {
            println("missing module error message was not preserved")
            return 6
        }
    }

    try {
        let unexpected: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/nok/broken_module.py")
        println("broken module unexpectedly loaded")
        return 7
    } catch (e: Exception) {
        if (e.toString().isEmpty()) {
            println("broken module error message was not preserved")
            return 8
        }
    }

    try {
        let unexpected: Extern<PythonRuntime> = PythonRuntime.evalScript("def broken(:")
        println("invalid Python unexpectedly succeeded")
        return 9
    } catch (e: Exception) {
        if (e.toString().isEmpty()) {
            println("missing Python syntax error message")
            return 10
        }
    }

    for (_ in 0..100) {
        let result: Extern<PythonRuntime> = PythonRuntime.evalScript("1 + 2")
        if (PythonRuntime.fromExtern<Float64>(result) != 3.0) {
            println("repeated eval failed")
            return 11
        }
    }

    println("errors_and_lifecycle ok")
    return 0
}
