# Spec Delta

## Purpose

Defines the WASM engine layer that the plugin API and other embedders use on native and js: compiling and
instantiating modules with host imports, calls, guest memory access, resource bounds and the errors of each.

## ADDED Requirements

### Requirement: Engines per target
The engine package SHALL support the `native` target with the WAMR fast interpreter built from C source, and the
`js` target with the `WebAssembly` API of Node.js and browsers. It SHALL need no prebuilt engine library and no
Rust toolchain.

#### Scenario: Native build from a fresh consumer
- **WHEN** a module outside this repository adds the published package and builds for native on Linux x64, Linux
  arm64, macOS arm64 or Windows x64 with MSVC
- **THEN** the build compiles the engine from the vendored C source and links with no other library

#### Scenario: Same module on both engines
- **WHEN** a test module that adds two `i64` values runs on the native and the js engine
- **THEN** both engines return the same result

### Requirement: Host imports as MoonBit functions
The engine SHALL instantiate a module with host imports that the caller gives as MoonBit functions, each with a
module name, a field name and a signature of `i32`, `i64`, `f32` and `f64` parameters and results. An import whose
signature differs from the module's import SHALL fail the instantiation and name the import.

#### Scenario: Host function called by the guest
- **WHEN** a module imports `env.add (i64, i64) -> i64` and the caller gives a MoonBit function for it
- **THEN** a guest call of `env.add` runs the MoonBit function and the guest gets its result

#### Scenario: Wrong signature
- **WHEN** the caller gives `env.add` with the signature `(i32) -> i32`
- **THEN** instantiation fails with a link error that names `env.add` and both signatures

### Requirement: Module linking
The engine SHALL let one instance's exported functions satisfy another module's imports, so that a plugin's
kernel imports call the kernel instance.

#### Scenario: Exports of one instance as imports of another
- **WHEN** module B imports `extism:host/env.alloc` and the caller links it to the `alloc` export of instance A
- **THEN** a call of `alloc` in B runs in A and changes A's memory, not B's

### Requirement: Imports bound per instance
The engine SHALL bind the imports of each instance to the functions given for that instance, also when several
instances come from one compiled module.

#### Scenario: Two instances of one module
- **WHEN** two instances of one compiled module B link `extism:host/env.alloc` to the `alloc` exports of two
  different instances A1 and A2
- **THEN** a call of `alloc` in the first B instance changes only A1's memory, and in the second only A2's memory

### Requirement: Guest memory access
The engine SHALL let a host function and the caller read and write the exported memory of an instance by offset
and length. An access outside the current memory size SHALL raise an error and SHALL NOT read or write any byte.

#### Scenario: Read past the end
- **WHEN** a host function reads 8 bytes at 4 bytes before the end of guest memory
- **THEN** the read raises an out-of-bounds error and no bytes are returned

### Requirement: Memory ceiling
Each instance SHALL have a memory ceiling in 64 KiB pages, also when the module declares no maximum or a larger
one. A `memory.grow` past the ceiling SHALL return -1 to the guest. The engine SHALL record a refused `memory.grow` for
the current call, and a call that fails after a refused grow SHALL fail with a memory limit error. A ceiling smaller
than the initial pages of the module's memory SHALL fail the instantiation. The default ceiling SHALL be 4096 pages
(256 MiB).

#### Scenario: Module without a maximum
- **WHEN** a module that declares no memory maximum, on an instance with a ceiling of 32 pages, grows its memory
  to 33 pages
- **THEN** `memory.grow` returns -1 and the memory stays at its earlier size, on native and on js

#### Scenario: Refused grow, then a trap
- **WHEN** a guest call grows its memory past the ceiling, gets -1 and then runs `unreachable`
- **THEN** the call fails with a memory limit error, not a trap error, on native and on js

#### Scenario: Ceiling below the initial pages
- **WHEN** a module declares 16 initial pages and the caller instantiates it with a ceiling of 8 pages
- **THEN** instantiation fails with an error that holds both page counts, on native and on js

### Requirement: Instruction budget
Where the engine meters instructions, a call SHALL stop with a budget error when it runs more instructions than
its budget. The native engine SHALL meter instructions. The js engine does not meter. A budget SHALL be from 1 to
2147483647 instructions, the range of the C `int` that WAMR takes. The native engine SHALL enforce the budget with every C
compiler that builds it, including MSVC.

#### Scenario: Budget range
- **WHEN** a caller makes a budget of 2147483647 and a budget of 2147483648
- **THEN** the first is accepted and the second is refused with a limit error that names the rule

#### Scenario: Runaway loop on native
- **WHEN** a guest loops forever in a call with a budget of 1,000,000 instructions on native
- **THEN** the call stops with a budget error and the instance is not usable for more calls

#### Scenario: Budget with every C compiler
- **WHEN** the native engine is built with a C compiler that has no computed goto, such as MSVC, and a guest loops
  forever in a call with a budget of 1,000,000 instructions
- **THEN** the call stops with a budget error, as with a compiler that has computed goto

### Requirement: Interruption
Where the engine supports it, a call SHALL stop with an interruption error when its deadline passes. The native
engine SHALL support per-call deadlines. On js the embedder stops a runaway call by ending its worker. The
watchdog of a deadline SHALL be stopped and joined before the call returns, on every outcome of the call. Where the
engine cannot stop a call at its deadline on a platform, its bounds report SHALL give interruption as not
enforced.

#### Scenario: Deadline on native
- **WHEN** a guest loops forever in a call with a deadline of 100 ms and no instruction budget on native
- **THEN** the call stops with an interruption error within 1 second

#### Scenario: No watchdog left
- **WHEN** a caller runs 1,000 short calls with a deadline of 1 second on native
- **THEN** every call returns its result and no watchdog thread is left after the calls

### Requirement: Enforced bounds report
Each engine SHALL report which bounds it enforces: memory ceiling, instruction budget and interruption, each as
enforced or not enforced. A caller SHALL be able to read the report before it runs a module.

#### Scenario: js engine report
- **WHEN** a caller reads the bounds report of the js engine
- **THEN** the memory ceiling is enforced, and the instruction budget and interruption are not enforced

#### Scenario: Native engine report
- **WHEN** a caller reads the bounds report of the native engine
- **THEN** the memory ceiling, the instruction budget and interruption are enforced

### Requirement: Feature errors
The engine SHALL refuse at load a module that needs a WASM feature that the engine does not support, with an
error that names the feature from a closed set, for example `simd`, `threads`, `memory64`, `exception-handling`
or `gc`. When the engine cannot name the feature, the error SHALL say that it is unknown. Both engines SHALL
find the feature with the same pure scan of the module bytes, so that the native and the js engine name the same
feature.

#### Scenario: SIMD module on an engine built without SIMD
- **WHEN** a module with a `v128` instruction loads on an engine built without SIMD
- **THEN** the load fails with a feature error that names `simd`, before any call

#### Scenario: Feature scan
- **WHEN** the scan reads a module with a `v128` instruction, a shared memory and a 64-bit memory
- **THEN** it gives `simd`, `threads` and `memory64`, on every target and without an engine

### Requirement: Traps
A trap in a guest call SHALL raise an error that gives the trap kind from a closed set, for example
`unreachable`, `out-of-bounds memory access`, `integer divide by zero`, `call stack exhausted` or `host`. After a
trap the instance SHALL NOT be used for more calls.

#### Scenario: Unreachable
- **WHEN** a guest call runs `unreachable`
- **THEN** the call raises a trap error with the kind `unreachable`, on native and on js
