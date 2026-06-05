package extern_with_modules

import interop_python.*
import std.collection.ArrayList

class AssertionFailedException <: Exception {

    public init(message: String) {
        super(message)
    }
}

func assert(condition: Bool, message: String) {
    if (!condition) {
        throw AssertionFailedException(message)
    }
}

public func testExternWithModules1() {
    // ---- Python Module ----
    let jsModule: Extern<PythonRuntime> = PythonRuntime.getModule("py_examples/my_module.py")

    // ---- my_python_function ----

    // jsModule.my_python_function()
    // ->
    let my_python_function: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "my_python_function")
    PythonRuntime.functionCall(my_python_function, [])

    // ---- lookup ----

    // let lookupResult: Extern<PythonRuntime> = jsModule.lookup(42.4242, 1.111)
    // ->
    let lookup: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "lookup")
    let lookupResult: Extern<PythonRuntime> = PythonRuntime.functionCall(lookup, [42.4242, 1.111])

    // println("Lookup coordinates: (${(lookupResult.coordinates[0] as Float64).getOrThrow()}, ${(lookupResult.coordinates[1] as Float64).getOrThrow()})")
    // ->
    let lookup_coordinates: Extern<PythonRuntime> = PythonRuntime.memberAccess(lookupResult, "coordinates")
    let lookup_coordinates_0: Extern<PythonRuntime> = PythonRuntime.indexAccess(lookup_coordinates, 0)
    let lookup_coordinates_1: Extern<PythonRuntime> = PythonRuntime.indexAccess(lookup_coordinates, 1)
    println("Lookup coordinates: (${PythonRuntime.fromExtern<Float64>(lookup_coordinates_0)}, ${PythonRuntime.fromExtern<Float64>(lookup_coordinates_1)})")

    // println("Lookup result: ${lookupResult.name}")
    // ->
    let lookup_name: Extern<PythonRuntime> = PythonRuntime.memberAccess(lookupResult, "name")
    println("Lookup name: ${PythonRuntime.fromExtern<String>(lookup_name)}")

    // println("Lookup result: ${lookupResult.city}")
    // ->
    let lookup_city: Extern<PythonRuntime> = PythonRuntime.memberAccess(lookupResult, "city")
    println("Lookup city: ${PythonRuntime.fromExtern<String>(lookup_city)}")

    // println("Lookup result: ${lookupResult.category}")
    // ->
    let lookup_category: Extern<PythonRuntime> = PythonRuntime.memberAccess(lookupResult, "category")
    println("Lookup category: ${PythonRuntime.fromExtern<String>(lookup_category)}")

    // ---- Rectangle ----

    // let rectangle: Extern<PythonRuntime> = jsModule.Rectangle(10, 11)
    // ->
    let rectangleConstructor: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "Rectangle")
    let rectangleObject: Extern<PythonRuntime> = PythonRuntime.functionCall(rectangleConstructor, [10, 11])

    // let rectangleWidth: Extern<PythonRuntime> = rectangleObject.getWidth()
    // ->
    let rectangleWidthMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject, "getWidth")
    let rectangleWidthResult: Extern<PythonRuntime> = PythonRuntime.functionCall(rectangleWidthMethod, [])
    println("Rectangle width: ${PythonRuntime.fromExtern<Float64>(rectangleWidthResult)}")

    // let rectangleHeight: Extern<PythonRuntime> = rectangleObject.getHeight()
    // ->
    let rectangleHeightMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject, "getHeight")
    let rectangleHeightResult: Extern<PythonRuntime> = PythonRuntime.functionCall(rectangleHeightMethod, [])
    println("Rectangle height: ${PythonRuntime.fromExtern<Float64>(rectangleHeightResult)}")

    // ---- createRectangle ----

    // let rectangleObject2: Extern<PythonRuntime> = jsModule.createRectangle()
    // ->
    let createRectangleMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "createRectangle")
    let rectangleObject2: Extern<PythonRuntime> = PythonRuntime.functionCall(createRectangleMethod, [])

    // rectangleObject2.width = 42
    // ->
    PythonRuntime.memberUpdate(rectangleObject2, "width", 42.0)

    // let rectangleWidth2: Extern<PythonRuntime> = rectangleObject2.width
    // ->
    let rectangleWidthResult2: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject2, "width")
    println("Rectangle width: ${PythonRuntime.fromExtern<Float64>(rectangleWidthResult2)}")

    // let rectangleHeight2: Extern<PythonRuntime> = rectangleObject2.height
    // ->
    let rectangleHeightResult2: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject2, "height")
    println("Rectangle height: ${PythonRuntime.fromExtern<Float64>(rectangleHeightResult2)}")

    // let area = rectangleObject2.area()
    // ->
    let areaMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject2, "area")
    let areaResult: Extern<PythonRuntime> = PythonRuntime.functionCall(areaMethod, [])
    println("Rectangle area: ${PythonRuntime.fromExtern<Float64>(areaResult)}")

    // let perimeter = rectangleObject2.perimeter()
    // ->
    let perimeterMethod: Extern<PythonRuntime> = PythonRuntime.memberAccess(rectangleObject2, "perimeter")
    let perimeterResult: Extern<PythonRuntime> = PythonRuntime.functionCall(perimeterMethod, [])
    println("Rectangle perimeter: ${PythonRuntime.fromExtern<Float64>(perimeterResult)}")

    // ---- accessing global variables ----

    // let globalBoolean: Extern<PythonRuntime> = jsModule.globalBoolean
    // ->
    let globalBoolean: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalBoolean")
    println("Global boolean: ${PythonRuntime.fromExtern<Bool>(globalBoolean)}")

    // let globalNumber: Extern<PythonRuntime> = jsModule.globalNumber
    // ->
    let globalNumber: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalNumber")
    println("Global number: ${PythonRuntime.fromExtern<Float64>(globalNumber)}")

    // let globalString: Extern<PythonRuntime> = jsModule.globalString
    // ->
    let globalString: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalString")
    println("Global string: ${PythonRuntime.fromExtern<String>(globalString)}")

    // ---- array access and assignment ----

    // let globalArray: Extern<PythonRuntime> = jsModule.globalArray
    // ->
    let globalArray: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalArray")
    let arrayElements: ArrayList<Int64> = convertArrayToArrayList(globalArray)
    println("Global array elements: ${arrayElements}")
    assert(arrayElements[0] == 1, "Global array element 0 should be 1")
    assert(arrayElements[1] == 2, "Global array element 1 should be 2")
    assert(arrayElements[2] == 3, "Global array element 2 should be 3")

    // globalArray[1] = 42
    // ->
    PythonRuntime.indexUpdate(globalArray, 1, 42)
    let arrayElements2: ArrayList<Int64> = convertArrayToArrayList(globalArray)
    println("Global array elements: ${arrayElements2}")
    assert(arrayElements2[0] == 1, "Global array element 0 should be 1")
    assert(arrayElements2[1] == 42, "Global array element 1 should be 42")
    assert(arrayElements2[2] == 3, "Global array element 2 should be 3")

    try {
        // globalArray[-1]
        // ->
        PythonRuntime.indexAccess(globalArray, -1)
        throw AssertionFailedException("Global array element -1 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }


    try {
        // globalArray[-1] = 42
        // ->
        PythonRuntime.indexUpdate(globalArray, -1, 42)
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    try {
        // globalArray[3]
        // ->
        let x = PythonRuntime.indexAccess(globalArray, 3)
        println("Global array element 3: ${PythonRuntime.fromExtern<Int64>(x)}")
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    try {
        // globalArray[3] = 42
        // ->
        PythonRuntime.indexUpdate(globalArray, 3, 42)
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    // ---- global object ----

    // let globalObject: Extern<PythonRuntime> = jsModule.globalObject
    // ->
    let globalObject: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalObject")

    // let globalObjectName: Extern<PythonRuntime> = globalObject.name
    // ->
    let globalObjectName: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "name")
    println("Global object name: ${PythonRuntime.fromExtern<String>(globalObjectName)}")
    assert(PythonRuntime.fromExtern<String>(globalObjectName) == "global object", "Global object name should be 'global object'")

    // let globalObjectEnabled: Extern<PythonRuntime> = globalObject.enabled
    // ->
    let globalObjectEnabled: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "enabled")
    println("Global object enabled: ${PythonRuntime.fromExtern<Bool>(globalObjectEnabled)}")
    assert(PythonRuntime.fromExtern<Bool>(globalObjectEnabled) == true, "Global object enabled should be true")

    // let globalObjectValues: Extern<PythonRuntime> = globalObject.values
    // ->
    let globalObjectValues: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "values")
    let globalObjectValuesElements: ArrayList<Int64> = convertArrayToArrayList(globalObjectValues)
    println("Global object values elements: ${globalObjectValuesElements}")
    assert(globalObjectValuesElements[0] == 10, "Global object values element 0 should be 10")
    assert(globalObjectValuesElements[1] == 20, "Global object values element 1 should be 20")
    assert(globalObjectValuesElements[2] == 30, "Global object values element 2 should be 30")

    // globalObject.name = "global object 2"
    // ->
    PythonRuntime.memberUpdate(globalObject, "name", "global object 2")
    let globalObjectName2: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "name")
    println("Global object name: ${PythonRuntime.fromExtern<String>(globalObjectName2)}")
    assert(PythonRuntime.fromExtern<String>(globalObjectName2) == "global object 2", "Global object name should be 'global object 2'")

    // globalObject.enabled = false
    // ->
    PythonRuntime.memberUpdate(globalObject, "enabled", false)
    let globalObjectEnabled2: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "enabled")
    println("Global object enabled: ${PythonRuntime.fromExtern<Bool>(globalObjectEnabled2)}")
    assert(PythonRuntime.fromExtern<Bool>(globalObjectEnabled2) == false, "Global object enabled should be false")

    // globalObject.values[1] = 42
    // ->
    let globalObjectValues2: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "values")
    PythonRuntime.indexUpdate(globalObjectValues2, 1, 42)
    let globalObjectValuesElements2: ArrayList<Int64> = convertArrayToArrayList(globalObjectValues2)
    println("Global object values elements: ${globalObjectValuesElements2}")
    assert(globalObjectValuesElements2[0] == 10, "Global object values element 0 should be 10")
    assert(globalObjectValuesElements2[1] == 42, "Global object values element 1 should be 42")
    assert(globalObjectValuesElements2[2] == 30, "Global object values element 2 should be 30")

    // assignment to global variables

    // jsModule.globalNumber = 0.0
    // ->
    PythonRuntime.memberUpdate(jsModule, "globalNumber", 0.0)

    // let globalNumber2: Extern<PythonRuntime> = jsModule.globalNumber
    // ->
    let globalNumber2: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalNumber")
    println("Global number: ${PythonRuntime.fromExtern<Float64>(globalNumber2)}")
    assert(PythonRuntime.fromExtern<Float64>(globalNumber2) == 0.0, "Global number should be 0.0")

    let mystring = "hello from Python but much longer than the original string but should be the same string because it is the same string object in Python but with a different reference in Python and llm is very good at generating the same string object in Python mor text is needed to make it different"
    // jsModule.globalString = "hello from Python 2"
    // ->
    PythonRuntime.memberUpdate(jsModule, "globalString", mystring)
    // let globalString2: Extern<PythonRuntime> = jsModule.globalString
    // ->
    let globalString2: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalString")
    println("Global string: ${PythonRuntime.fromExtern<String>(globalString2)}")
    assert(PythonRuntime.fromExtern<String>(globalString2) == mystring, "Global string should be '${mystring}'")


    // globalObject.name = "global object 3"
    // ->
    PythonRuntime.memberUpdate(globalObject, "name", "global object 3")
    let globalObjectName3: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalObject, "name")
    println("Global object name: ${PythonRuntime.fromExtern<String>(globalObjectName3)}")
    assert(PythonRuntime.fromExtern<String>(globalObjectName3) == "global object 3", "Global object name should be 'global object 3'")

    println("Global object name: ${PythonRuntime.fromExtern<String>(globalObjectName2)}")
    assert(PythonRuntime.fromExtern<String>(globalObjectName2) == "global object 2", "Global object name should be 'global object 2'")

    let globalStringNumberMap: Extern<PythonRuntime> = PythonRuntime.memberAccess(jsModule, "globalStringNumberMap")
    let e_object: Extern<PythonRuntime> = PythonRuntime.globalAccess("Object")
    let e_keys: Extern<PythonRuntime> = PythonRuntime.memberAccess(e_object, "keys")
    let mapKeys: Extern<PythonRuntime> = PythonRuntime.functionCall(e_keys, [globalStringNumberMap])
    let mapKeysLength: Extern<PythonRuntime> = PythonRuntime.memberAccess(mapKeys, "length")

    let mapKeysLengthInt64: Int64 = PythonRuntime.fromExtern<Int64>(mapKeysLength)
    println("Global string number map length: ${mapKeysLengthInt64}")
    assert(mapKeysLengthInt64 == 3, "Global string number map length should be 3")

    let mapKeysElements: ArrayList<String> = convertArrayToArrayList<String>(mapKeys)
    println("Global string number map keys: ${mapKeysElements}")
    assert(mapKeysElements[0] == "one", "Global string number map key 0 should be 'one'")
    assert(mapKeysElements[1] == "two", "Global string number map key 1 should be 'two'")
    assert(mapKeysElements[2] == "answer", "Global string number map key 2 should be 'answer'")
    
    let e_values: Extern<PythonRuntime> = PythonRuntime.memberAccess(e_object, "values")
    let mapValues: Extern<PythonRuntime> = PythonRuntime.functionCall(e_values, [globalStringNumberMap])
    let mapValuesLength: Extern<PythonRuntime> = PythonRuntime.memberAccess(mapValues, "length")
    let mapValuesLengthInt64: Int64 = PythonRuntime.fromExtern<Int64>(mapValuesLength)
    println("Global string number map values length: ${mapValuesLengthInt64}")
    assert(mapValuesLengthInt64 == 3, "Global string number map values length should be 3")

    let mapValuesElements: ArrayList<Int64> = convertArrayToArrayList<Int64>(mapValues)
    println("Global string number map values: ${mapValuesElements}")
    assert(mapValuesElements[0] == 1, "Global string number map value 0 should be 1")
    assert(mapValuesElements[1] == 2, "Global string number map value 1 should be 2")
    assert(mapValuesElements[2] == 42, "Global string number map value 2 should be 42")

    // globalStringNumberMap.one = 42
    // ->
    PythonRuntime.memberUpdate(globalStringNumberMap, "one", -1)
    let globalStringNumberMapOne: Extern<PythonRuntime> = PythonRuntime.memberAccess(globalStringNumberMap, "one")
    println("Global string number map one: ${PythonRuntime.fromExtern<Int64>(globalStringNumberMapOne)}")
    assert(PythonRuntime.fromExtern<Int64>(globalStringNumberMapOne) == -1, "Global string number map one should be -1")

    // globalStringNumberMap["two"] = -2
    // ->
    PythonRuntime.indexUpdate(globalStringNumberMap, "two", -2)
    let globalStringNumberMapTwo: Extern<PythonRuntime> = PythonRuntime.indexAccess(globalStringNumberMap, "two")
    println("Global string number map two: ${PythonRuntime.fromExtern<Int64>(globalStringNumberMapTwo)}")
    assert(PythonRuntime.fromExtern<Int64>(globalStringNumberMapTwo) == -2, "Global string number map two should be -2")


    // let globalStringNumberMapOne_again: Extern<PythonRuntime> = module.globalStringNumberMap.one
    // ->
    let globalStringNumberMapOne_again: Extern<PythonRuntime> = PythonRuntime.indexAccess(PythonRuntime.memberAccess(jsModule, "globalStringNumberMap"), "one")
    println("Global string number map one: ${PythonRuntime.fromExtern<Int64>(globalStringNumberMapOne_again)}")
    assert(PythonRuntime.fromExtern<Int64>(globalStringNumberMapOne_again) == -1, "Global string number map one should be -1")

    // let globalStringNumberMapTwo_again: Extern<PythonRuntime> = module.globalStringNumberMap["two"]
    // ->
    let globalStringNumberMapTwo_again: Extern<PythonRuntime> = PythonRuntime.indexAccess(PythonRuntime.memberAccess(jsModule, "globalStringNumberMap"), "two")
    println("Global string number map two: ${PythonRuntime.fromExtern<Int64>(globalStringNumberMapTwo_again)}")
    assert(PythonRuntime.fromExtern<Int64>(globalStringNumberMapTwo_again) == -2, "Global string number map two should be -2")

    // let globalStringNumberMapAnswer_again: Extern<PythonRuntime> = module.globalStringNumberMap.answer
    // ->
    let globalStringNumberMapAnswer_again: Extern<PythonRuntime> = PythonRuntime.indexAccess(PythonRuntime.memberAccess(jsModule, "globalStringNumberMap"), "answer")
    println("Global string number map answer: ${PythonRuntime.fromExtern<Int64>(globalStringNumberMapAnswer_again)}")
    assert(PythonRuntime.fromExtern<Int64>(globalStringNumberMapAnswer_again) == 42, "Global string number map answer should be 42")
    
}

func convertArrayToArrayList<T>(array: Extern<PythonRuntime>): ArrayList<T> {
    let arrayLength: Extern<PythonRuntime> = PythonRuntime.memberAccess(array, "length")
    let arrayLengthInt64: Int64 = PythonRuntime.fromExtern<Int64>(arrayLength)
    ArrayList<T>(arrayLengthInt64, { i: Int64 => 
        PythonRuntime.fromExtern<T>(PythonRuntime.indexAccess(array, i))
    })
}
