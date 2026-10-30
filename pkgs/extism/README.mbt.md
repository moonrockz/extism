# The plugin API of moonrockz/extism

Load an Extism plugin from a manifest and call it by export name (design PLG-1 and PLG-2). Each plugin has its
own instance of the Zig kernel. The manifest gives the limits, the policy for the Extism host functions, the
host functions that the embedder registers in any namespace and, when the plugin needs it, the WASI sandbox.

| Family | Policy choices | Default |
| --- | --- | --- |
| `config_get` | `Deny`, `Empty`, `Values(map)` | `Empty`: handle 0 |
| `var_get`, `var_set` | `Deny`, `Empty` (get gives 0, set is denied), `Session(limit)` | `Empty` |
| `log_*`, `get_log_level` | `Discard`, `Sink(level, sink)` | `Discard`; the level is 2147483647 |
| `http_request`, `http_status_code`, `http_headers` | `Deny`, `Handler(handler)` | `Deny` |

A call fails with a typed `CallError`: `Plugin(code, text)`, `Exit(code)`, `Denied(call)`,
`HostFunction(name, message)`, `MemoryLimit(memory)`, `Limit(name)`, `Engine(error)`, `Initialization(error)`
or `UnknownExport(name)`.

```moonbit check
///|
test "a manifest, a policy and a call" {
  let policy = @extism.Policy::default().config(Values({ "mode": "strict" }))
  let plugin = @extism.Plugin::load(
    @extism.Manifest::new(@fixtures.plugin())
    .policy(policy)
    .register(
      @extism.HostFunction::new(
        @extism.Namespace::parse("extism:host/user"),
        @extism.FunctionName::parse("lookup"),
        @engine.Signature::new([I64], [I64]),
        (context, args) => {
          guard args is [I64(offset)] else {
            raise @engine.HostError("bad arguments")
          }
          let input = context.read(@extism.Handle::parse(offset)) catch {
            _ => raise @engine.HostError("no input")
          }
          let output = context.allocate(input) catch {
            _ => raise @engine.HostError("no room")
          }
          [I64(output.offset())]
        },
      ),
    ),
  )
  assert_eq(plugin.call(@extism.ExportName::parse("config"), b""), b"strict")
  assert_eq(plugin.call(@extism.ExportName::parse("lookup"), b"same"), b"same")
}

///|
test "a plugin with the WASI sandbox" {
  let printed = []
  let sandbox = @wasi.Sandbox::new().stdout(bytes => {
    printed.push(bytes.to_owned())
  })
  let plugin = @extism.Plugin::load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(sandbox),
  )
  assert_eq(plugin.call(@extism.ExportName::parse("print"), b""), b"")
  assert_eq(printed, [b"hello"])
}
```
