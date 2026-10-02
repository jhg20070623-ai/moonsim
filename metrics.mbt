///|
/// A time-weighted collector for entity, queue, and flow metrics.
pub struct Metrics {
  priv start_time : Int
  priv mut last_update : Int
  priv mut created_count : Int
  priv mut completed_count : Int
  priv mut current_wip : Int
  priv mut max_wip : Int
  priv mut wip_area : Int
  priv mut total_cycle_time : Int
  priv mut waiting_observation_count : Int
  priv mut total_waiting_time : Int
  priv mut current_queue_length : Int
  priv mut max_queue_length : Int
  priv mut queue_area : Int
}

///|
/// Creates a metrics collector whose observation window begins at `start_time`.
pub fn Metrics::new(start_time : Int) -> Result[Metrics, String] {
  if start_time < 0 {
    Err("metrics start time must be non-negative")
  } else {
    Ok(Metrics::{
      start_time,
      last_update: start_time,
      created_count: 0,
      completed_count: 0,
      current_wip: 0,
      max_wip: 0,
      wip_area: 0,
      total_cycle_time: 0,
      waiting_observation_count: 0,
      total_waiting_time: 0,
      current_queue_length: 0,
      max_queue_length: 0,
      queue_area: 0,
    })
  }
}

///|
/// Records an entity entering the system at its creation time.
pub fn Metrics::record_entity_created(
  self : Metrics,
  entity : Entity,
) -> Result[Unit, String] {
  match self.advance_time(entity.created_at()) {
    Err(message) => Err(message)
    Ok(_) => {
      self.created_count += 1
      self.current_wip += 1
      if self.current_wip > self.max_wip {
        self.max_wip = self.current_wip
      }
      Ok(())
    }
  }
}

///|
/// Records an entity leaving the system and accumulates its cycle time.
pub fn Metrics::record_entity_completed(
  self : Metrics,
  entity : Entity,
  completed_at : Int,
) -> Result[Unit, String] {
  if completed_at < entity.created_at() {
    Err("entity completion time cannot precede creation")
  } else if self.current_wip == 0 {
    Err("cannot complete an entity when WIP is zero")
  } else {
    match self.advance_time(completed_at) {
      Err(message) => Err(message)
      Ok(_) => {
        self.current_wip -= 1
        self.completed_count += 1
        self.total_cycle_time += completed_at - entity.created_at()
        Ok(())
      }
    }
  }
}

///|
/// Records one observed waiting duration at time `now`.
pub fn Metrics::record_waiting_time(
  self : Metrics,
  waiting_time : Int,
  now : Int,
) -> Result[Unit, String] {
  if waiting_time < 0 {
    Err("waiting time cannot be negative")
  } else {
    match self.advance_time(now) {
      Err(message) => Err(message)
      Ok(_) => {
        self.waiting_observation_count += 1
        self.total_waiting_time += waiting_time
        Ok(())
      }
    }
  }
}

///|
/// Records a queue length observation at time `now`.
pub fn Metrics::record_queue_length(
  self : Metrics,
  queue_length : Int,
  now : Int,
) -> Result[Unit, String] {
  if queue_length < 0 {
    Err("queue length cannot be negative")
  } else {
    match self.advance_time(now) {
      Err(message) => Err(message)
      Ok(_) => {
        self.current_queue_length = queue_length
        if queue_length > self.max_queue_length {
          self.max_queue_length = queue_length
        }
        Ok(())
      }
    }
  }
}

///|
/// Returns elapsed observation time from the configured start.
pub fn Metrics::simulation_time(
  self : Metrics,
  now : Int,
) -> Result[Int, String] {
  if now < self.last_update {
    Err("metrics query time cannot move backwards")
  } else {
    Ok(now - self.start_time)
  }
}

///|
/// Returns entities created during the observation window.
pub fn Metrics::entity_created_count(self : Metrics) -> Int {
  self.created_count
}

///|
/// Returns entities completed during the observation window.
pub fn Metrics::entity_completed_count(self : Metrics) -> Int {
  self.completed_count
}

///|
/// Returns the current work-in-process count.
pub fn Metrics::wip(self : Metrics) -> Int {
  self.current_wip
}

///|
/// Returns the largest observed work-in-process count.
pub fn Metrics::max_wip(self : Metrics) -> Int {
  self.max_wip
}

///|
/// Returns the mean cycle time of completed entities, or zero when none completed.
pub fn Metrics::mean_cycle_time(self : Metrics) -> Double {
  if self.completed_count == 0 {
    0.0
  } else {
    self.total_cycle_time.to_double() / self.completed_count.to_double()
  }
}

///|
/// Returns the mean recorded waiting time, or zero when no wait was recorded.
pub fn Metrics::mean_waiting_time(self : Metrics) -> Double {
  if self.waiting_observation_count == 0 {
    0.0
  } else {
    self.total_waiting_time.to_double() /
    self.waiting_observation_count.to_double()
  }
}

///|
/// Returns completed entities per simulation tick, or zero for a zero-length window.
pub fn Metrics::throughput(self : Metrics, now : Int) -> Result[Double, String] {
  match self.simulation_time(now) {
    Err(message) => Err(message)
    Ok(duration) =>
      if duration == 0 {
        Ok(0.0)
      } else {
        Ok(self.completed_count.to_double() / duration.to_double())
      }
  }
}

///|
/// Returns time-weighted average WIP over the observation window.
pub fn Metrics::average_wip(
  self : Metrics,
  now : Int,
) -> Result[Double, String] {
  self.time_weighted_average(self.wip_area, self.current_wip, now)
}

///|
/// Returns the current observed queue length.
pub fn Metrics::queue_length(self : Metrics) -> Int {
  self.current_queue_length
}

///|
/// Returns the largest observed queue length.
pub fn Metrics::max_queue_length(self : Metrics) -> Int {
  self.max_queue_length
}

///|
/// Returns time-weighted average queue length over the observation window.
pub fn Metrics::average_queue_length(
  self : Metrics,
  now : Int,
) -> Result[Double, String] {
  self.time_weighted_average(self.queue_area, self.current_queue_length, now)
}

///|
fn Metrics::time_weighted_average(
  self : Metrics,
  area : Int,
  current_value : Int,
  now : Int,
) -> Result[Double, String] {
  if now < self.last_update {
    Err("metrics query time cannot move backwards")
  } else {
    let duration = now - self.start_time
    if duration == 0 {
      Ok(0.0)
    } else {
      let accumulated = area + current_value * (now - self.last_update)
      Ok(accumulated.to_double() / duration.to_double())
    }
  }
}

///|
fn Metrics::advance_time(self : Metrics, now : Int) -> Result[Unit, String] {
  if now < self.last_update {
    Err("metrics observation time cannot move backwards")
  } else {
    let elapsed = now - self.last_update
    self.wip_area += self.current_wip * elapsed
    self.queue_area += self.current_queue_length * elapsed
    self.last_update = now
    Ok(())
  }
}
