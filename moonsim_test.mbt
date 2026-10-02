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

///|
test "event queue orders by time, priority, and stable sequence" {
  let queue = @moonsim.EventQueue::new()
  queue.push(@moonsim.Event::new(3, 2, 0, 0, fn() {  }).unwrap())
  queue.push(@moonsim.Event::new(2, 1, 2, 1, fn() {  }).unwrap())
  queue.push(@moonsim.Event::new(1, 1, 0, 2, fn() {  }).unwrap())
  queue.push(@moonsim.Event::new(4, 1, 0, 3, fn() {  }).unwrap())
  queue.push(@moonsim.Event::new(5, 1, -1, 4, fn() {  }).unwrap())

  assert_eq(queue.length(), 5)
  assert_eq(pop_event_id(queue), 5)
  assert_eq(pop_event_id(queue), 1)
  assert_eq(pop_event_id(queue), 4)
  assert_eq(pop_event_id(queue), 2)
  assert_eq(pop_event_id(queue), 3)
  assert_true(queue.is_empty())
  match queue.pop() {
    None => ()
    Some(_) => fail("an empty queue returned an event")
  }
}

///|
fn pop_event_id(queue : @moonsim.EventQueue) -> Int raise Error {
  match queue.pop() {
    Some(event) => event.id
    None => fail("expected a queued event")
  }
}
