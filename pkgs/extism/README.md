# moonrockz/extism

An [Extism](https://extism.org) host for MoonBit. The OpenSpec change `host-extism-plugins` in the
repository gives the requirements and the design. `README.mbt.md` documents the plugin API, and each package
has its own README.

| Package | Gives | Targets |
| --- | --- | --- |
| `moonrockz/extism` | The plugin API: manifest, Extism host functions with an embedder policy, host functions that the embedder registers in any namespace, call by export name, limits | native, js |
| `moonrockz/extism/kernel` | The Extism kernel, written in Zig and compiled to one `wasm32-freestanding` module, embedded as bytes | all |
| `moonrockz/extism/wasi` | A WASI preview 1 sandbox for plugins | all |
| `moonrockz/extism/engine` | A small WASM engine layer: WAMR on native, `WebAssembly` on js | native, js |

No version is published yet.

## Third-party code

`moonrockz/extism/engine` builds the WebAssembly Micro Runtime (WAMR) `WAMR-2.4.5` from its C source,
vendored in `engine/wamr/core/` with its license in `engine/wamr/LICENSE` (Apache-2.0 WITH LLVM-exception).
`engine/wamr/UPSTREAM.md` gives the commit, the files and the SHA-256 of each upstream file. Copyright: the
WAMR contributors (Intel Corporation and others).
