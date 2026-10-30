# Tasks

Every group is part of task group 4 of `host-extensions-as-workers` in finos/morphir-moonbit, tracked by bead
`morphir-ukvn.5.64.36.4` in the shared Morphir tracker. The repository setup (task 4.1) and this change (task 4.2)
land before group 1.

## 1. Extism kernel in Zig (morphir-ukvn.5.64.36.4, task 4.3)

- [ ] 1.1 Add `kernel/` with `build.zig`, the Zig kernel and its Zig tests for the allocator, handles, input,
  output, errors, reset and bounds checks (KRN-1); verify `zig build test` passes with the pinned Zig
- [ ] 1.2 Add `mise run build:kernel`, which compiles the kernel to `wasm32-freestanding` with
  `-mcpu=mvp+mutable_globals+sign_ext` and writes `pkgs/extism/kernel/kernel_bytes.mbt` with the bytes and their
  SHA-256, and `mise run check:kernel`; verify the check fails after a one-byte change to the Zig source and passes
  after `build:kernel`
- [ ] 1.3 Expose the kernel bytes and the kernel ABI (the 20 export names and signatures) in
  `moonrockz/extism/kernel`; verify the "Export signatures", "Feature set of the kernel bytes" and "Same bytes on
  every target" scenarios as tests on `wasm`, `wasm-gc`, `js` and `native`
- [ ] 1.4 Add a CI job that runs `zig build test` and `check:kernel` on Linux and macOS; verify it passes on the
  pull request

## 2. Engine layer and the EXT-2 gate (morphir-ukvn.5.64.36.4, task 4.4)

- [ ] 2.1 Spike: vendor the WAMR `WAMR-2.4.5` fast-interpreter source with `UPSTREAM.md`, add `build.zig` and the
  generated `native-stub` list (ENG-2), and build an empty engine package from a fresh consumer module on Linux
  x64, Linux arm64, macOS arm64 and Windows x64 with MSVC; verify each build in one CI run, and switch to the
  pre-build static library before 2.2 if `native-stub` fails
- [ ] 2.2 Implement the engine API types (`Value`, `Signature`, `PageCount`, `Budget`, `Deadline`, `Feature`,
  `Bounds` and the error enums) with their smart constructors (ENG-1); verify a test for each rule on each side
  of the limit
- [ ] 2.3 Implement the js backend over `WebAssembly`, with the memory-maximum rewrite (ENG-3); verify the "Same
  module on both engines" (js half), "Host function called by the guest", "Wrong signature", "Exports of one
  instance as imports of another", "Read past the end", "Module without a maximum", "js engine report" and
  "Unreachable" scenarios on Node.js
- [ ] 2.4 Implement the WAMR backend with host imports, the forwarding kernel binding, maximum pages, metering and
  the watchdog deadline (ENG-2, ENG-4, BND-1); verify the same scenarios on native, and "Runaway loop on native",
  "Deadline on native", "Native engine report" and "SIMD module on an engine built without SIMD"
- [ ] 2.5 Add the differential kernel test in `tests/` with the upstream `extism-runtime.wasm` fixture, its
  license and SHA-256 (KRN-2); verify the "Differential call sequence", "Freed handle", "Kernel memory at its
  ceiling", "Load past the end", "Store into the root record" and "Input past its length" scenarios on js and
  native
- [ ] 2.6 Run the EXT-2 gate with `mise run qualify:engine` (GATE-1) on each qualified platform; record the call
  times for the forwarding binding and for multi-module linking as a comment on bead `morphir-ukvn.5.64.36.4`, and
  if the gate fails, update this design for the Wasmtime C API before any other work
- [ ] 2.7 Document the engine API and the bounds per engine in `pkgs/extism/engine/README.mbt.md`; verify its
  examples run as documentation tests

## 3. WASI preview 1 sandbox (morphir-ukvn.5.64.36.4, task 4.5)

- [ ] 3.1 Implement the `GuestMemory` trait, the preview 1 function table with signatures and the answer of each
  function (PKG-1, WASI-1); verify a test that every function of the pinned witx is in the table, and the "Program
  reads its arguments", "Program reads stdin", "Plugin prints", "Deterministic clock", "No random source",
  "Preopen scan", "Open a file", "Write to stdin" and "Plugin exits with code 3" scenarios over an in-memory guest
  memory on all four targets
- [ ] 3.2 Implement `GuestMemory` for engine instances on native and js; verify the "Same answers on native and
  js" scenario with a WASI fixture plugin built from source with an upstream Extism PDK and the pinned toolchain
- [ ] 3.3 Document the sandbox answers in `pkgs/extism/wasi/README.mbt.md`; verify the README table matches the
  function table through a test

## 4. Plugin API (morphir-ukvn.5.64.36.4, task 4.5)

- [ ] 4.1 Implement `Manifest`, `Limits`, `Policy`, `HostFunction` and the validated names and handle types
  (PLG-1, PLG-2); verify the "Load from bytes", "Name clash with the kernel" and "Default policy" scenarios and a
  test for each smart constructor rule
- [ ] 4.2 Implement the pure import check; verify the "Unknown import" and "Sandbox not enabled" scenarios without
  an engine
- [ ] 4.3 Implement `Plugin::load`, the guest runtime start-up, `has_function` and `call` on both engines; verify
  the "Two plugins", "WASI reactor", "Initialization traps", "Export probe", "Successful call", "Plugin sets an
  error" and "Unknown export" scenarios on native and Node.js
- [ ] 4.4 Implement the Extism host functions with the policy, session variables, logging sinks and the HTTP
  handler; verify the "Configuration values", "Denied HTTP request", "Handler answers" and "Variable over the
  limit" scenarios
- [ ] 4.5 Implement `CallContext` and registered host functions with their errors; verify the "Function in a
  custom namespace", "Host function fails" and "Limits on js" scenarios
- [ ] 4.6 Run the Morphir Python extension `0.4.1` and `0.4.2` fixtures (pinned by URL and SHA-256) with
  `morphir_extension_info` and a `describe` request through `handle` on native, Node.js and a browser; verify the
  "Python extension describe" scenario
- [ ] 4.7 Document the plugin API in `pkgs/extism/README.mbt.md`, with a manifest, a registered host function and
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
