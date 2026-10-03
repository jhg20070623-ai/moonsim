///|
priv struct BasicQueueState {
  sim : @sim.Simulation
  resource : @sim.Resource
  queue : @sim.Queue[@sim.Entity]
  metrics : @sim.Metrics
  service_time : Int
  mut peak_usage : Int
}

///|
fn run_basic_queue(
  parameters : BasicQueueParameters,
  seed : Int,
) -> Result[SimulationResult, String] {
  let sim = match @sim.Simulation::with_seed(seed) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let resource = match
    @sim.Resource::new("machine", parameters.resource_capacity) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let state = BasicQueueState::{
    sim,
    resource,
    queue: @sim.Queue::new(),
    metrics: @sim.Metrics::new(0).unwrap(),
    service_time: parameters.service_time,
    peak_usage: 0,
  }

  let mut entity_id = 0
  while entity_id < parameters.entity_count {
    let id = entity_id
    let arrival_time = if parameters.arrival_times.length() > 0 {
      parameters.arrival_times[entity_id]
    } else {
      entity_id * parameters.arrival_interval
    }
    match
      state.sim.schedule(arrival_time, 0, fn() {
        let entity = @sim.Entity::new(id, arrival_time).unwrap()
        state.metrics.record_entity_created(entity).unwrap() |> ignore
        let now = state.sim.now()
        if state.queue.length() > 0 {
          state.queue.enqueue(entity, now).unwrap() |> ignore
          record_basic_queue_length(state, now)
          start_waiting_basic_queue_items(state)
        } else if state.resource.acquire(now).unwrap() {
          record_basic_waiting_time(state, 0, now)
          if state.resource.used() > state.peak_usage {
            state.peak_usage = state.resource.used()
          }
          start_basic_queue_service(state, entity)
        } else {
          state.queue.enqueue(entity, now).unwrap() |> ignore
          record_basic_queue_length(state, now)
        }
      }) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    entity_id += 1
  }

  let events_processed = state.sim.run()
  let now = state.sim.now()
  let utilization = match state.resource.utilization_at(now) {
    Err(message) => return Err(message)
    Ok(value) => value
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
  Ok(SimulationResult::{
    scenario: "basic_queue",
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
    resource_utilization: [
      ResourceSummary::{
        name: state.resource.name(),
        utilization,
        capacity: state.resource.capacity(),
        peak_usage: state.peak_usage,
      },
    ],
    batch_statistics: None,
  })
}

///|
fn start_waiting_basic_queue_items(state : BasicQueueState) -> Unit {
  let mut continue_starting = true
  while continue_starting && state.queue.length() > 0 {
    match state.resource.acquire(state.sim.now()) {
      Err(_) => continue_starting = false
      Ok(false) => continue_starting = false
      Ok(true) =>
        match state.queue.dequeue_with_wait(state.sim.now()) {
          Err(_) => {
            state.resource.release(state.sim.now()) |> ignore
            continue_starting = false
          }
          Ok(None) => {
            state.resource.release(state.sim.now()) |> ignore
            continue_starting = false
          }
          Ok(Some((entity, waiting_time))) => {
            record_basic_waiting_time(state, waiting_time, state.sim.now())
            record_basic_queue_length(state, state.sim.now())
            if state.resource.used() > state.peak_usage {
              state.peak_usage = state.resource.used()
            }
            start_basic_queue_service(state, entity)
          }
        }
    }
  }
}

///|
fn record_basic_waiting_time(
  state : BasicQueueState,
  waiting_time : Int,
  now : Int,
) -> Unit {
  state.metrics.record_waiting_time(waiting_time, now).unwrap() |> ignore
}

///|
fn record_basic_queue_length(state : BasicQueueState, now : Int) -> Unit {
  state.metrics.record_queue_length(state.queue.length(), now).unwrap()
  |> ignore
}

///|
fn start_basic_queue_service(
  state : BasicQueueState,
  entity : @sim.Entity,
) -> Unit {
  let completion_time = state.sim.now() + state.service_time
  state.sim.schedule(completion_time, 0, fn() {
    let now = state.sim.now()
    state.resource.release(now).unwrap() |> ignore
    state.metrics.record_entity_completed(entity, now).unwrap() |> ignore
    start_waiting_basic_queue_items(state)
  })
  |> ignore
}
