# Changelog

## Unreleased

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
