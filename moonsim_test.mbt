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
test "queue dequeue wait observations can be collected by metrics" {
  let queue : @moonsim.Queue[Int] = @moonsim.Queue::new()
  let metrics = @moonsim.Metrics::new(0).unwrap()
  queue.enqueue(1, 0).unwrap()
  queue.enqueue(2, 0).unwrap()

  match queue.dequeue_with_wait(0).unwrap() {
    None => fail("expected the first queued item")
    Some((value, waiting_time)) => {
      assert_eq(value, 1)
      assert_eq(waiting_time, 0)
      metrics.record_waiting_time(waiting_time, 0).unwrap()
    }
  }
  match queue.dequeue_with_wait(4).unwrap() {
    None => fail("expected the second queued item")
    Some((value, waiting_time)) => {
      assert_eq(value, 2)
      assert_eq(waiting_time, 4)
      metrics.record_waiting_time(waiting_time, 4).unwrap()
    }
  }

  assert_eq(queue.total_waiting_time(), 4)
  assert_eq(queue.average_waiting_time(), 2.0)
  assert_eq(metrics.mean_waiting_time(), queue.average_waiting_time())
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
test "fixed-time and fixed-batch policies use their thresholds" {
  let fixed_time = @moonsim.BatchPolicy::fixed_time(5).unwrap()
  assert_false(fixed_time.should_trigger(0, 8).unwrap())
  assert_false(fixed_time.should_trigger(2, 4).unwrap())
  assert_true(fixed_time.should_trigger(2, 5).unwrap())

  let fixed_batch = @moonsim.BatchPolicy::fixed_batch(3).unwrap()
  assert_false(fixed_batch.should_trigger(2, 10).unwrap())
  assert_true(fixed_batch.should_trigger(3, 0).unwrap())
  assert_true(fixed_batch.should_trigger(4, 0).unwrap())
}

///|
test "batch policies reject invalid configuration and observations" {
  match @moonsim.BatchPolicy::fixed_time(0) {
    Err(message) => assert_eq(message, "fixed-time interval must be positive")
    Ok(_) => fail("zero fixed-time interval was accepted")
  }
  match @moonsim.BatchPolicy::fixed_batch(-1) {
    Err(message) => assert_eq(message, "fixed batch size must be positive")
    Ok(_) => fail("negative batch size was accepted")
  }

  let policy = @moonsim.BatchPolicy::fixed_batch(2).unwrap()
  assert_eq(
    policy.should_trigger(-1, 0),
    Err("waiting count cannot be negative"),
  )
  assert_eq(policy.should_trigger(1, -1), Err("oldest wait cannot be negative"))
}

///|
test "hybrid batching triggers on quantity or timeout" {
  let policy = @moonsim.BatchPolicy::hybrid(4, 6).unwrap()
  assert_false(policy.should_trigger(0, 20).unwrap())
  assert_false(policy.should_trigger(3, 5).unwrap())
  assert_true(policy.should_trigger(4, 0).unwrap())
  assert_true(policy.should_trigger(2, 6).unwrap())
}

///|
test "hybrid policy rejects non-positive thresholds" {
  match @moonsim.BatchPolicy::hybrid(0, 5) {
    Err(message) => assert_eq(message, "hybrid batch size must be positive")
    Ok(_) => fail("zero hybrid batch size was accepted")
  }
  match @moonsim.BatchPolicy::hybrid(2, 0) {
    Err(message) => assert_eq(message, "hybrid max wait must be positive")
    Ok(_) => fail("zero hybrid timeout was accepted")
  }
}

///|
test "random sources reproduce streams from the same seed" {
  let first = @moonsim.RandomSource::new(42).unwrap()
  let second = @moonsim.RandomSource::new(42).unwrap()
  assert_eq(first.next_int(), second.next_int())
  assert_eq(first.int_below(17).unwrap(), second.int_below(17).unwrap())
  assert_eq(first.next_double(), second.next_double())
  let bounded = first.int_below(5).unwrap()
  assert_true(bounded >= 0 && bounded < 5)
  let value = first.next_double()
  assert_true(value >= 0.0 && value < 1.0)
  assert_true(
    @moonsim.RandomSource::new(42).unwrap().next_int() !=
    @moonsim.RandomSource::new(43).unwrap().next_int(),
  )
}

///|
test "simulation random stream is seeded and validates limits" {
  let first = @moonsim.Simulation::with_seed(7).unwrap()
  let second = @moonsim.Simulation::with_seed(7).unwrap()
  assert_eq(
    first.random_int_below(100).unwrap(),
    second.random_int_below(100).unwrap(),
  )
  assert_eq(first.random_double(), second.random_double())
  assert_eq(
    first.random_int_below(0),
    Err("random integer limit must be positive"),
  )
  match @moonsim.RandomSource::new(-1) {
    Err(message) => assert_eq(message, "random seed must be non-negative")
    Ok(_) => fail("negative random seed was accepted")
  }
}

///|
test "metrics report cycle time, waiting time, WIP, throughput, and queue length" {
  let metrics = @moonsim.Metrics::new(0).unwrap()
  let first = @moonsim.Entity::new(1, 0).unwrap()
  let second = @moonsim.Entity::new(2, 2).unwrap()
  metrics.record_entity_created(first).unwrap()
  metrics.record_queue_length(1, 0).unwrap()
  metrics.record_entity_created(second).unwrap()
  metrics.record_queue_length(2, 2).unwrap()
  metrics.record_waiting_time(3, 4).unwrap()
  metrics.record_entity_completed(first, 6).unwrap()
  metrics.record_queue_length(0, 6).unwrap()
  metrics.record_entity_completed(second, 8).unwrap()

  assert_eq(metrics.simulation_time(8).unwrap(), 8)
  assert_eq(metrics.entity_created_count(), 2)
  assert_eq(metrics.entity_completed_count(), 2)
  assert_eq(metrics.wip(), 0)
  assert_eq(metrics.max_wip(), 2)
  assert_eq(metrics.mean_cycle_time(), 6.0)
  assert_eq(metrics.mean_waiting_time(), 3.0)
  assert_eq(metrics.throughput(8).unwrap(), 0.25)
  assert_eq(metrics.average_wip(8).unwrap(), 1.5)
  assert_eq(metrics.queue_length(), 0)
  assert_eq(metrics.max_queue_length(), 2)
  assert_eq(metrics.average_queue_length(8).unwrap(), 1.25)
}

///|
test "metrics reject invalid counts and timestamps without corrupting state" {
  let metrics = @moonsim.Metrics::new(0).unwrap()
  let entity = @moonsim.Entity::new(1, 0).unwrap()
  match metrics.record_entity_completed(entity, 1) {
    Err(message) =>
      assert_eq(message, "cannot complete an entity when WIP is zero")
    Ok(_) => fail("completion with zero WIP was accepted")
  }
  assert_eq(metrics.wip(), 0)
  assert_eq(
    metrics.record_waiting_time(-1, 1),
    Err("waiting time cannot be negative"),
  )
  assert_eq(
    metrics.record_queue_length(-1, 1),
    Err("queue length cannot be negative"),
  )
  metrics.record_entity_created(entity).unwrap()
  assert_eq(metrics.record_queue_length(1, 2), Ok(()))
  assert_eq(
    metrics.record_queue_length(2, 1),
    Err("metrics observation time cannot move backwards"),
  )
  assert_eq(metrics.wip(), 1)
}

///|
fn pop_event_id(queue : @moonsim.EventQueue) -> Int raise Error {
  match queue.pop() {
    Some(event) => event.id
    None => fail("expected a queued event")
  }
}
