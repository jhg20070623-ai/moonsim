///|
test "batch policies preserve completion and metric invariants" {
  let policies : Array[@moonsim.BatchPolicy] = [
    @moonsim.BatchPolicy::fixed_time(5).unwrap(),
    @moonsim.BatchPolicy::fixed_batch(3).unwrap(),
    @moonsim.BatchPolicy::hybrid(3, 5).unwrap(),
  ]

  for policy in policies {
    let result = simulate_policy(policy)
    assert_eq(result.completed_count, 17)
    assert_eq(result.final_wip, 0)
    assert_eq(result.final_queue_length, 0)
    assert_true(result.batch_count > 0)
    assert_true(result.mean_waiting_time >= 0.0)
    assert_true(result.overdue_entities >= 0)
    assert_true(result.overdue_entities <= result.completed_count)
    assert_true(result.forced_partial_batches >= 0)
    assert_true(result.forced_partial_batches <= result.batch_count)
    assert_true(result.throughput > 0.0)
  }
}

///|
test "fixed-time, fixed-batch, and hybrid examples exercise their triggers" {
  let fixed_time = simulate_policy(@moonsim.BatchPolicy::fixed_time(5).unwrap())
  let fixed_batch = simulate_policy(
    @moonsim.BatchPolicy::fixed_batch(3).unwrap(),
  )
  let hybrid = simulate_policy(@moonsim.BatchPolicy::hybrid(3, 5).unwrap())

  assert_eq(fixed_time.quantity_releases, 0)
  assert_true(fixed_time.timeout_releases > 0)
  assert_true(fixed_batch.quantity_releases > 0)
  assert_eq(fixed_batch.timeout_releases, 0)
  assert_true(hybrid.quantity_releases > 0)
  assert_true(hybrid.timeout_releases > 0)
}
