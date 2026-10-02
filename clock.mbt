///|
/// A monotonic simulation clock. Values are integer ticks whose unit is chosen
/// by the model (for example, seconds or minutes).
pub struct SimulationClock {
  mut current_time : Int
}

///|
/// Creates a clock at simulation time zero.
pub fn SimulationClock::new() -> SimulationClock {
  SimulationClock::{ current_time: 0, }
}

///|
/// Returns the current simulation time.
pub fn SimulationClock::now(self : SimulationClock) -> Int {
  self.current_time
}

///|
/// Advances the clock to `target`. Returns false if that would move time
/// backwards; equal-time advancement is allowed.
pub fn SimulationClock::advance_to(
  self : SimulationClock,
  target : Int,
) -> Bool {
  if target < self.current_time {
    false
  } else {
    self.current_time = target
    true
  }
}
