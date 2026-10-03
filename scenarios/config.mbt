///|
/// Parameters for the single-resource FIFO queue scenario.
pub struct BasicQueueParameters {
  entity_count : Int
  arrival_interval : Int
  arrival_times : Array[Int]
  service_time : Int
  resource_capacity : Int
} derive(FromJson, ToJson)

///|
/// Parameters for the seven-station manufacturing preset and variants.
pub struct ManufacturingParameters {
  entity_count : Int
  arrival_interval : Int
  processing_times : Array[Int]
  station_capacities : Array[Int]
} derive(FromJson, ToJson)

///|
/// Parameters for comparing logistics batch release policies.
pub struct LogisticsParameters {
  entity_count : Int
  arrival_times : Array[Int]
  delivery_delay : Int
  policy_type : String
  fixed_time_threshold : Int
  fixed_batch_threshold : Int
  hybrid_batch_threshold : Int
  hybrid_timeout : Int
} derive(FromJson, ToJson)

///|
pub extend BasicQueueParameters with @json.FromJson::{from_json}

///|
pub extend BasicQueueParameters with ToJson::{to_json}

///|
pub fn BasicQueueParameters::new(
  entity_count : Int,
  arrival_interval : Int,
  arrival_times : Array[Int],
  service_time : Int,
  resource_capacity : Int,
) -> BasicQueueParameters {
  {
    entity_count,
    arrival_interval,
    arrival_times,
    service_time,
    resource_capacity,
  }
}

///|
pub extend ManufacturingParameters with @json.FromJson::{from_json}

///|
pub extend ManufacturingParameters with ToJson::{to_json}

///|
pub fn ManufacturingParameters::new(
  entity_count : Int,
  arrival_interval : Int,
  processing_times : Array[Int],
  station_capacities : Array[Int],
) -> ManufacturingParameters {
  { entity_count, arrival_interval, processing_times, station_capacities, }
}

///|
pub extend LogisticsParameters with @json.FromJson::{from_json}

///|
pub extend LogisticsParameters with ToJson::{to_json}

///|
pub fn LogisticsParameters::new(
  entity_count : Int,
  arrival_times : Array[Int],
  delivery_delay : Int,
  policy_type : String,
  fixed_time_threshold : Int,
  fixed_batch_threshold : Int,
  hybrid_batch_threshold : Int,
  hybrid_timeout : Int,
) -> LogisticsParameters {
  {
    entity_count,
    arrival_times,
    delivery_delay,
    policy_type,
    fixed_time_threshold,
    fixed_batch_threshold,
    hybrid_batch_threshold,
    hybrid_timeout,
  }
}

///|
/// A validated-at-run-time model request. Construction is cheap; `run_scenario`
/// checks every field before scheduling any events.
pub enum ScenarioConfig {
  BasicQueue(BasicQueueParameters, Int)
  ManufacturingLine(ManufacturingParameters, Int)
  LogisticsBatching(LogisticsParameters, Int)
}

///|
/// Resource utilization observed at the end of a run.
pub struct ResourceSummary {
  name : String
  utilization : Double
  capacity : Int
  peak_usage : Int
} derive(ToJson)

///|
pub extend ResourceSummary with ToJson::{to_json}

///|
/// Policy-specific counters produced by a logistics batching run.
pub struct BatchStatistics {
  batch_count : Int
  quantity_releases : Int
  timeout_releases : Int
  forced_partial_batches : Int
  overdue_entities : Int
} derive(ToJson)

///|
pub extend BatchStatistics with ToJson::{to_json}

///|
/// Structured metrics from an actual MoonSim model execution.
pub struct SimulationResult {
  scenario : String
  seed : Int
  parameters : Json
  completed : Int
  cycle_time : Double
  waiting_time : Double
  wip : Int
  throughput : Double
  queue_length : Int
  average_queue_length : Double
  max_queue_length : Int
  average_wip : Double
  simulation_time : Int
  events_processed : Int
  resource_utilization : Array[ResourceSummary]
  batch_statistics : BatchStatistics?
} derive(ToJson)

///|
pub extend SimulationResult with ToJson::{to_json}

///|
/// Creates a basic queue configuration.
pub fn ScenarioConfig::basic_queue(
  parameters : BasicQueueParameters,
  seed : Int,
) -> ScenarioConfig {
  BasicQueue(parameters, seed)
}

///|
/// Creates a manufacturing line configuration.
pub fn ScenarioConfig::manufacturing_line(
  parameters : ManufacturingParameters,
  seed : Int,
) -> ScenarioConfig {
  ManufacturingLine(parameters, seed)
}

///|
/// Creates a logistics batching configuration.
pub fn ScenarioConfig::logistics_batching(
  parameters : LogisticsParameters,
  seed : Int,
) -> ScenarioConfig {
  LogisticsBatching(parameters, seed)
}

///|
/// Returns the standard five-entity FIFO queue preset.
pub fn ScenarioConfig::basic_queue_preset() -> ScenarioConfig {
  ScenarioConfig::basic_queue(
    BasicQueueParameters::{
      entity_count: 5,
      arrival_interval: 2,
      arrival_times: [0, 1, 3, 7, 8],
      service_time: 2,
      resource_capacity: 1,
    },
    42,
  )
}

///|
/// Returns the existing 20-entity, seven-station manufacturing preset.
pub fn ScenarioConfig::manufacturing_preset() -> ScenarioConfig {
  ScenarioConfig::manufacturing_line(
    ManufacturingParameters::{
      entity_count: 20,
      arrival_interval: 6,
      processing_times: [12, 8, 6, 10, 5, 4, 9],
      station_capacities: [1, 1, 1, 1, 1, 1, 1],
    },
    42,
  )
}

///|
/// Returns the existing 17-entity logistics preset for one of its policies.
pub fn ScenarioConfig::logistics_preset(policy_type : String) -> ScenarioConfig {
  ScenarioConfig::logistics_batching(
    LogisticsParameters::{
      entity_count: 17,
      arrival_times: [
        0, 1, 2, 3, 4, 12, 13, 14, 15, 16, 24, 25, 26, 27, 28, 35, 36,
      ],
      delivery_delay: 2,
      policy_type,
      fixed_time_threshold: 5,
      fixed_batch_threshold: 3,
      hybrid_batch_threshold: 3,
      hybrid_timeout: 5,
    },
    42,
  )
}

///|
const MAX_INT_VALUE : Int = 2147483647

///|
fn nonnegative_sum_fits(left : Int, right : Int) -> Bool {
  left >= 0 && right >= 0 && left <= MAX_INT_VALUE - right
}

///|
fn nonnegative_product_fits(left : Int, right : Int) -> Bool {
  left >= 0 && right >= 0 && (left == 0 || right <= MAX_INT_VALUE / left)
}

///|
fn validate_basic_queue(
  parameters : BasicQueueParameters,
  seed : Int,
) -> Result[Unit, String] {
  if parameters.entity_count < 0 {
    Err("entity_count must be non-negative")
  } else if parameters.arrival_interval < 0 {
    Err("arrival_interval must be non-negative")
  } else if parameters.service_time < 0 {
    Err("service_time must be non-negative")
  } else if parameters.resource_capacity < 1 {
    Err("resource_capacity must be at least 1")
  } else if parameters.arrival_times.length() != 0 &&
    parameters.arrival_times.length() != parameters.entity_count {
    Err("arrival_times must be empty or contain one time per entity")
  } else if seed < 0 {
    Err("seed must be non-negative")
  } else {
    let count = parameters.entity_count
    let explicit_arrivals = parameters.arrival_times.length() > 0
    let mut arrivals_valid = true
    let mut index = 0
    while index < parameters.arrival_times.length() {
      if parameters.arrival_times[index] < 0 ||
        (
          index > 0 &&
          parameters.arrival_times[index] < parameters.arrival_times[index - 1]
        ) {
        arrivals_valid = false
      }
      index += 1
    }
    let arrival_fits = if explicit_arrivals {
      arrivals_valid
    } else {
      count <= 1 ||
      nonnegative_product_fits(count - 1, parameters.arrival_interval)
    }
    let service_fits = nonnegative_product_fits(count, parameters.service_time)
    let last_arrival = if explicit_arrivals {
      parameters.arrival_times[count - 1]
    } else if count <= 1 {
      0
    } else {
      (count - 1) * parameters.arrival_interval
    }
    let total_service = count * parameters.service_time
    if !arrival_fits {
      Err("arrival_times must be non-negative and in non-decreasing order")
    } else if !service_fits ||
      !nonnegative_sum_fits(last_arrival, total_service) {
      Err("scenario time exceeds the supported integer tick range")
    } else {
      Ok(())
    }
  }
}

///|
fn validate_manufacturing(
  parameters : ManufacturingParameters,
  seed : Int,
) -> Result[Unit, String] {
  if parameters.entity_count < 0 {
    Err("entity_count must be non-negative")
  } else if parameters.arrival_interval < 0 {
    Err("arrival_interval must be non-negative")
  } else if parameters.processing_times.length() != 7 {
    Err("processing_times must contain exactly 7 values")
  } else if parameters.station_capacities.length() != 7 {
    Err("station_capacities must contain exactly 7 values")
  } else if seed < 0 {
    Err("seed must be non-negative")
  } else {
    let mut index = 0
    let mut total_processing_time = 0
    let mut valid = true
    while index < 7 {
      let processing_time = parameters.processing_times[index]
      let capacity = parameters.station_capacities[index]
      if processing_time < 0 {
        return Err("station processing times must be non-negative")
      }
      if capacity < 1 {
        return Err("station capacities must be at least 1")
      }
      if !nonnegative_sum_fits(total_processing_time, processing_time) {
        valid = false
      } else {
        total_processing_time += processing_time
      }
      index += 1
    }
    let count = parameters.entity_count
    let arrival_fits = count <= 1 ||
      nonnegative_product_fits(count - 1, parameters.arrival_interval)
    let workload_fits = nonnegative_product_fits(count, total_processing_time)
    let last_arrival = if count <= 1 {
      0
    } else {
      (count - 1) * parameters.arrival_interval
    }
    let total_workload = count * total_processing_time
    if !valid ||
      !arrival_fits ||
      !workload_fits ||
      !nonnegative_sum_fits(last_arrival, total_workload) {
      Err("scenario time exceeds the supported integer tick range")
    } else {
      Ok(())
    }
  }
}

///|
fn validate_logistics(
  parameters : LogisticsParameters,
  seed : Int,
) -> Result[Unit, String] {
  if parameters.entity_count < 0 {
    Err("entity_count must be non-negative")
  } else if parameters.entity_count != parameters.arrival_times.length() {
    Err("arrival_times length must equal entity_count")
  } else if parameters.delivery_delay < 0 {
    Err("delivery_delay must be non-negative")
  } else if parameters.fixed_time_threshold <= 0 {
    Err("fixed_time_threshold must be positive")
  } else if parameters.fixed_batch_threshold <= 0 {
    Err("fixed_batch_threshold must be positive")
  } else if parameters.hybrid_batch_threshold <= 0 {
    Err("hybrid_batch_threshold must be positive")
  } else if parameters.hybrid_timeout <= 0 {
    Err("hybrid_timeout must be positive")
  } else if seed < 0 {
    Err("seed must be non-negative")
  } else if parameters.policy_type != "fixed_time" &&
    parameters.policy_type != "fixed_batch" &&
    parameters.policy_type != "hybrid" {
    Err("policy_type must be fixed_time, fixed_batch, or hybrid")
  } else {
    let mut index = 0
    let mut sorted = true
    while index < parameters.arrival_times.length() {
      let arrival_time = parameters.arrival_times[index]
      if arrival_time < 0 {
        return Err("arrival_times must be non-negative")
      }
      if index > 0 && arrival_time < parameters.arrival_times[index - 1] {
        sorted = false
      }
      index += 1
    }
    if !sorted {
      Err("arrival_times must be in non-decreasing order")
    } else {
      let last_arrival = if parameters.arrival_times.length() == 0 {
        0
      } else {
        parameters.arrival_times[parameters.arrival_times.length() - 1]
      }
      let wait_bound = if parameters.policy_type == "fixed_time" {
        parameters.fixed_time_threshold
      } else if parameters.policy_type == "fixed_batch" {
        0
      } else {
        parameters.hybrid_timeout
      }
      let final_flush_bound = parameters.hybrid_timeout
      let wait_bound = if wait_bound > final_flush_bound {
        wait_bound
      } else {
        final_flush_bound
      }
      let release_time_fits = nonnegative_sum_fits(last_arrival, wait_bound)
      let release_time = last_arrival + wait_bound
      if !release_time_fits ||
        !nonnegative_sum_fits(release_time, parameters.delivery_delay) {
        Err("scenario time exceeds the supported integer tick range")
      } else {
        Ok(())
      }
    }
  }
}

///|
/// Validates a configuration and runs its MoonSim model.
pub fn run_scenario(
  config : ScenarioConfig,
) -> Result[SimulationResult, String] {
  match config {
    BasicQueue(parameters, seed) =>
      match validate_basic_queue(parameters, seed) {
        Err(message) => Err(message)
        Ok(_) => run_basic_queue(parameters, seed)
      }
    ManufacturingLine(parameters, seed) =>
      match validate_manufacturing(parameters, seed) {
        Err(message) => Err(message)
        Ok(_) => run_manufacturing_line(parameters, seed)
      }
    LogisticsBatching(parameters, seed) =>
      match validate_logistics(parameters, seed) {
        Err(message) => Err(message)
        Ok(_) => run_logistics_batching(parameters, seed)
      }
  }
}
