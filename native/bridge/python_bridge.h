#ifndef INTEROP_PYTHON_BRIDGE_H
#define INTEROP_PYTHON_BRIDGE_H

#include <stdint.h>

typedef struct py_runtime_handle py_runtime_handle;
typedef struct py_value_handle py_value_handle;

py_runtime_handle *py_runtime_create(void);
void py_runtime_destroy(py_runtime_handle *handle);
const char *py_runtime_last_error(py_runtime_handle *handle);
int64_t py_runtime_enable_std_module(py_runtime_handle *handle);

py_value_handle *py_runtime_eval_value(py_runtime_handle *handle, const char *source);
py_value_handle *py_runtime_get_global_property(py_runtime_handle *handle, const char *name);
py_value_handle *py_runtime_new_bool(py_runtime_handle *handle, int64_t value);
py_value_handle *py_runtime_new_number(py_runtime_handle *handle, double value);
py_value_handle *py_runtime_new_integer(py_runtime_handle *handle, const char *value);
py_value_handle *py_runtime_new_string(py_runtime_handle *handle, const char *value);
py_value_handle *py_runtime_import_module(py_runtime_handle *handle, const char *path_or_name);

void py_value_destroy(py_value_handle *handle);
int64_t py_value_kind(py_value_handle *handle);
int64_t py_value_to_bool(py_value_handle *handle);
double py_value_to_number(py_value_handle *handle);
const char *py_value_to_string(py_value_handle *handle);
void py_bridge_free_string(const char *value);

int64_t py_value_is_array(py_value_handle *handle);
int64_t py_value_array_length(py_value_handle *handle);
py_value_handle *py_value_get_property(py_value_handle *handle, const char *name);
int64_t py_value_set_property(py_value_handle *handle, const char *name, py_value_handle *value);
py_value_handle *py_value_get_index(py_value_handle *handle, int64_t index);
int64_t py_value_set_index(py_value_handle *handle, int64_t index, py_value_handle *value);

py_value_handle *py_value_call(py_value_handle *function, py_value_handle *this_value, py_value_handle **args, int num_args);
py_value_handle *py_value_construct(py_value_handle *constructor, py_value_handle **args, int num_args);

#endif
