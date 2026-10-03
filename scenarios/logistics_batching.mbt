///|
priv struct BatchState {
  policy : @sim.BatchPolicy
  queue : @sim.Queue[@sim.Entity]
  metrics : @sim.Metrics
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
fn run_logistics_batching(
  parameters : LogisticsParameters,
  seed : Int,
) -> Result[SimulationResult, String] {
  let sim = match @sim.Simulation::with_seed(seed) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let policy = match parameters.policy_type {
    "fixed_time" =>
      @sim.BatchPolicy::fixed_time(parameters.fixed_time_threshold)
    "fixed_batch" =>
      @sim.BatchPolicy::fixed_batch(parameters.fixed_batch_threshold)
    "hybrid" =>
      @sim.BatchPolicy::hybrid(
        parameters.hybrid_batch_threshold,
        parameters.hybrid_timeout,
      )
    _ => Err("policy_type must be fixed_time, fixed_batch, or hybrid")
  }
  let policy = match policy {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let metrics = match @sim.Metrics::new(0) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let state = BatchState::{
    policy,
    queue: @sim.Queue::new(),
    metrics,
    batch_started_at: 0,
    batch_open: false,
    generation: 0,
    batch_count: 0,
    quantity_releases: 0,
    timeout_releases: 0,
    forced_partial_batches: 0,
    overdue_entities: 0,
  }
  let overdue_threshold = if parameters.policy_type == "fixed_time" {
    parameters.fixed_time_threshold
  } else {
    parameters.hybrid_timeout
  }

  let mut entity_id = 0
  while entity_id < parameters.entity_count {
    let id = entity_id
    let arrival_time = parameters.arrival_times[entity_id]
    let is_last_arrival = entity_id == parameters.entity_count - 1
    match
      sim.schedule(arrival_time, 0, fn() {
        let entity = @sim.Entity::new(id, arrival_time).unwrap()
        state.metrics.record_entity_created(entity).unwrap() |> ignore
        let starts_batch = state.queue.length() == 0
        state.queue.enqueue(entity, sim.now()).unwrap() |> ignore
        record_batch_queue_length(state, sim.now())
        if starts_batch {
          state.batch_open = true
          state.batch_started_at = sim.now()
          state.generation += 1
          schedule_batch_timeout(
            sim,
            state,
            state.generation,
            timeout_for(policy),
            parameters.delivery_delay,
            overdue_threshold,
          )
        }
        let oldest_wait = sim.now() - state.batch_started_at
        if state.policy
          .should_trigger(state.queue.length(), oldest_wait)
          .unwrap() {
          if triggered_by_quantity(state.policy, state.queue.length()) {
            state.quantity_releases += 1
          } else {
            state.timeout_releases += 1
          }
          release_batch(
            sim,
            state,
            sim.now(),
            parameters.delivery_delay,
            overdue_threshold,
          )
        }
        if is_last_arrival {
          let flush_at = sim.now() + parameters.hybrid_timeout
          sim.schedule(flush_at, 0, fn() {
            if state.queue.length() > 0 {
              state.forced_partial_batches += 1
              release_batch(
                sim,
                state,
                sim.now(),
                parameters.delivery_delay,
                overdue_threshold,
              )
            }
          })
          |> ignore
        }
      }) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    entity_id += 1
  }

  let events_processed = sim.run()
  let now = sim.now()
  if state.metrics.entity_completed_count() != parameters.entity_count {
    return Err("batch policy did not complete all entities")
  }
  if state.metrics.wip() != 0 || state.queue.length() != 0 {
    return Err("batch policy ended with WIP or queued entities")
  }
  let throughput = match state.metrics.throughput(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let average_queue_length = match state.metrics.average_queue_length(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let average_wip = match state.metrics.average_wip(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let statistics = BatchStatistics::{
    batch_count: state.batch_count,
    quantity_releases: state.quantity_releases,
    timeout_releases: state.timeout_releases,
    forced_partial_batches: state.forced_partial_batches,
    overdue_entities: state.overdue_entities,
  }
  if statistics.batch_count < 0 ||
    statistics.overdue_entities < 0 ||
    statistics.overdue_entities > state.metrics.entity_completed_count() ||
    statistics.forced_partial_batches > statistics.batch_count {
    return Err("batch metrics violated their count invariants")
  }
  Ok(SimulationResult::{
    scenario: "logistics_batching",
    seed,
    parameters: @json.to_json(parameters),
    completed: state.metrics.entity_completed_count(),
    cycle_time: state.metrics.mean_cycle_time(),
    waiting_time: state.metrics.mean_waiting_time(),
    wip: state.metrics.wip(),
    throughput,
    queue_length: state.queue.length(),
    average_queue_length,
    max_queue_length: state.metrics.max_queue_length(),
    average_wip,
    simulation_time: now,
    events_processed,
    resource_utilization: [],
    batch_statistics: Some(statistics),
  })
}

///|
fn triggered_by_quantity(
  policy : @sim.BatchPolicy,
  waiting_count : Int,
) -> Bool {
  match policy {
    @sim.FixedTime(_) => false
    @sim.FixedBatch(_) => true
    @sim.Hybrid(batch_size, _) => waiting_count >= batch_size
  }
}

///|
fn timeout_for(policy : @sim.BatchPolicy) -> Int? {
  match policy {
    @sim.FixedTime(interval) => Some(interval)
    @sim.FixedBatch(_) => None
    @sim.Hybrid(_, max_wait) => Some(max_wait)
  }
}

///|
fn record_batch_queue_length(state : BatchState, now : Int) -> Unit {
  state.metrics.record_queue_length(state.queue.length(), now).unwrap()
  |> ignore
}

///|
fn schedule_batch_timeout(
  sim : @sim.Simulation,
  state : BatchState,
  generation : Int,
  timeout : Int?,
  delivery_delay : Int,
  overdue_threshold : Int,
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
            release_batch(
              sim,
              state,
              sim.now(),
              delivery_delay,
              overdue_threshold,
            )
          }
        }
      })
      |> ignore
  }
}

///|
fn release_batch(
  sim : @sim.Simulation,
  state : BatchState,
  released_at : Int,
  delivery_delay : Int,
  overdue_threshold : Int,
) -> Unit {
  state.batch_count += 1
  state.batch_open = false
  while state.queue.length() > 0 {
    match state.queue.dequeue_with_wait(released_at).unwrap() {
      None => ()
      Some((entity, waiting_time)) => {
        if waiting_time > overdue_threshold {
          state.overdue_entities += 1
        }
        state.metrics.record_waiting_time(waiting_time, released_at).unwrap()
        |> ignore
        record_batch_queue_length(state, released_at)
        sim.schedule(released_at + delivery_delay, 0, fn() {
          state.metrics.record_entity_completed(entity, sim.now()).unwrap()
          |> ignore
        })
        |> ignore
      }
    }
  }
}
