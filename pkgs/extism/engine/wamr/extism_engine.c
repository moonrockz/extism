/*
 * The C stub of the moonrockz/extism native engine over WAMR (design ENG-2, ENG-4 and BND-1).
 *
 * - Every host import is a raw native (wasm_runtime_register_natives_raw), so no invokeNative runs.
 *   WAMR's native registry is process-global and it resolves imports at load, so each (module, field)
 *   name is registered once, with one generic trampoline and its symbol id as the attachment.
 * - The imports are bound per instance: each instance has an InstanceData with one entry per symbol,
 *   either a MoonBit host function (called through the callback that extism_wamr_init stores) or an
 *   exported function of another instance (called directly, with that instance's execution
 *   environment, so a kernel call does not cross into MoonBit and does not count against the budget).
 * - A call can have an instruction budget (wasm_runtime_set_instruction_count_limit) and a deadline: a
 *   watchdog thread calls wasm_runtime_terminate when the deadline passes. The watchdog is always
 *   cancelled and joined before extism_wamr_call returns.
 * - The enlarge-memory error callback records a refused memory.grow on the instance.
 * - The stub maps the WAMR exception text to a status code, so MoonBit code never reads messages.
 */
#include "extism_config.h"
#include "core/iwasm/include/wasm_export.h"
#include "core/shared/platform/include/platform_api_vmcore.h"
#include "core/shared/platform/include/platform_api_extension.h"
#include "moonbit.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Status codes of extism_wamr_call; native.mbt has the same values. */
enum {
  EXTISM_STATUS_OK = 0,
  EXTISM_STATUS_UNKNOWN_EXPORT = 1,
  EXTISM_STATUS_ARITY = 2,
  EXTISM_STATUS_TRAP_UNREACHABLE = 10,
  EXTISM_STATUS_TRAP_MEMORY = 11,
  EXTISM_STATUS_TRAP_DIVIDE_BY_ZERO = 12,
  EXTISM_STATUS_TRAP_INTEGER_OVERFLOW = 13,
  EXTISM_STATUS_TRAP_CONVERSION = 14,
  EXTISM_STATUS_TRAP_STACK = 15,
  EXTISM_STATUS_TRAP_INDIRECT_CALL = 16,
  EXTISM_STATUS_TRAP_HOST = 17,
  EXTISM_STATUS_TRAP_TABLE = 18,
  EXTISM_STATUS_TRAP_OTHER = 19,
  EXTISM_STATUS_BUDGET = 20,
  EXTISM_STATUS_INTERRUPTED = 21,
};

enum { EXTISM_BINDING_NONE = 0, EXTISM_BINDING_HOST = 1, EXTISM_BINDING_EXPORT = 2 };

/* The exception that a failed host function sets on its calling instance. */
static const char host_failure[] = "moonrockz-extism: host function failed";

typedef int32_t (*host_callback_t)(int32_t host_id, uint64_t cells);

typedef struct InstanceData InstanceData;

typedef struct {
  int32_t symbol;
  int32_t kind;
  int32_t host_id;
  InstanceData *target;
  wasm_function_inst_t function;
} Binding;

struct InstanceData {
  wasm_module_inst_t instance;
  wasm_exec_env_t env;
  int32_t count;
  Binding *bindings;
  int32_t grow_refused;
  int32_t host_failed;
};

typedef struct {
  wasm_module_t module;
  uint8_t *bytes;
} ModuleObject;

typedef struct {
  InstanceData *data;
} InstanceObject;

static int initialized = 0;
static host_callback_t host_callback = NULL;

/* The instance data of the instance that wasm_runtime_instantiate is making, for imports that its
   start function calls before the data is set on the instance. The engine is single-threaded. */
static InstanceData *pending = NULL;

static InstanceData *
data_of(wasm_module_inst_t instance)
{
  InstanceData *data = (InstanceData *)wasm_runtime_get_custom_data(instance);
  return data ? data : pending;
}

static void
on_enlarge_error(uint32_t inc_page_count, uint64_t current_memory_size, uint32_t memory_index,
                 enlarge_memory_error_reason_t reason, wasm_module_inst_t instance,
                 wasm_exec_env_t exec_env, void *user_data)
{
  (void)inc_page_count;
  (void)current_memory_size;
  (void)memory_index;
  (void)reason;
  (void)exec_env;
  (void)user_data;
  InstanceData *data = data_of(instance);
  if (data) {
    data->grow_refused = 1;
  }
}

int32_t
extism_wamr_init(host_callback_t callback)
{
  host_callback = callback;
  if (initialized) {
    return 1;
  }
  RuntimeInitArgs args;
  memset(&args, 0, sizeof(args));
  args.mem_alloc_type = Alloc_With_System_Allocator;
  if (!wasm_runtime_full_init(&args)) {
    return 0;
  }
  wasm_runtime_set_log_level(WASM_LOG_LEVEL_FATAL);
  wasm_runtime_set_enlarge_mem_error_callback(on_enlarge_error, NULL);
  initialized = 1;
  return 1;
}

/* Raw natives never reach invokeNative, and the C API (wasm_c_api.c) is not built. The two symbols
   exist only for the link. */
void
invokeNative(void (*function)(void), uint32_t *argv, uint32_t argc)
{
  (void)function;
  (void)argv;
  (void)argc;
  abort();
}

void
wasm_trap_delete(void *trap)
{
  (void)trap;
  abort();
}

/* The Windows platform of WAMR starts Winsock; the engine opens no socket and links no Winsock. */
#if defined(_WIN32)
int
init_winsock(void)
{
  return 0;
}

void
deinit_winsock(void)
{}
#endif

/* ---- Registered names ---- */

typedef struct {
  char *module;
  char *field;
} Name;

static Name *names = NULL;
static int32_t name_count = 0;
static int32_t name_capacity = 0;

static char *
copy_text(moonbit_bytes_t bytes)
{
  int32_t length = Moonbit_array_length(bytes);
  char *text = (char *)malloc((size_t)length + 1);
  memcpy(text, bytes, (size_t)length);
  text[length] = '\0';
  return text;
}

static void trampoline(wasm_exec_env_t env, uint64_t *args);

int32_t
extism_wamr_register(moonbit_bytes_t module, moonbit_bytes_t field)
{
  int32_t module_length = Moonbit_array_length(module);
  int32_t field_length = Moonbit_array_length(field);
  for (int32_t i = 0; i < name_count; i++) {
    if ((int32_t)strlen(names[i].module) == module_length
        && (int32_t)strlen(names[i].field) == field_length
        && memcmp(names[i].module, module, (size_t)module_length) == 0
        && memcmp(names[i].field, field, (size_t)field_length) == 0) {
      return i;
    }
  }
  if (name_count == name_capacity) {
    name_capacity = name_capacity ? name_capacity * 2 : 64;
    names = (Name *)realloc(names, sizeof(Name) * (size_t)name_capacity);
  }
  int32_t id = name_count++;
  names[id].module = copy_text(module);
  names[id].field = copy_text(field);
  /* WAMR keeps the symbol array and the strings; they live for the process. A raw native with no
     signature string takes any type; the engine checks the types itself before it instantiates. */
  NativeSymbol *symbol = (NativeSymbol *)calloc(1, sizeof(NativeSymbol));
  symbol->symbol = names[id].field;
  symbol->func_ptr = (void *)trampoline;
  symbol->signature = NULL;
  symbol->attachment = (void *)(intptr_t)id;
  if (!wasm_runtime_register_natives_raw(names[id].module, symbol, 1)) {
    return -1;
  }
  return id;
}

/* ---- Modules ---- */

static void
finalize_module(void *self)
{
  ModuleObject *object = (ModuleObject *)self;
  if (object->module) {
    wasm_runtime_unload(object->module);
  }
  free(object->bytes);
}

static void
write_error(moonbit_bytes_t out, const char *text)
{
  int32_t capacity = Moonbit_array_length(out);
  int32_t length = (int32_t)strlen(text);
  if (length > capacity) {
    length = capacity;
  }
  memset(out, 0, (size_t)capacity);
  memcpy(out, text, (size_t)length);
}

void *
extism_wamr_load(moonbit_bytes_t wasm, moonbit_bytes_t error)
{
  ModuleObject *object =
    (ModuleObject *)moonbit_make_external_object(finalize_module, sizeof(ModuleObject));
  int32_t length = Moonbit_array_length(wasm);
  /* WAMR reads the module bytes after the load, so the stub keeps its own copy. */
  object->bytes = (uint8_t *)malloc(length > 0 ? (size_t)length : 1);
  memcpy(object->bytes, wasm, (size_t)length);
  char buffer[256] = { 0 };
  object->module = wasm_runtime_load(object->bytes, (uint32_t)length, buffer, sizeof(buffer));
  if (!object->module) {
    write_error(error, buffer);
  }
  return object;
}

int32_t
extism_wamr_module_ok(ModuleObject *object)
{
  return object->module != NULL;
}

/* ---- Linkers and instances ---- */

uint64_t
extism_wamr_linker_new(int32_t count)
{
  InstanceData *data = (InstanceData *)calloc(1, sizeof(InstanceData));
  data->count = count;
  data->bindings = (Binding *)calloc(count > 0 ? (size_t)count : 1, sizeof(Binding));
  return (uint64_t)(uintptr_t)data;
}

void
extism_wamr_linker_host(uint64_t linker, int32_t index, int32_t symbol, int32_t host_id)
{
  InstanceData *data = (InstanceData *)(uintptr_t)linker;
  data->bindings[index].symbol = symbol;
  data->bindings[index].kind = EXTISM_BINDING_HOST;
  data->bindings[index].host_id = host_id;
}

int32_t
extism_wamr_linker_export(uint64_t linker, int32_t index, int32_t symbol, InstanceObject *target,
                          moonbit_bytes_t name)
{
  InstanceData *data = (InstanceData *)(uintptr_t)linker;
  char *text = copy_text(name);
  wasm_function_inst_t function = wasm_runtime_lookup_function(target->data->instance, text);
  free(text);
  if (!function) {
    return 0;
  }
  data->bindings[index].symbol = symbol;
  data->bindings[index].kind = EXTISM_BINDING_EXPORT;
  data->bindings[index].target = target->data;
  data->bindings[index].function = function;
  return 1;
}

static void
free_data(InstanceData *data)
{
  if (data->env) {
    wasm_runtime_destroy_exec_env(data->env);
  }
  if (data->instance) {
    wasm_runtime_deinstantiate(data->instance);
  }
  free(data->bindings);
  free(data);
}

static void
finalize_instance(void *self)
{
  InstanceObject *object = (InstanceObject *)self;
  if (object->data) {
    free_data(object->data);
  }
}

void *
extism_wamr_instantiate(ModuleObject *module, uint64_t linker, int32_t max_pages,
                        int32_t stack_size, moonbit_bytes_t error)
{
  InstanceObject *object =
    (InstanceObject *)moonbit_make_external_object(finalize_instance, sizeof(InstanceObject));
  object->data = NULL;
  InstanceData *data = (InstanceData *)(uintptr_t)linker;
  struct InstantiationArgs2 *args = NULL;
  if (!wasm_runtime_instantiation_args_create(&args)) {
    write_error(error, "cannot make the instantiation arguments");
    free_data(data);
    return object;
  }
  wasm_runtime_instantiation_args_set_default_stack_size(args, (uint32_t)stack_size);
  wasm_runtime_instantiation_args_set_host_managed_heap_size(args, 0);
  wasm_runtime_instantiation_args_set_max_memory_pages(args, (uint32_t)max_pages);
  char buffer[256] = { 0 };
  pending = data;
  data->instance = wasm_runtime_instantiate_ex2(module->module, args, buffer, sizeof(buffer));
  pending = NULL;
  wasm_runtime_instantiation_args_destroy(args);
  if (!data->instance) {
    write_error(error, buffer);
    free_data(data);
    return object;
  }
  wasm_runtime_set_custom_data(data->instance, data);
  data->env = wasm_runtime_create_exec_env(data->instance, (uint32_t)stack_size);
  if (!data->env) {
    write_error(error, "cannot make the execution environment");
    free_data(data);
    return object;
  }
  object->data = data;
  return object;
}

int32_t
extism_wamr_instance_ok(InstanceObject *object)
{
  return object->data != NULL;
}

int32_t
extism_wamr_take_grow_refused(InstanceObject *object)
{
  int32_t refused = object->data->grow_refused;
  object->data->grow_refused = 0;
  return refused;
}

/* ---- Calls ---- */

static int32_t
status_of(const char *exception)
{
  if (!exception) {
    return EXTISM_STATUS_TRAP_OTHER;
  }
  if (strstr(exception, "terminated by user")) {
    return EXTISM_STATUS_INTERRUPTED;
  }
  if (strstr(exception, "instruction limit exceeded")) {
    return EXTISM_STATUS_BUDGET;
  }
  if (strstr(exception, host_failure)) {
    return EXTISM_STATUS_TRAP_HOST;
  }
  if (strstr(exception, "unreachable")) {
    return EXTISM_STATUS_TRAP_UNREACHABLE;
  }
  if (strstr(exception, "out of bounds memory access")) {
    return EXTISM_STATUS_TRAP_MEMORY;
  }
  if (strstr(exception, "integer divide by zero")) {
    return EXTISM_STATUS_TRAP_DIVIDE_BY_ZERO;
  }
  if (strstr(exception, "integer overflow")) {
    return EXTISM_STATUS_TRAP_INTEGER_OVERFLOW;
  }
  if (strstr(exception, "invalid conversion to integer")) {
    return EXTISM_STATUS_TRAP_CONVERSION;
  }
  if (strstr(exception, "stack overflow")) {
    return EXTISM_STATUS_TRAP_STACK;
  }
  if (strstr(exception, "indirect call") || strstr(exception, "undefined element")
      || strstr(exception, "uninitialized element") || strstr(exception, "invalid function index")) {
    return EXTISM_STATUS_TRAP_INDIRECT_CALL;
  }
  if (strstr(exception, "out of bounds table access")) {
    return EXTISM_STATUS_TRAP_TABLE;
  }
  return EXTISM_STATUS_TRAP_OTHER;
}

/* Calls `function` of `data` with one 64-bit cell per parameter and writes the results into the
   cells. Gives a status code. */
static int32_t
call_cells(InstanceData *data, wasm_exec_env_t env, wasm_function_inst_t function, uint64_t *cells)
{
  uint32_t params = wasm_func_get_param_count(function, data->instance);
  uint32_t results = wasm_func_get_result_count(function, data->instance);
  wasm_valkind_t param_types[16];
  wasm_valkind_t result_types[16];
  if (params > 16 || results > 16) {
    return EXTISM_STATUS_ARITY;
  }
  wasm_func_get_param_types(function, data->instance, param_types);
  wasm_func_get_result_types(function, data->instance, result_types);
  uint32_t argv[32];
  uint32_t used = 0;
  for (uint32_t i = 0; i < params; i++) {
    if (param_types[i] == WASM_I64 || param_types[i] == WASM_F64) {
      memcpy(&argv[used], &cells[i], sizeof(uint64_t));
      used += 2;
    }
    else {
      argv[used++] = (uint32_t)cells[i];
    }
  }
  if (!wasm_runtime_call_wasm(env, function, used, argv)) {
    return status_of(wasm_runtime_get_exception(data->instance));
  }
  uint32_t at = 0;
  for (uint32_t i = 0; i < results; i++) {
    if (result_types[i] == WASM_I64 || result_types[i] == WASM_F64) {
      memcpy(&cells[i], &argv[at], sizeof(uint64_t));
      at += 2;
    }
    else {
      cells[i] = argv[at++];
    }
  }
  return EXTISM_STATUS_OK;
}

static void
trampoline(wasm_exec_env_t env, uint64_t *args)
{
  wasm_module_inst_t instance = wasm_runtime_get_module_inst(env);
  InstanceData *data = data_of(instance);
  int32_t symbol = (int32_t)(intptr_t)wasm_runtime_get_function_attachment(env);
  Binding *binding = NULL;
  for (int32_t i = 0; data && i < data->count; i++) {
    if (data->bindings[i].symbol == symbol && data->bindings[i].kind != EXTISM_BINDING_NONE) {
      binding = &data->bindings[i];
      break;
    }
  }
  if (!binding) {
    wasm_runtime_set_exception(instance, "failed to call unlinked import function");
    return;
  }
  if (binding->kind == EXTISM_BINDING_HOST) {
    if (!host_callback || host_callback(binding->host_id, (uint64_t)(uintptr_t)args) != 0) {
      data->host_failed = 1;
      wasm_runtime_set_exception(instance, host_failure);
    }
    return;
  }
  InstanceData *target = binding->target;
  int32_t status = call_cells(target, target->env, binding->function, args);
  if (status != EXTISM_STATUS_OK) {
    const char *exception = wasm_runtime_get_exception(target->instance);
    wasm_runtime_set_exception(instance, exception ? exception : "trap in a linked instance");
    wasm_runtime_clear_exception(target->instance);
  }
}

/* ---- The deadline watchdog ---- */

typedef struct {
  korp_mutex lock;
  korp_cond done;
  int finished;
  uint64_t microseconds;
  wasm_module_inst_t instance;
} Watchdog;

static int32_t live_watchdogs = 0;

static void *
watch(void *arg)
{
  Watchdog *watchdog = (Watchdog *)arg;
  uint64_t start = os_time_get_boot_us();
  os_mutex_lock(&watchdog->lock);
  while (!watchdog->finished) {
    uint64_t now = os_time_get_boot_us();
    if (now - start >= watchdog->microseconds) {
      wasm_runtime_terminate(watchdog->instance);
      break;
    }
    os_cond_reltimedwait(&watchdog->done, &watchdog->lock,
                         watchdog->microseconds - (now - start));
  }
  os_mutex_unlock(&watchdog->lock);
  return NULL;
}

int32_t
extism_wamr_live_watchdogs(void)
{
  return live_watchdogs;
}

int32_t
extism_wamr_call(InstanceObject *object, moonbit_bytes_t name, uint64_t *cells, int32_t budget,
                 int32_t deadline_ms)
{
  InstanceData *data = object->data;
  char *text = copy_text(name);
  wasm_function_inst_t function = wasm_runtime_lookup_function(data->instance, text);
  free(text);
  if (!function) {
    return EXTISM_STATUS_UNKNOWN_EXPORT;
  }
  data->host_failed = 0;
  wasm_runtime_set_instruction_count_limit(data->env, budget > 0 ? budget : -1);
  Watchdog watchdog;
  korp_tid thread;
  int watching = 0;
  if (deadline_ms > 0) {
    memset(&watchdog, 0, sizeof(watchdog));
    watchdog.microseconds = (uint64_t)deadline_ms * 1000;
    watchdog.instance = data->instance;
    if (os_mutex_init(&watchdog.lock) == 0) {
      if (os_cond_init(&watchdog.done) == 0) {
        if (os_thread_create(&thread, watch, &watchdog, 64 * 1024) == 0) {
          watching = 1;
          live_watchdogs++;
        }
        else {
          os_cond_destroy(&watchdog.done);
          os_mutex_destroy(&watchdog.lock);
        }
      }
      else {
        os_mutex_destroy(&watchdog.lock);
      }
    }
  }
  int32_t status = call_cells(data, data->env, function, cells);
  if (watching) {
    os_mutex_lock(&watchdog.lock);
    watchdog.finished = 1;
    os_cond_signal(&watchdog.done);
    os_mutex_unlock(&watchdog.lock);
    os_thread_join(thread, NULL);
    os_cond_destroy(&watchdog.done);
    os_mutex_destroy(&watchdog.lock);
    live_watchdogs--;
  }
  if (status != EXTISM_STATUS_OK && data->host_failed) {
    status = EXTISM_STATUS_TRAP_HOST;
  }
  return status;
}

/* Whether a thread for a deadline can start on this platform. */
int32_t
extism_wamr_deadline_supported(void)
{
  return initialized;
}

int32_t
extism_wamr_has_export(InstanceObject *object, moonbit_bytes_t name)
{
  char *text = copy_text(name);
  wasm_function_inst_t function = wasm_runtime_lookup_function(object->data->instance, text);
  free(text);
  return function != NULL;
}

/* ---- Cells of host calls ---- */

uint64_t
extism_wamr_cell_get(uint64_t cells, int32_t index)
{
  return ((uint64_t *)(uintptr_t)cells)[index];
}

void
extism_wamr_cell_set(uint64_t cells, int32_t index, uint64_t value)
{
  ((uint64_t *)(uintptr_t)cells)[index] = value;
}

/* ---- Guest memory ---- */

int64_t
extism_wamr_memory_size(InstanceObject *object)
{
  wasm_memory_inst_t memory = wasm_runtime_get_default_memory(object->data->instance);
  if (!memory) {
    return -1;
  }
  return (int64_t)wasm_memory_get_cur_page_count(memory)
         * (int64_t)wasm_memory_get_bytes_per_page(memory);
}

static uint8_t *
memory_range(InstanceObject *object, int64_t offset, int32_t length)
{
  int64_t size = extism_wamr_memory_size(object);
  if (size < 0 || offset < 0 || length < 0 || offset > size || (int64_t)length > size - offset) {
    return NULL;
  }
  wasm_memory_inst_t memory = wasm_runtime_get_default_memory(object->data->instance);
  return (uint8_t *)wasm_memory_get_base_address(memory) + offset;
}

int32_t
extism_wamr_memory_read(InstanceObject *object, int64_t offset, moonbit_bytes_t out,
                        int32_t out_offset, int32_t length)
{
  uint8_t *source = memory_range(object, offset, length);
  if (!source || out_offset < 0 || out_offset + length > Moonbit_array_length(out)) {
    return 0;
  }
  memcpy(out + out_offset, source, (size_t)length);
  return 1;
}

int32_t
extism_wamr_memory_write(InstanceObject *object, int64_t offset, moonbit_bytes_t bytes,
                         int32_t bytes_offset, int32_t length)
{
  uint8_t *target = memory_range(object, offset, length);
  if (!target || bytes_offset < 0 || bytes_offset + length > Moonbit_array_length(bytes)) {
    return 0;
  }
  memcpy(target, bytes + bytes_offset, (size_t)length);
  return 1;
}
