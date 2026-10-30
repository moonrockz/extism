///|
test "limits on native: the budget stops a call, and the bounds are enforced" {
  let limits = @extism.Limits::default().budget(@engine.Budget::parse(1000L))
  let plugin = @extism.Plugin::load(plugin_manifest().limits(limits))
  assert_eq(plugin.bounds(), {
    memory: Enforced,
    budget: Enforced,
    interruption: Enforced,
  })
  let echo = @extism.ExportName::parse("echo")
  let error = try plugin.call(echo, Bytes::make(5000, b'a')) catch {
    error => error
  } noraise {
    _ => fail("the call must stop")
  }
  assert_true(error is Engine(BudgetExhausted))
}

///|
test "Start-up under the deadline on native: an _initialize that loops forever stops" {
  let limits = @extism.Limits::default()
    .deadline(@engine.Deadline::parse(100))
    .budget(@engine.Budget::parse(2147483647L))
  let plugin = @extism.Plugin::load(
    @extism.Manifest::new(@fixtures.init_loop()).limits(limits),
  )
  let error = call_error(plugin, "run", b"")
  assert_true(error is Initialization(Interrupted))
}

///|
test "Instantiation under the deadline on native: a start function that loops forever stops" {
  let limits = @extism.Limits::default()
    .deadline(@engine.Deadline::parse(100))
    .budget(@engine.Budget::parse(2147483647L))
  let error = load_error(
    @extism.Manifest::new(@fixtures.start_loop()).limits(limits),
  )
  assert_true(error is Engine(Start(Interrupted)))
}

///|
test "Host function table on native: loading and dropping many plugins keeps it bounded" {
  for _ in 0..<200 {
    let plugin = @extism.Plugin::load(plugin_manifest())
    assert_eq(
      plugin.call(@extism.ExportName::parse("echo"), b"x"),
      b"x",
    )
  }
  // At most the entries of the plugins that are still alive (none) or not yet released.
  assert_true(@engine.host_entry_count() <= 64)
}

///|
test "A guest that writes in a loop: each fd_write gives the sink at most its bound, and the call ends at the deadline" {
  let largest = Ref(0)
  let calls = Ref(0)
  let sandbox = @wasi.Sandbox::new().stdout(
    bytes => {
      calls.val += 1
      if bytes.length() > largest.val {
        largest.val = bytes.length()
      }
    },
    bound=@wasi.SinkBound::parse(4096),
  )
  let limits = @extism.Limits::default()
    .deadline(@engine.Deadline::parse(200))
    .budget(@engine.Budget::parse(2147483647L))
  let plugin = @extism.Plugin::load(
    @extism.Manifest::new(@fixtures.wasi_flood()).wasi(sandbox).limits(limits),
  )
  let error = call_error(plugin, "flood", b"")
  assert_true(error is Engine(Interrupted))
  assert_true(calls.val > 0)
  assert_true(largest.val <= 4096)
}
