///|
struct BatchState {
  policy : @moonsim.BatchPolicy
  queue : @moonsim.Queue[@moonsim.Entity]
  metrics : @moonsim.Metrics
  mut batch_started_at : Int
  mut batch_open : Bool
  mut generation : Int
  mut batch_count : Int
  mut quantity_releases : Int
  mut timeout_releases : Int
  mut forced_partial_batches : Int
  mut overdue_entities : Int
}

///|
struct BatchSummary {
  completed_count : Int
  final_wip : Int
  final_queue_length : Int
  batch_count : Int
  mean_waiting_time : Double
  throughput : Double
  quantity_releases : Int
  timeout_releases : Int
  forced_partial_batches : Int
  overdue_entities : Int
  events_processed : Int
  simulation_time : Int
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
  let result = simulate_policy(policy)
  println("Policy: \{label}")
  println("  Entities completed: \{result.completed_count}")
  println("  Batches released: \{result.batch_count}")
  println("  Mean waiting time: \{result.mean_waiting_time} ticks")
  println("  Throughput: \{result.throughput} entities/tick")
  println("  Timeout releases: \{result.timeout_releases}")
  println("  Overdue entities (> 5 ticks): \{result.overdue_entities}")
  println("  End-of-intake partial batches: \{result.forced_partial_batches}")
  println("  Events processed: \{result.events_processed}")
  println("  Simulation time: \{result.simulation_time} ticks")
}

///|
fn simulate_policy(policy : @moonsim.BatchPolicy) -> BatchSummary raise {
  let sim = @moonsim.Simulation::new()
  let state = BatchState::{
    policy,
    queue: @moonsim.Queue::new(),
    metrics: @moonsim.Metrics::new(0).unwrap(),
    batch_started_at: 0,
    batch_open: false,
    generation: 0,
    batch_count: 0,
    quantity_releases: 0,
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
        if triggered_by_quantity(policy, state.queue.length()) {
          state.quantity_releases += 1
        } else {
          state.timeout_releases += 1
        }
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
  let result = BatchSummary::{
    completed_count: state.metrics.entity_completed_count(),
    final_wip: state.metrics.wip(),
    final_queue_length: state.queue.length(),
    batch_count: state.batch_count,
    mean_waiting_time: state.metrics.mean_waiting_time(),
    throughput: state.metrics.throughput(now).unwrap(),
    quantity_releases: state.quantity_releases,
    timeout_releases: state.timeout_releases,
    forced_partial_batches: state.forced_partial_batches,
    overdue_entities: state.overdue_entities,
    events_processed,
    simulation_time: now,
  }
  if result.completed_count != arrivals.length() ||
    result.final_wip != 0 ||
    result.final_queue_length != 0 ||
    result.batch_count <= 0 ||
    result.mean_waiting_time < 0.0 ||
    result.overdue_entities < 0 ||
    result.overdue_entities > result.completed_count ||
    result.forced_partial_batches < 0 ||
    result.forced_partial_batches > result.batch_count {
    fail("batch model result violates completion or metric invariants")
  }
  match policy {
    @moonsim.FixedTime(_) =>
      if result.quantity_releases != 0 || result.timeout_releases == 0 {
        fail("fixed-time policy did not release by elapsed time")
      }
    @moonsim.FixedBatch(_) =>
      if result.quantity_releases == 0 || result.timeout_releases != 0 {
        fail("fixed-batch policy did not release by its quantity threshold")
      }
    @moonsim.Hybrid(_, _) =>
      if result.quantity_releases == 0 || result.timeout_releases == 0 {
        fail("hybrid policy did not exercise both trigger conditions")
      }
  }
  result
}

///|
fn triggered_by_quantity(
  policy : @moonsim.BatchPolicy,
  waiting_count : Int,
) -> Bool {
  match policy {
    @moonsim.FixedTime(_) => false
    @moonsim.FixedBatch(_) => true
    @moonsim.Hybrid(batch_size, _) => waiting_count >= batch_size
  }
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
