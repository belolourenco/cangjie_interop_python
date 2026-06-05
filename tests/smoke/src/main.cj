package smoke

main(): Int64 {
    println("◆ starting smoke tests")

    println("▶ running primitive_types")
    let primitiveTypesResult = runPrimitiveTypesSmoke()
    if (primitiveTypesResult != 0) {
        println("✗ primitive_types failed with exit code ${primitiveTypesResult}")
        return primitiveTypesResult
    }
    println("✓ primitive_types passed")

    println("▶ running functions")
    let functionsResult = runFunctionsSmoke()
    if (functionsResult != 0) {
        println("✗ functions failed with exit code ${functionsResult}")
        return functionsResult
    }
    println("✓ functions passed")

    println("▶ running classes_and_objects")
    let classesAndObjectsResult = runClassesAndObjectsSmoke()
    if (classesAndObjectsResult != 0) {
        println("✗ classes_and_objects failed with exit code ${classesAndObjectsResult}")
        return classesAndObjectsResult
    }
    println("✓ classes_and_objects passed")

    println("▶ running load_modules")
    let loadModulesResult = runLoadModulesSmoke()
    if (loadModulesResult != 0) {
        println("✗ load_modules failed with exit code ${loadModulesResult}")
        return loadModulesResult
    }
    println("✓ load_modules passed")

    println("▶ running errors_and_lifecycle")
    let errorsAndLifecycleResult = runErrorsAndLifecycleSmoke()
    if (errorsAndLifecycleResult != 0) {
        println("✗ errors_and_lifecycle failed with exit code ${errorsAndLifecycleResult}")
        return errorsAndLifecycleResult
    }
    println("✓ errors_and_lifecycle passed")

    println("◆ all smoke tests ok")
    return 0
}
