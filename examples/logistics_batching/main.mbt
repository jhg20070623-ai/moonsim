///|
struct BatchState {
  policy : @moonsim.BatchPolicy
  queue : @moonsim.Queue[@moonsim.Entity]
  metrics : @moonsim.Metrics
  mut batch_started_at : Int
  mut batch_open : Bool
  mut generation : Int
  mut batch_count : Int
  mut timeout_releases : Int
  mut forced_partial_batches : Int
  mut overdue_entities : Int
}

///|
fn main raise {
  let fixed_time = @moonsim.BatchPolicy::fixed_time(5).unwrap()
  let fixed_batch = @moonsim.BatchPolicy::fixed_batch(3).unwrap()
  let hybrid = @moonsim.BatchPolicy::hybrid(3, 5).unwrap()
  run_policy("FixedTime(5)", fixed_time)
  run_policy("FixedBatch(3)", fixed_batch)
  run_policy("Hybrid(3, 5)", hybrid)
}

///|
fn run_policy(label : String, policy : @moonsim.BatchPolicy) -> Unit raise {
  let sim = @moonsim.Simulation::new()
  let state = BatchState::{
    policy,
    queue: @moonsim.Queue::new(),
    metrics: @moonsim.Metrics::new(0).unwrap(),
    batch_started_at: 0,
    batch_open: false,
    generation: 0,
    batch_count: 0,
    timeout_releases: 0,
    forced_partial_batches: 0,
    overdue_entities: 0,
  }
  let arrivals = [0, 1, 2, 3, 4, 12, 13, 14, 15, 16, 24, 25, 26, 27, 28, 35, 36]
  let max_wait = 5
  let delivery_delay = 2
  let mut entity_id = 0
  while entity_id < arrivals.length() {
    let id = entity_id
    let arrival_time = arrivals[entity_id]
    let is_last_arrival = entity_id == arrivals.length() - 1
    sim.schedule(arrival_time, 0, fn() {
      let entity = @moonsim.Entity::new(id, arrival_time).unwrap()
      state.metrics.record_entity_created(entity).unwrap() |> ignore
      let starts_batch = state.queue.length() == 0
      state.queue.enqueue(entity, arrival_time).unwrap() |> ignore
      if starts_batch {
        state.batch_open = true
        state.batch_started_at = arrival_time
        state.generation += 1
        schedule_batch_timeout(
          sim,
          state,
          state.generation,
          timeout_for(policy),
          delivery_delay,
          max_wait,
        )
      }
      let oldest_wait = sim.now() - state.batch_started_at
      if policy.should_trigger(state.queue.length(), oldest_wait).unwrap() {
        release_batch(sim, state, sim.now(), delivery_delay, max_wait)
      }
      if is_last_arrival {
        sim.schedule(sim.now() + max_wait, 0, fn() {
          if state.queue.length() > 0 {
            state.forced_partial_batches += 1
            release_batch(sim, state, sim.now(), delivery_delay, max_wait)
          }
        })
        |> ignore
      }
    })
    |> ignore
    entity_id += 1
  }

  let events_processed = sim.run()
  if state.metrics.entity_completed_count() != arrivals.length() ||
    state.metrics.wip() != 0 ||
    state.queue.length() != 0 {
    fail("batch policy left entities incomplete or waiting")
  }
  let now = sim.now()
  println("Policy: \{label}")
  println("  Entities completed: \{state.metrics.entity_completed_count()}")
  println("  Batches released: \{state.batch_count}")
  println("  Mean waiting time: \{state.metrics.mean_waiting_time()} ticks")
  println(
    "  Throughput: \{state.metrics.throughput(now).unwrap()} entities/tick",
  )
  println("  Timeout releases: \{state.timeout_releases}")
  println("  Overdue entities (> \{max_wait} ticks): \{state.overdue_entities}")
  println("  End-of-intake partial batches: \{state.forced_partial_batches}")
  println("  Events processed: \{events_processed}")
  println("  Simulation time: \{now} ticks")
}

///|
fn timeout_for(policy : @moonsim.BatchPolicy) -> Int? {
  match policy {
    @moonsim.FixedTime(interval) => Some(interval)
    @moonsim.FixedBatch(_) => None
    @moonsim.Hybrid(_, max_wait) => Some(max_wait)
  }
}

///|
fn schedule_batch_timeout(
  sim : @moonsim.Simulation,
  state : BatchState,
  generation : Int,
  timeout : Int?,
  delivery_delay : Int,
  max_wait : Int,
) -> Unit {
  match timeout {
    None => ()
    Some(duration) =>
      sim.schedule(sim.now() + duration, 0, fn() {
        if state.batch_open && state.generation == generation {
          let oldest_wait = sim.now() - state.batch_started_at
          if state.policy
            .should_trigger(state.queue.length(), oldest_wait)
            .unwrap() {
            state.timeout_releases += 1
            release_batch(sim, state, sim.now(), delivery_delay, max_wait)
          }
        }
      })
      |> ignore
  }
}

///|
fn release_batch(
  sim : @moonsim.Simulation,
  state : BatchState,
  released_at : Int,
  delivery_delay : Int,
  max_wait : Int,
) -> Unit {
  state.batch_count += 1
  state.batch_open = false
  while state.queue.length() > 0 {
    match state.queue.dequeue_with_wait(released_at).unwrap() {
      None => ()
      Some((entity, waiting_time)) => {
        if waiting_time > max_wait {
          state.overdue_entities += 1
        }
        state.metrics.record_waiting_time(waiting_time, released_at).unwrap()
        |> ignore
        sim.schedule(released_at + delivery_delay, 0, fn() {
          state.metrics.record_entity_completed(entity, sim.now()).unwrap()
          |> ignore
        })
        |> ignore
      }
    }
  }
}
