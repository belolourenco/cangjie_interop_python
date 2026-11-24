package interop_python

import std.math.numeric.BigInt
import std.sync.AtomicReference

@C
struct PythonBridgeError {
    var kind: Int64 = 0
    var message = CString(CPointer<UInt8>())

    func throwIfSet(): Unit {
        if (kind == 0) {
            return
        }

        let text = if (message.isNull()) {
            "Python bridge operation failed"
        } else {
            try {
                message.toString()
            } finally {
                unsafe { py_bridge_free_string(message) }
            }
        }

        // The discriminants match py_error_kind in python_bridge.h.
        match (kind) {
            case 2 => throw ExternMemberAccessException(text)
            case 3 => throw ExternIndexedAccessException(text)
            case 4 => throw ExternFunctionAccessException(text)
            case 5 => throw ExternFunctionCallException(text)
            case 6 => throw ExternConversionException(text)
            case _ => throw ForeignRuntimeException(text)
        }
    }
}

foreign func py_runtime_create(error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_destroy(handle: CPointer<Unit>): Unit
foreign func py_runtime_eval_value(handle: CPointer<Unit>, source: CString, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_get_global_property(handle: CPointer<Unit>, name: CString, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_new_bool(handle: CPointer<Unit>, value: Int64, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_new_number(handle: CPointer<Unit>, value: Float64, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_new_integer(handle: CPointer<Unit>, value: CString, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_new_string(handle: CPointer<Unit>, value: CString, size: Int64, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_runtime_import_module(handle: CPointer<Unit>, path: CString, error: CPointer<PythonBridgeError>): CPointer<Unit>

foreign func py_value_destroy(handle: CPointer<Unit>): Unit
foreign func py_value_kind(handle: CPointer<Unit>): Int64
foreign func py_value_to_bool(handle: CPointer<Unit>): Int64
foreign func py_value_is_callable(handle: CPointer<Unit>): Int64
foreign func py_value_to_number(handle: CPointer<Unit>, error: CPointer<PythonBridgeError>): Float64
foreign func py_value_to_string(handle: CPointer<Unit>, size: CPointer<Int64>, error: CPointer<PythonBridgeError>): CString
foreign func py_bridge_free_string(value: CString): Unit
foreign func py_value_get_property(handle: CPointer<Unit>, name: CString, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_value_set_property(handle: CPointer<Unit>, name: CString, value: CPointer<Unit>, error: CPointer<PythonBridgeError>): Unit
foreign func py_value_get_index(handle: CPointer<Unit>, index: CPointer<Unit>, error: CPointer<PythonBridgeError>): CPointer<Unit>
foreign func py_value_set_index(handle: CPointer<Unit>, index: CPointer<Unit>, value: CPointer<Unit>, error: CPointer<PythonBridgeError>): Unit
foreign func py_value_call(function: CPointer<Unit>, args: CPointer<CPointer<Unit>>, numArgs: Int64, error: CPointer<PythonBridgeError>): CPointer<Unit>

private let pythonValueBoolKind: Int64 = 2
private let pythonValueNumberKind: Int64 = 3
private let pythonValueStringKind: Int64 = 4
private let pythonValueIntegerKind: Int64 = 5

private let emptyReference = Object()
private let liveReference = AtomicReference<Object>(emptyReference)

// Keep native handle owners reachable across foreign calls, as std.regex does.
private func keepAlive(owner: Object): Unit {
    liveReference.store(owner)
    liveReference.store(emptyReference)
}

private class PythonRuntimeRef {
    let handle: CPointer<Unit>

    init() {
        var error = PythonBridgeError()
        handle = unsafe { py_runtime_create(inout error) }
        error.throwIfSet()
    }

    ~init() {
        unsafe { py_runtime_destroy(handle) }
    }
}

private class PythonValueRef {
    let handle: CPointer<Unit>

    init(handle: CPointer<Unit>, error: PythonBridgeError) {
        error.throwIfSet()
        if (handle.isNull()) {
            throw ForeignRuntimeException("Python bridge returned an empty handle")
        }
        this.handle = handle
    }

    ~init() {
        unsafe { py_value_destroy(handle) }
    }
}

private func pythonRef(value: Extern<PythonRuntime>, error: () -> Exception): PythonValueRef {
    match (Extern<PythonRuntime>.getPayload(value)) {
        case ref: PythonValueRef => ref
        case _ => throw error()
    }
}

private func pythonString(value: PythonValueRef): String {
    var error = PythonBridgeError()
    var size: Int64 = 0
    let text = unsafe { py_value_to_string(value.handle, inout size, inout error) }
    keepAlive(value)
    error.throwIfSet()

    try {
        let bytes = text.getChars()
        String.fromUtf8(Array<UInt8>(size, { i => unsafe { bytes.read(i) } }))
    } finally {
        unsafe { py_bridge_free_string(text) }
    }
}

private func pythonFloat(value: PythonValueRef): Float64 {
    var error = PythonBridgeError()
    let number = unsafe { py_value_to_number(value.handle, inout error) }
    keepAlive(value)
    error.throwIfSet()
    number
}

private func pythonInteger(value: PythonValueRef, kind: Int64): BigInt {
    if (kind == pythonValueIntegerKind) {
        return BigInt.parse(pythonString(value))
    }

    let number = pythonFloat(value)
    if (number.isNaN() || number.isInf()) {
        throw ExternConversionException("Non-finite Python number cannot be converted to an integer")
    }
    BigInt(number)
}

private func pythonToCangjie<T>(value: PythonValueRef, cjType: Option<T>): T {
    let kind = unsafe { py_value_kind(value.handle) }
    keepAlive(value)
    match (cjType) {
        case _: Option<Bool> =>
            if (kind == pythonValueBoolKind) {
                let result = unsafe { py_value_to_bool(value.handle) != 0 }
                keepAlive(value)
                return (result as T).getOrThrow()
            }
        case _: Option<String> =>
            if (kind == pythonValueStringKind || kind == pythonValueIntegerKind) {
                return (pythonString(value) as T).getOrThrow()
            }
        case _ => ()
    }

    if (kind == pythonValueNumberKind || kind == pythonValueIntegerKind) {
        match (cjType) {
            case _: Option<Int8> => return (pythonInteger(value, kind).toInt8() as T).getOrThrow()
            case _: Option<Int16> => return (pythonInteger(value, kind).toInt16() as T).getOrThrow()
            case _: Option<Int32> => return (pythonInteger(value, kind).toInt32() as T).getOrThrow()
            case _: Option<Int64> => return (pythonInteger(value, kind).toInt64() as T).getOrThrow()
            case _: Option<UInt8> => return (pythonInteger(value, kind).toUInt8() as T).getOrThrow()
            case _: Option<UInt16> => return (pythonInteger(value, kind).toUInt16() as T).getOrThrow()
            case _: Option<UInt32> => return (pythonInteger(value, kind).toUInt32() as T).getOrThrow()
            case _: Option<UInt64> => return (pythonInteger(value, kind).toUInt64() as T).getOrThrow()
            case _: Option<BigInt> => return (pythonInteger(value, kind) as T).getOrThrow()
            case _: Option<Float16> => return (Float16(pythonFloat(value)) as T).getOrThrow()
            case _: Option<Float32> => return (Float32(pythonFloat(value)) as T).getOrThrow()
            case _: Option<Float64> => return (pythonFloat(value) as T).getOrThrow()
            case _ => ()
        }
    }

    throw ExternConversionException("Unsupported type conversion by PythonRuntime")
}

public abstract class PythonRuntime <: ForeignRuntime<PythonRuntime> {
    private static let runtime = PythonRuntimeRef()

    private static func toPythonInteger(value: String): PythonValueRef {
        let text = unsafe { LibC.mallocCString(value) }.asResource()
        try {
            var error = PythonBridgeError()
            let handle = unsafe { py_runtime_new_integer(runtime.handle, text.value, inout error) }
            PythonValueRef(handle, error)
        } finally {
            text.close()
        }
    }

    private static func toPythonFloat(value: Float64): PythonValueRef {
        var error = PythonBridgeError()
        let handle = unsafe { py_runtime_new_number(runtime.handle, value, inout error) }
        PythonValueRef(handle, error)
    }

    private static func toPythonString(value: String): PythonValueRef {
        let text = unsafe { LibC.mallocCString(value) }.asResource()
        try {
            var error = PythonBridgeError()
            let handle = unsafe { py_runtime_new_string(runtime.handle, text.value, value.size, inout error) }
            PythonValueRef(handle, error)
        } finally {
            text.close()
        }
    }

    private static func toPythonValue(value: Any): PythonValueRef {
        match (value) {
            case e: Extern<PythonRuntime> =>
                pythonRef(e, { => ExternConversionException("Extern value does not contain a Python value") })
            case i: Int8 => toPythonInteger("${i}")
            case i: Int16 => toPythonInteger("${i}")
            case i: Int32 => toPythonInteger("${i}")
            case i: Int64 => toPythonInteger("${i}")
            case i: UInt8 => toPythonInteger("${i}")
            case i: UInt16 => toPythonInteger("${i}")
            case i: UInt32 => toPythonInteger("${i}")
            case i: UInt64 => toPythonInteger("${i}")
            case i: BigInt => toPythonInteger("${i}")
            case f: Float16 => toPythonFloat(Float64(f))
            case f: Float32 => toPythonFloat(Float64(f))
            case f: Float64 => toPythonFloat(f)
            case b: Bool =>
                var error = PythonBridgeError()
                let handle = unsafe { py_runtime_new_bool(runtime.handle, if (b) { 1 } else { 0 }, inout error) }
                PythonValueRef(handle, error)
            case s: String => toPythonString(s)
            case _ => throw ExternConversionException("Unsupported type by PythonRuntime")
        }
    }

    private static func toPythonIndex(index: Any): PythonValueRef {
        try {
            toPythonValue(index)
        } catch (e: ExternConversionException) {
            throw ExternIndexedAccessException(e.message)
        }
    }

    public static func evalScript(source: String): Extern<PythonRuntime> {
        try (text = unsafe { LibC.mallocCString(source) }.asResource()) {
            var error = PythonBridgeError()
            let handle = unsafe { py_runtime_eval_value(runtime.handle, text.value, inout error) }
            return Extern<PythonRuntime>(PythonValueRef(handle, error))
        }
    }

    public static func enableStdModule(): Unit {
        // Standard modules are available through getModule once CPython is initialized.
    }

    public static func globalAccess(name: String): Extern<PythonRuntime> {
        try (text = unsafe { LibC.mallocCString(name) }.asResource()) {
            var error = PythonBridgeError()
            let handle = unsafe { py_runtime_get_global_property(runtime.handle, text.value, inout error) }
            return Extern<PythonRuntime>(PythonValueRef(handle, error))
        }
    }

    public static func getModule(moduleName: String): Extern<PythonRuntime> {
        try (path = unsafe { LibC.mallocCString(moduleName) }.asResource()) {
            var error = PythonBridgeError()
            let handle = unsafe { py_runtime_import_module(runtime.handle, path.value, inout error) }
            return Extern<PythonRuntime>(PythonValueRef(handle, error))
        }
    }

    public static func memberAccess(e: Extern<PythonRuntime>, field: String): Extern<PythonRuntime> {
        let target = pythonRef(e, { => ExternMemberAccessException("Expected a Python value") })
        try (name = unsafe { LibC.mallocCString(field) }.asResource()) {
            var error = PythonBridgeError()
            let handle = unsafe { py_value_get_property(target.handle, name.value, inout error) }
            keepAlive(target)
            return Extern<PythonRuntime>(PythonValueRef(handle, error))
        }
    }

    public static func memberUpdate(e: Extern<PythonRuntime>, field: String, value: Any): Unit {
        let target = pythonRef(e, { => ExternMemberAccessException("Expected a Python value") })
        let replacement = toPythonValue(value)
        try (name = unsafe { LibC.mallocCString(field) }.asResource()) {
            var error = PythonBridgeError()
            unsafe { py_value_set_property(target.handle, name.value, replacement.handle, inout error) }
            keepAlive(target)
            keepAlive(replacement)
            error.throwIfSet()
        }
    }

    public static func indexedAccess(e: Extern<PythonRuntime>, index: Any): Extern<PythonRuntime> {
        let target = pythonRef(e, { => ExternIndexedAccessException("Expected a Python value") })
        let key = toPythonIndex(index)
        var error = PythonBridgeError()
        let handle = unsafe { py_value_get_index(target.handle, key.handle, inout error) }
        keepAlive(target)
        keepAlive(key)
        Extern<PythonRuntime>(PythonValueRef(handle, error))
    }

    public static func indexedUpdate(e: Extern<PythonRuntime>, index: Any, value: Any): Unit {
        let target = pythonRef(e, { => ExternIndexedAccessException("Expected a Python value") })
        let key = toPythonIndex(index)
        let replacement = toPythonValue(value)
        var error = PythonBridgeError()
        unsafe { py_value_set_index(target.handle, key.handle, replacement.handle, inout error) }
        keepAlive(target)
        keepAlive(key)
        keepAlive(replacement)
        error.throwIfSet()
    }

    public static func functionCall(e: Extern<PythonRuntime>, args: Array<Any>): Extern<PythonRuntime> {
        let function = pythonRef(e, { => ExternFunctionAccessException("Expected a Python callable") })
        if (unsafe { py_value_is_callable(function.handle) == 0 }) {
            throw ExternFunctionAccessException("Python value is not callable")
        }

        let pythonArgs = try {
            args.map(toPythonValue)
        } catch (e: ExternConversionException) {
            throw ExternFunctionCallException(e.message)
        }
        let nativeArgs = pythonArgs.map({ arg => arg.handle })
        var error = PythonBridgeError()
        let handle = unsafe {
            let raw = acquireArrayRawData(nativeArgs)
            try {
                py_value_call(function.handle, raw.pointer, nativeArgs.size, inout error)
            } finally {
                releaseArrayRawData(raw)
                keepAlive(function)
                keepAlive(Box(pythonArgs))
            }
        }
        Extern<PythonRuntime>(PythonValueRef(handle, error))
    }

    public static func fromExtern<R>(h: Extern<PythonRuntime>): R {
        let value = pythonRef(h, { => ExternConversionException("Extern value does not contain a Python value") })
        try {
            let resultType: Option<R> = None
            pythonToCangjie(value, resultType)
        } catch (e: OverflowException) {
            throw ExternConversionException(e.message)
        } catch (e: IllegalArgumentException) {
            throw ExternConversionException(e.message)
        }
    }

    public static func toExtern<R>(v: R): Extern<PythonRuntime> {
        Extern<PythonRuntime>(toPythonValue(v))
    }
}
