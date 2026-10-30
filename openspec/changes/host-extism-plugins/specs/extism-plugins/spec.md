# Spec Delta

## Purpose

Defines how an embedder loads and calls an Extism plugin with this library: the manifest, the import surface that
the library links, the policy for each Extism host function, host functions that the embedder registers, calls,
limits and the errors of each.

## ADDED Requirements

### Requirement: Manifest
An embedder SHALL load a plugin from a manifest that holds the module bytes, the limits, the Extism host function
policy, the registered host functions and whether the WASI sandbox is enabled. The library SHALL NOT read a
manifest, a module or a configuration from a file, a URL or the environment.

#### Scenario: Load from bytes
- **WHEN** an embedder gives a manifest with the bytes of a plugin and no other setting
- **THEN** the plugin loads with the default limits and the default policy

### Requirement: Closed import surface
At load, the library SHALL link the kernel, the Extism host functions, the registered host functions and, when
enabled, the WASI sandbox. A module import that none of these links SHALL fail the load before instantiation,
with an error that names the module and field of the first such import.

#### Scenario: Unknown import
- **WHEN** a plugin imports `env.secret_syscall` and the embedder registered no such function
- **THEN** the load fails with an unlinked import error that names `env.secret_syscall`

### Requirement: Full kernel for every plugin
Every plugin SHALL have its own kernel instance, created from the embedded kernel bytes, and its
`extism:host/env` kernel imports SHALL call that instance. Two plugins SHALL NOT share kernel memory.

#### Scenario: Two plugins
- **WHEN** an embedder loads two plugins and calls both
- **THEN** each call reads its input from and writes its output to its own kernel memory

#### Scenario: Two plugins from the same bytes
- **WHEN** an embedder loads two plugins from the same module bytes, sets a different input for each and calls both
- **THEN** each call returns the output of its own input, on native and on js

### Requirement: Call by export name
`call` SHALL reset the kernel, put the input bytes in kernel memory, call the named export with no arguments, and
return the output bytes when the export returns 0 and no error is set. A non-zero return, a set kernel error or a
trap SHALL make the call fail with a typed error that holds the return code, the error text or the trap kind.

#### Scenario: Successful call
- **WHEN** an embedder enables the WASI sandbox and calls `count_vowels` with the input `hello world` on the
  count-vowels plugin of `extism/wamr-sdk`
- **THEN** the call returns the plugin's output bytes, a JSON object whose `count` is 3

#### Scenario: Plugin sets an error
- **WHEN** the export calls `error_set` with a handle to `bad input` and returns 1
- **THEN** the call fails with a plugin error that holds the code 1 and the text `bad input`

### Requirement: Set error
A kernel error SHALL count as set when `error_get` gives a handle that is not 0 and the `length` of that handle is
not 0, as upstream decides.

#### Scenario: Error handle with no bytes
- **WHEN** the export calls `error_set` with a handle, frees that handle and returns 0
- **THEN** the call succeeds, because the error has length 0

### Requirement: Memory limit errors
When a memory grow of the plugin or of its kernel was refused during a call that fails, the call SHALL fail with a
memory limit error that names that memory.

#### Scenario: Kernel memory full during a call
- **WHEN** the kernel memory ceiling is 17 pages and the export allocates 2 MiB in the kernel and then traps
- **THEN** the call fails with a memory limit error that names the kernel memory

#### Scenario: Unknown export
- **WHEN** an embedder calls an export name that the module does not export
- **THEN** the call fails with an unknown export error that names it, and the plugin can still be called

### Requirement: Guest runtime initialization
Before the first call of an instance, the library SHALL initialize the guest runtime once, as upstream Extism
does: when the module exports `hs_init`, call `_initialize` if it is `() -> ()` and then `hs_init(0, 0)`; else,
when the module exports `__wasm_call_ctors`, call it if it is `() -> ()`; else call `_initialize` if it is
`() -> ()`. This SHALL be the only start-up call of these exports: the engine SHALL NOT call them.

#### Scenario: WASI reactor
- **WHEN** a plugin exports `_initialize` with the type `() -> ()` and no `hs_init` or `__wasm_call_ctors`
- **THEN** `_initialize` runs one time, before the first call, and not before later calls

#### Scenario: Constructors run once
- **WHEN** a plugin exports `__wasm_call_ctors`, `__post_instantiate` and `_initialize`, each `() -> ()`
- **THEN** on native and on js `__wasm_call_ctors` runs one time and the other two do not run

#### Scenario: Constructors of another type
- **WHEN** a plugin exports `__wasm_call_ctors` with a parameter, and `_initialize` with the type `() -> ()`
- **THEN** neither runs, as upstream

#### Scenario: Initialization traps
- **WHEN** `_initialize` traps
- **THEN** the first call fails with an initialization error that holds the trap kind

### Requirement: Start-up bounds
Each start-up call, and the start function of the module at load, SHALL run with the budget and the deadline of
the limits.

#### Scenario: Start-up under the deadline
- **WHEN** a plugin's `_initialize` loops forever, or its start function loops forever, and the limits have a
  deadline, on the native engine
- **THEN** the first call fails with an initialization error, or the load fails with a start error, that holds
  `Interrupted`

### Requirement: Function existence
The plugin API SHALL tell an embedder whether the module exports a function with a given name, without calling
it.

#### Scenario: Export probe
- **WHEN** an embedder asks for `handle` on a module that exports `handle`
- **THEN** the answer is yes, and no guest code runs

### Requirement: Extism host function policy
The library SHALL link `config_get`, `var_get`, `var_set`, `log_*`, `get_log_level`, `http_request`,
`http_status_code` and `http_headers` in `extism:host/env` for every plugin. The embedder's policy SHALL decide for
each family whether it is allowed with embedder values, answered empty, or denied.

#### Scenario: Default policy
- **WHEN** a plugin loads with the default policy
- **THEN** `config_get` and `var_get` give handle 0, `var_set` is denied, log calls are discarded, `get_log_level`
  gives the level that disables logging, and the HTTP functions are denied

#### Scenario: Host function signatures
- **WHEN** a test reads the linked `extism:host/env` host functions
- **THEN** their signatures are `config_get (i64) -> i64`, `var_get (i64) -> i64`, `var_set (i64, i64) -> ()`,
  `log_trace`, `log_debug`, `log_info`, `log_warn` and `log_error (i64) -> ()`, `get_log_level () -> i32`,
  `http_request (i64, i64) -> i64`, `http_status_code () -> i32` and `http_headers () -> i64`

#### Scenario: Logging off
- **WHEN** a plugin calls `get_log_level` with the default policy
- **THEN** it gets 2147483647

#### Scenario: Configuration values
- **WHEN** the policy allows configuration with the value `mode=strict` and the plugin calls `config_get` for `mode`
- **THEN** the plugin gets a handle to the bytes `strict`

### Requirement: Denied host function
A call of a denied Extism host function SHALL fail the plugin call with a denied error that names the function,
and the call SHALL NOT reach the network, a file or the embedder's state. For `http_request`, the denied error SHALL also
hold the method and the URL of the refused request.

#### Scenario: Denied HTTP request
- **WHEN** a plugin calls `http_request` and the policy denies HTTP
- **THEN** the plugin call fails with a denied error that names `http_request` and holds the method and the URL of
  the request, and no request is made

### Requirement: HTTP only through the embedder
When the policy allows HTTP, the library SHALL give each request (method, URL, headers and body) to the embedder's
handler and give its status, headers and body to the plugin. The library SHALL NOT open a network connection.

#### Scenario: Handler answers
- **WHEN** the embedder's handler answers a request with status 204 and an empty body
- **THEN** the plugin's `http_request` gets a handle to empty bytes and `http_status_code` gives 204

### Requirement: Session variables
When the policy allows variables, `var_set` and `var_get` SHALL store and read bytes by name for the life of the
plugin instance, with a total size limit. A `var_set` past the limit SHALL fail the call.

#### Scenario: Variable over the limit
- **WHEN** the variable limit is 1 KiB and a plugin sets a 2 KiB variable
- **THEN** the call fails with a limit error that names the variable store

### Requirement: Registered host functions
An embedder SHALL be able to register a host function in any namespace and with any name, with `i32`, `i64`, `f32`
and `f64` parameters and results. During a call, the function SHALL be able to read the bytes of a kernel handle,
allocate kernel memory and write bytes to it.

#### Scenario: Function in a custom namespace
- **WHEN** an embedder registers `extism:host/user.lookup (i64) -> i64` that reads the input handle and returns a
  handle to new bytes, and the plugin calls it
- **THEN** the plugin reads the new bytes through the returned handle

#### Scenario: Name clash with the kernel
- **WHEN** an embedder registers `extism:host/env.alloc`
- **THEN** the manifest is refused with an error that names `extism:host/env.alloc`

### Requirement: Host function failure
A registered host function SHALL be able to fail with an error. The plugin call SHALL then fail with a host
function error that names the function and holds its message.

#### Scenario: Host function fails
- **WHEN** a registered host function raises an error with the message `not found`
- **THEN** the plugin call fails with a host function error that names the function and holds `not found`

### Requirement: Plugin limits
A manifest SHALL set the plugin memory ceiling, the kernel memory ceiling, the per-call instruction budget, the
per-call deadline and the variable store limit. Each limit that the engine does not enforce SHALL be reported as
not enforced, and SHALL NOT be reported as enforced. Kernel calls of the plugin SHALL NOT count against
the plugin's instruction budget.

#### Scenario: Limits on js
- **WHEN** an embedder loads a plugin on js with an instruction budget and a deadline
- **THEN** the plugin's bounds report lists both as not enforced, and the memory ceilings as enforced

### Requirement: Same results on native and js
A plugin call with the same manifest and input SHALL give the same output bytes, the same error kind and the same
host function calls on the native and the js target. This does not apply to an outcome that comes from a bound that
only one engine enforces, such as an exhausted instruction budget or a deadline.

#### Scenario: Python extension describe
- **WHEN** the Morphir Python extension `0.4.1` or `0.4.2` gets a `describe` request through `handle` on native,
  Node.js and a browser
- **THEN** the three responses are the same bytes
