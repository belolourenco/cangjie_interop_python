#ifndef INTEROP_PYTHON_BRIDGE_H
#define INTEROP_PYTHON_BRIDGE_H

#include <stdint.h>

typedef struct py_runtime_handle py_runtime_handle;
typedef struct py_value_handle py_value_handle;

typedef enum {
    PY_ERROR_FOREIGN = 1,
    PY_ERROR_MEMBER,
    PY_ERROR_INDEX,
    PY_ERROR_NOT_CALLABLE,
    PY_ERROR_ARGUMENTS,
    PY_ERROR_CONVERSION,
} py_error_kind;

typedef struct {
    int64_t kind;
    const char *message;
} py_bridge_error;

py_runtime_handle *py_runtime_create(py_bridge_error *error);
void py_runtime_destroy(py_runtime_handle *handle);

py_value_handle *py_runtime_eval_value(py_runtime_handle *handle, const char *source, py_bridge_error *error);
py_value_handle *py_runtime_get_global_property(py_runtime_handle *handle, const char *name, py_bridge_error *error);
py_value_handle *py_runtime_new_bool(py_runtime_handle *handle, int64_t value, py_bridge_error *error);
py_value_handle *py_runtime_new_number(py_runtime_handle *handle, double value, py_bridge_error *error);
py_value_handle *py_runtime_new_integer(py_runtime_handle *handle, const char *value, py_bridge_error *error);
py_value_handle *py_runtime_new_string(py_runtime_handle *handle, const char *value, int64_t size, py_bridge_error *error);
py_value_handle *py_runtime_import_module(py_runtime_handle *handle, const char *path_or_name, py_bridge_error *error);

void py_value_destroy(py_value_handle *handle);
int64_t py_value_kind(py_value_handle *handle);
int64_t py_value_to_bool(py_value_handle *handle);
int64_t py_value_is_callable(py_value_handle *handle);
double py_value_to_number(py_value_handle *handle, py_bridge_error *error);
const char *py_value_to_string(py_value_handle *handle, int64_t *size, py_bridge_error *error);
void py_bridge_free_string(const char *value);

py_value_handle *py_value_get_property(py_value_handle *handle, const char *name, py_bridge_error *error);
void py_value_set_property(py_value_handle *handle, const char *name, py_value_handle *value, py_bridge_error *error);
py_value_handle *py_value_get_index(py_value_handle *handle, py_value_handle *index, py_bridge_error *error);
void py_value_set_index(py_value_handle *handle, py_value_handle *index, py_value_handle *value, py_bridge_error *error);

py_value_handle *py_value_call(py_value_handle *function, py_value_handle **args, int64_t num_args, py_bridge_error *error);

#endif
