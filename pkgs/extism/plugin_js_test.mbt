///|
test "Limits on js: the budget and the deadline are not enforced, the memory ceilings are" {
  let limits = @extism.Limits::default()
    .budget(@engine.Budget::parse(1000000L))
    .deadline(@engine.Deadline::parse(1000))
  let plugin = @extism.Plugin::load(plugin_manifest().limits(limits))
  assert_eq(plugin.bounds(), {
    memory: Enforced,
    budget: NotEnforced,
    interruption: NotEnforced,
  })
}
