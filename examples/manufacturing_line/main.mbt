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
  println(
    "Final WIP / queue: \{result.final_wip} / \{result.final_queue_length}",
  )
  for station in result.stations {
    if station.used > station.capacity || station.peak_usage > station.capacity {
      fail("station resource capacity invariant failed")
    }
    println(
      "\{station.name} utilization: \{station.utilization} (peak \{station.peak_usage}/\{station.capacity})",
    )
  }
}

///|
fn simulate_manufacturing(
  entity_count : Int,
  arrival_interval : Int,
) -> ManufacturingSummary raise {
  let config = @scenarios.ScenarioConfig::manufacturing_line(
    @scenarios.ManufacturingParameters::new(
      entity_count,
      arrival_interval,
      [12, 8, 6, 10, 5, 4, 9],
      [1, 1, 1, 1, 1, 1, 1],
    ),
    42,
  )
  let result = match @scenarios.run_scenario(config) {
    Err(message) => fail("manufacturing line failed: \{message}")
    Ok(value) => value
  }
  let stations : Array[StationSummary] = Array(
    capacity=result.resource_utilization.length(),
  )
  for resource in result.resource_utilization {
    stations.push(StationSummary::{
      name: resource.name,
      utilization: resource.utilization,
      used: 0,
      capacity: resource.capacity,
      peak_usage: resource.peak_usage,
    })
  }
  ManufacturingSummary::{
    completed_count: result.completed,
    final_wip: result.wip,
    final_queue_length: result.queue_length,
    mean_cycle_time: result.cycle_time,
    mean_station_queue_wait: result.waiting_time,
    average_wip: result.average_wip,
    throughput: result.throughput,
    simulation_time: result.simulation_time,
    events_processed: result.events_processed,
    stations,
  }
}
