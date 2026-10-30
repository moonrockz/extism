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
  // The largest budget is a backstop: when the deadline does not stop the loop, the call ends with
  // BudgetExhausted after some seconds and the test fails, instead of a run that never ends.
  let backstop = @engine.Budget::parse(2147483647L)
  let start = @env.now()
  let error = try instance.call("spin", [], deadline~, budget=backstop) catch {
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
test "a budget large enough lets the call finish" {
  let instance = compile(@fixtures.add()).instantiate(@engine.Imports::new())
  let budget = @engine.Budget::parse(100L)
  assert_eq(instance.call("add", [I64(1), I64(2)], budget~), [I64(3)])
  assert_eq(instance.call("add", [I64(1), I64(2)], budget~), [I64(3)])
}

///|
test "Start function under a deadline on native: a start that loops forever stops at the deadline" {
  let deadline = @engine.Deadline::parse(100)
  let backstop = @engine.Budget::parse(2147483647L)
  let module_ = compile(@fixtures.start_loop())
  let start = @env.now()
  let error = try
    module_.instantiate(@engine.Imports::new(), deadline~, budget=backstop)
  catch {
    error => error
  } noraise {
    _ => fail("the instantiation must stop")
  }
  assert_true(error is Start(Interrupted))
  assert_true(@env.now() - start < 1000UL)
  assert_eq(@engine.live_watchdogs(), 0)
}

///|
test "Start function under a budget on native: a start that loops forever stops at the budget" {
  let module_ = compile(@fixtures.start_loop())
  let budget = @engine.Budget::parse(100000L)
  let error = try module_.instantiate(@engine.Imports::new(), budget~) catch {
    error => error
  } noraise {
    _ => fail("the instantiation must stop")
  }
  assert_true(error is Start(BudgetExhausted))
}

///|
test "Watchdog race: calls that end just inside the deadline leave no interruption for the next call" {
  let module_ = compile(@fixtures.spin_n())
  // Calibrate the iterations per millisecond of this machine.
  let probe = module_.instantiate(@engine.Imports::new())
  let calibration = 20000000
  let begin = @env.now()
  probe.call("spin_n", [I32(calibration)]) |> ignore
  let elapsed = @cmp.maximum((@env.now() - begin).to_int(), 1)
  let per_ms = @cmp.maximum(calibration / elapsed, 1)
  let deadline = @engine.Deadline::parse(2)
  let mut finished = 0
  let mut interrupted = 0
  for k in 0..<600 {
    // From 1.6 ms to 2.4 ms of work, around the deadline of 2 ms.
    let n = per_ms * 2 * (80 + k % 41) / 100
    let instance = module_.instantiate(@engine.Imports::new())
    let ended = try instance.call("spin_n", [I32(n)], deadline~) catch {
      Interrupted => false
      error => fail("unexpected error: \{@debug.to_string(error)}")
    } noraise {
      _ => true
    }
    if ended {
      finished += 1
      // The watchdog can fire after the guest returns; the next call must not see it.
      assert_eq(instance.call("one", []), [I32(1)])
      assert_eq(instance.call("one", [], deadline~), [I32(1)])
    } else {
      interrupted += 1
    }
  }
  assert_true(finished > 0)
  assert_eq(@engine.live_watchdogs(), 0)
  ignore(interrupted)
}
