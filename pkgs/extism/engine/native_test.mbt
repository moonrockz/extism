///|
fn spin_instance() -> @engine.Instance raise {
  compile(@fixtures.traps()).instantiate(@engine.Imports::new())
}

///|
test "Native engine report: memory, budget and interruption are enforced" {
  assert_eq(@engine.Engine::default().bounds(), {
    memory: Enforced,
    budget: Enforced,
    interruption: Enforced,
  })
}

///|
test "Runaway loop on native: a budget of 1,000,000 instructions stops the call" {
  let instance = spin_instance()
  let budget = @engine.Budget::parse(1000000L)
  let error = try instance.call("spin", [], budget~) catch {
    error => error
  } noraise {
    _ => fail("the call must stop")
  }
  assert_true(error is BudgetExhausted)
  assert_false(instance.is_usable())
}

///|
test "Deadline on native: a loop with a 100 ms deadline stops within 1 second" {
  let instance = spin_instance()
  let deadline = @engine.Deadline::parse(100)
  let start = @env.now()
  let error = try instance.call("spin", [], deadline~) catch {
    error => error
  } noraise {
    _ => fail("the call must stop")
  }
  let elapsed = @env.now() - start
  assert_true(error is Interrupted)
  assert_true(elapsed >= 90UL && elapsed < 1000UL)
  assert_eq(@engine.live_watchdogs(), 0)
}

///|
test "No watchdog left: 1,000 short calls with a deadline leave no thread" {
  let instance = compile(@fixtures.add()).instantiate(@engine.Imports::new())
  let deadline = @engine.Deadline::parse(1000)
  for i in 0..<1000 {
    assert_eq(instance.call("add", [I64(i.to_int64()), I64(1)], deadline~), [
      I64(i.to_int64() + 1L),
    ])
  }
  assert_eq(@engine.live_watchdogs(), 0)
}

///|
test "the watchdog is joined after a trap and after an exhausted budget" {
  let deadline = @engine.Deadline::parse(1000)
  let budget = @engine.Budget::parse(1000L)
  (spin_instance().call("spin", [], budget~, deadline~) catch { _ => [] })
  |> ignore
  (spin_instance().call("boom", [], deadline~) catch { _ => [] }) |> ignore
  assert_eq(@engine.live_watchdogs(), 0)
}

///|
test "SIMD module on an engine built without SIMD: the load names simd" {
  let error = try compile(@fixtures.simd()) catch {
    error => error
  } noraise {
    _ => fail("the load must fail")
  }
  assert_true(error is FeatureUnsupported(Simd))
}

///|
test "a budget large enough lets the call finish" {
  let instance = compile(@fixtures.add()).instantiate(@engine.Imports::new())
  let budget = @engine.Budget::parse(100L)
  assert_eq(instance.call("add", [I64(1), I64(2)], budget~), [I64(3)])
  assert_eq(instance.call("add", [I64(1), I64(2)], budget~), [I64(3)])
}
