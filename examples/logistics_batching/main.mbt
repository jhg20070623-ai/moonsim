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
  run_policy("FixedTime(5)", @moonsim.BatchPolicy::fixed_time(5).unwrap())
  run_policy("FixedBatch(3)", @moonsim.BatchPolicy::fixed_batch(3).unwrap())
  run_policy("Hybrid(3, 5)", @moonsim.BatchPolicy::hybrid(3, 5).unwrap())
}

///|
fn run_policy(label : String, policy : @moonsim.BatchPolicy) -> Unit raise {
  let result = simulate_policy(policy)
  println("Policy: \{label}")
  println("  Entities completed: \{result.completed_count}")
  println(
    "  Final WIP / queue: \{result.final_wip} / \{result.final_queue_length}",
  )
  println("  Batches released: \{result.batch_count}")
  println("  Mean waiting time: \{result.mean_waiting_time} ticks")
  println("  Throughput: \{result.throughput} entities/tick")
  println("  Timeout releases: \{result.timeout_releases}")
  println("  Quantity releases: \{result.quantity_releases}")
  println("  Overdue entities: \{result.overdue_entities}")
  println("  End-of-intake partial batches: \{result.forced_partial_batches}")
  println("  Events processed: \{result.events_processed}")
  println("  Simulation time: \{result.simulation_time} ticks")
}

///|
fn simulate_policy(policy : @moonsim.BatchPolicy) -> BatchSummary raise {
  let policy_type = match policy {
    @moonsim.FixedTime(_) => "fixed_time"
    @moonsim.FixedBatch(_) => "fixed_batch"
    @moonsim.Hybrid(_, _) => "hybrid"
  }
  let fixed_time_threshold = match policy {
    @moonsim.FixedTime(interval) => interval
    _ => 1
  }
  let fixed_batch_threshold = match policy {
    @moonsim.FixedBatch(batch_size) => batch_size
    _ => 1
  }
  let hybrid_batch_threshold = match policy {
    @moonsim.Hybrid(batch_size, _) => batch_size
    _ => 1
  }
  let hybrid_timeout = match policy {
    @moonsim.Hybrid(_, timeout) => timeout
    _ => 1
  }
  let config = @scenarios.ScenarioConfig::logistics_batching(
    @scenarios.LogisticsParameters::new(
      17,
      [0, 1, 2, 3, 4, 12, 13, 14, 15, 16, 24, 25, 26, 27, 28, 35, 36],
      2,
      policy_type,
      fixed_time_threshold,
      fixed_batch_threshold,
      hybrid_batch_threshold,
      hybrid_timeout,
    ),
    42,
  )
  let result = match @scenarios.run_scenario(config) {
    Err(message) => fail("logistics batching failed: \{message}")
    Ok(value) => value
  }
  let statistics = match result.batch_statistics {
    None => fail("logistics batching result has no batch statistics")
    Some(value) => value
  }
  BatchSummary::{
    completed_count: result.completed,
    final_wip: result.wip,
    final_queue_length: result.queue_length,
    batch_count: statistics.batch_count,
    mean_waiting_time: result.waiting_time,
    throughput: result.throughput,
    quantity_releases: statistics.quantity_releases,
    timeout_releases: statistics.timeout_releases,
    forced_partial_batches: statistics.forced_partial_batches,
    overdue_entities: statistics.overdue_entities,
    events_processed: result.events_processed,
    simulation_time: result.simulation_time,
  }
}
