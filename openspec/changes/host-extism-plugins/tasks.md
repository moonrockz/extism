# Tasks

Every group is part of task group 4 of `host-extensions-as-workers` in finos/morphir-moonbit, tracked by bead
`morphir-ukvn.5.64.36.4` in the shared Morphir tracker. The repository setup (task 4.1) and this change (task 4.2)
land before group 1.

## 1. Extism kernel in Zig (morphir-ukvn.5.64.36.4, task 4.3)

- [x] 1.1 Add `kernel/` with `build.zig`, the Zig kernel and its Zig tests for the allocator, handles, input,
  output, errors, reset and bounds checks (KRN-1); verify `zig build test` passes with the pinned Zig
- [x] 1.2 Add `mise run build:kernel`, which compiles the kernel to `wasm32-freestanding` with
  `-mcpu=mvp+mutable_globals+sign_ext` and writes `pkgs/extism/kernel/kernel_bytes.mbt` with the bytes and their
  SHA-256, and `mise run check:kernel`; verify the check fails after a one-byte change to the Zig source and passes
  after `build:kernel`
- [x] 1.3 Expose the kernel bytes and the kernel ABI (the 20 export names and signatures) in
  `moonrockz/extism/kernel`; verify the "Export signatures", "Feature set of the kernel bytes", "No data and no
  stack" and "Same bytes on every target" scenarios as tests on `wasm`, `wasm-gc`, `js` and `native`
- [x] 1.4 Add a CI job that runs `zig build test` and `check:kernel` on Linux and macOS; verify it passes on the
  pull request

## 2. Engine layer and the EXT-2 gate (morphir-ukvn.5.64.36.4, task 4.4)

- [x] 2.1 Spike: vendor the WAMR `WAMR-2.4.5` fast-interpreter source with its `LICENSE` (Apache-2.0 WITH
  LLVM-exception) and `UPSTREAM.md`, add a third-party note to `pkgs/extism/README.md`, add `build.zig` and the
  generated `native-stub` list (ENG-2) with `THREAD_MGR=1` and no `invokeNative` source, and build an empty engine
  package from a fresh consumer module on Linux x64, Linux arm64, macOS arm64 and Windows x64 with MSVC; verify
  each build in one CI run (Windows MSVC by a cross-build or one manual workflow run), and switch to the pre-build
  static library before 2.2 if `native-stub` fails
- [x] 2.2 Run the EXT-2 gate with `mise run qualify:engine` (GATE-1) on each qualified platform, with the minimal
  harness: the raw-native kernel forwarders, a stub WASI and stubs for the four `morphir_*` functions; run the
  Python `0.4.2` compile with a budget of 1,000,000,000 and record the call times and the instructions used, and
  the same with the separate `MULTI_MODULE=1` gate build, as a comment on bead `morphir-ukvn.5.64.36.4`; if the
  gate fails, update this design for the Wasmtime C API before any other work. Nothing else builds on WAMR before
  the gate passes
- [x] 2.3 Implement the engine API types (`Value`, `Signature`, `PageCount`, `Budget`, `Deadline`, `Feature`,
  `Bounds` and the error enums) with their smart constructors, and the pure feature scan (ENG-1); verify a test for
  each rule on each side of the limit, "Budget range" and "Feature scan"
- [x] 2.4 Implement the js backend over `WebAssembly`, with the memory-maximum and `memory.grow` rewrite (ENG-3);
  verify the "Same module on both engines" (js half), "Host function called by the guest", "Wrong signature",
  "Exports of one instance as imports of another", "Two instances of one module", "Read past the end", "Module
  without a maximum", "Refused grow, then a trap", "Ceiling below the initial pages", "js engine report" and
  "Unreachable" scenarios on Node.js
- [x] 2.5 Implement the WAMR backend with raw host imports bound per instance, the forwarding kernel binding,
  maximum pages, the enlarge-memory callback, metering and the watchdog deadline (ENG-2, ENG-4, BND-1); verify the
  same scenarios on native, and "Runaway loop on native", "Deadline on native", "No watchdog left", "Native engine
  report", "Budget with every C compiler", "SIMD on both engines" and "Feature that the engine does not support"
- [x] 2.6 Add the differential kernel test in `tests/` with the upstream `extism-runtime.wasm` fixture, its
  license and SHA-256 (KRN-2); verify the "Differential call sequence", "Freed handle", "Kernel memory at its
  ceiling", "Load past the end", "Load at the memory size", "Store into the root record", "Input past its length"
  and "First handle" scenarios on js and native
- [x] 2.7 Document the engine API and the bounds per engine in `pkgs/extism/engine/README.mbt.md`; verify its
  examples run as documentation tests

## 3. WASI preview 1 sandbox (morphir-ukvn.5.64.36.4, task 4.5)

- [x] 3.1 Implement the `GuestMemory` trait, the preview 1 function table with signatures and the answer of each
  function (PKG-1, WASI-1); verify a test that every function of the pinned witx is in the table, and the "Program
  reads its arguments", "Program reads stdin", "Plugin prints", "Deterministic clock", "No random source",
  "Start-up checks of stdout", "Preopen scan", "Open a file", "Write to stdin", "Plugin exits with code 3" and
  "Plugin exits with code 0" scenarios over an in-memory guest
  memory on all four targets
- [ ] 3.2 Implement `GuestMemory` for engine instances on native and js; verify the "Same answers on native and
  js" scenario with a WASI fixture plugin built from source with an upstream Extism PDK and the pinned toolchain
- [x] 3.3 Document the sandbox answers in `pkgs/extism/wasi/README.mbt.md`; verify the README table matches the
  function table through a test

## 4. Plugin API (morphir-ukvn.5.64.36.4, task 4.5)

- [x] 4.1 Implement `Manifest`, `Limits`, `Policy`, `HostFunction` and the validated names and handle types
  (PLG-1, PLG-2); verify the "Load from bytes", "Name clash with the kernel" and "Default policy" scenarios and a
  test for each smart constructor rule
- [x] 4.2 Implement the pure import check; verify the "Unknown import" and "Sandbox not enabled" scenarios without
  an engine
- [x] 4.3 Implement `Plugin::load`, the guest runtime start-up, `has_function` and `call` on both engines; verify
  the "Two plugins", "Two plugins from the same bytes", "WASI reactor", "Initialization traps", "Export
  probe", "Successful call", "Plugin sets an error", "Error handle with no bytes", "Kernel memory full during a call"
  and "Unknown export" scenarios on native and Node.js
- [x] 4.4 Implement the Extism host functions with the policy, session variables, logging sinks and the HTTP
  handler; verify the "Host function signatures", "Logging off", "Configuration values", "Denied HTTP request",
  "Handler answers" and "Variable over the limit" scenarios
- [x] 4.5 Implement `CallContext` and registered host functions with their errors; verify the "Function in a
  custom namespace", "Host function fails" and "Limits on js" scenarios
- [x] 4.6 Run the Morphir Python extension `0.4.1` and `0.4.2` fixtures (pinned by URL and SHA-256) with
  `morphir_extension_info` and a `describe` request through `handle` on native, Node.js and a browser; verify the
  "Python extension describe" scenario
- [x] 4.7 Document the plugin API in `pkgs/extism/README.mbt.md`, with a manifest, a registered host function and
  the WASI sandbox; verify its examples run as documentation tests

## 5. First release (morphir-ukvn.5.64.36.4, task 4.6)

- [ ] 5.1 Add the release workflow and the publication allowlist, adapted from moon-lander, that publishes only
  `moonrockz/extism` after an approved version change (REL-1); verify a dry run on the release pull request
- [ ] 5.2 After the maintainer approves, publish `0.1.0` to Mooncakes; verify that a fresh module outside the
  repository pins `moonrockz/extism@0.1.0` and builds and runs a plugin call on native and js, and record the
  archive size and checksum on bead `morphir-ukvn.5.64.36.4`

## Workflow follow-up

- Archive the change in the pull request of the last group, following the archive guidance in
  `openspec/config.yaml`.
