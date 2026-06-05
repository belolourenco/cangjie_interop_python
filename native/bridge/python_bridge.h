#ifndef INTEROP_PYTHON_BRIDGE_H
#define INTEROP_PYTHON_BRIDGE_H

#include <stdint.h>

typedef struct runtime_handle runtime_handle;
typedef struct value_handle value_handle;

runtime_handle *runtime_create(void);
void runtime_destroy(runtime_handle *handle);
const char *runtime_last_error(runtime_handle *handle);
int64_t runtime_enable_std_module(runtime_handle *handle);

value_handle *runtime_eval_value(runtime_handle *handle, const char *source);
value_handle *runtime_get_global_property(runtime_handle *handle, const char *name);
value_handle *runtime_new_bool(runtime_handle *handle, int64_t value);
value_handle *runtime_new_number(runtime_handle *handle, double value);
value_handle *runtime_new_integer(runtime_handle *handle, const char *value);
value_handle *runtime_new_string(runtime_handle *handle, const char *value);
value_handle *runtime_import_module(runtime_handle *handle, const char *path_or_name);

void value_destroy(value_handle *handle);
int64_t value_kind(value_handle *handle);
int64_t value_to_bool(value_handle *handle);
double value_to_number(value_handle *handle);
const char *value_to_string(value_handle *handle);
void bridge_free_string(const char *value);

int64_t value_is_array(value_handle *handle);
int64_t value_array_length(value_handle *handle);
value_handle *value_get_property(value_handle *handle, const char *name);
int64_t value_set_property(value_handle *handle, const char *name, value_handle *value);
value_handle *value_get_index(value_handle *handle, int64_t index);
int64_t value_set_index(value_handle *handle, int64_t index, value_handle *value);

value_handle *value_call(value_handle *function, value_handle *this_value, value_handle **args, int num_args);
value_handle *value_construct(value_handle *constructor, value_handle **args, int num_args);

#endif
