name = "moonrockz/extism"

version = "0.1.0"

description = "An Extism host for MoonBit: a WASM engine layer, the Extism kernel and a plugin API"

repository = "https://github.com/moonrockz/extism"

license = "Apache-2.0"

readme = "README.md"

keywords = [ "extism", "wasm", "webassembly", "plugin", "wamr" ]

// The engine and the plugin API have no wasm or wasm-gc backend, so `moon info` writes their
// interfaces from native.
preferred_target = "native"
