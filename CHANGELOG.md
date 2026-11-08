# Changelog

## Unreleased

## 0.2.0

A toolchain release. `moonrockz/extism` 0.2.0 requires MoonBit 0.10.20 or newer
(`moonc v0.10.20+65efd5b93`, `moon 0.1.20261104`). MoonBit 0.10.18 and older are no longer
supported: the source uses the `#derive(...)` attribute of 0.10.20, and 0.10.18 ignores it, so the
types do not get their derived traits. The behavior of the plugin API, the engine, the kernel and the
WASI sandbox does not change. To upgrade, move to MoonBit 0.10.20 or newer, then import
`moonrockz/extism@0.2.0`.

### Changed

- The source uses the `#derive(...)` attribute of MoonBit 0.10.20 and builds without warnings on
  0.10.20. MoonBit 0.10.18 is no longer supported.

### Repository

- The toolchain pin moves to MoonBit 0.10.20+65efd5b93. `mise run format` and `mise run lint:moonbit`
  format and check every package again: with the 0.10.20 `moon`, `moon fmt .` selects only the
  workspace root, which is not a package.
- The docs site driver in `apps/site` moves to `moonrockz/telescope` 0.6.0, which requires MoonBit
  0.10.20 and gives search and version picker islands that are built with 0.10.20.
- The READMEs give MoonBit 0.10.20 as the minimum toolchain.

## 0.1.1

A fix of the speed of the native engine on Windows with MSVC.

### Fixed

- `moonrockz/extism/engine`: on Windows with MSVC, the WAMR fast interpreter was slow. WAMR has
  32-bit atomics only with GCC and Clang, so with MSVC the suspend flags were not atomic and the
  interpreter locked and unlocked a Win32 mutex at each branch, loop and call. A vendored patch of
  `bh_atomic.h` gives MSVC the 32-bit atomics with the Interlocked intrinsics, so the flags need no
  lock. On windows-latest, the mean compile of the EXT-2 Python guest went from 306 ms to 18.5 ms.
  Metering, deadlines and memory bounds do not change.

### Repository

- The OpenSpec change `host-extism-plugins` records the Zig kernel as a maintainer decision, and the
  Windows engine measurements.

## 0.1.0

The first release of `moonrockz/extism`, an Extism host for MoonBit on native and js.

### Added

- `moonrockz/extism`: the plugin API. A manifest, the Extism host functions with an embedder policy,
  host functions that the embedder registers in any namespace, calls by export name, and limits on
  memory, time and instructions.
- `moonrockz/extism/engine`: a small WASM engine layer. On native it is the WAMR fast interpreter,
  built from the vendored C source with the consumer's C compiler, with SIMD. On js it is the
  `WebAssembly` API of Node.js or of a browser. It compiles, instantiates with host imports, calls
  exports, and gives a memory ceiling, an instruction budget, interruption and named feature errors.
- `moonrockz/extism/kernel`: the Extism kernel, written in Zig, compiled to one
  `wasm32-freestanding` module and embedded as bytes.
- `moonrockz/extism/wasi`: a WASI preview 1 sandbox with no preopens, empty arguments, environment
  and stdin, clocks and random bytes from the embedder, and stdout and stderr to the embedder.
- The vendored WAMR and SIMDe sources with their licenses, attributions and SHA-256 hashes.
- The Release workflow: a `vX.Y.Z` tag push runs every CI check, packages and audits the module,
  publishes it to mooncakes.io, verifies the public archive checksum and creates the GitHub release.

### Fixed

- The module reader refuses an index, a count or a size above 2^31 - 1, and a length that passes the
  end of the bytes, with a decode error. Before, the type index 0xffffffff of a function import
  caused a panic before either engine validated the module.

### Repository

- A MoonBit workspace with the docs site driver over `moonrockz/telescope`, task scripts run with
  `moonx`, Lefthook hooks, GitHub Actions CI, and OpenSpec with the `html-design` schema.
- The OpenSpec change `host-extism-plugins`, which gives the requirements and the design of the
  engine, kernel, WASI sandbox and plugin packages.
