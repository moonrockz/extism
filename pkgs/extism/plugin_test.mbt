///|
fn export_name(text : String) -> @extism.ExportName raise {
  @extism.ExportName::parse(text)
}

///|
fn load(manifest : @extism.Manifest) -> @extism.Plugin raise {
  @extism.Plugin::load(manifest)
}

///|
fn call(plugin : @extism.Plugin, name : String, input : Bytes) -> Bytes raise {
  plugin.call(export_name(name), input)
}

///|
fn call_error(
  plugin : @extism.Plugin,
  name : String,
  input : Bytes,
) -> @extism.CallError raise {
  let exported = export_name(name)
  try plugin.call(exported, input) catch {
    error => error
  } noraise {
    _ => fail("the call of \{name} must fail")
  }
}

///|
fn load_error(manifest : @extism.Manifest) -> @extism.LoadError raise {
  try @extism.Plugin::load(manifest) catch {
    error => error
  } noraise {
    _ => fail("the load must fail")
  }
}

///|
fn lookup_function(
  function : (@extism.CallContext, Array[@engine.Value]) -> Array[@engine.Value] raise @engine.HostError,
) -> @extism.HostFunction raise {
  @extism.HostFunction::new(
    @extism.Namespace::parse("extism:host/user"),
    @extism.FunctionName::parse("lookup"),
    @engine.Signature::new([I64], [I64]),
    function,
  )
}

///|
/// The plugin fixture with a `lookup` that answers its input in capitals.
fn plugin_manifest() -> @extism.Manifest raise {
  @extism.Manifest::new(@fixtures.plugin()).register(
    lookup_function((context, args) => {
      guard args is [I64(offset)] else {
        raise @engine.HostError("bad arguments")
      }
      let handle = @extism.Handle::parse(offset) catch {
        _ => raise @engine.HostError("no handle")
      }
      let bytes = context.read(handle) catch {
        _ => raise @engine.HostError("no bytes")
      }
      let upper = Bytes::makei(bytes.length(), i => {
        let b = bytes[i]
        if b >= b'a' && b <= b'z' {
          (b.to_int() - 32).to_byte()
        } else {
          b
        }
      })
      let made = context.allocate(upper) catch {
        _ => raise @engine.HostError("no room")
      }
      [I64(made.offset())]
    }),
  )
}

///|
test "Load from bytes: default limits and the default policy" {
  let plugin = load(plugin_manifest())
  assert_eq(call(plugin, "echo", b"hello world"), b"hello world")
  assert_eq(call(plugin, "echo", b""), b"")
}

///|
test "Two plugins: each call uses its own kernel memory" {
  let a = load(plugin_manifest())
  let b = load(plugin_manifest())
  assert_eq(call(a, "echo", b"first"), b"first")
  assert_eq(call(b, "echo", b"second"), b"second")
  assert_eq(call(a, "echo", b"third"), b"third")
}

///|
test "Two plugins from the same bytes give the output of their own input" {
  let manifest = plugin_manifest()
  let a = load(manifest)
  let b = load(manifest)
  assert_eq(call(a, "lookup", b"abc"), b"ABC")
  assert_eq(call(b, "lookup", b"xyz"), b"XYZ")
}

///|
test "Plugin sets an error: the code 1 and the text bad input" {
  let error = call_error(load(plugin_manifest()), "fail", b"")
  assert_true(error is Plugin(1, "bad input"))
}

///|
test "a non-zero code with no error text" {
  assert_true(call_error(load(plugin_manifest()), "code", b"") is Plugin(7, ""))
}

///|
test "Error handle with no bytes: the call succeeds" {
  assert_eq(call(load(plugin_manifest()), "empty_error", b""), b"")
}

///|
test "Unknown export: the error names it and the plugin can still be called" {
  let plugin = load(plugin_manifest())
  assert_true(call_error(plugin, "missing", b"") is UnknownExport("missing"))
  assert_eq(call(plugin, "echo", b"still"), b"still")
}

///|
test "Export probe: the plugin exports echo and not missing" {
  let plugin = load(plugin_manifest())
  assert_true(plugin.has_function(export_name("echo")))
  assert_false(plugin.has_function(export_name("missing")))
}

///|
test "Unknown import: the load names env.secret_syscall" {
  let error = load_error(@extism.Manifest::new(@fixtures.unknown_import()))
  assert_true(error is UnlinkedImport("env", "secret_syscall"))
}

///|
test "Sandbox not enabled: the load names wasi_snapshot_preview1.fd_write" {
  let error = load_error(@extism.Manifest::new(@fixtures.fd_write_import()))
  assert_true(error is UnlinkedImport("wasi_snapshot_preview1", "fd_write"))
  let plugin = load(
    @extism.Manifest::new(@fixtures.fd_write_import()).wasi(
      @wasi.Sandbox::new(),
    ),
  )
  assert_eq(call(plugin, "handle", b""), b"")
}

///|
test "Name clash with the kernel: extism:host/env.alloc is refused" {
  let function = @extism.HostFunction::new(
    @extism.Namespace::parse("extism:host/env"),
    @extism.FunctionName::parse("alloc"),
    @engine.Signature::new([I64], [I64]),
    (_, args) => args,
  )
  let error = try @extism.Manifest::new(b"").register(function) catch {
    error => error
  } noraise {
    _ => fail("the registration must fail")
  }
  assert_true(error is ReservedName("extism:host/env.alloc"))
}

///|
test "a name registered twice is refused" {
  let manifest = plugin_manifest()
  let again = lookup_function((_, args) => args)
  let error = try manifest.register(again) catch {
    error => error
  } noraise {
    _ => fail("the registration must fail")
  }
  assert_true(error is AlreadyRegistered("extism:host/user.lookup"))
}

///|
test "Default policy: config gives 0, var_set is denied, logging is off, HTTP is denied" {
  let plugin = load(plugin_manifest())
  assert_eq(call(plugin, "config", b""), b"")
  assert_true(
    call_error(plugin, "var_big", b"")
    is Denied({ function: "var_set", method_: None, url: None, }),
  )
  let level = call(load(plugin_manifest()), "log_level", b"")
  assert_eq(level, b"\xff\xff\xff\x7f\x00\x00\x00\x00")
  assert_eq(call(load(plugin_manifest()), "log", b""), b"")
}

///|
test "Logging off: get_log_level gives 2147483647" {
  assert_eq(@extism.logging_off, 2147483647)
}

///|
test "Configuration values: config_get of mode gives strict" {
  let policy = @extism.Policy::default().config(Values({ "mode": "strict" }))
  let plugin = load(plugin_manifest().policy(policy))
  assert_eq(call(plugin, "config", b""), b"strict")
}

///|
test "Denied HTTP request: the error names http_request with the method and the URL" {
  let error = call_error(load(plugin_manifest()), "http", b"")
  assert_true(
    error
    is Denied(
      {
        function: "http_request",
        method_: Some("POST"),
        url: Some("https://example.com/api"),
      }
    ),
  )
}

///|
test "Handler answers: status 204 and an empty body" {
  let seen = []
  let policy = @extism.Policy::default().http(
    Handler(request => {
      seen.push((request.method_, request.url))
      { status: 204, headers: {}, body: b"", }
    }),
  )
  let output = call(load(plugin_manifest().policy(policy)), "http", b"")
  assert_eq(
    output, b"\xcc\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(seen, [("POST", "https://example.com/api")])
}

///|
test "Variable over the limit: a 2 KiB variable with a 1 KiB limit" {
  let policy = @extism.Policy::default().variables(
    Session(@extism.ByteLimit::parse(1024)),
  )
  let error = call_error(load(plugin_manifest().policy(policy)), "var_big", b"")
  assert_true(error is Limit("variable store"))
}

///|
test "session variables keep their value for the plugin" {
  let policy = @extism.Policy::default().variables(
    Session(@extism.ByteLimit::parse(1024)),
  )
  let plugin = load(plugin_manifest().policy(policy))
  assert_eq(call(plugin, "var_roundtrip", b"kept"), b"kept")
}

///|
test "a log sink gets the messages at its level and above" {
  let messages = []
  let policy = @extism.Policy::default().logging(
    Sink(Info, (level, text) => messages.push((level, text))),
  )
  let plugin = load(plugin_manifest().policy(policy))
  assert_eq(call(plugin, "log", b""), b"")
  assert_eq(messages, [(@extism.LogLevel::Info, "hello")])
  assert_eq(call(plugin, "log_level", b""), b"\x02\x00\x00\x00\x00\x00\x00\x00")
}

///|
test "Function in a custom namespace: lookup reads the input handle and gives new bytes" {
  assert_eq(call(load(plugin_manifest()), "lookup", b"morphir"), b"MORPHIR")
}

///|
test "Host function fails: the error names the function and holds the message" {
  let manifest = @extism.Manifest::new(@fixtures.plugin()).register(
    lookup_function((_, _) => raise @engine.HostError("not found")),
  )
  let error = call_error(load(manifest), "lookup", b"x")
  assert_true(error is HostFunction("extism:host/user.lookup", "not found"))
}

///|
test "Kernel memory full during a call: a memory limit error for the kernel memory" {
  let limits = @extism.Limits::default().kernel_memory(
    @engine.PageCount::parse(17),
  )
  let error = call_error(
    load(plugin_manifest().limits(limits)),
    "kernel_full",
    b"",
  )
  assert_true(error is MemoryLimit(KernelMemory))
}

///|
test "a trap is an engine error" {
  assert_true(
    call_error(load(plugin_manifest()), "boom", b"")
    is Engine(Trap(Unreachable)),
  )
}

///|
test "WASI reactor: _initialize runs once, before the first call" {
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(@wasi.Sandbox::new()),
  )
  assert_eq(call(plugin, "starts", b""), b"\x01")
  assert_eq(call(plugin, "starts", b""), b"\x01")
}

///|
test "Initialization traps: the first call fails with an initialization error" {
  let error = call_error(
    load(@extism.Manifest::new(@fixtures.init_trap())),
    "handle",
    b"",
  )
  assert_true(error is Initialization(Trap(Unreachable)))
}

///|
test "the sandbox sinks get what the plugin prints" {
  let out = []
  let sandbox = @wasi.Sandbox::new().stdout(bytes => out.push(bytes.to_owned()))
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(sandbox),
  )
  assert_eq(call(plugin, "print", b""), b"")
  assert_eq(out, [b"hello"])
}

///|
test "Plugin that imports an unusual function: path_symlink returns an error code" {
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(@wasi.Sandbox::new()),
  )
  assert_eq(call(plugin, "symlink", b""), b"\x08")
}

///|
test "Plugin exits with code 0: the call succeeds with its output" {
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(@wasi.Sandbox::new()),
  )
  assert_eq(call(plugin, "done", b""), b"\x64")
}

///|
test "Plugin exits with code 3: an exit error that holds 3" {
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_plugin()).wasi(@wasi.Sandbox::new()),
  )
  assert_true(call_error(plugin, "exit3", b"") is Exit(3))
}

///|
test "Host function signatures: the upstream signatures of extism:host/env" {
  let signature = (f : @extism.ExtismFunction) => f.signature().to_string()
  assert_eq(signature(ConfigGet), "(i64) -> i64")
  assert_eq(signature(VarGet), "(i64) -> i64")
  assert_eq(signature(VarSet), "(i64, i64) -> ()")
  for
    f in [
      @extism.ExtismFunction::LogTrace,
      LogDebug,
      LogInfo,
      LogWarn,
      LogError,
    ] {
    assert_eq(signature(f), "(i64) -> ()")
  }
  assert_eq(signature(GetLogLevel), "() -> i32")
  assert_eq(signature(HttpRequest), "(i64, i64) -> i64")
  assert_eq(signature(HttpStatusCode), "() -> i32")
  assert_eq(signature(HttpHeaders), "() -> i64")
}

///|
test "names are not empty and have no NUL" {
  assert_eq(@extism.Namespace::parse("x").text(), "x")
  let refused = (text : String) => {
    try @extism.ExportName::parse(text) catch {
      NameError(_, _, _) => true
    } noraise {
      _ => false
    }
  }
  assert_true(refused(""))
  assert_true(refused("a\u{0}b"))
  assert_true(refused("a".repeat(1025)))
  assert_false(refused("a".repeat(1024)))
}

///|
test "handles are more than 0 and byte limits are from 0 to 2147483647" {
  assert_eq(@extism.Handle::parse(1).offset(), 1)
  assert_true(
    try @extism.Handle::parse(0) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  assert_eq(@extism.ByteLimit::parse(0).bytes(), 0)
  assert_eq(@extism.ByteLimit::parse(2147483647).bytes(), 2147483647)
  assert_true(
    try @extism.ByteLimit::parse(-1) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  assert_true(
    try @extism.ByteLimit::parse(2147483648) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}

///|
test "Constructors run once: __wasm_call_ctors once, and no _initialize, on each engine" {
  let plugin = load(@extism.Manifest::new(@fixtures.ctors()))
  assert_eq(call(plugin, "count", b""), b"10")
  assert_eq(call(plugin, "count", b""), b"10")
}

///|
test "A __wasm_call_ctors with another type: no start-up export runs, as upstream" {
  let plugin = load(@extism.Manifest::new(@fixtures.ctors_wrong_type()))
  assert_eq(call(plugin, "count", b""), b"00")
}

///|
test "A plugin that does not export its memory prints through WASI on each engine" {
  let out = []
  let sandbox = @wasi.Sandbox::new().stdout(bytes => out.push(bytes.to_owned()))
  let plugin = load(
    @extism.Manifest::new(@fixtures.wasi_hidden_memory()).wasi(sandbox),
  )
  assert_eq(call(plugin, "print", b""), b"")
  assert_eq(out, [b"hello"])
}
