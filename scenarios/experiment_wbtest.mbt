///|
fn must_run_experiment(
  runner : ExperimentRunner,
  config : ScenarioConfig,
) -> ExperimentSummary raise {
  match runner.run(config) {
    Err(message) => fail("unexpected experiment error: \{message}")
    Ok(result) => result
  }
}

///|
test "experiment runner executes the requested seed range" {
  let runner = match ExperimentRunner::new(42, 3) {
    Err(message) => fail("valid experiment settings were rejected: \{message}")
    Ok(value) => value
  }
  let result = must_run_experiment(
    runner,
    ScenarioConfig::manufacturing_preset(),
  )
  assert_eq(result.base_seed, 42)
  assert_eq(result.run_count, 3)
  assert_true(result.completed.min == 20.0)
  assert_true(result.completed.mean == 20.0)
  assert_true(result.completed.max == 20.0)
  assert_true(result.cycle_time.min <= result.cycle_time.mean)
  assert_true(result.cycle_time.mean <= result.cycle_time.max)
  assert_true(result.waiting_time.min <= result.waiting_time.mean)
  assert_true(result.waiting_time.mean <= result.waiting_time.max)
  assert_true(result.throughput.min <= result.throughput.mean)
  assert_true(result.throughput.mean <= result.throughput.max)
}

///|
test "one replication matches the direct scenario metrics" {
  let config = ScenarioConfig::basic_queue_preset()
  let direct = must_run(config)
  let runner = match ExperimentRunner::new(42, 1) {
    Err(message) => fail("valid single run was rejected: \{message}")
    Ok(value) => value
  }
  let experiment = must_run_experiment(runner, config)
  assert_eq(experiment.run_count, 1)
  assert_true(experiment.completed.mean == direct.completed.to_double())
  assert_true(experiment.cycle_time.mean == direct.cycle_time)
  assert_true(experiment.waiting_time.mean == direct.waiting_time)
  assert_true(experiment.throughput.mean == direct.throughput)
}

///|
test "experiment means equal arithmetic means of the requested direct runs" {
  let config = ScenarioConfig::manufacturing_preset()
  let first = must_run(config.with_seed(7))
  let second = must_run(config.with_seed(8))
  let third = must_run(config.with_seed(9))
  let runner = match ExperimentRunner::new(7, 3) {
    Err(_) => fail("valid three-run experiment was rejected")
    Ok(value) => value
  }
  let result = must_run_experiment(runner, config)
  assert_true(
    result.cycle_time.mean ==
    (first.cycle_time + second.cycle_time + third.cycle_time) / 3.0,
  )
  assert_true(
    result.waiting_time.mean ==
    (first.waiting_time + second.waiting_time + third.waiting_time) / 3.0,
  )
  assert_true(
    result.throughput.mean ==
    (first.throughput + second.throughput + third.throughput) / 3.0,
  )
  assert_true(
    result.mean_wip.mean ==
    (first.average_wip + second.average_wip + third.average_wip) / 3.0,
  )
}

///|
test "experiment mean WIP aggregates observed average WIP" {
  let runner = match ExperimentRunner::new(5, 2) {
    Err(message) => fail("valid experiment settings were rejected: \{message}")
    Ok(value) => value
  }
  let result = must_run_experiment(
    runner,
    ScenarioConfig::manufacturing_preset(),
  )
  assert_true(result.mean_wip.mean > 0.0)
  assert_true(result.mean_wip.min > 0.0)
  assert_true(result.mean_wip.max >= result.mean_wip.min)
}

///|
test "experiment runner rejects invalid counts and overflowing seed ranges" {
  assert_true(ExperimentRunner::new(42, 0) is Err(_))
  assert_true(ExperimentRunner::new(-1, 1) is Err(_))
  assert_true(ExperimentRunner::new(2147483647, 2) is Err(_))
}

///|
test "experiment runner returns scenario validation errors" {
  let runner = match ExperimentRunner::new(42, 2) {
    Err(message) => fail("valid experiment settings were rejected: \{message}")
    Ok(value) => value
  }
  let invalid = ScenarioConfig::basic_queue(
    BasicQueueParameters::{
      entity_count: -1,
      arrival_interval: 1,
      arrival_times: [],
      service_time: 1,
      resource_capacity: 1,
    },
    42,
  )
  assert_true(runner.run(invalid) is Err(_))
}
