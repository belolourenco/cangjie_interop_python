package extern_with_modules

import interop_python.PythonRuntime
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

    jsModule.my_python_function()

    // ---- lookup ----

    let lookupResult: Extern<PythonRuntime> = jsModule.lookup(42.4242, 1.111)

    // println("Lookup coordinates: (${(Float64)lookupResult.coordinates[0]}, ${(Float64)lookupResult.coordinates[1]})")
    println("Lookup coordinates: (${(Float64)lookupResult.coordinates[0]}, ${(Float64)lookupResult.coordinates[1]})")
    assert((Float64)lookupResult.coordinates[0] == 1.111000, "Lookup coordinates[0] should be 1.111000")
    assert((Float64)lookupResult.coordinates[1] == 42.424200, "Lookup coordinates[1] should be 42.424200")

    // println("Lookup result: ${(String)lookupResult.name}")
    // ->
    println("Lookup result: ${(String)lookupResult.name}")
    assert((String)lookupResult.name == "Space Needle", "Lookup name should be 'My Location'")

    // println("Lookup result: ${(String)lookupResult.city}")
    // ->
    println("Lookup result: ${(String)lookupResult.city}")
    assert((String)lookupResult.city == "Seattle", "Lookup city should be 'Seattle'")

    // println("Lookup result: ${(String)lookupResult.category}")
    // ->
    println("Lookup result: ${(String)lookupResult.category}")
    assert((String)lookupResult.category == "Landmark", "Lookup category should be 'Landmark'")

    // ---- Rectangle ----

    let rectangleObject: Extern<PythonRuntime> = jsModule.Rectangle(10, 11)

    let rectangleWidthResult: Extern<PythonRuntime> = rectangleObject.getWidth()
    println("Rectangle width: ${(Float64)rectangleWidthResult}")
    assert((Float64)rectangleWidthResult == 10.0, "Rectangle width should be 10.0")

    let rectangleHeightResult: Extern<PythonRuntime> = rectangleObject.getHeight()
    println("Rectangle height: ${(Float64)rectangleHeightResult}")
    assert((Float64)rectangleHeightResult == 11.0, "Rectangle height should be 11.0")

    // ---- createRectangle ----

    let rectangleObject2: Extern<PythonRuntime> = jsModule.createRectangle()

    rectangleObject2.width = 42.0

    let rectangleWidth2: Extern<PythonRuntime> = rectangleObject2.width
    
    // println("Rectangle width: ${(Float64)rectangleWidth2}")
    println("Rectangle width: ${(Float64)rectangleWidth2}")
    assert((Float64)rectangleWidth2 == 42.0, "Rectangle width should be 42.0")

    let rectangleHeight2: Extern<PythonRuntime> = rectangleObject2.height

    // println("Rectangle height: ${(Float64)rectangleHeight2}")
    println("Rectangle height: ${(Float64)rectangleHeight2}")
    assert((Float64)rectangleHeight2 == 13.0, "Rectangle height should be 13.0")

    let areaResult = rectangleObject2.area()

    // println("Rectangle area: ${(Float64)areaResult}")
    // ->
    println("Rectangle area: ${(Float64)areaResult}")
    assert((Float64)areaResult == 546.0, "Rectangle area should be 546.0")

    let perimeterResult = rectangleObject2.perimeter()

    // println("Rectangle perimeter: ${(Float64)perimeterResult}")
    // ->
    println("Rectangle perimeter: ${(Float64)perimeterResult}")
    assert((Float64)perimeterResult == 110.0, "Rectangle perimeter should be 110.0")

    // ---- accessing global variables ----

    let globalBoolean: Extern<PythonRuntime> = jsModule.globalBoolean
    println("Global boolean: ${(Bool)globalBoolean}")
    assert((Bool)globalBoolean == true, "Global boolean should be true")

    let globalNumber: Extern<PythonRuntime> = jsModule.globalNumber
    println("Global number: ${(Float64)globalNumber}")
    assert((Float64)globalNumber == 42.4242, "Global number should be 42.4242")

    let globalString: Extern<PythonRuntime> = jsModule.globalString
    println("Global string: ${(String)globalString}")
    assert((String)globalString == "hello from Python", "Global string should be 'hello from Python'")

    // ---- array access and assignment ----

    let globalArray: Extern<PythonRuntime> = jsModule.globalArray
    let arrayElements: ArrayList<Int64> = convertArrayToArrayList(globalArray)
    println("Global array elements: ${arrayElements}")
    assert(arrayElements[0] == 1, "Global array element 0 should be 1")
    assert(arrayElements[1] == 2, "Global array element 1 should be 2")
    assert(arrayElements[2] == 3, "Global array element 2 should be 3")

    globalArray[1] = 42

    let arrayElements2: ArrayList<Int64> = convertArrayToArrayList(globalArray)
    println("Global array elements: ${arrayElements2}")
    assert(arrayElements2[0] == 1, "Global array element 0 should be 1")
    assert(arrayElements2[1] == 42, "Global array element 1 should be 42")
    assert(arrayElements2[2] == 3, "Global array element 2 should be 3")

    try {
        globalArray[-1]
        throw AssertionFailedException("Global array element -1 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }


    try {
        globalArray[-1] = 42
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    try {
        let x = globalArray[3]
        println("Global array element 3: ${(Int64)x}")
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    try {
        globalArray[3] = 42
        throw AssertionFailedException("Global array element 3 should be out of range")
    } catch (e: ExternDynamicException) {
        println("Expected exception: ${e.message}")
    }

    // ---- global object ----

    let globalObject: Extern<PythonRuntime> = jsModule.globalObject

    let globalObjectName: Extern<PythonRuntime> = globalObject.name
    println("Global object name: ${(String)globalObjectName}")
    assert((String)globalObjectName == "global object", "Global object name should be 'global object'")

    let globalObjectEnabled: Extern<PythonRuntime> = globalObject.enabled
    println("Global object enabled: ${(Bool)globalObjectEnabled}")
    assert((Bool)globalObjectEnabled == true, "Global object enabled should be true")

    let globalObjectValues: Extern<PythonRuntime> = globalObject.values
    let globalObjectValuesElements: ArrayList<Int64> = convertArrayToArrayList(globalObjectValues)
    println("Global object values elements: ${globalObjectValuesElements}")
    assert(globalObjectValuesElements[0] == 10, "Global object values element 0 should be 10")
    assert(globalObjectValuesElements[1] == 20, "Global object values element 1 should be 20")
    assert(globalObjectValuesElements[2] == 30, "Global object values element 2 should be 30")

    globalObject.name = "global object 2"
    let globalObjectName2: Extern<PythonRuntime> = globalObject.name
    println("Global object name: ${(String)globalObjectName2}")
    assert((String)globalObjectName2 == "global object 2", "Global object name should be 'global object 2'")

    globalObject.enabled = false
    let globalObjectEnabled2: Extern<PythonRuntime> = globalObject.enabled
    println("Global object enabled: ${(Bool)globalObjectEnabled2}")
    assert((Bool)globalObjectEnabled2 == false, "Global object enabled should be false")

    let globalObjectValues2: Extern<PythonRuntime> = globalObject.values
    globalObject.values[1] = 42
    let globalObjectValuesElements2: ArrayList<Int64> = convertArrayToArrayList(globalObjectValues2)
    println("Global object values elements: ${globalObjectValuesElements2}")
    assert(globalObjectValuesElements2[0] == 10, "Global object values element 0 should be 10")
    assert(globalObjectValuesElements2[1] == 42, "Global object values element 1 should be 42")
    assert(globalObjectValuesElements2[2] == 30, "Global object values element 2 should be 30")

    // assignment to global variables

    jsModule.globalNumber = 0.0

    let globalNumber2: Extern<PythonRuntime> = jsModule.globalNumber
    println("Global number: ${(Float64)globalNumber2}")
    assert((Float64)globalNumber2 == 0.0, "Global number should be 0.0")

    let mystring = "hello from JavaScript but much longer than the original string but should be the same string because it is the same string object in JavaScript but with a different reference in JavaScript and llm is very good at generating the same string object in JavaScript mor text is needed to make it different"
    jsModule.globalString = mystring
    let globalString2: Extern<PythonRuntime> = jsModule.globalString
    println("Global string: ${(String)globalString2}")
    assert((String)globalString2 == mystring, "Global string should be '${mystring}'")


    globalObject.name = "global object 3"
    let globalObjectName3: Extern<PythonRuntime> = globalObject.name
    println("Global object name: ${(String)globalObjectName3}")
    assert((String)globalObjectName3 == "global object 3", "Global object name should be 'global object 3'")

    println("Global object name: ${(String)globalObjectName2}")
    assert((String)globalObjectName2 == "global object 2", "Global object name should be 'global object 2'")

    let globalStringNumberMap: Extern<PythonRuntime> = jsModule.globalStringNumberMap
    // TODO: to be discussed!
    let e_object: Extern<PythonRuntime> = PythonRuntime.globalAccess("Object")
    let e_keys: Extern<PythonRuntime> = e_object.keys
    let mapKeys: Extern<PythonRuntime> = e_keys(globalStringNumberMap)
    let mapKeysLength: Extern<PythonRuntime> = mapKeys.length

    let mapKeysLengthInt64: Int64 = (Int64)mapKeysLength
    println("Global string number map length: ${mapKeysLengthInt64}")
    assert(mapKeysLengthInt64 == 3, "Global string number map length should be 3")

    let mapKeysElements: ArrayList<String> = convertArrayToArrayList<String>(mapKeys)
    println("Global string number map keys: ${mapKeysElements}")
    assert(mapKeysElements[0] == "one", "Global string number map key 0 should be 'one'")
    assert(mapKeysElements[1] == "two", "Global string number map key 1 should be 'two'")
    assert(mapKeysElements[2] == "answer", "Global string number map key 2 should be 'answer'")
    
    let e_values: Extern<PythonRuntime> = e_object.values
    let mapValues: Extern<PythonRuntime> = e_values(globalStringNumberMap)
    let mapValuesLength: Extern<PythonRuntime> = mapValues.length
    let mapValuesLengthInt64: Int64 = (Int64)mapValuesLength
    println("Global string number map values length: ${mapValuesLengthInt64}")
    assert(mapValuesLengthInt64 == 3, "Global string number map values length should be 3")

    let mapValuesElements: ArrayList<Int64> = convertArrayToArrayList<Int64>(mapValues)
    println("Global string number map values: ${mapValuesElements}")
    assert(mapValuesElements[0] == 1, "Global string number map value 0 should be 1")
    assert(mapValuesElements[1] == 2, "Global string number map value 1 should be 2")
    assert(mapValuesElements[2] == 42, "Global string number map value 2 should be 42")

    globalStringNumberMap.one = -1
    let globalStringNumberMapOne: Extern<PythonRuntime> = globalStringNumberMap.one
    println("Global string number map one: ${(Int64)globalStringNumberMapOne}")
    assert((Int64)globalStringNumberMapOne == -1, "Global string number map one should be -1")

    globalStringNumberMap["two"] = -2
    let globalStringNumberMapTwo: Extern<PythonRuntime> = globalStringNumberMap["two"]
    println("Global string number map two: ${(Int64)globalStringNumberMapTwo}")
    assert((Int64)globalStringNumberMapTwo == -2, "Global string number map two should be -2")
    let globalStringNumberMapTwo_field: Extern<PythonRuntime> = globalStringNumberMap.two
    println("Global string number map two: ${(Int64)globalStringNumberMapTwo_field}")
    assert((Int64)globalStringNumberMapTwo_field == -2, "Global string number map two should be -2")

    let globalStringNumberMapOne_again: Extern<PythonRuntime> = jsModule.globalStringNumberMap["one"]
    println("Global string number map one: ${(Int64)globalStringNumberMapOne_again}")
    assert((Int64)globalStringNumberMapOne_again == -1, "Global string number map one should be -1")

    let globalStringNumberMapTwo_again: Extern<PythonRuntime> = jsModule.globalStringNumberMap["two"]
    println("Global string number map two: ${(Int64)globalStringNumberMapTwo_again}")
    assert((Int64)globalStringNumberMapTwo_again == -2, "Global string number map two should be -2")

    let globalStringNumberMapAnswer_again: Extern<PythonRuntime> = jsModule.globalStringNumberMap.answer
    println("Global string number map answer: ${(Int64)globalStringNumberMapAnswer_again}")
    assert((Int64)globalStringNumberMapAnswer_again == 42, "Global string number map answer should be 42")
    
}

func convertArrayToArrayList<T>(array: Extern<PythonRuntime>): ArrayList<T> {
    let arrayLength: Extern<PythonRuntime> = array.length
    let arrayLengthInt64: Int64 = (Int64)arrayLength
    ArrayList<T>(arrayLengthInt64, { i: Int64 =>
        (T)array[i]
    })
}
