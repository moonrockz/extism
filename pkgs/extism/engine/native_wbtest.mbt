///|
/// A delay between the end of a guest call and the stop of its watchdog, for the race test.
extern "C" fn wamr_test_stop_delay(microseconds : Int32) = "extism_wamr_test_stop_delay"

///|
test "Watchdog race, made certain: the deadline passes after the guest returns, and the next call does not see it" {
  // The stop of the watchdog waits 5 ms after the guest returns, so a deadline of 1 ms always fires
  // after the return.
  wamr_test_stop_delay(5000)
  defer wamr_test_stop_delay(0)
  let instance = Engine::default()
    .compile(@fixtures.spin_n())
    .instantiate(Imports::new())
  let deadline = Deadline::parse(1)
  for _ in 0..<20 {
    assert_eq(instance.call("one", [], deadline~), [I32(1)])
    assert_eq(instance.call("one", []), [I32(1)])
  }
  assert_true(instance.is_usable())
  assert_eq(live_watchdogs(), 0)
}
