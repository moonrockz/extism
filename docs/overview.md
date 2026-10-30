---
title: Overview
---
# Overview

`moonrockz/extism` is one MoonBit module with four packages.

| Package | Gives | Targets |
| --- | --- | --- |
| `moonrockz/extism` | The plugin API: a manifest, the Extism host functions with an embedder policy, host functions that the embedder registers in any namespace, a call by export name, and limits | native, js |
| `moonrockz/extism/kernel` | The Extism kernel, written in Zig and compiled to one `wasm32-freestanding` module, embedded as bytes | all |
| `moonrockz/extism/wasi` | A WASI preview 1 sandbox: no preopens, empty arguments, environment and stdin, clocks and random bytes from the embedder, stdout and stderr to the embedder | all |
| `moonrockz/extism/engine` | A small WASM engine layer: compile, instantiate with host imports, call an export, memory ceiling, instruction budget, interruption | native, js |

On native, the engine is the WAMR fast interpreter, built from C source with Zig. On js, the engine
uses the `WebAssembly` API of Node.js or of the browser. The kernel module is the same on every engine,
so allocation, handles and errors are the same everywhere.

## Status

The packages are empty. The first OpenSpec change, `host-extism-plugins`, gives the requirements and
the design. It is in `openspec/changes/host-extism-plugins/` in the repository. The work is tracked in
the shared Morphir tracker as bead `morphir-ukvn.5.64.36.4`.

## First consumer

The Morphir MoonBit CLI (`finos/morphir-moonbit`) runs Morphir extensions that are Extism plugins. It
uses this module from Mooncakes, pinned to an exact version, after the first release.
