package smoke

import interop_python.*

func runFunctionsSmoke(): Int64 {
    PythonRuntime.evalScript("def add(a, b):\n    return a + b\n")
    let add: Extern<PythonRuntime> = PythonRuntime.globalAccess("add")
    let sum: Extern<PythonRuntime> = PythonRuntime.functionCall(add, [Int32(2), Int32(3)])
    if (PythonRuntime.fromExtern<Float64>(sum) != 5.0) {
        println("two-argument function call failed")
        return 1
    }

    PythonRuntime.evalScript("def forty_two():\n    return 42\n")
    let fortyTwo: Extern<PythonRuntime> = PythonRuntime.globalAccess("forty_two")
    let fortyTwoResult: Extern<PythonRuntime> = PythonRuntime.functionCall(fortyTwo, [])
    if (PythonRuntime.fromExtern<Float64>(fortyTwoResult) != 42.0) {
        println("zero-argument function call failed")
        return 2
    }

    PythonRuntime.evalScript("def double(x):\n    return x * 2\n")
    let double: Extern<PythonRuntime> = PythonRuntime.globalAccess("double")
    let doubleResult: Extern<PythonRuntime> = PythonRuntime.functionCall(double, [Int32(21)])
    if (PythonRuntime.fromExtern<Float64>(doubleResult) != 42.0) {
        println("one-argument function call failed")
        return 3
    }

    PythonRuntime.evalScript("class Accumulator:\n    def __init__(self):\n        self.base = 10\n    def add(self, n):\n        return self.base + n\naccumulator = Accumulator()\n")
    let objectValue: Extern<PythonRuntime> = PythonRuntime.globalAccess("accumulator")
    let method: Extern<PythonRuntime> = PythonRuntime.memberAccess(objectValue, "add")
    let methodResult: Extern<PythonRuntime> = PythonRuntime.functionCall(method, [Int32(5)])
    if (PythonRuntime.fromExtern<Float64>(methodResult) != 15.0) {
        println("method call did not preserve this value")
        return 4
    }

    println("functions ok")
    return 0
}
