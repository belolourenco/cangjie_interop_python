package interop_python

import std.math.numeric.BigInt

foreign func runtime_create(): CPointer<Unit>
foreign func runtime_destroy(handle: CPointer<Unit>): Unit
foreign func runtime_last_error(handle: CPointer<Unit>): CString
foreign func runtime_enable_std_module(handle: CPointer<Unit>): Int64

foreign func runtime_eval_value(handle: CPointer<Unit>, source: CString): CPointer<Unit>
foreign func runtime_get_global_property(handle: CPointer<Unit>, name: CString): CPointer<Unit>
foreign func runtime_new_bool(handle: CPointer<Unit>, value: Int64): CPointer<Unit>
foreign func runtime_new_number(handle: CPointer<Unit>, value: Float64): CPointer<Unit>
foreign func runtime_new_integer(handle: CPointer<Unit>, value: CString): CPointer<Unit>
foreign func runtime_new_string(handle: CPointer<Unit>, value: CString): CPointer<Unit>
foreign func runtime_import_module(handle: CPointer<Unit>, path: CString): CPointer<Unit>

foreign func value_destroy(handle: CPointer<Unit>): Unit
foreign func value_kind(handle: CPointer<Unit>): Int64
foreign func value_to_bool(handle: CPointer<Unit>): Int64
foreign func value_to_number(handle: CPointer<Unit>): Float64
foreign func value_to_string(handle: CPointer<Unit>): CString
foreign func bridge_free_string(value: CString): Unit
foreign func value_is_array(handle: CPointer<Unit>): Int64
foreign func value_array_length(handle: CPointer<Unit>): Int64
foreign func value_get_property(handle: CPointer<Unit>, name: CString): CPointer<Unit>
foreign func value_set_property(handle: CPointer<Unit>, name: CString, value: CPointer<Unit>): Int64
foreign func value_get_index(handle: CPointer<Unit>, index: Int64): CPointer<Unit>
foreign func value_set_index(handle: CPointer<Unit>, index: Int64, value: CPointer<Unit>): Int64
foreign func value_call(function: CPointer<Unit>, thisValue: CPointer<Unit>, args: CPointer<CPointer<Unit>>, numArgs: Int32): CPointer<Unit>
foreign func value_construct(function: CPointer<Unit>, args: CPointer<CPointer<Unit>>, numArgs: Int32): CPointer<Unit>

private let pythonValueBoolKind: Int64 = 2
private let pythonValueNumberKind: Int64 = 3
private let pythonValueStringKind: Int64 = 4
private let pythonValueIntegerKind: Int64 = 5
private let pythonValueObjectKind: Int64 = 6
private let pythonValueCallableKind: Int64 = 7

private func createRuntime(): CPointer<Unit> {
    let handle = unsafe { runtime_create() }
    if (handle.isNull()) {
        throw ExternDynamicException("failed to create Python runtime")
    }

    handle
}

private func boolAsInt64(value: Bool): Int64 {
    if (value) {
        1
    } else {
        0
    }
}

private func ownedCStringToString(value: CString): String {
    if (value.isNull()) {
        return ""
    }

    let result = value.toString()
    unsafe { bridge_free_string(value) }
    result
}

private func runtimeError(runtime: CPointer<Unit>): String {
    unsafe { runtime_last_error(runtime).toString() }
}

private func valueFromRuntimeHandle(runtime: CPointer<Unit>, value: CPointer<Unit>): CPointer<Unit> {
    if (value.isNull()) {
        throw ExternDynamicException(runtimeError(runtime))
    }

    value
}

private func valueFromCallHandle(runtime: CPointer<Unit>, value: CPointer<Unit>): CPointer<Unit> {
    if (value.isNull()) {
        let message = runtimeError(runtime)
        if (message.isEmpty()) {
            throw ExternDynamicException("Python call failed")
        }
        throw ExternDynamicException(message)
    }

    value
}

private class PythonRuntimeRef {
    private let handle: CPointer<Unit>

    init(handle: CPointer<Unit>) {
        this.handle = handle
    }

    func pointer(): CPointer<Unit> {
        handle
    }

    ~init() {
        unsafe { runtime_destroy(handle) }
    }
}

private class PythonValueRef {
    private let handle: CPointer<Unit>

    init(handle: CPointer<Unit>) {
        this.handle = handle
    }

    func pointer(): CPointer<Unit> {
        handle
    }

    ~init() {
        unsafe { value_destroy(handle) }
    }
}

private class PythonMethodRef {
    let function: PythonValueRef
    let receiver: PythonValueRef

    init(function: PythonValueRef, receiver: PythonValueRef) {
        this.function = function
        this.receiver = receiver
    }
}

private func pythonExtern(handle: CPointer<Unit>): Extern<PythonRuntime> {
    Extern<PythonRuntime>(PythonValueRef(handle))
}

private func pythonExtern(ref: PythonValueRef): Extern<PythonRuntime> {
    Extern<PythonRuntime>(ref)
}

private func pythonExtern(method: PythonMethodRef): Extern<PythonRuntime> {
    Extern<PythonRuntime>(method)
}

private func externContentToRef(content: Any): PythonValueRef {
    match (content) {
        case value: PythonValueRef => value
        case value: CPointer<Unit> => PythonValueRef(value)
        case _ => throw ExternConversionException("Extern value does not contain a Python value")
    }
}

private func externContentToValue(content: Any): CPointer<Unit> {
    externContentToRef(content).pointer()
}

private func valueKind(value: CPointer<Unit>): Int64 {
    if (value.isNull()) {
        throw ExternDynamicException("Python value handle must not be null")
    }

    unsafe { value_kind(value) }
}

private func valueIsBool(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueBoolKind
}

private func valueIsNumber(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueNumberKind
}

private func valueIsInteger(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueIntegerKind
}

private func valueIsString(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueStringKind
}

private func valueIsObject(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueObjectKind || valueKind(value) == pythonValueCallableKind
}

private func valueIsCallable(value: CPointer<Unit>): Bool {
    valueKind(value) == pythonValueCallableKind
}

private func valueIsArray(value: CPointer<Unit>): Bool {
    unsafe { value_is_array(value) != 0 }
}

private func valueAsBool(value: CPointer<Unit>): Bool {
    if (!valueIsBool(value)) {
        throw ExternConversionException("Python value is not a boolean")
    }

    unsafe { value_to_bool(value) != 0 }
}

private func valueAsFloat64(value: CPointer<Unit>): Float64 {
    if (!valueIsNumber(value) && !valueIsInteger(value)) {
        throw ExternConversionException("Python value is not a number")
    }

    unsafe { value_to_number(value) }
}

private func valueAsString(value: CPointer<Unit>): String {
    if (!valueIsString(value) && !valueIsInteger(value)) {
        throw ExternConversionException("Python value is not a string")
    }

    ownedCStringToString(unsafe { value_to_string(value) })
}

private func getProperty(value: CPointer<Unit>, name: String): CPointer<Unit> {
    if (!valueIsObject(value)) {
        throw ExternDynamicException("Python value is not an object")
    }

    let cName = unsafe { LibC.mallocCString(name) }
    let result = unsafe { value_get_property(value, cName) }
    unsafe { LibC.free(cName) }
    if (result.isNull()) {
        throw ExternDynamicException("failed to read Python property")
    }

    result
}

private func setProperty(target: CPointer<Unit>, name: String, value: CPointer<Unit>): Unit {
    if (!valueIsObject(target)) {
        throw ExternDynamicException("Python value is not an object")
    }

    let cName = unsafe { LibC.mallocCString(name) }
    let status = unsafe { value_set_property(target, cName, value) }
    unsafe { LibC.free(cName) }
    if (status != 0) {
        throw ExternDynamicException("failed to write Python property")
    }
}

private func getIndex(value: CPointer<Unit>, index: Int64): CPointer<Unit> {
    if (!valueIsArray(value)) {
        throw ExternDynamicException("Expected Python sequence")
    }

    let length = unsafe { value_array_length(value) }
    if (index < 0 || index >= length) {
        throw ExternDynamicException("Python sequence index is out of range")
    }

    let result = unsafe { value_get_index(value, index) }
    if (result.isNull()) {
        throw ExternDynamicException("failed to read Python sequence index")
    }

    result
}

private func setIndex(target: CPointer<Unit>, index: Int64, value: CPointer<Unit>): Unit {
    if (!valueIsArray(target)) {
        throw ExternDynamicException("Expected Python sequence")
    }

    let length = unsafe { value_array_length(target) }
    if (index < 0 || index >= length) {
        throw ExternDynamicException("Python sequence index is out of range")
    }

    let status = unsafe { value_set_index(target, index, value) }
    if (status != 0) {
        throw ExternDynamicException("failed to write Python sequence index")
    }
}

private func pythonIndex(arg: Any): Int64 {
    match (arg) {
        case i: Int8 => Int64(i)
        case i: Int16 => Int64(i)
        case i: Int32 => Int64(i)
        case i: Int64 => i
        case i: UInt8 => Int64(i)
        case i: UInt16 => Int64(i)
        case i: UInt32 => Int64(i)
        case _ => throw ExternConversionException("Python sequence index must be an integer")
    }
}

private func python2Cangjie<T>(value: CPointer<Unit>, cjType: Option<T>) {
    match (cjType) {
        case _: Option<Bool> =>
            if (valueIsBool(value)) {
                return (valueAsBool(value) as T).getOrThrow()
            }
        case _: Option<String> =>
            if (valueIsString(value) || valueIsInteger(value)) {
                return (valueAsString(value) as T).getOrThrow()
            }
        case _: Option<Int8> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (Int8(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Int16> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (Int16(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Int32> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (Int32(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Int64> =>
            if (valueIsInteger(value)) {
                return (BigInt.parse(valueAsString(value)).toInt64() as T).getOrThrow()
            } else if (valueIsNumber(value)) {
                return (Int64(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<UInt8> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (UInt8(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<UInt16> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (UInt16(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<UInt32> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (UInt32(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<UInt64> =>
            if (valueIsInteger(value)) {
                return (BigInt.parse(valueAsString(value)).toUInt64() as T).getOrThrow()
            } else if (valueIsNumber(value)) {
                return (UInt64(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<BigInt> =>
            if (valueIsInteger(value)) {
                return (BigInt.parse(valueAsString(value)) as T).getOrThrow()
            } else if (valueIsNumber(value)) {
                return (BigInt(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Float16> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (Float16(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Float32> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (Float32(valueAsFloat64(value)) as T).getOrThrow()
            }
        case _: Option<Float64> =>
            if (valueIsNumber(value) || valueIsInteger(value)) {
                return (valueAsFloat64(value) as T).getOrThrow()
            }
        case _ => ()
    }

    throw ExternConversionException("Unsupported type conversion by PythonRuntime")
}

abstract public class PythonRuntime <: Runtime<PythonRuntime> {
    private static let runtimeOwner = PythonRuntimeRef(createRuntime())
    private static let runtime = runtimeOwner.pointer()

    private static func toPythonInteger(value: String): PythonValueRef {
        let cValue = unsafe { LibC.mallocCString(value) }
        let handle = unsafe { runtime_new_integer(runtime, cValue) }
        unsafe { LibC.free(cValue) }
        PythonValueRef(valueFromRuntimeHandle(runtime, handle))
    }

    private static func toPythonValue(value: Any): PythonValueRef {
        match (value) {
            case e: Extern<PythonRuntime> =>
                externContentToRef(getPayload(e))
            case handle: CPointer<Unit> =>
                PythonValueRef(handle)
            case i: Int8 =>
                toPythonInteger("${i}")
            case i: Int16 =>
                toPythonInteger("${i}")
            case i: Int32 =>
                toPythonInteger("${i}")
            case i: Int64 =>
                toPythonInteger("${i}")
            case i: UInt8 =>
                toPythonInteger("${i}")
            case i: UInt16 =>
                toPythonInteger("${i}")
            case i: UInt32 =>
                toPythonInteger("${i}")
            case i: UInt64 =>
                toPythonInteger("${i}")
            case i: BigInt =>
                toPythonInteger("${i}")
            case f: Float16 =>
                PythonValueRef(valueFromRuntimeHandle(runtime, unsafe { runtime_new_number(runtime, Float64(f)) }))
            case f: Float32 =>
                PythonValueRef(valueFromRuntimeHandle(runtime, unsafe { runtime_new_number(runtime, Float64(f)) }))
            case f: Float64 =>
                PythonValueRef(valueFromRuntimeHandle(runtime, unsafe { runtime_new_number(runtime, f) }))
            case b: Bool =>
                PythonValueRef(valueFromRuntimeHandle(runtime, unsafe { runtime_new_bool(runtime, boolAsInt64(b)) }))
            case s: String =>
                let cValue = unsafe { LibC.mallocCString(s) }
                let handle = unsafe { runtime_new_string(runtime, cValue) }
                unsafe { LibC.free(cValue) }
                PythonValueRef(valueFromRuntimeHandle(runtime, handle))
            case _ => throw ExternConversionException("Unsupported type by PythonRuntime")
        }
    }

    private static func toPythonValues(args: Array<Any>): Array<PythonValueRef> {
        args.map(toPythonValue)
    }

    private static func refPointer(ref: PythonValueRef): CPointer<Unit> {
        ref.pointer()
    }

    private static func callValue(function: PythonValueRef, receiver: PythonValueRef, args: Array<PythonValueRef>): CPointer<Unit> {
        let nativeArgs = args.map(refPointer)
        unsafe {
            let rawNativeArgs = acquireArrayRawData(nativeArgs)
            try {
                let result = valueFromCallHandle(runtime, value_call(function.pointer(), receiver.pointer(), rawNativeArgs.pointer, Int32(args.size)))
                releaseArrayRawData(rawNativeArgs)
                return result
            } catch (e: Exception) {
                releaseArrayRawData(rawNativeArgs)
                throw e
            }
        }
    }

    public static func evalScript(source: String): Extern<PythonRuntime> {
        let cSource = unsafe { LibC.mallocCString(source) }
        let value = unsafe { runtime_eval_value(runtime, cSource) }
        unsafe { LibC.free(cSource) }
        if (value.isNull()) {
            throw ExternDynamicException(runtimeError(runtime))
        }

        pythonExtern(value)
    }

    public static func enableStdModule(): Unit {
        let status = unsafe { runtime_enable_std_module(runtime) }
        if (status != 0) {
            throw ExternDynamicException(runtimeError(runtime))
        }
    }

    public static func globalAccess(name: String): Extern<PythonRuntime> {
        let cName = unsafe { LibC.mallocCString(name) }
        let value = unsafe { runtime_get_global_property(runtime, cName) }
        unsafe { LibC.free(cName) }
        if (value.isNull()) {
            throw ExternDynamicException(runtimeError(runtime))
        }

        pythonExtern(value)
    }

    public static func getModule(moduleName: String): Extern<PythonRuntime> {
        let cPath = unsafe { LibC.mallocCString(moduleName) }
        let namespace = unsafe { runtime_import_module(runtime, cPath) }
        unsafe { LibC.free(cPath) }
        if (namespace.isNull()) {
            throw ExternDynamicException(runtimeError(runtime))
        }

        pythonExtern(namespace)
    }

    public static func memberAccess(e: Extern<PythonRuntime>, field: String): Extern<PythonRuntime> {
        match (getPayload(e)) {
            case value: PythonValueRef =>
                let fieldValue = getProperty(value.pointer(), field)
                if (valueIsCallable(fieldValue)) {
                    pythonExtern(PythonMethodRef(PythonValueRef(fieldValue), value))
                } else {
                    pythonExtern(fieldValue)
                }
            case _ => throw ExternDynamicException("Unsupported member access")
        }
    }

    public static func functionCall(e: Extern<PythonRuntime>, args: Array<Any>): Extern<PythonRuntime> {
        match (getPayload(e)) {
            case method: PythonMethodRef =>
                let pythonArgs = toPythonValues(args)
                pythonExtern(callValue(method.function, method.receiver, pythonArgs))
            case value: PythonValueRef =>
                let pythonArgs = toPythonValues(args)
                pythonExtern(callValue(value, PythonValueRef(CPointer<Unit>()), pythonArgs))
            case _ => throw ExternDynamicException("Expected Python callable")
        }
    }

    public static func memberUpdate(e: Extern<PythonRuntime>, field: String, value: Any): Unit {
        match (getPayload(e)) {
            case target: PythonValueRef =>
                let pythonValue = toPythonValue(value)
                setProperty(target.pointer(), field, pythonValue.pointer())
            case _ => throw ExternDynamicException("Unsupported assignment")
        }
    }

    public static func indexAccess(e: Extern<PythonRuntime>, arg: Any): Extern<PythonRuntime> {
        match (getPayload(e)) {
            case value: PythonValueRef =>
                match (arg) {
                    case key: String => pythonExtern(getProperty(value.pointer(), key))
                    case _ => pythonExtern(getIndex(value.pointer(), pythonIndex(arg)))
                }
            case _ => throw ExternDynamicException("Expected Python sequence or mapping")
        }
    }

    public static func indexUpdate(e: Extern<PythonRuntime>, arg: Any, value: Any): Unit {
        match (getPayload(e)) {
            case target: PythonValueRef =>
                match (arg) {
                    case key: String =>
                        let pythonValue = toPythonValue(value)
                        setProperty(target.pointer(), key, pythonValue.pointer())
                    case _ =>
                        let pythonValue = toPythonValue(value)
                        setIndex(target.pointer(), pythonIndex(arg), pythonValue.pointer())
                }
            case _ => throw ExternDynamicException("Expected Python sequence or mapping")
        }
    }

    public static func fromExtern<T>(e: Extern<PythonRuntime>): T {
        let dummy: Option<T> = None
        python2Cangjie(externContentToValue(getPayload(e)), dummy)
    }

    public static func toExtern<T>(value: T): Extern<PythonRuntime> {
        pythonExtern(toPythonValue(value))
    }
}
