///|
fn main raise {
  let result = match
    @scenarios.run_scenario(@scenarios.ScenarioConfig::basic_queue_preset()) {
    Err(message) => fail("basic_queue scenario failed: \{message}")
    Ok(value) => value
  }
  println("Events processed: \{result.events_processed}")
  println("Completed entities: \{result.completed}")
  println("Simulation time: \{result.simulation_time} ticks")
  println("Mean cycle time: \{result.cycle_time} ticks")
  println("Mean queue wait: \{result.waiting_time} ticks")
  println("Throughput: \{result.throughput} entities/tick")
  for resource in result.resource_utilization {
    println("Machine utilization: \{resource.utilization}")
  }
}
