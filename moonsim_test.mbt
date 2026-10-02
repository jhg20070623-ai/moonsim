///|
test "simulation clock advances monotonically" {
  let clock = @moonsim.SimulationClock::new()
  assert_eq(clock.now(), 0)
  assert_true(clock.advance_to(5))
  assert_eq(clock.now(), 5)
  assert_true(clock.advance_to(5))
  assert_false(clock.advance_to(4))
  assert_eq(clock.now(), 5)
}

///|
test "event validates time and preserves its action" {
  let mut calls = 0
  let event = @moonsim.Event::new(1, 3, 0, 0, fn() { calls += 1 })
  match event {
    Ok(value) => value.execute()
    Err(_) => fail("valid event was rejected")
  }
  assert_eq(calls, 1)

  let invalid = @moonsim.Event::new(2, -1, 0, 1, fn() {  })
  match invalid {
    Err(message) => assert_eq(message, "event time must be non-negative")
    Ok(_) => fail("negative event time was accepted")
  }
}
