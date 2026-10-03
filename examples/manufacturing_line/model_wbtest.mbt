///|
test "manufacturing model preserves completion and resource invariants" {
  let result = simulate_manufacturing(20, 6)
  assert_eq(result.completed_count, 20)
  assert_eq(result.final_wip, 0)
  assert_eq(result.final_queue_length, 0)
  assert_true(result.mean_cycle_time > 0.0)
  assert_true(result.throughput > 0.0)
  assert_eq(result.stations.length(), 7)

  for station in result.stations {
    assert_true(station.utilization >= 0.0 && station.utilization <= 1.0)
    assert_eq(station.used, 0)
    assert_true(station.peak_usage <= station.capacity)
  }
}
