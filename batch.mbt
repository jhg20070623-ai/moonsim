///|
/// A rule for deciding when a waiting batch should be released.
pub enum BatchPolicy {
  FixedTime(Int)
  FixedBatch(Int)
}

///|
/// Creates a policy that releases a non-empty batch after `interval` ticks
/// since its first item arrived.
pub fn BatchPolicy::fixed_time(interval : Int) -> Result[BatchPolicy, String] {
  if interval <= 0 {
    Err("fixed-time interval must be positive")
  } else {
    Ok(FixedTime(interval))
  }
}

///|
/// Creates a policy that releases a batch after it reaches `batch_size` items.
pub fn BatchPolicy::fixed_batch(
  batch_size : Int,
) -> Result[BatchPolicy, String] {
  if batch_size <= 0 {
    Err("fixed batch size must be positive")
  } else {
    Ok(FixedBatch(batch_size))
  }
}

///|
/// Checks whether a policy should release the current waiting batch.
pub fn BatchPolicy::should_trigger(
  self : BatchPolicy,
  waiting_count : Int,
  oldest_wait : Int,
) -> Result[Bool, String] {
  if waiting_count < 0 {
    Err("waiting count cannot be negative")
  } else if oldest_wait < 0 {
    Err("oldest wait cannot be negative")
  } else {
    match self {
      FixedTime(interval) => Ok(waiting_count > 0 && oldest_wait >= interval)
      FixedBatch(batch_size) => Ok(waiting_count >= batch_size)
    }
  }
}
