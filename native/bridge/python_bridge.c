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
    PYTHON_VALUE_CALLABLE,
};

struct py_runtime_handle {
    PyObject *globals;
    char *last_error;
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

static void set_error(py_runtime_handle *runtime, const char *message) {
    if (runtime == NULL) {
        return;
    }

    free(runtime->last_error);
    runtime->last_error = copy_string(message);
}

static void clear_error(py_runtime_handle *runtime) {
    if (runtime == NULL) {
        return;
    }

    free(runtime->last_error);
    runtime->last_error = NULL;
}

static void capture_exception(py_runtime_handle *runtime) {
    if (runtime == NULL) {
        PyErr_Clear();
        return;
    }

    if (!PyErr_Occurred()) {
        set_error(runtime, "unknown Python error");
        return;
    }

    PyObject *type = NULL;
    PyObject *value = NULL;
    PyObject *traceback = NULL;
    PyErr_Fetch(&type, &value, &traceback);
    PyErr_NormalizeException(&type, &value, &traceback);

    PyObject *message_object = value == NULL ? NULL : PyObject_Str(value);
    const char *message = message_object == NULL ? NULL : PyUnicode_AsUTF8(message_object);
    if (message == NULL || message[0] == '\0') {
        PyObject *type_name = type == NULL ? NULL : PyObject_GetAttrString(type, "__name__");
        message = type_name == NULL ? "unknown Python error" : PyUnicode_AsUTF8(type_name);
        set_error(runtime, message);
        Py_XDECREF(type_name);
    } else {
        set_error(runtime, message);
    }

    Py_XDECREF(message_object);
    Py_XDECREF(type);
    Py_XDECREF(value);
    Py_XDECREF(traceback);
    PyErr_Clear();
}

static int valid_runtime(py_runtime_handle *runtime) {
    return runtime != NULL && runtime->globals != NULL;
}

static int valid_value(py_value_handle *value) {
    return value != NULL && valid_runtime(value->runtime) && value->value != NULL;
}

static void free_runtime(py_runtime_handle *runtime) {
    if (runtime == NULL) {
        return;
    }

    Py_XDECREF(runtime->globals);
    free(runtime->last_error);
    free(runtime);
}

static void free_runtime_if_ready(py_runtime_handle *runtime) {
    if (runtime != NULL && runtime->destroying && runtime->value_count == 0) {
        free_runtime(runtime);
    }
}

static py_value_handle *new_value_handle(py_runtime_handle *runtime, PyObject *value) {
    if (!valid_runtime(runtime) || value == NULL) {
        Py_XDECREF(value);
        return NULL;
    }

    py_value_handle *handle = (py_value_handle *)calloc(1, sizeof(py_value_handle));
    if (handle == NULL) {
        Py_DECREF(value);
        set_error(runtime, "failed to allocate Python value handle");
        return NULL;
    }

    handle->runtime = runtime;
    handle->value = value;
    runtime->value_count++;
    return handle;
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
        capture_exception(runtime);
        return -1;
    }
    Py_DECREF(result);
    return 0;
}

py_runtime_handle *py_runtime_create(void) {
    if (!Py_IsInitialized()) {
        Py_Initialize();
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    py_runtime_handle *handle = (py_runtime_handle *)calloc(1, sizeof(py_runtime_handle));
    if (handle == NULL) {
        PyGILState_Release(gil);
        return NULL;
    }

    handle->globals = PyDict_New();
    if (handle->globals == NULL) {
        free(handle);
        PyGILState_Release(gil);
        return NULL;
    }

    if (PyDict_SetItemString(handle->globals, "__builtins__", PyEval_GetBuiltins()) != 0 ||
        install_global_helpers(handle) != 0) {
        Py_DECREF(handle->globals);
        free(handle->last_error);
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

const char *py_runtime_last_error(py_runtime_handle *handle) {
    return handle == NULL || handle->last_error == NULL ? "" : handle->last_error;
}

int64_t py_runtime_enable_std_module(py_runtime_handle *handle) {
    if (!valid_runtime(handle)) {
        return 1;
    }
    clear_error(handle);
    return 0;
}

py_value_handle *py_runtime_eval_value(py_runtime_handle *handle, const char *source) {
    if (!valid_runtime(handle) || source == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);

    PyObject *code = Py_CompileString(source, "<cangjie-python-eval>", Py_eval_input);
    if (code == NULL) {
        if (!PyErr_ExceptionMatches(PyExc_SyntaxError)) {
            capture_exception(handle);
            PyGILState_Release(gil);
            return NULL;
        }

        PyErr_Clear();
        code = Py_CompileString(source, "<cangjie-python-eval>", Py_file_input);
        if (code == NULL) {
            capture_exception(handle);
            PyGILState_Release(gil);
            return NULL;
        }
    }

    PyObject *result = PyEval_EvalCode(code, handle->globals, handle->globals);
    Py_DECREF(code);
    if (result == NULL) {
        capture_exception(handle);
        PyGILState_Release(gil);
        return NULL;
    }

    py_value_handle *value = new_value_handle(handle, result);
    PyGILState_Release(gil);
    return value;
}

py_value_handle *py_runtime_get_global_property(py_runtime_handle *handle, const char *name) {
    if (!valid_runtime(handle) || name == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);

    PyObject *value = PyDict_GetItemString(handle->globals, name);
    if (value == NULL) {
        set_error(handle, "Python global was not found");
        PyGILState_Release(gil);
        return NULL;
    }

    Py_INCREF(value);
    py_value_handle *result = new_value_handle(handle, value);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_bool(py_runtime_handle *handle, int64_t value) {
    if (!valid_runtime(handle)) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);
    PyObject *object = PyBool_FromLong(value != 0);
    py_value_handle *result = new_value_handle(handle, object);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_number(py_runtime_handle *handle, double value) {
    if (!valid_runtime(handle)) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);
    PyObject *object = PyFloat_FromDouble(value);
    if (object == NULL) {
        capture_exception(handle);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_integer(py_runtime_handle *handle, const char *value) {
    if (!valid_runtime(handle) || value == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);
    PyObject *object = PyLong_FromString(value, NULL, 10);
    if (object == NULL) {
        capture_exception(handle);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object);
    PyGILState_Release(gil);
    return result;
}

py_value_handle *py_runtime_new_string(py_runtime_handle *handle, const char *value) {
    if (!valid_runtime(handle) || value == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);
    PyObject *object = PyUnicode_FromString(value);
    if (object == NULL) {
        capture_exception(handle);
        PyGILState_Release(gil);
        return NULL;
    }
    py_value_handle *result = new_value_handle(handle, object);
    PyGILState_Release(gil);
    return result;
}

static py_value_handle *runtime_import_file(py_runtime_handle *handle, const char *path) {
    char resolved_path[PATH_MAX];
    if (realpath(path, resolved_path) == NULL) {
        set_error(handle, "failed to read Python module file");
        return NULL;
    }

    char *module_name = module_name_for_path(resolved_path);
    if (module_name == NULL) {
        set_error(handle, "failed to allocate Python module name");
        return NULL;
    }

    PyObject *importlib_util = PyImport_ImportModule("importlib.util");
    PyObject *sys_modules = PyImport_GetModuleDict();
    PyObject *spec = NULL;
    PyObject *module = NULL;
    PyObject *loader = NULL;
    PyObject *exec_module = NULL;
    PyObject *result = NULL;

    if (importlib_util == NULL) {
        capture_exception(handle);
        goto fail;
    }

    PyObject *spec_from_file_location = PyObject_GetAttrString(importlib_util, "spec_from_file_location");
    if (spec_from_file_location == NULL) {
        capture_exception(handle);
        goto fail;
    }

    spec = PyObject_CallFunction(spec_from_file_location, "ss", module_name, resolved_path);
    Py_DECREF(spec_from_file_location);
    if (spec == NULL || spec == Py_None) {
        capture_exception(handle);
        if (handle->last_error == NULL || handle->last_error[0] == '\0') {
            set_error(handle, "failed to create Python module spec");
        }
        goto fail;
    }

    PyObject *module_from_spec = PyObject_GetAttrString(importlib_util, "module_from_spec");
    if (module_from_spec == NULL) {
        capture_exception(handle);
        goto fail;
    }

    module = PyObject_CallFunctionObjArgs(module_from_spec, spec, NULL);
    Py_DECREF(module_from_spec);
    if (module == NULL) {
        capture_exception(handle);
        goto fail;
    }

    if (PyDict_SetItemString(sys_modules, module_name, module) != 0) {
        capture_exception(handle);
        goto fail;
    }

    loader = PyObject_GetAttrString(spec, "loader");
    if (loader == NULL || loader == Py_None) {
        set_error(handle, "failed to create Python module loader");
        goto fail;
    }

    exec_module = PyObject_GetAttrString(loader, "exec_module");
    if (exec_module == NULL) {
        capture_exception(handle);
        goto fail;
    }

    result = PyObject_CallFunctionObjArgs(exec_module, module, NULL);
    if (result == NULL) {
        capture_exception(handle);
        goto fail;
    }

    Py_DECREF(result);
    result = NULL;

    free(module_name);
    Py_XDECREF(exec_module);
    Py_XDECREF(loader);
    Py_XDECREF(spec);
    Py_XDECREF(importlib_util);
    return new_value_handle(handle, module);

fail:
    if (module_name != NULL && sys_modules != NULL) {
        PyDict_DelItemString(sys_modules, module_name);
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

py_value_handle *py_runtime_import_module(py_runtime_handle *handle, const char *path_or_name) {
    if (!valid_runtime(handle) || path_or_name == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle);

    py_value_handle *result = NULL;
    if (string_ends_with(path_or_name, ".py")) {
        result = runtime_import_file(handle, path_or_name);
    } else {
        PyObject *module = PyImport_ImportModule(path_or_name);
        if (module == NULL) {
            capture_exception(handle);
        } else {
            result = new_value_handle(handle, module);
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
    if (!valid_value(handle)) {
        return PYTHON_VALUE_NULL;
    }

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
    } else if (PyCallable_Check(value)) {
        kind = PYTHON_VALUE_CALLABLE;
    }
    PyGILState_Release(gil);
    return kind;
}

int64_t py_value_to_bool(py_value_handle *handle) {
    if (!valid_value(handle)) {
        return 0;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    int truth = PyObject_IsTrue(handle->value);
    if (truth < 0) {
        capture_exception(handle->runtime);
        truth = 0;
    }
    PyGILState_Release(gil);
    return truth != 0;
}

double py_value_to_number(py_value_handle *handle) {
    if (!valid_value(handle)) {
        return 0.0;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    double number = PyFloat_AsDouble(handle->value);
    if (PyErr_Occurred()) {
        capture_exception(handle->runtime);
        number = 0.0;
    }
    PyGILState_Release(gil);
    return number;
}

const char *py_value_to_string(py_value_handle *handle) {
    if (!valid_value(handle)) {
        return copy_string("");
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    PyObject *string = PyObject_Str(handle->value);
    if (string == NULL) {
        capture_exception(handle->runtime);
        PyGILState_Release(gil);
        return copy_string("");
    }

    const char *utf8 = PyUnicode_AsUTF8(string);
    char *copy = copy_string(utf8 == NULL ? "" : utf8);
    Py_DECREF(string);
    PyGILState_Release(gil);
    return copy;
}

void py_bridge_free_string(const char *value) {
    free((void *)value);
}

int64_t py_value_is_array(py_value_handle *handle) {
    if (!valid_value(handle)) {
        return 0;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    int is_array = PyList_Check(handle->value) || PyTuple_Check(handle->value);
    PyGILState_Release(gil);
    return is_array;
}

int64_t py_value_array_length(py_value_handle *handle) {
    if (!valid_value(handle)) {
        return 0;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    Py_ssize_t size = PySequence_Size(handle->value);
    if (size < 0) {
        capture_exception(handle->runtime);
        size = 0;
    }
    PyGILState_Release(gil);
    return (int64_t)size;
}

static PyObject *length_property(py_runtime_handle *runtime, PyObject *value) {
    Py_ssize_t size = -1;
    if (PyList_Check(value) || PyTuple_Check(value) || PyDict_Check(value)) {
        size = PyObject_Length(value);
    }

    if (size < 0) {
        if (PyErr_Occurred()) {
            capture_exception(runtime);
        }
        return NULL;
    }

    return PyLong_FromSsize_t(size);
}

py_value_handle *py_value_get_property(py_value_handle *handle, const char *name) {
    if (!valid_value(handle) || name == NULL) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle->runtime);

    PyObject *result = NULL;
    if (strcmp(name, "length") == 0) {
        result = length_property(handle->runtime, handle->value);
        if (result != NULL) {
            py_value_handle *value = new_value_handle(handle->runtime, result);
            PyGILState_Release(gil);
            return value;
        }
        PyErr_Clear();
    }

    result = PyObject_GetAttrString(handle->value, name);
    if (result == NULL) {
        PyErr_Clear();
        PyObject *key = PyUnicode_FromString(name);
        if (key == NULL) {
            capture_exception(handle->runtime);
            PyGILState_Release(gil);
            return NULL;
        }
        result = PyObject_GetItem(handle->value, key);
        Py_DECREF(key);
        if (result == NULL) {
            capture_exception(handle->runtime);
            PyGILState_Release(gil);
            return NULL;
        }
    }

    py_value_handle *value = new_value_handle(handle->runtime, result);
    PyGILState_Release(gil);
    return value;
}

int64_t py_value_set_property(py_value_handle *handle, const char *name, py_value_handle *value) {
    if (!valid_value(handle) || !valid_value(value) || name == NULL) {
        return 1;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle->runtime);

    int status = PyObject_SetAttrString(handle->value, name, value->value);
    if (status != 0) {
        PyErr_Clear();
        PyObject *key = PyUnicode_FromString(name);
        if (key == NULL) {
            capture_exception(handle->runtime);
            PyGILState_Release(gil);
            return 1;
        }
        status = PyObject_SetItem(handle->value, key, value->value);
        Py_DECREF(key);
    }

    if (status != 0) {
        capture_exception(handle->runtime);
    }

    PyGILState_Release(gil);
    return status == 0 ? 0 : 1;
}

py_value_handle *py_value_get_index(py_value_handle *handle, int64_t index) {
    if (!valid_value(handle)) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle->runtime);

    PyObject *key = PyLong_FromLongLong(index);
    if (key == NULL) {
        capture_exception(handle->runtime);
        PyGILState_Release(gil);
        return NULL;
    }

    PyObject *result = PyObject_GetItem(handle->value, key);
    Py_DECREF(key);
    if (result == NULL) {
        capture_exception(handle->runtime);
        PyGILState_Release(gil);
        return NULL;
    }

    py_value_handle *value = new_value_handle(handle->runtime, result);
    PyGILState_Release(gil);
    return value;
}

int64_t py_value_set_index(py_value_handle *handle, int64_t index, py_value_handle *value) {
    if (!valid_value(handle) || !valid_value(value)) {
        return 1;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(handle->runtime);

    PyObject *key = PyLong_FromLongLong(index);
    if (key == NULL) {
        capture_exception(handle->runtime);
        PyGILState_Release(gil);
        return 1;
    }

    int status = PyObject_SetItem(handle->value, key, value->value);
    Py_DECREF(key);
    if (status != 0) {
        capture_exception(handle->runtime);
    }

    PyGILState_Release(gil);
    return status == 0 ? 0 : 1;
}

py_value_handle *py_value_call(py_value_handle *function, py_value_handle *this_value, py_value_handle **args, int num_args) {
    (void)this_value;
    if (!valid_value(function) || num_args < 0) {
        return NULL;
    }

    PyGILState_STATE gil = PyGILState_Ensure();
    clear_error(function->runtime);

    if (!PyCallable_Check(function->value)) {
        set_error(function->runtime, "Python value is not callable");
        PyGILState_Release(gil);
        return NULL;
    }

    PyObject *tuple = PyTuple_New((Py_ssize_t)num_args);
    if (tuple == NULL) {
        capture_exception(function->runtime);
        PyGILState_Release(gil);
        return NULL;
    }

    for (int i = 0; i < num_args; i++) {
        if (args == NULL || !valid_value(args[i])) {
            Py_DECREF(tuple);
            set_error(function->runtime, "Python call argument is invalid");
            PyGILState_Release(gil);
            return NULL;
        }
        Py_INCREF(args[i]->value);
        PyTuple_SetItem(tuple, (Py_ssize_t)i, args[i]->value);
    }

    PyObject *result = PyObject_CallObject(function->value, tuple);
    Py_DECREF(tuple);
    if (result == NULL) {
        capture_exception(function->runtime);
        PyGILState_Release(gil);
        return NULL;
    }

    py_value_handle *value = new_value_handle(function->runtime, result);
    PyGILState_Release(gil);
    return value;
}

py_value_handle *py_value_construct(py_value_handle *constructor, py_value_handle **args, int num_args) {
    return py_value_call(constructor, NULL, args, num_args);
}
