///|
priv struct Workstation {
  name : String
  resource : @sim.Resource
  queue : @sim.Queue[@sim.Entity]
  processing_time : Int
  mut peak_usage : Int
}

///|
fn run_manufacturing_line(
  parameters : ManufacturingParameters,
  seed : Int,
) -> Result[SimulationResult, String] {
  let sim = match @sim.Simulation::with_seed(seed) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let station_names = [
    "cutting", "drilling", "welding", "painting", "assembly", "inspection", "packaging",
  ]
  let route = match @sim.Route::new(station_names) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let stations : Array[Workstation] = Array(capacity=7)
  let mut index = 0
  while index < 7 {
    let resource = match
      @sim.Resource::new(
        station_names[index],
        parameters.station_capacities[index],
      ) {
      Err(message) => return Err(message)
      Ok(value) => value
    }
    stations.push(Workstation::{
      name: station_names[index],
      resource,
      queue: @sim.Queue::new(),
      processing_time: parameters.processing_times[index],
      peak_usage: 0,
    })
    index += 1
  }
  let metrics = match @sim.Metrics::new(0) {
    Err(message) => return Err(message)
    Ok(value) => value
  }

  let mut entity_id = 0
  while entity_id < parameters.entity_count {
    let id = entity_id
    let arrival_time = entity_id * parameters.arrival_interval
    match
      sim.schedule(arrival_time, 0, fn() {
        let entity = @sim.Entity::new(id, arrival_time).unwrap()
        metrics.record_entity_created(entity).unwrap() |> ignore
        entity.advance_route(route) |> ignore
        submit_to_station(sim, entity, 0, stations, route, metrics)
      }) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    entity_id += 1
  }

  let events_processed = sim.run()
  let now = sim.now()
  let queue_length = total_queue_length(stations)
  if metrics.entity_completed_count() != parameters.entity_count {
    return Err("manufacturing line did not complete all entities")
  }
  if metrics.wip() != 0 || queue_length != 0 {
    return Err("manufacturing line ended with WIP or queued entities")
  }

  let resource_utilization : Array[ResourceSummary] = Array(capacity=7)
  index = 0
  while index < stations.length() {
    let station = stations[index]
    if station.resource.used() > station.resource.capacity() ||
      station.peak_usage > station.resource.capacity() {
      return Err("manufacturing station exceeded its resource capacity")
    }
    let utilization = match station.resource.utilization_at(now) {
      Err(message) => return Err(message)
      Ok(value) => value
    }
    resource_utilization.push(ResourceSummary::{
      name: station.name,
      utilization,
      capacity: station.resource.capacity(),
      peak_usage: station.peak_usage,
    })
    index += 1
  }
  let throughput = match metrics.throughput(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let average_queue_length = match metrics.average_queue_length(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  let average_wip = match metrics.average_wip(now) {
    Err(message) => return Err(message)
    Ok(value) => value
  }
  Ok(SimulationResult::{
    scenario: "manufacturing_line",
    seed,
    parameters: @json.to_json(parameters),
    completed: metrics.entity_completed_count(),
    cycle_time: metrics.mean_cycle_time(),
    waiting_time: metrics.mean_waiting_time(),
    wip: metrics.wip(),
    throughput,
    queue_length,
    average_queue_length,
    max_queue_length: metrics.max_queue_length(),
    average_wip,
    simulation_time: now,
    events_processed,
    resource_utilization,
    batch_statistics: None,
  })
}

///|
fn submit_to_station(
  sim : @sim.Simulation,
  entity : @sim.Entity,
  station_index : Int,
  stations : Array[Workstation],
  route : @sim.Route,
  metrics : @sim.Metrics,
) -> Unit {
  let station = stations[station_index]
  let now = sim.now()
  station.queue.enqueue(entity, now).unwrap() |> ignore
  record_total_queue_length(stations, metrics, now)
  try_start_station(sim, station_index, stations, route, metrics)
}

///|
fn try_start_station(
  sim : @sim.Simulation,
  station_index : Int,
  stations : Array[Workstation],
  route : @sim.Route,
  metrics : @sim.Metrics,
) -> Unit {
  let station = stations[station_index]
  let now = sim.now()
  if station.resource.acquire(now).unwrap() {
    if station.resource.used() > station.peak_usage {
      station.peak_usage = station.resource.used()
    }
    match station.queue.dequeue_with_wait(now).unwrap() {
      None => station.resource.release(now) |> ignore
      Some((entity, waiting_time)) => {
        metrics.record_waiting_time(waiting_time, now).unwrap() |> ignore
        record_total_queue_length(stations, metrics, now)
        sim.schedule(now + station.processing_time, 0, fn() {
          let completed_at = sim.now()
          station.resource.release(completed_at).unwrap() |> ignore
          match entity.advance_route(route) {
            None =>
              metrics.record_entity_completed(entity, completed_at) |> ignore
            Some(_) =>
              submit_to_station(
                sim,
                entity,
                station_index + 1,
                stations,
                route,
                metrics,
              )
          }
          try_start_station(sim, station_index, stations, route, metrics)
        })
        |> ignore
      }
    }
  }
}

///|
fn record_total_queue_length(
  stations : Array[Workstation],
  metrics : @sim.Metrics,
  now : Int,
) -> Unit {
  metrics.record_queue_length(total_queue_length(stations), now).unwrap()
  |> ignore
}

///|
fn total_queue_length(stations : Array[Workstation]) -> Int {
  let mut total = 0
  for station in stations {
    total += station.queue.length()
  }
  total
}
