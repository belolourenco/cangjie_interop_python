#include "python_bridge.h"

#include <Python.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    PYTHON_VALUE_NONE,
    PYTHON_VALUE_NULL,
    PYTHON_VALUE_BOOL,
    PYTHON_VALUE_NUMBER,
    PYTHON_VALUE_STRING,
    PYTHON_VALUE_INTEGER,
    PYTHON_VALUE_OBJECT,
};

struct py_runtime_handle {
    PyObject *globals;
    size_t value_count;
    int destroying;
};

struct py_value_handle {
    py_runtime_handle *runtime;
    PyObject *value;
};

static char *copy_string(const char *value) {
    if (value == NULL) {
        value = "unknown Python error";
    }

    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1);
    if (copy != NULL) {
        memcpy(copy, value, length + 1);
    }
    return copy;
}

static void set_error(py_bridge_error *error, py_error_kind kind, const char *message) {
    error->kind = kind;
    error->message = copy_string(message);
}

static PyObject *format_exception(PyObject *type, PyObject *value, PyObject *traceback) {
    PyObject *module = PyImport_ImportModule("traceback");
    if (module == NULL) {
        return NULL;
    }

    PyObject *lines = PyObject_CallMethod(module, "format_exception", "OOO",
                                         type, value, traceback == NULL ? Py_None : traceback);
    Py_DECREF(module);
    if (lines == NULL) {
        return NULL;
    }

    PyObject *separator = PyUnicode_FromString("");
    PyObject *formatted = separator == NULL ? NULL : PyUnicode_Join(separator, lines);
    Py_XDECREF(separator);
    Py_DECREF(lines);
    return formatted;
}

static void capture_exception(py_bridge_error *error, py_error_kind operation) {
    PyObject *type = NULL;
    PyObject *value = NULL;
    PyObject *traceback = NULL;
    PyErr_Fetch(&type, &value, &traceback);

    py_error_kind kind = PY_ERROR_FOREIGN;
    // Python frames distinguish exceptions raised by user code from CPython's
    // argument binding and built-in access errors.
    if (traceback == NULL && type != NULL) {
        switch (operation) {
        case PY_ERROR_MEMBER:
            if (PyErr_GivenExceptionMatches(type, PyExc_AttributeError)) {
                kind = operation;
            }
            break;
        case PY_ERROR_INDEX:
            if (PyErr_GivenExceptionMatches(type, PyExc_IndexError) ||
                PyErr_GivenExceptionMatches(type, PyExc_KeyError) ||
                PyErr_GivenExceptionMatches(type, PyExc_TypeError)) {
                kind = operation;
            }
            break;
        case PY_ERROR_ARGUMENTS:
            if (PyErr_GivenExceptionMatches(type, PyExc_TypeError)) {
                kind = operation;
            }
            break;
        case PY_ERROR_CONVERSION:
            kind = operation;
            break;
        default:
            break;
        }
    }

    PyErr_NormalizeException(&type, &value, &traceback);
    PyObject *formatted = NULL;
    if (value != NULL) {
        if (kind == PY_ERROR_FOREIGN && type != NULL) {
            formatted = format_exception(type, value, traceback);
        }
        if (formatted == NULL) {
            PyErr_Clear();
            formatted = PyObject_Str(value);
        }
    }
    const char *message = formatted == NULL ? NULL : PyUnicode_AsUTF8(formatted);
    set_error(error, kind, message);
    Py_XDECREF(formatted);
    Py_XDECREF(type);
    Py_XDECREF(value);
    Py_XDECREF(traceback);
    PyErr_Clear();
}

static int valid_runtime(py_runtime_handle *runtime) {
    return runtime != NULL && runtime->globals != NULL;
}

static void free_runtime(py_runtime_handle *runtime) {
    if (runtime == NULL) {
        return;
    }

    Py_XDECREF(runtime->globals);
    free(runtime);
}

static void free_runtime_if_ready(py_runtime_handle *runtime) {
    if (runtime != NULL && runtime->destroying && runtime->value_count == 0) {
        free_runtime(runtime);
    }
}

static py_value_handle *new_value_handle(py_runtime_handle *runtime, PyObject *value, py_bridge_error *error) {
    if (value == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        return NULL;
    }

    py_value_handle *handle = (py_value_handle *)calloc(1, sizeof(py_value_handle));
    if (handle == NULL) {
        Py_DECREF(value);
        set_error(error, PY_ERROR_FOREIGN, "failed to allocate Python value handle");
        return NULL;
    }

    handle->runtime = runtime;
    handle->value = value;
    runtime->value_count++;
    return handle;
}

static PyObject *lookup_dict_member(PyObject *dict, const char *name) {
    PyObject *key = PyUnicode_FromString(name);
    PyObject *member = key == NULL ? NULL : PyDict_GetItemWithError(dict, key);
    Py_XINCREF(member);
    Py_XDECREF(key);
    return member;
}

static int string_ends_with(const char *value, const char *suffix) {
    if (value == NULL || suffix == NULL) {
        return 0;
    }

    size_t value_len = strlen(value);
    size_t suffix_len = strlen(suffix);
    return value_len >= suffix_len && strcmp(value + value_len - suffix_len, suffix) == 0;
}

static char *module_name_for_path(const char *path) {
    unsigned long hash = 1469598103934665603UL;
    for (const unsigned char *p = (const unsigned char *)path; *p != '\0'; p++) {
        hash ^= (unsigned long)(*p);
        hash *= 1099511628211UL;
    }

    char buffer[96];
    snprintf(buffer, sizeof(buffer), "_cangjie_interop_python_%lx", hash);
    return copy_string(buffer);
}

static int install_global_helpers(py_runtime_handle *runtime) {
    static const char *helper_source =
        "class _CangjieInteropObject:\n"
        "    @staticmethod\n"
        "    def keys(value):\n"
        "        if hasattr(value, 'keys'):\n"
        "            return list(value.keys())\n"
        "        return list(vars(value).keys())\n"
        "    @staticmethod\n"
        "    def values(value):\n"
        "        if hasattr(value, 'values'):\n"
        "            return list(value.values())\n"
        "        return [getattr(value, key) for key in vars(value).keys()]\n"
        "Object = _CangjieInteropObject\n";

    PyObject *result = PyRun_String(helper_source, Py_file_input, runtime->globals, runtime->globals);
    if (result == NULL) {
        return -1;
    }
    Py_DECREF(result);
    return 0;
}

py_runtime_handle *py_runtime_create(py_bridge_error *error) {
    if (!Py_IsInitialized()) {
        Py_Initialize();
        PyEval_SaveThread();
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    py_runtime_handle *handle = (py_runtime_handle *)calloc(1, sizeof(py_runtime_handle));
    if (handle == NULL) {
        set_error(error, PY_ERROR_FOREIGN, "failed to allocate Python runtime");
        PyGILState_Release(gil);
        return NULL;
    }

    handle->globals = PyDict_New();
    if (handle->globals == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        free(handle);
        PyGILState_Release(gil);
        return NULL;
    }

    if (PyDict_SetItemString(handle->globals, "__builtins__", PyEval_GetBuiltins()) != 0 ||
        install_global_helpers(handle) != 0) {
        capture_exception(error, PY_ERROR_FOREIGN);
        Py_DECREF(handle->globals);
        free(handle);
        PyGILState_Release(gil);
        return NULL;
    }

    PyGILState_Release(gil);
    return handle;
}

void py_runtime_destroy(py_runtime_handle *handle) {
    if (handle == NULL) {
        return;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    handle->destroying = 1;
    free_runtime_if_ready(handle);
    PyGILState_Release(gil);
}

py_value_handle *py_runtime_eval_value(py_runtime_handle *handle, const char *source, py_bridge_error *error) {
    if (!valid_runtime(handle) || source == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();

    PyObject *code = Py_CompileString(source, "<cangjie-python-eval>", Py_eval_input);
    if (code == NULL) {
        if (!PyErr_ExceptionMatches(PyExc_SyntaxError)) {
            capture_exception(error, PY_ERROR_FOREIGN);
            PyGILState_Release(gil);
            return NULL;
        }

        PyErr_Clear();
        code = Py_CompileString(source, "<cangjie-python-eval>", Py_file_input);
        if (code == NULL) {
            capture_exception(error, PY_ERROR_FOREIGN);
            PyGILState_Release(gil);
            return NULL;
        }
    }

    PyObject *result = PyEval_EvalCode(code, handle->globals, handle->globals);
    Py_DECREF(code);
    if (result == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        PyGILState_Release(gil);
        return NULL;
    }

    py_value_handle *value = new_value_handle(handle, result, error);
    PyGILState_Release(gil);
    return value;
}

py_value_handle *py_runtime_get_global_property(py_runtime_handle *handle, const char *name, py_bridge_error *error) {
    if (!valid_runtime(handle) || name == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();

    PyObject *value = lookup_dict_member(handle->globals, name);
    if (value == NULL) {
        if (PyErr_Occurred()) {
            capture_exception(error, PY_ERROR_FOREIGN);
        } else {
            set_error(error, PY_ERROR_MEMBER, "Python global was not found");
        }
        PyGILState_Release(gil);
        return NULL;
    }

    py_value_handle *result = new_value_handle(handle, value, error);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_bool(py_runtime_handle *handle, int64_t value, py_bridge_error *error) {
    if (!valid_runtime(handle)) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *object = PyBool_FromLong(value != 0);
    py_value_handle *result = new_value_handle(handle, object, error);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_number(py_runtime_handle *handle, double value, py_bridge_error *error) {
    if (!valid_runtime(handle)) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *object = PyFloat_FromDouble(value);
    if (object == NULL) {
        capture_exception(error, PY_ERROR_CONVERSION);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object, error);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_integer(py_runtime_handle *handle, const char *value, py_bridge_error *error) {
    if (!valid_runtime(handle) || value == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *object = PyLong_FromString(value, NULL, 10);
    if (object == NULL) {
        capture_exception(error, PY_ERROR_CONVERSION);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object, error);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_string(py_runtime_handle *handle, const char *value, int64_t size, py_bridge_error *error) {
    if (!valid_runtime(handle) || value == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *object = PyUnicode_FromStringAndSize(value, (Py_ssize_t)size);
    if (object == NULL) {
        capture_exception(error, PY_ERROR_CONVERSION);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object, error);
    PyGILState_Release(gil);
    return result;
}

static py_value_handle *runtime_import_file(py_runtime_handle *handle, const char *path, py_bridge_error *error) {
    char resolved_path[PATH_MAX];
    if (realpath(path, resolved_path) == NULL) {
        set_error(error, PY_ERROR_FOREIGN, "failed to read Python module file");
        return NULL;
    }

    char *module_name = module_name_for_path(resolved_path);
    if (module_name == NULL) {
        set_error(error, PY_ERROR_FOREIGN, "failed to allocate Python module name");
        return NULL;
    }

    PyObject *importlib_util = PyImport_ImportModule("importlib.util");
    PyObject *sys_modules = PyImport_GetModuleDict();
    PyObject *spec = NULL;
    PyObject *module = NULL;
    PyObject *loader = NULL;
    PyObject *exec_module = NULL;
    PyObject *result = NULL;
    int registered = 0;

    if (importlib_util == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    PyObject *spec_from_file_location = PyObject_GetAttrString(importlib_util, "spec_from_file_location");
    if (spec_from_file_location == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    spec = PyObject_CallFunction(spec_from_file_location, "ss", module_name, resolved_path);
    Py_DECREF(spec_from_file_location);
    if (spec == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }
    if (spec == Py_None) {
        set_error(error, PY_ERROR_FOREIGN, "failed to create Python module spec");
        goto fail;
    }

    PyObject *module_from_spec = PyObject_GetAttrString(importlib_util, "module_from_spec");
    if (module_from_spec == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    module = PyObject_CallFunctionObjArgs(module_from_spec, spec, NULL);
    Py_DECREF(module_from_spec);
    if (module == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    if (PyDict_SetItemString(sys_modules, module_name, module) != 0) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    registered = 1;
    loader = PyObject_GetAttrString(spec, "loader");
    if (loader == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }
    if (loader == Py_None) {
        set_error(error, PY_ERROR_FOREIGN, "failed to create Python module loader");
        goto fail;
    }

    exec_module = PyObject_GetAttrString(loader, "exec_module");
    if (exec_module == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    result = PyObject_CallFunctionObjArgs(exec_module, module, NULL);
    if (result == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        goto fail;
    }

    Py_DECREF(result);
    result = NULL;

    free(module_name);
    Py_XDECREF(exec_module);
    Py_XDECREF(loader);
    Py_XDECREF(spec);
    Py_XDECREF(importlib_util);
    return new_value_handle(handle, module, error);

fail:
    if (registered && PyDict_DelItemString(sys_modules, module_name) != 0) {
        PyErr_Clear();
    }
    free(module_name);
    Py_XDECREF(result);
    Py_XDECREF(exec_module);
    Py_XDECREF(loader);
    Py_XDECREF(module);
    Py_XDECREF(spec);
    Py_XDECREF(importlib_util);
    return NULL;
}

py_value_handle *py_runtime_import_module(py_runtime_handle *handle, const char *path_or_name, py_bridge_error *error) {
    if (!valid_runtime(handle) || path_or_name == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();

    py_value_handle *result = NULL;
    if (string_ends_with(path_or_name, ".py")) {
        result = runtime_import_file(handle, path_or_name, error);
    } else {
        PyObject *module = PyImport_ImportModule(path_or_name);
        if (module == NULL) {
            capture_exception(error, PY_ERROR_FOREIGN);
        } else {
            result = new_value_handle(handle, module, error);
        }
    }

    PyGILState_Release(gil);
    return result;
}

void py_value_destroy(py_value_handle *handle) {
    if (handle == NULL) {
        return;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    py_runtime_handle *runtime = handle->runtime;
    Py_XDECREF(handle->value);
    free(handle);
    if (runtime != NULL) {
        if (runtime->value_count > 0) {
            runtime->value_count--;
        }
        free_runtime_if_ready(runtime);
    }
    PyGILState_Release(gil);
}

int64_t py_value_kind(py_value_handle *handle) {
    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *value = handle->value;
    int64_t kind = PYTHON_VALUE_OBJECT;
    if (value == Py_None) {
        kind = PYTHON_VALUE_NONE;
    } else if (PyBool_Check(value)) {
        kind = PYTHON_VALUE_BOOL;
    } else if (PyFloat_Check(value)) {
        kind = PYTHON_VALUE_NUMBER;
    } else if (PyLong_Check(value)) {
        kind = PYTHON_VALUE_INTEGER;
    } else if (PyUnicode_Check(value)) {
        kind = PYTHON_VALUE_STRING;
    }
    PyGILState_Release(gil);
    return kind;
}

int64_t py_value_to_bool(py_value_handle *handle) {
    PyGILState_STATE gil = PyGILState_Ensure();
    int64_t result = handle->value == Py_True;
    PyGILState_Release(gil);
    return result;
}

int64_t py_value_is_callable(py_value_handle *handle) {
    PyGILState_STATE gil = PyGILState_Ensure();
    int64_t result = PyCallable_Check(handle->value);
    PyGILState_Release(gil);
    return result;
}

double py_value_to_number(py_value_handle *handle, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    double number = PyFloat_AsDouble(handle->value);
    if (PyErr_Occurred()) {
        capture_exception(error, PY_ERROR_CONVERSION);
    }
    PyGILState_Release(gil);
    return number;
}

const char *py_value_to_string(py_value_handle *handle, int64_t *size, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *string = PyObject_Str(handle->value);
    Py_ssize_t length = 0;
    const char *utf8 = string == NULL ? NULL : PyUnicode_AsUTF8AndSize(string, &length);
    char *copy = NULL;

    if (utf8 == NULL) {
        capture_exception(error, PY_ERROR_CONVERSION);
    } else {
        copy = malloc((size_t)length + 1);
        if (copy == NULL) {
            set_error(error, PY_ERROR_FOREIGN, "failed to allocate Python string buffer");
        } else {
            memcpy(copy, utf8, (size_t)length + 1);
            *size = (int64_t)length;
        }
    }

    Py_XDECREF(string);
    PyGILState_Release(gil);
    return copy;
}

void py_bridge_free_string(const char *value) {
    free((void *)value);
}

static const char *python_operator(const char *name) {
    static const struct {
        const char *cangjie;
        const char *python;
    } operators[] = {
        {"*", "mul"}, {"/", "truediv"}, {"%", "mod"}, {"**", "pow"},
        {"<<", "lshift"}, {">>", "rshift"}, {"~", "invert"}, {"!", "not_"},
        {"&", "and_"}, {"|", "or_"}, {"^", "xor"},
        {"==", "eq"}, {"!=", "ne"}, {"<", "lt"}, {"<=", "le"},
        {">", "gt"}, {">=", "ge"},
    };

    for (size_t i = 0; i < sizeof(operators) / sizeof(operators[0]); i++) {
        if (strcmp(name, operators[i].cangjie) == 0) {
            return operators[i].python;
        }
    }
    return NULL;
}

static PyObject *python_plus(PyObject *value, PyObject *args) {
    Py_ssize_t size = PyTuple_GET_SIZE(args);
    if (size == 0) {
        return PyNumber_Positive(value);
    }
    if (size == 1) {
        return PyNumber_Add(value, PyTuple_GET_ITEM(args, 0));
    }
    PyErr_SetString(PyExc_TypeError, "Python '+' operator takes at most one argument");
    return NULL;
}

static PyObject *python_minus(PyObject *value, PyObject *args) {
    Py_ssize_t size = PyTuple_GET_SIZE(args);
    if (size == 0) {
        return PyNumber_Negative(value);
    }
    if (size == 1) {
        return PyNumber_Subtract(value, PyTuple_GET_ITEM(args, 0));
    }
    PyErr_SetString(PyExc_TypeError, "Python '-' operator takes at most one argument");
    return NULL;
}

static PyObject *bind_operator(PyObject *value, const char *name) {
    PyObject *operator_module = PyImport_ImportModule("operator");
    if (operator_module == NULL) {
        return NULL;
    }
    PyObject *operation = PyObject_GetAttrString(operator_module, name);
    Py_DECREF(operator_module);
    if (operation == NULL) {
        return NULL;
    }

    PyObject *functools = PyImport_ImportModule("functools");
    PyObject *bound = functools == NULL ? NULL : PyObject_CallMethod(functools, "partial", "OO", operation, value);
    Py_XDECREF(functools);
    Py_DECREF(operation);
    return bound;
}

static PyObject *get_member(PyObject *target, const char *name) {
    static PyMethodDef plus = {"+", python_plus, METH_VARARGS, NULL};
    static PyMethodDef minus = {"-", python_minus, METH_VARARGS, NULL};
    if (strcmp(name, "+") == 0) {
        return PyCFunction_New(&plus, target);
    }
    if (strcmp(name, "-") == 0) {
        return PyCFunction_New(&minus, target);
    }

    const char *operation = python_operator(name);
    if (operation != NULL) {
        return bind_operator(target, operation);
    }
    if (strcmp(name, "length") == 0 &&
        (PyList_Check(target) || PyTuple_Check(target) || PyDict_Check(target))) {
        Py_ssize_t length = PyObject_Length(target);
        return length < 0 ? NULL : PyLong_FromSsize_t(length);
    }

    PyObject *member = PyObject_GetAttrString(target, name);
    if (member == NULL && PyDict_CheckExact(target) && PyErr_ExceptionMatches(PyExc_AttributeError)) {
        PyErr_Clear();
        // Dict keys have also been exposed as members by this bridge.
        member = lookup_dict_member(target, name);
        if (member == NULL && !PyErr_Occurred()) {
            PyErr_Format(PyExc_AttributeError, "Python dictionary has no member '%s'", name);
        }
    }
    return member;
}

py_value_handle *py_value_get_property(py_value_handle *handle, const char *name, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *member = get_member(handle->value, name);
    py_value_handle *result = NULL;
    if (member == NULL) {
        capture_exception(error, PY_ERROR_MEMBER);
    } else {
        result = new_value_handle(handle->runtime, member, error);
    }
    PyGILState_Release(gil);
    return result;
}

static int set_member(PyObject *target, const char *name, PyObject *value) {
    // A static lookup checks that the member exists without calling its getter.
    PyObject *inspect = PyImport_ImportModule("inspect");
    if (inspect == NULL) {
        return -1;
    }
    PyObject *member = PyObject_CallMethod(inspect, "getattr_static", "Os", target, name);
    Py_DECREF(inspect);
    if (member != NULL) {
        Py_DECREF(member);
        return PyObject_SetAttrString(target, name, value);
    }
    if (!PyErr_ExceptionMatches(PyExc_AttributeError)) {
        return -1;
    }
    PyErr_Clear();

    if (PyDict_CheckExact(target)) {
        member = lookup_dict_member(target, name);
        if (member != NULL) {
            Py_DECREF(member);
            return PyDict_SetItemString(target, name, value);
        }
        if (PyErr_Occurred()) {
            return -1;
        }
    }

    // Dynamic attributes can be supplied by __getattr__.
    member = PyObject_GetAttrString(target, name);
    if (member == NULL) {
        return -1;
    }
    Py_DECREF(member);
    return PyObject_SetAttrString(target, name, value);
}

void py_value_set_property(py_value_handle *handle, const char *name, py_value_handle *value, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    if (set_member(handle->value, name, value->value) != 0) {
        capture_exception(error, PY_ERROR_MEMBER);
    }
    PyGILState_Release(gil);
}

static int valid_index(PyObject *target, PyObject *index, py_bridge_error *error) {
    // The bridge uses nonnegative indexes for built-in lists and tuples.
    if ((PyList_CheckExact(target) || PyTuple_CheckExact(target)) && PyLong_Check(index)) {
        int overflow = 0;
        long long position = PyLong_AsLongLongAndOverflow(index, &overflow);
        if (overflow < 0 || (overflow == 0 && position < 0)) {
            set_error(error, PY_ERROR_INDEX, "Python sequence index is out of range");
            return 0;
        }
    }
    return 1;
}

py_value_handle *py_value_get_index(py_value_handle *handle, py_value_handle *index, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    py_value_handle *result = NULL;
    if (valid_index(handle->value, index->value, error)) {
        PyObject *item = PyObject_GetItem(handle->value, index->value);
        if (item == NULL) {
            capture_exception(error, PY_ERROR_INDEX);
        } else {
            result = new_value_handle(handle->runtime, item, error);
        }
    }
    PyGILState_Release(gil);
    return result;
}

void py_value_set_index(py_value_handle *handle, py_value_handle *index, py_value_handle *value, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    if (valid_index(handle->value, index->value, error) &&
        PyObject_SetItem(handle->value, index->value, value->value) != 0) {
        capture_exception(error, PY_ERROR_INDEX);
    }
    PyGILState_Release(gil);
}

py_value_handle *py_value_call(py_value_handle *function, py_value_handle **args, int64_t num_args, py_bridge_error *error) {
    PyGILState_STATE gil = PyGILState_Ensure();
    if (!PyCallable_Check(function->value)) {
        set_error(error, PY_ERROR_NOT_CALLABLE, "Python value is not callable");
        PyGILState_Release(gil);
        return NULL;
    }

    PyObject *tuple = PyTuple_New((Py_ssize_t)num_args);
    if (tuple == NULL) {
        capture_exception(error, PY_ERROR_FOREIGN);
        PyGILState_Release(gil);
        return NULL;
    }

    for (int64_t i = 0; i < num_args; i++) {
        PyObject *arg = args[i]->value;
        Py_INCREF(arg);
        PyTuple_SET_ITEM(tuple, (Py_ssize_t)i, arg);
    }

    PyObject *returned = PyObject_CallObject(function->value, tuple);
    Py_DECREF(tuple);
    py_value_handle *result = NULL;
    if (returned == NULL) {
        capture_exception(error, PY_ERROR_ARGUMENTS);
    } else {
        result = new_value_handle(function->runtime, returned, error);
    }
    PyGILState_Release(gil);
    return result;
}
