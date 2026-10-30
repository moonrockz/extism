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
