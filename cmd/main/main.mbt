///|
/// Entry point for a minimal MoonSim smoke run.
fn main {
  let sim = @moonsim.Simulation::new()
  sim.schedule(5, 0, fn() { println("event at tick 5") }) |> ignore
  let processed = sim.run()
  println(
    "Processed \{processed} event(s); simulation time is \{sim.now()} ticks",
  )
}
