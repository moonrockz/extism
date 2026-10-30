# moonrockz/extism/engine

A small WASM engine layer with one API on two engines (design ENG-1): the WAMR 2.4.5 fast interpreter on
native, built from the vendored C source in `wamr/` with the consumer's C compiler, and the `WebAssembly` API
of Node.js and browsers on js. It knows nothing of Extism.

- `Engine::compile` reads the module, refuses a feature that the engine lacks with `FeatureUnsupported` and
  the feature name (from the same pure scan on both engines), and compiles it.
- `Module::instantiate` binds each import to a MoonBit function or to an exported function of another
  instance, per instance, with a memory ceiling in pages. The start function of the module runs after the
  instance exists, as a call with the budget and the deadline of the instantiation; when it fails, the
  instantiation fails with `Start`.
- `Instance::call` calls an export with typed values, an instruction budget and a deadline.
- `Instance::memory` reads and writes guest memory; it is also the WASI `GuestMemory`.

## Bounds per engine

| Bound | Native (WAMR) | js (`WebAssembly`) |
| --- | --- | --- |
| Memory ceiling | Enforced: the maximum pages of the instantiation | Enforced: a rewrite of the memory maximum |
| Refused `memory.grow` | `MemoryLimit` (enlarge-memory callback) | `MemoryLimit` (an appended grow function) |
| Instruction budget | Enforced: WAMR metering, 1 to 2147483647 instructions | Not enforced |
| Deadline | Enforced: a watchdog thread calls `wasm_runtime_terminate`; it is always joined | Not enforced: end the worker |
| Host work | Not metered: a host function and the kernel's forwarded calls count no instructions; the deadline bounds them | Not metered |
| Features beyond the core set | `simd` (SIMDe headers) | `simd` |

```moonbit check
///|
test "add two i64 values" {
  let engine = @engine.Engine::default()
  let instance = engine
    .compile(@fixtures.add())
    .instantiate(@engine.Imports::new())
  assert_eq(instance.call("add", [I64(2), I64(40)]), [I64(42)])
}

///|
test "a host function for an import" {
  let signature = @engine.Signature::new([I64, I64], [I64])
  let imports = @engine.Imports::new().host("env", "add", signature, (_, args) => {
    guard args is [I64(a), I64(b)] else {
      raise @engine.HostError("bad arguments")
    }
    [I64(a + b)]
  })
  let instance = @engine.Engine::default()
    .compile(@fixtures.host())
    .instantiate(imports)
  assert_eq(instance.call("call_add", [I64(1), I64(2)]), [I64(3)])
}

///|
test "a memory ceiling" {
  let instance = @engine.Engine::default()
    .compile(@fixtures.grow())
    .instantiate(
      @engine.Imports::new(),
      memory_ceiling=@engine.PageCount::parse(2),
    )
  assert_eq(instance.call("grow", [I32(1)]), [I32(1)])
  assert_eq(instance.call("grow", [I32(1)]), [I32(-1)])
}
```
