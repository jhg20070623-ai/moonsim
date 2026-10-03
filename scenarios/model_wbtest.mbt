///|
fn must_run(config : ScenarioConfig) -> SimulationResult raise {
  match run_scenario(config) {
    Err(message) => fail("unexpected scenario error: \{message}")
    Ok(result) => result
  }
}

///|
test "basic queue preset preserves its irregular arrival schedule and drains" {
  let result = must_run(ScenarioConfig::basic_queue_preset())
  assert_eq(result.scenario, "basic_queue")
  assert_eq(result.completed, 5)
  assert_eq(result.wip, 0)
  assert_eq(result.queue_length, 0)
  assert_true(result.waiting_time > 0.0)
  assert_true(result.throughput > 0.0)
  assert_eq(result.simulation_time, 11)
}

///|
test "basic queue supports uniform parameterized arrivals" {
  let config = ScenarioConfig::basic_queue(
    BasicQueueParameters::{
      entity_count: 4,
      arrival_interval: 1,
      arrival_times: [],
      service_time: 2,
      resource_capacity: 1,
    },
    9,
  )
  let result = must_run(config)
  assert_eq(result.completed, 4)
  assert_eq(result.simulation_time, 8)
  assert_eq(result.seed, 9)
}

///|
test "basic queue supports explicit arrival patterns" {
  let config = ScenarioConfig::basic_queue(
    BasicQueueParameters::{
      entity_count: 3,
      arrival_interval: 999,
      arrival_times: [0, 1, 3],
      service_time: 2,
      resource_capacity: 1,
    },
    42,
  )
  let result = must_run(config)
  assert_eq(result.completed, 3)
  assert_eq(result.simulation_time, 6)
}

///|
test "basic queue rejects a negative entity count" {
  let result = run_scenario(
    ScenarioConfig::basic_queue(
      BasicQueueParameters::{
        entity_count: -1,
        arrival_interval: 1,
        arrival_times: [],
        service_time: 1,
        resource_capacity: 1,
      },
      42,
    ),
  )
  assert_true(result is Err(_))
}

///|
test "basic queue rejects invalid capacity and arrival order" {
  let invalid_capacity = run_scenario(
    ScenarioConfig::basic_queue(
      BasicQueueParameters::{
        entity_count: 1,
        arrival_interval: 1,
        arrival_times: [],
        service_time: 1,
        resource_capacity: 0,
      },
      42,
    ),
  )
  let invalid_arrivals = run_scenario(
    ScenarioConfig::basic_queue(
      BasicQueueParameters::{
        entity_count: 2,
        arrival_interval: 1,
        arrival_times: [2, 1],
        service_time: 1,
        resource_capacity: 1,
      },
      42,
    ),
  )
  assert_true(invalid_capacity is Err(_))
  assert_true(invalid_arrivals is Err(_))
}

///|
test "basic queue guards time tick overflow before scheduling" {
  let result = run_scenario(
    ScenarioConfig::basic_queue(
      BasicQueueParameters::{
        entity_count: 2,
        arrival_interval: 2147483647,
        arrival_times: [],
        service_time: 1,
        resource_capacity: 1,
      },
      42,
    ),
  )
  assert_true(result is Err(_))
}

///|
test "manufacturing preset completes all entities with valid station utilization" {
  let result = must_run(ScenarioConfig::manufacturing_preset())
  assert_eq(result.completed, 20)
  assert_eq(result.wip, 0)
  assert_eq(result.queue_length, 0)
  assert_true(result.cycle_time > 0.0)
  assert_true(result.throughput > 0.0)
  assert_eq(result.resource_utilization.length(), 7)
  for station in result.resource_utilization {
    assert_true(station.utilization >= 0.0 && station.utilization <= 1.0)
    assert_true(station.peak_usage <= station.capacity)
  }
}

///|
test "manufacturing runner uses caller processing times and capacities" {
  let config = ScenarioConfig::manufacturing_line(
    ManufacturingParameters::{
      entity_count: 3,
      arrival_interval: 20,
      processing_times: [1, 1, 1, 1, 1, 1, 1],
      station_capacities: [2, 2, 2, 2, 2, 2, 2],
    },
    4,
  )
  let result = must_run(config)
  assert_eq(result.completed, 3)
  assert_eq(result.resource_utilization.length(), 7)
  for station in result.resource_utilization {
    assert_true(station.capacity == 2)
    assert_true(station.peak_usage <= station.capacity)
  }
}

///|
test "manufacturing runner rejects malformed station arrays" {
  let result = run_scenario(
    ScenarioConfig::manufacturing_line(
      ManufacturingParameters::{
        entity_count: 1,
        arrival_interval: 1,
        processing_times: [1, 2],
        station_capacities: [1, 1, 1, 1, 1, 1, 1],
      },
      42,
    ),
  )
  assert_true(result is Err(_))
}

///|
test "manufacturing runner rejects negative work and zero capacity" {
  let negative_work = run_scenario(
    ScenarioConfig::manufacturing_line(
      ManufacturingParameters::{
        entity_count: 1,
        arrival_interval: 1,
        processing_times: [-1, 1, 1, 1, 1, 1, 1],
        station_capacities: [1, 1, 1, 1, 1, 1, 1],
      },
      42,
    ),
  )
  let zero_capacity = run_scenario(
    ScenarioConfig::manufacturing_line(
      ManufacturingParameters::{
        entity_count: 1,
        arrival_interval: 1,
        processing_times: [1, 1, 1, 1, 1, 1, 1],
        station_capacities: [1, 0, 1, 1, 1, 1, 1],
      },
      42,
    ),
  )
  assert_true(negative_work is Err(_))
  assert_true(zero_capacity is Err(_))
}

///|
test "all logistics policies complete the preset with valid batch statistics" {
  for policy in ["fixed_time", "fixed_batch", "hybrid"] {
    let result = must_run(ScenarioConfig::logistics_preset(policy))
    assert_eq(result.completed, 17)
    assert_eq(result.wip, 0)
    assert_eq(result.queue_length, 0)
    assert_true(result.waiting_time >= 0.0)
    assert_true(result.throughput > 0.0)
    match result.batch_statistics {
      None => fail("expected logistics batch statistics")
      Some(stats) => {
        assert_true(stats.batch_count > 0)
        assert_true(stats.overdue_entities >= 0)
        assert_true(stats.overdue_entities <= result.completed)
        assert_true(stats.forced_partial_batches <= stats.batch_count)
      }
    }
  }
}

///|
test "fixed-time strategy releases at timeout" {
  let result = must_run(ScenarioConfig::logistics_preset("fixed_time"))
  match result.batch_statistics {
    None => fail("expected fixed-time batch statistics")
    Some(stats) => {
      assert_eq(stats.quantity_releases, 0)
      assert_true(stats.timeout_releases > 0)
    }
  }
}

///|
test "fixed-batch strategy releases at quantity threshold" {
  let result = must_run(ScenarioConfig::logistics_preset("fixed_batch"))
  match result.batch_statistics {
    None => fail("expected fixed-batch statistics")
    Some(stats) => {
      assert_true(stats.quantity_releases > 0)
      assert_eq(stats.timeout_releases, 0)
    }
  }
}

///|
test "hybrid strategy exercises both quantity and timeout releases" {
  let result = must_run(ScenarioConfig::logistics_preset("hybrid"))
  match result.batch_statistics {
    None => fail("expected hybrid statistics")
    Some(stats) => {
      assert_true(stats.quantity_releases > 0)
      assert_true(stats.timeout_releases > 0)
    }
  }
}

///|
test "logistics runner rejects unknown policy and unsorted arrivals" {
  let unknown = run_scenario(ScenarioConfig::logistics_preset("other"))
  let unsorted = run_scenario(
    ScenarioConfig::logistics_batching(
      LogisticsParameters::{
        entity_count: 2,
        arrival_times: [2, 1],
        delivery_delay: 1,
        policy_type: "fixed_batch",
        fixed_time_threshold: 2,
        fixed_batch_threshold: 2,
        hybrid_batch_threshold: 2,
        hybrid_timeout: 2,
      },
      42,
    ),
  )
  assert_true(unknown is Err(_))
  assert_true(unsorted is Err(_))
}

///|
test "fixed seed produces the same structured result" {
  let first = must_run(ScenarioConfig::manufacturing_preset())
  let second = must_run(ScenarioConfig::manufacturing_preset())
  assert_true(@json.to_json(first).equal(@json.to_json(second)))
}

///|
test "a different seed is accepted and recorded in the result" {
  let result = must_run(
    ScenarioConfig::basic_queue(
      BasicQueueParameters::{
        entity_count: 2,
        arrival_interval: 1,
        arrival_times: [],
        service_time: 1,
        resource_capacity: 1,
      },
      43,
    ),
  )
  assert_eq(result.seed, 43)
  assert_eq(result.completed, 2)
}
