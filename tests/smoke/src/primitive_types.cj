package smoke

import interop_python.*
import std.math.numeric.BigInt

func runPrimitiveTypesSmoke(): Int64 {
    let boolValue: Extern<PythonRuntime> = PythonRuntime.toExtern(true)
    if (!PythonRuntime.fromExtern<Bool>(boolValue)) {
        println("unexpected Cangjie bool conversion")
        return 1
    }

    let intValue: Extern<PythonRuntime> = PythonRuntime.toExtern(Int64(42))
    if (PythonRuntime.fromExtern<Int64>(intValue) != 42) {
        println("unexpected Cangjie Int64 conversion")
        return 2
    }

    let stringValue: Extern<PythonRuntime> = PythonRuntime.toExtern("hello")
    if (PythonRuntime.fromExtern<String>(stringValue) != "hello") {
        println("unexpected Cangjie string conversion")
        return 3
    }

    let floatValue: Extern<PythonRuntime> = PythonRuntime.toExtern(Float64(42.5))
    if (PythonRuntime.fromExtern<Float64>(floatValue) != 42.5) {
        println("unexpected Cangjie Float64 conversion")
        return 4
    }

    let bigIntValue: Extern<PythonRuntime> = PythonRuntime.toExtern(BigInt.parse("9007199254740993"))
    if (PythonRuntime.fromExtern<BigInt>(bigIntValue) != BigInt.parse("9007199254740993")) {
        println("unexpected Cangjie BigInt conversion")
        return 5
    }

    let numberResult: Extern<PythonRuntime> = PythonRuntime.evalScript("1 + 2")
    if (PythonRuntime.fromExtern<Float64>(numberResult) != 3.0) {
        println("unexpected numeric eval result")
        return 6
    }

    let firstStringResult: Extern<PythonRuntime> = PythonRuntime.evalScript("'hello'")
    let secondStringResult: Extern<PythonRuntime> = PythonRuntime.evalScript("'world'")
    if (PythonRuntime.fromExtern<String>(firstStringResult) != "hello" ||
        PythonRuntime.fromExtern<String>(secondStringResult) != "world") {
        println("native value handles were overwritten by later eval")
        return 7
    }

    try {
        PythonRuntime.fromExtern<Float64>(boolValue)
        println("boolean converted to number unexpectedly")
        return 8
    } catch (_) {
        ()
    }

    println("primitive_types ok")
    return 0
}
