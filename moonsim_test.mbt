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
test "FIFO queue preserves order and records waiting time" {
  let queue : @moonsim.Queue[String] = @moonsim.Queue::new()
  queue.enqueue("first", 0).unwrap()
  queue.enqueue("second", 2).unwrap()
  queue.enqueue("third", 3).unwrap()

  assert_eq(queue.length(), 3)
  assert_eq(queue.dequeue(4).unwrap(), Some("first"))
  assert_eq(queue.dequeue(6).unwrap(), Some("second"))
  assert_eq(queue.length(), 1)
  assert_eq(queue.total_waiting_time(), 8)
  assert_eq(queue.dequeued_count(), 2)
  assert_eq(queue.average_waiting_time(), 4.0)
  assert_eq(queue.dequeue(7).unwrap(), Some("third"))
  assert_eq(queue.dequeue(8).unwrap(), None)
  assert_eq(queue.average_waiting_time(), 4.0)
}

///|
test "FIFO queue rejects backwards timestamps" {
  let queue : @moonsim.Queue[Int] = @moonsim.Queue::new()
  queue.enqueue(1, 5).unwrap()
  assert_eq(
    queue.enqueue(2, 4),
    Err("queue operation time cannot move backwards"),
  )
  assert_eq(queue.dequeue(4), Err("queue operation time cannot move backwards"))
  assert_eq(queue.length(), 1)
}

///|
test "FIFO queue compaction preserves remaining items" {
  let queue : @moonsim.Queue[Int] = @moonsim.Queue::new()
  let mut index = 0
  while index < 100 {
    queue.enqueue(index, index).unwrap()
    index += 1
  }

  index = 0
  while index < 70 {
    assert_eq(queue.dequeue(100).unwrap(), Some(index))
    index += 1
  }
  assert_eq(queue.length(), 30)

  while index < 100 {
    assert_eq(queue.dequeue(100).unwrap(), Some(index))
    index += 1
  }
  assert_eq(queue.length(), 0)
}

///|
test "entity advances along reusable routes and tracks cycle time" {
  let route = @moonsim.Route::new(["cut", "drill", "pack"]).unwrap()
  let entity = @moonsim.Entity::new(42, 3).unwrap()
  assert_eq(route.length(), 3)
  assert_eq(entity.id(), 42)
  assert_eq(entity.created_at(), 3)
  assert_eq(entity.route_position(), -1)
  assert_eq(entity.current_station(route), None)
  assert_eq(entity.advance_route(route), Some("cut"))
  assert_eq(entity.current_station(route), Some("cut"))
  assert_eq(entity.advance_route(route), Some("drill"))
  assert_eq(entity.advance_route(route), Some("pack"))
  assert_eq(entity.advance_route(route), None)
  assert_eq(entity.route_position(), 2)
  assert_eq(entity.cycle_time_at(11).unwrap(), 8)
  assert_eq(
    entity.cycle_time_at(2),
    Err("entity cycle time cannot precede creation"),
  )
}

///|
test "entity and route validate their inputs" {
  match @moonsim.Entity::new(-1, 0) {
    Err(message) => assert_eq(message, "entity ID must be non-negative")
    Ok(_) => fail("negative entity ID was accepted")
  }
  match @moonsim.Entity::new(1, -1) {
    Err(message) =>
      assert_eq(message, "entity creation time must be non-negative")
    Ok(_) => fail("negative entity creation time was accepted")
  }
  match @moonsim.Route::new([]) {
    Err(message) =>
      assert_eq(message, "route must contain at least one station")
    Ok(_) => fail("empty route was accepted")
  }
  match @moonsim.Route::new(["cut", ""]) {
    Err(message) => assert_eq(message, "route station name cannot be empty")
    Ok(_) => fail("empty station name was accepted")
  }
}

///|
fn pop_event_id(queue : @moonsim.EventQueue) -> Int raise Error {
  match queue.pop() {
    Some(event) => event.id
    None => fail("expected a queued event")
  }
}
