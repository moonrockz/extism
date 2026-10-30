# Proposal

## Why

No Extism host exists for MoonBit. A MoonBit program that must run Extism plugins today needs `libextism` (a 33 to
40 MiB prebuilt Rust library with no Windows arm64 build) or the JavaScript SDK (no instruction budget, a
`maxPages` that does not limit guest memory, and no native target). The Morphir MoonBit CLI
(`finos/morphir-moonbit`, change `host-extensions-as-workers`) must run any conformant Extism Morphir extension on
native, Node.js and browsers, with no Rust or Node.js helper. This change gives the packages for that, as a
general library with no Morphir concepts.

## What Changes

- **Kernel (`moonrockz/extism/kernel`).** The Extism kernel written once in Zig and compiled to one
  `wasm32-freestanding` module with an explicit CPU feature set. It has the 20 upstream kernel exports with their
  upstream names and signatures, and no `extism_context` externref global. The module is embedded as bytes, and a
  check makes sure that the bytes are the same as a fresh build of the Zig source.
- **Engine (`moonrockz/extism/engine`).** A small WASM engine layer: compile a module, instantiate it with host
  imports given as MoonBit functions, call an export, read and write guest memory, a memory ceiling, an
  instruction budget where the engine meters, interruption, and load errors that name the missing feature. Native
  uses the WAMR fast interpreter, built from C source with Zig. js uses `WebAssembly`. A qualification gate
  measures WAMR on the real Python extension; the Wasmtime C API is the fallback if the gate fails.
- **WASI sandbox (`moonrockz/extism/wasi`).** WASI preview 1 for plugins that need it: every preview 1 function is
  linked, there are no preopens, the arguments, environment and stdin are empty, clocks and random bytes come
  from sources that the embedder gives, stdout and stderr go to sinks that the embedder gives, and every other
  function returns `ENOTCAPABLE` or `EBADF`. It is written once and every engine uses it.
- **Plugin API (`moonrockz/extism`).** A manifest, the full kernel, the Extism host functions (`config_get`,
  `var_get`, `var_set`, `log_*`, `get_log_level`, `http_request`, `http_status_code`, `http_headers`) with a
  policy that lets the embedder allow, answer empty or deny each of them, host functions that the embedder
  registers in any namespace with `i32`, `i64`, `f32` and `f64` values and access to kernel memory, call by
  export name, and limits. A plugin that imports a function that nothing links is refused at load, with the
  import named.
- **First release.** An exact version on Mooncakes, after the maintainer approves it.

Out of scope:

- Morphir concepts. The Morphir host functions (`extism:host/user` `morphir_*`) and the `morphir-bytes-v1` ABI
  stay in `finos/morphir-moonbit`, which registers them through the plugin API and the engine package.
- A network client. The library never opens a connection; an embedder that allows `http_request` handles it.
- WASI preview 2, the component model, threads, shared memory, memory64, AOT and JIT compilation.
- A manifest that the library reads from a file or a URL, and plugin download.
- The `wasm` and `wasm-gc` targets for the engine and the plugin API: a WASM host has no engine to embed.
- Process or worker isolation. The embedder runs a plugin in a worker process or a worker thread when it needs a
  hard stop (as the Morphir CLI does).

## Capabilities

### New Capabilities

- `extism-kernel`: the Extism kernel module: exports, memory layout, allocation, handles, input, output, errors,
  and the build that embeds it.
- `wasm-engine`: compiling and running WASM modules on native and js: host imports, guest memory access, limits,
  interruption, feature errors and the bounds that an engine enforces.
- `wasi-sandbox`: the WASI preview 1 import set for sandboxed plugins and the answer of each function.
- `extism-plugins`: loading and calling an Extism plugin: manifest, kernel binding, Extism host functions and
  their policy, registered host functions, import checks, calls and their errors.

### Modified Capabilities

None. `openspec/specs/` holds no specs yet.

## Beads

- **Tracked by**: `morphir-ukvn.5.64.36.4` (task group 4 of `host-extensions-as-workers` in the shared Morphir
  tracker, label `repo:extism`)
- **Related**:
  - `morphir-ukvn.5.64.36` (parent epic: host extensions as MEP workers in the MoonBit CLI)
  - `morphir-ukvn.5.64.36.5` (WASM workers in finos/morphir-moonbit; it consumes the published version and is
    blocked by this bead)

## Impact

- **Code:** `pkgs/extism/` (the four packages), `kernel/` (Zig source, tests and `build.zig`),
  `pkgs/extism/engine/wamr/` (vendored WAMR source), new task scripts for the kernel check and the engine gate,
  and new CI jobs for Zig, Windows MSVC and macOS.
- **Dependencies:** WAMR `WAMR-2.4.5` C source (Apache-2.0 with LLVM exception), vendored. Zig `0.17.0` (already
  pinned). The upstream kernel module `extism-runtime.wasm` (BSD-3-Clause) as a test fixture only. No Rust
  toolchain, no prebuilt library.
- **Consumers:** `finos/morphir-moonbit` pins the first published version.
- **Package size:** the native engine adds about 1 MiB to a consumer's executable; the Mooncakes archive grows by
  the vendored WAMR source.
