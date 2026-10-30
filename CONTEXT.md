# moonrockz/extism language

**Plugin**:
A WASM module that follows the Extism plugin ABI, with its imports bound and its instance ready for
calls. The embedder calls a plugin by export name with input bytes and gets output bytes.

**Embedder**:
The MoonBit program that uses this library to load and call plugins. The embedder supplies the
policy, the host functions it registers, and the sources and sinks of the WASI sandbox.
_Avoid_: host application, client

**Manifest**:
The description of one plugin: its module bytes, its limits and its policy. The embedder makes it;
the library does not read it from a file or a URL.

**Kernel**:
The WASM module that serves the `extism:host/env` memory and I/O functions of a plugin: allocation,
handles, input, output and errors. It has its own linear memory. Here it is written in Zig and
embedded as bytes.

**Kernel export**:
One of the 20 functions of the upstream Extism kernel, with its upstream name and signature, for
example `alloc(i64) -> i64` or `output_set(i64, i64)`.

**Handle**:
A 64-bit offset into the kernel's memory that names one allocated block. Plugins, host functions and
the embedder pass bytes to each other as handles. Zero is no block.

**Extism host function**:
A function that upstream Extism hosts give to plugins in `extism:host/env` and that is not a kernel
export: `config_get`, `var_get`, `var_set`, `log_*`, `get_log_level`, `http_request`,
`http_status_code`, `http_headers`.

**Policy**:
The embedder's decision for each Extism host function: allow it with an embedder value, answer with
an empty or default value, or deny it. A denied function is linked and fails when the plugin calls it.

**Registered host function**:
A function that the embedder gives to plugins in a namespace that it chooses, with `i32`, `i64`,
`f32` and `f64` parameters and results. It can read and write the kernel's memory through handles.
_Avoid_: user function

**WASI sandbox**:
The WASI preview 1 import set that the library gives to a plugin that imports
`wasi_snapshot_preview1`. It has no preopens and empty arguments, environment and stdin. Clocks and
random bytes come from embedder sources; stdout and stderr go to embedder sinks. Every other function
returns `ENOTCAPABLE` or `EBADF`.

**Engine**:
The layer that compiles and runs WASM modules: WAMR on native, `WebAssembly` on js. The plugin API
uses it only through the engine package.

**Kernel binding**:
How an engine connects a plugin's `extism:host/env` kernel imports to the kernel instance. On js the
kernel exports are the plugin's imports. On WAMR each import is a native forwarder to the kernel
instance.

**Memory ceiling**:
The largest linear memory, in 64 KiB pages, that a plugin instance can have, also when the module
declares no maximum or a larger one.

**Instruction budget**:
The number of WASM instructions that one call can run on an engine that meters instructions. An
engine that does not meter reports the budget as not enforced.
_Avoid_: fuel, when the engine is not Wasmtime

**Interruption**:
Stopping a running call from outside the call, for example at a deadline.

**Feature error**:
A load failure that names the WASM feature that the module needs and the engine does not support,
for example `simd` or `threads`.
