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
  match queue.peek() {
    None => ()
    Some(_) => fail("an empty queue had a next event")
  }
  match queue.pop() {
    None => ()
    Some(_) => fail("an empty queue returned an event")
  }
}

///|
test "simulation schedules events in deterministic order" {
  let sim = @moonsim.Simulation::new()
  let seen = Array(capacity=0)
  assert_eq(sim.schedule(2, 0, fn() { seen.push(10) }).unwrap(), 0)
  assert_eq(sim.schedule(2, 2, fn() { seen.push(20) }).unwrap(), 1)
  assert_eq(sim.schedule(2, 0, fn() { seen.push(11) }).unwrap(), 2)
  assert_eq(sim.schedule(1, 5, fn() { seen.push(5) }).unwrap(), 3)

  assert_eq(sim.pending_events(), 4)
  assert_eq(sim.run(), 4)
  assert_eq(sim.now(), 2)
  assert_eq(seen, [5, 10, 11, 20])
  assert_eq(sim.pending_events(), 0)
}

///|
test "run_until includes boundary events and leaves later events pending" {
  let sim = @moonsim.Simulation::new()
  let seen = Array(capacity=0)
  sim.schedule(3, 0, fn() { seen.push(3) }).unwrap() |> ignore
  sim.schedule(5, 0, fn() { seen.push(5) }).unwrap() |> ignore
  sim.schedule(8, 0, fn() { seen.push(8) }).unwrap() |> ignore

  assert_eq(sim.run_until(5).unwrap(), 2)
  assert_eq(sim.now(), 5)
  assert_eq(sim.pending_events(), 1)
  assert_eq(seen, [3, 5])
  assert_eq(sim.run(), 1)
  assert_eq(sim.now(), 8)
  assert_eq(seen, [3, 5, 8])
}

///|
test "simulation rejects scheduling and running into the past" {
  let sim = @moonsim.Simulation::new()
  assert_eq(
    sim.schedule(-1, 0, fn() {  }),
    Err("cannot schedule an event before the current simulation time"),
  )
  sim.run_until(4).unwrap() |> ignore
  assert_eq(
    sim.schedule(3, 0, fn() {  }),
    Err("cannot schedule an event before the current simulation time"),
  )
  assert_eq(
    sim.run_until(2),
    Err("run_until cannot move before the current simulation time"),
  )
}

///|
test "resource capacity and utilization are tracked over time" {
  let resource = @moonsim.Resource::new("press", 2).unwrap()
  assert_eq(resource.name(), "press")
  assert_eq(resource.capacity(), 2)
  assert_true(resource.acquire(1).unwrap())
  assert_true(resource.acquire(2).unwrap())
  assert_false(resource.acquire(3).unwrap())
  assert_eq(resource.used(), 2)
  assert_true(resource.release(4).unwrap())
  assert_true(resource.release(5).unwrap())
  assert_false(resource.release(6).unwrap())
  assert_eq(resource.used(), 0)
  assert_eq(resource.utilization_at(6).unwrap(), 0.5)
}

///|
test "resource rejects invalid capacity and backwards time" {
  match @moonsim.Resource::new("invalid", 0) {
    Err(message) => assert_eq(message, "resource capacity must be positive")
    Ok(_) => fail("zero-capacity resource was accepted")
  }

  let resource = @moonsim.Resource::new("lathe", 1).unwrap()
  resource.acquire(5).unwrap() |> ignore
  assert_eq(
    resource.acquire(4),
    Err("resource operation time cannot move backwards"),
  )
  assert_eq(resource.used(), 1)
  assert_eq(
    resource.utilization_at(4),
    Err("resource utilization time cannot move backwards"),
  )
}

///|
fn pop_event_id(queue : @moonsim.EventQueue) -> Int raise Error {
  match queue.pop() {
    Some(event) => event.id
    None => fail("expected a queued event")
  }
}
