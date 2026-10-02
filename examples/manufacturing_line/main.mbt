///|
struct Workstation {
  name : String
  resource : @moonsim.Resource
  queue : @moonsim.Queue[@moonsim.Entity]
  processing_time : Int
}

///|
fn main raise {
  let sim = @moonsim.Simulation::new()
  let route = @moonsim.Route::new([
    "cutting", "drilling", "welding", "painting", "assembly", "inspection", "packaging",
  ]).unwrap()
  let processing_times = [12, 8, 6, 10, 5, 4, 9]
  let station_names = [
    "cutting", "drilling", "welding", "painting", "assembly", "inspection", "packaging",
  ]
  let stations : Array[Workstation] = Array(capacity=processing_times.length())
  let mut index = 0
  while index < processing_times.length() {
    stations.push(Workstation::{
      name: station_names[index],
      resource: @moonsim.Resource::new(station_names[index], 1).unwrap(),
      queue: @moonsim.Queue::new(),
      processing_time: processing_times[index],
    })
    index += 1
  }

  let metrics = @moonsim.Metrics::new(0).unwrap()
  let entity_count = 20
  let arrival_interval = 6
  let mut entity_id = 0
  while entity_id < entity_count {
    let id = entity_id
    let arrival_time = entity_id * arrival_interval
    sim.schedule(arrival_time, 0, fn() {
      let entity = @moonsim.Entity::new(id, arrival_time).unwrap()
      metrics.record_entity_created(entity).unwrap() |> ignore
      entity.advance_route(route) |> ignore
      submit_to_station(sim, entity, 0, stations, route, metrics)
    })
    |> ignore
    entity_id += 1
  }

  let processed_events = sim.run()
  if metrics.entity_completed_count() != entity_count || metrics.wip() != 0 {
    fail("manufacturing line did not complete all entities and drain WIP")
  }
  let now = sim.now()
  let mut total_station_wait = 0
  let mut total_station_dequeues = 0
  index = 0
  while index < stations.length() {
    let station = stations[index]
    total_station_wait += station.queue.total_waiting_time()
    total_station_dequeues += station.queue.dequeued_count()
    index += 1
  }
  let mean_station_wait = if total_station_dequeues == 0 {
    0.0
  } else {
    total_station_wait.to_double() / total_station_dequeues.to_double()
  }

  println("Entities completed: \{metrics.entity_completed_count()}")
  println("Events processed: \{processed_events}")
  println("Simulation time: \{now} ticks")
  println("Mean cycle time: \{metrics.mean_cycle_time()} ticks")
  println("Mean station queue wait: \{mean_station_wait} ticks")
  println("Average WIP: \{metrics.average_wip(now).unwrap()}")
  println("Throughput: \{metrics.throughput(now).unwrap()} entities/tick")
  index = 0
  while index < stations.length() {
    let station = stations[index]
    println(
      "\{station.name} utilization: \{station.resource.utilization_at(now).unwrap()}",
    )
    index += 1
  }
}

///|
fn submit_to_station(
  sim : @moonsim.Simulation,
  entity : @moonsim.Entity,
  station_index : Int,
  stations : Array[Workstation],
  route : @moonsim.Route,
  metrics : @moonsim.Metrics,
) -> Unit {
  let station = stations[station_index]
  let now = sim.now()
  station.queue.enqueue(entity, now).unwrap() |> ignore
  record_total_queue_length(stations, metrics, now)
  try_start_station(sim, station_index, stations, route, metrics)
}

///|
fn try_start_station(
  sim : @moonsim.Simulation,
  station_index : Int,
  stations : Array[Workstation],
  route : @moonsim.Route,
  metrics : @moonsim.Metrics,
) -> Unit {
  let station = stations[station_index]
  let now = sim.now()
  if station.resource.acquire(now).unwrap() {
    match station.queue.dequeue(now).unwrap() {
      None => station.resource.release(now) |> ignore
      Some(entity) => {
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
  metrics : @moonsim.Metrics,
  now : Int,
) -> Unit {
  let mut total = 0
  for station in stations {
    total += station.queue.length()
  }
  metrics.record_queue_length(total, now).unwrap() |> ignore
}
