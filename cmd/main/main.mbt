///|
/// Entry point for a minimal MoonSim smoke run.
fn main {
  let clock = @moonsim.SimulationClock::new()
  println("MoonSim clock starts at \{clock.now()} ticks")
}
