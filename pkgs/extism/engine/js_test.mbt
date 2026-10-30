///|
test "js engine report: the memory ceiling is enforced, the budget and interruption are not" {
  assert_eq(@engine.Engine::default().bounds(), {
    memory: Enforced,
    budget: NotEnforced,
    interruption: NotEnforced,
  })
}

///|
test "the js engine supports simd" {
  let instance = compile(@fixtures.simd()).instantiate(@engine.Imports::new())
  assert_eq(instance.call("v", []), [])
}
