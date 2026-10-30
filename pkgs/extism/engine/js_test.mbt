///|
test "js engine report: the memory ceiling is enforced, the budget and interruption are not" {
  assert_eq(@engine.Engine::default().bounds(), {
    memory: Enforced,
    budget: NotEnforced,
    interruption: NotEnforced,
  })
}
