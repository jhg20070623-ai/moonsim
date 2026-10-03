///|
struct Workstation {
  name : String
  resource : @moonsim.Resource
  queue : @moonsim.Queue[@moonsim.Entity]
  processing_time : Int
  mut peak_usage : Int
}

///|
struct StationSummary {
  name : String
  utilization : Double
  used : Int
  capacity : Int
  peak_usage : Int
}

///|
struct ManufacturingSummary {
  completed_count : Int
  final_wip : Int
  final_queue_length : Int
  mean_cycle_time : Double
  mean_station_queue_wait : Double
  average_wip : Double
  throughput : Double
  simulation_time : Int
  events_processed : Int
  stations : Array[StationSummary]
}

///|
fn main raise {
  let result = simulate_manufacturing(20, 6)
  println("Entities completed: \{result.completed_count}")
  println("Events processed: \{result.events_processed}")
  println("Simulation time: \{result.simulation_time} ticks")
  println("Mean cycle time: \{result.mean_cycle_time} ticks")
  println("Mean station queue wait: \{result.mean_station_queue_wait} ticks")
  println("Average WIP: \{result.average_wip}")
  println("Throughput: \{result.throughput} entities/tick")
  for station in result.stations {
    println("\{station.name} utilization: \{station.utilization}")
  }
}

///|
fn simulate_manufacturing(
  entity_count : Int,
  arrival_interval : Int,
) -> ManufacturingSummary raise {
  let sim = @moonsim.Simulation::new()
  let station_names = [
    "cutting", "drilling", "welding", "painting", "assembly", "inspection", "packaging",
  ]
  let route = @moonsim.Route::new(station_names).unwrap()
  let processing_times = [12, 8, 6, 10, 5, 4, 9]
  let stations : Array[Workstation] = Array(capacity=processing_times.length())
  let mut index = 0
  while index < processing_times.length() {
    stations.push(Workstation::{
      name: station_names[index],
      resource: @moonsim.Resource::new(station_names[index], 1).unwrap(),
      queue: @moonsim.Queue::new(),
      processing_time: processing_times[index],
      peak_usage: 0,
    })
    index += 1
  }

  let metrics = @moonsim.Metrics::new(0).unwrap()
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
  let station_summaries : Array[StationSummary] = Array(
    capacity=stations.length(),
  )
  index = 0
  while index < stations.length() {
    let station = stations[index]
    station_summaries.push(StationSummary::{
      name: station.name,
      utilization: station.resource.utilization_at(now).unwrap(),
      used: station.resource.used(),
      capacity: station.resource.capacity(),
      peak_usage: station.peak_usage,
    })
    index += 1
  }
  let final_queue_length = total_queue_length(stations)
  if final_queue_length != 0 {
    fail("manufacturing line ended with queued entities")
  }
  for station in station_summaries {
    if station.used > station.capacity || station.peak_usage > station.capacity {
      fail("manufacturing station exceeded resource capacity")
    }
  }

  let result = ManufacturingSummary::{
    completed_count: metrics.entity_completed_count(),
    final_wip: metrics.wip(),
    final_queue_length,
    mean_cycle_time: metrics.mean_cycle_time(),
    mean_station_queue_wait: metrics.mean_waiting_time(),
    average_wip: metrics.average_wip(now).unwrap(),
    throughput: metrics.throughput(now).unwrap(),
    simulation_time: now,
    events_processed: processed_events,
    stations: station_summaries,
  }
  if result.final_wip != 0 || result.final_queue_length != 0 {
    fail("manufacturing line ended with WIP or a queued entity")
  }
  result
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
  metrics : @moonsim.Metrics,
  now : Int,
) -> Unit {
  let mut total = 0
  for station in stations {
    total += station.queue.length()
  }
  metrics.record_queue_length(total, now).unwrap() |> ignore
}

///|
fn total_queue_length(stations : Array[Workstation]) -> Int {
  let mut total = 0
  for station in stations {
    total += station.queue.length()
  }
  total
}
