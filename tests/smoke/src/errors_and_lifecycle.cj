package smoke

import interop_python.*

func runErrorsAndLifecycleSmoke(): Int64 {
    PythonRuntime.evalScript("def fail():\n    raise Exception('function failed')\n")
    let throwingFunction: Extern<PythonRuntime> = PythonRuntime.globalAccess("fail")
    try {
        let _ = PythonRuntime.functionCall(throwingFunction, [])
        println("throwing function unexpectedly succeeded")
        return 1
    } catch (e: ForeignRuntimeException) {
        if (!e.message.contains("function failed") || !e.message.contains("in fail")) {
            println("throwing function traceback was not preserved")
            return 2
        }
    }

    PythonRuntime.evalScript("class Broken:\n    def __init__(self):\n        raise Exception('constructor failed')\n")
    let throwingConstructor: Extern<PythonRuntime> = PythonRuntime.globalAccess("Broken")
    try {
        let _ = PythonRuntime.functionCall(throwingConstructor, [])
        println("throwing constructor unexpectedly succeeded")
        return 3
    } catch (e: ForeignRuntimeException) {
        if (!e.message.contains("constructor failed") || !e.message.contains("in __init__")) {
            println("throwing constructor traceback was not preserved")
            return 4
        }
    }

    try {
        let _ = PythonRuntime.getModule("py_examples/nok/missing_module.py")
        println("missing module unexpectedly loaded")
        return 5
    } catch (e: ForeignRuntimeException) {
        if (!e.toString().contains("failed to read Python module file")) {
            println("missing module error message was not preserved")
            return 6
        }
    }

    try {
        let _ = PythonRuntime.getModule("py_examples/nok/broken_module.py")
        println("broken module unexpectedly loaded")
        return 7
    } catch (e: ForeignRuntimeException) {
        if (!e.message.contains("SyntaxError") || !e.message.contains("broken_module.py")) {
            println("broken module error message was not preserved")
            return 8
        }
    }

    try {
        let _ = PythonRuntime.evalScript("def broken(:")
        println("invalid Python unexpectedly succeeded")
        return 9
    } catch (e: ForeignRuntimeException) {
        if (!e.message.contains("SyntaxError") || !e.message.contains("<cangjie-python-eval>")) {
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

    checkExternExceptions()
    checkConcurrentErrors()

    println("errors_and_lifecycle ok")
    return 0
}

private func expectPythonError<E>(operation: String, action: () -> Unit): E where E <: Exception {
    try {
        action()
    } catch (e: Exception) {
        match (e as E) {
            case Some(expected) => return expected
            case None => throw Exception("${operation} raised ${e}")
        }
    }
    throw Exception("${operation} unexpectedly succeeded")
}

private func checkExternExceptions(): Unit {
    let target = PythonRuntime.evalScript("__import__('types').SimpleNamespace(value=1)")
    expectPythonError<ExternMemberAccessException>("missing member read", { => let _ = target.missing })
    expectPythonError<ExternMemberAccessException>("missing member update", { => target.missing = 1 })
    expectPythonError<ExternFunctionAccessException>("calling a non-callable value", { => let _ = target() })

    let sequence = PythonRuntime.evalScript("[0]")
    expectPythonError<ExternIndexedAccessException>("wrong index type", { => let _ = sequence["key"] })
    expectPythonError<ExternIndexedAccessException>("out-of-bounds index update", { => sequence[1] = 1 })

    let mapping = PythonRuntime.evalScript("{'key': 1}")
    expectPythonError<ExternIndexedAccessException>("missing dictionary key", { => let _ = mapping["missing"] })

    let function = PythonRuntime.evalScript("lambda x: x")
    expectPythonError<ExternFunctionCallException>("wrong argument count", { => let _ = function() })
    expectPythonError<ExternFunctionCallException>("unsupported argument", { => let _ = function(Object()) })

    expectPythonError<ExternConversionException>("unsupported conversion to Python", {
        => let _ = PythonRuntime.toExtern(Object())
    })
    expectPythonError<ExternConversionException>("Python integer outside float range", {
        => let _ = PythonRuntime.fromExtern<Float64>(PythonRuntime.evalScript("10 ** 1000"))
    })

    PythonRuntime.evalScript("""
class BadAccess:
    @property
    def value(self):
        raise AttributeError('getter failed')

    @value.setter
    def value(self, replacement):
        raise TypeError('setter failed')

    def __getitem__(self, key):
        raise RuntimeError('item access failed')

def raises_type_error(value):
    raise TypeError('function body failed')
""")
    let badAccess = PythonRuntime.globalAccess("BadAccess")()
    let getterError = expectPythonError<ForeignRuntimeException>("throwing getter", { => let _ = badAccess.value })
    let setterError = expectPythonError<ForeignRuntimeException>("throwing setter", { => badAccess.value = 1 })
    let indexError = expectPythonError<ForeignRuntimeException>("throwing subscript", { => let _ = badAccess[0] })
    let throwingCall = PythonRuntime.globalAccess("raises_type_error")
    let callError = expectPythonError<ForeignRuntimeException>("throwing call", { => let _ = throwingCall(1) })
    if (!getterError.message.contains("getter failed") ||
        !setterError.message.contains("setter failed") ||
        !indexError.message.contains("in __getitem__") ||
        !callError.message.contains("in raises_type_error")) {
        throw Exception("Python exception details were lost")
    }
}

private func checkConcurrentErrors(): Unit {
    PythonRuntime.evalScript("""
def delayed_failure(message):
    __import__('time').sleep(0.001)
    raise ValueError(message)
""")
    let fail = PythonRuntime.globalAccess("delayed_failure")
    let calls = Array<Future<String>>(4, { i =>
        spawn {
            expectPythonError<ForeignRuntimeException>("concurrent call", {
                => let _ = fail("concurrent error ${i}")
            }).message
        }
    })
    for (i in 0..calls.size) {
        let message = calls[i].get(Duration.second * 10)
        if (!message.contains("ValueError: concurrent error ${i}")) {
            throw Exception("Python error was lost or overwritten by another call")
        }
    }
}
