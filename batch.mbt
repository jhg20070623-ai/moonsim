///|
/// A rule for deciding when a waiting batch should be released.
pub enum BatchPolicy {
  FixedTime(Int)
  FixedBatch(Int)
  Hybrid(Int, Int)
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
/// Creates a policy that releases on batch size or oldest-item timeout,
/// whichever happens first.
pub fn BatchPolicy::hybrid(
  batch_size : Int,
  max_wait : Int,
) -> Result[BatchPolicy, String] {
  if batch_size <= 0 {
    Err("hybrid batch size must be positive")
  } else if max_wait <= 0 {
    Err("hybrid max wait must be positive")
  } else {
    Ok(Hybrid(batch_size, max_wait))
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
      Hybrid(batch_size, max_wait) =>
        Ok(
          waiting_count >= batch_size ||
          (waiting_count > 0 && oldest_wait >= max_wait),
        )
    }
  }
}
