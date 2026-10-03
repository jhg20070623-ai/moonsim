///|
/// Mean and observed bounds for one result metric across independent runs.
pub struct MetricSummary {
  mean : Double
  min : Double
  max : Double
} derive(ToJson)

///|
pub extend MetricSummary with ToJson::{to_json}

///|
/// Aggregate metrics from repeated, independently initialized scenario runs.
pub struct ExperimentSummary {
  base_seed : Int
  run_count : Int
  completed : MetricSummary
  cycle_time : MetricSummary
  waiting_time : MetricSummary
  throughput : MetricSummary
  mean_wip : MetricSummary
} derive(ToJson)

///|
pub extend ExperimentSummary with ToJson::{to_json}

///|
/// Configures a deterministic sequence of independent replications.
pub struct ExperimentRunner {
  base_seed : Int
  run_count : Int
}

///|
/// Creates a runner for seeds base_seed through base_seed + run_count - 1.
pub fn ExperimentRunner::new(
  base_seed : Int,
  run_count : Int,
) -> Result[ExperimentRunner, String] {
  if base_seed < 0 {
    Err("base_seed must be non-negative")
  } else if run_count <= 0 {
    Err("run_count must be positive")
  } else if run_count - 1 > MAX_INT_VALUE - base_seed {
    Err("replication seed range exceeds the supported integer range")
  } else {
    Ok({ base_seed, run_count, })
  }
}

///|
/// Runs every replication using a fresh simulation state.
pub fn ExperimentRunner::run(
  self : ExperimentRunner,
  config : ScenarioConfig,
) -> Result[ExperimentSummary, String] {
  let mut cycle_time_total = 0.0
  let mut cycle_time_min = 0.0
  let mut cycle_time_max = 0.0
  let mut waiting_time_total = 0.0
  let mut waiting_time_min = 0.0
  let mut waiting_time_max = 0.0
  let mut throughput_total = 0.0
  let mut throughput_min = 0.0
  let mut throughput_max = 0.0
  let mut wip_total = 0.0
  let mut wip_min = 0.0
  let mut wip_max = 0.0
  let mut completed_total = 0.0
  let mut completed_min = 0.0
  let mut completed_max = 0.0

  let mut index = 0
  while index < self.run_count {
    let seed = self.base_seed + index
    let result = match run_scenario(config.with_seed(seed)) {
      Err(message) => return Err(message)
      Ok(value) => value
    }
    if index == 0 {
      completed_min = result.completed.to_double()
      completed_max = result.completed.to_double()
      cycle_time_min = result.cycle_time
      cycle_time_max = result.cycle_time
      waiting_time_min = result.waiting_time
      waiting_time_max = result.waiting_time
      throughput_min = result.throughput
      throughput_max = result.throughput
      wip_min = result.average_wip
      wip_max = result.average_wip
    } else {
      if result.completed.to_double() < completed_min {
        completed_min = result.completed.to_double()
      }
      if result.completed.to_double() > completed_max {
        completed_max = result.completed.to_double()
      }
      if result.cycle_time < cycle_time_min {
        cycle_time_min = result.cycle_time
      }
      if result.cycle_time > cycle_time_max {
        cycle_time_max = result.cycle_time
      }
      if result.waiting_time < waiting_time_min {
        waiting_time_min = result.waiting_time
      }
      if result.waiting_time > waiting_time_max {
        waiting_time_max = result.waiting_time
      }
      if result.throughput < throughput_min {
        throughput_min = result.throughput
      }
      if result.throughput > throughput_max {
        throughput_max = result.throughput
      }
      if result.average_wip < wip_min {
        wip_min = result.average_wip
      }
      if result.average_wip > wip_max {
        wip_max = result.average_wip
      }
    }
    completed_total += result.completed.to_double()
    cycle_time_total += result.cycle_time
    waiting_time_total += result.waiting_time
    throughput_total += result.throughput
    wip_total += result.average_wip
    index += 1
  }

  let divisor = self.run_count.to_double()
  Ok(ExperimentSummary::{
    base_seed: self.base_seed,
    run_count: self.run_count,
    completed: MetricSummary::{
      mean: completed_total / divisor,
      min: completed_min,
      max: completed_max,
    },
    cycle_time: MetricSummary::{
      mean: cycle_time_total / divisor,
      min: cycle_time_min,
      max: cycle_time_max,
    },
    waiting_time: MetricSummary::{
      mean: waiting_time_total / divisor,
      min: waiting_time_min,
      max: waiting_time_max,
    },
    throughput: MetricSummary::{
      mean: throughput_total / divisor,
      min: throughput_min,
      max: throughput_max,
    },
    mean_wip: MetricSummary::{
      mean: wip_total / divisor,
      min: wip_min,
      max: wip_max,
    },
  })
}

///|
fn ScenarioConfig::with_seed(
  self : ScenarioConfig,
  seed : Int,
) -> ScenarioConfig {
  match self {
    BasicQueue(parameters, _) => BasicQueue(parameters, seed)
    ManufacturingLine(parameters, _) => ManufacturingLine(parameters, seed)
    LogisticsBatching(parameters, _) => LogisticsBatching(parameters, seed)
  }
}
