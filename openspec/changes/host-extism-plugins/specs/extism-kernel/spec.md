# Spec Delta

## Purpose

Defines the Extism kernel module that this library gives to every plugin: its exports, its memory and handle
behavior, and the build that embeds it, so that a plugin sees the same kernel on every engine and target.

## ADDED Requirements

### Requirement: Upstream kernel exports
The kernel SHALL be one WASM module that exports `memory` and the 20 upstream Extism kernel functions with their
upstream names and WASM signatures: `alloc`, `free`, `length`, `length_unsafe`, `load_u8`, `load_u64`,
`input_load_u8`, `input_load_u64`, `store_u8`, `store_u64`, `input_set`, `output_set`, `input_length`,
`input_offset`, `output_length`, `output_offset`, `reset`, `error_set`, `error_get` and `memory_bytes`.

#### Scenario: Export signatures
- **WHEN** a test reads the export section of the embedded kernel bytes
- **THEN** it finds each of the 20 functions with the signature of the same export in upstream
  `extism-runtime.wasm`, for example `alloc (i64) -> i64`, `store_u8 (i64, i32) -> ()` and `reset () -> ()`

#### Scenario: Plugin that imports any kernel function
- **WHEN** a plugin imports any subset of the 20 functions from `extism:host/env`
- **THEN** each import is satisfied by the kernel export of the same name

### Requirement: No reference types
The kernel module SHALL NOT import anything, and SHALL NOT use reference types, SIMD, threads or any other WASM
feature outside its declared CPU feature set. It SHALL NOT export the upstream `extism_context` externref global.

#### Scenario: Feature set of the kernel bytes
- **WHEN** a test validates the embedded kernel bytes with only the declared features enabled
- **THEN** validation passes, the module has no import section entries and no `extism_context` export

### Requirement: Upstream memory behavior
The kernel SHALL give the same results as upstream `extism-runtime.wasm` for each sequence of kernel calls on
which upstream does not trap:
the handle that `alloc` returns, `length` of live, freed and unknown handles, reuse of freed blocks, `reset`,
input and output offsets and lengths, and `error_set` and `error_get`.

#### Scenario: Differential call sequence
- **WHEN** the same recorded sequence of kernel calls runs on the Zig kernel and on upstream `extism-runtime.wasm`
- **THEN** every call gives the same result and the bytes at each live handle are the same

#### Scenario: Freed handle
- **WHEN** a block is freed and `length` is called with its handle
- **THEN** the result is 0, as upstream gives

### Requirement: Allocation failure
When an allocation needs more memory than the kernel memory can grow to, `alloc` SHALL return 0 and SHALL NOT
trap. Kernel memory SHALL NOT grow past the ceiling that the instance has.

#### Scenario: Kernel memory at its ceiling
- **WHEN** a plugin calls `alloc` with a size larger than the memory left below the kernel memory ceiling
- **THEN** `alloc` returns 0 and earlier handles keep their bytes

### Requirement: Out-of-bounds access
As upstream does with its default bounds checks, a `load_*` or `input_load_*` call at an offset that is inside
the root record, past the end of kernel memory or past the input SHALL return 0, and a `store_*` call there SHALL
change nothing. A kernel call SHALL NOT read or write outside the kernel's linear memory.

#### Scenario: Load past the end
- **WHEN** a plugin calls `load_u64` with an offset 4 bytes before the end of kernel memory
- **THEN** the call returns 0 and does not trap

#### Scenario: Store into the root record
- **WHEN** a plugin calls `store_u8` with offset 1
- **THEN** the root record does not change and a later `alloc` gives the same handle as upstream

#### Scenario: Input past its length
- **WHEN** the input is 3 bytes and a plugin calls `input_load_u8` with offset 3
- **THEN** the call returns 0

### Requirement: Embedded bytes match the source
The library SHALL embed the kernel as bytes in the `moonrockz/extism/kernel` package. A repository check SHALL
build the kernel from its Zig source with the pinned Zig and fail when the built bytes differ from the embedded
bytes.

#### Scenario: Edited Zig source
- **WHEN** the Zig source changes and the embedded bytes are not regenerated
- **THEN** the kernel check fails and names the kernel package file

#### Scenario: Same bytes on every target
- **WHEN** a test reads the embedded kernel bytes on `wasm`, `wasm-gc`, `js` and `native`
- **THEN** the bytes and their SHA-256 are the same on each target
