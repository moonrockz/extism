# moonrockz/extism

An [Extism](https://extism.org) host for MoonBit. The packages are empty: the OpenSpec change
`host-extism-plugins` in the repository gives their requirements and design.

| Package | Gives | Targets |
| --- | --- | --- |
| `moonrockz/extism` | The plugin API: manifest, Extism host functions with an embedder policy, host functions that the embedder registers in any namespace, call by export name, limits | native, js |
| `moonrockz/extism/kernel` | The Extism kernel, written in Zig and compiled to one `wasm32-freestanding` module, embedded as bytes | all |
| `moonrockz/extism/wasi` | A WASI preview 1 sandbox for plugins | all |
| `moonrockz/extism/engine` | A small WASM engine layer: WAMR on native, `WebAssembly` on js | native, js |

No version is published yet.
