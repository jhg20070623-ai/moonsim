///|
/// Discrete-event simulation state and event-processing loop.
pub struct Simulation {
  priv clock : SimulationClock
  priv queue : EventQueue
  priv random : RandomSource
  priv mut next_event_id : Int
  priv mut next_sequence : Int
}

///|
/// Creates an empty simulation at time zero.
pub fn Simulation::new() -> Simulation {
  Simulation::with_seed(0).unwrap()
}

///|
/// Creates a simulation with a deterministic random stream for `seed`.
pub fn Simulation::with_seed(seed : Int) -> Result[Simulation, String] {
  match RandomSource::new(seed) {
    Err(message) => Err(message)
    Ok(random) =>
      Ok(Simulation::{
        clock: SimulationClock::new(),
        queue: EventQueue::new(),
        random,
        next_event_id: 0,
        next_sequence: 0,
      })
  }
}

///|
/// Returns the current simulation time.
pub fn Simulation::now(self : Simulation) -> Int {
  self.clock.now()
}

///|
/// Returns the number of events waiting to run.
pub fn Simulation::pending_events(self : Simulation) -> Int {
  self.queue.length()
}

///|
/// Draws an unbiased integer in `[0, limit)` from this simulation's random stream.
pub fn Simulation::random_int_below(
  self : Simulation,
  limit : Int,
) -> Result[Int, String] {
  self.random.int_below(limit)
}

///|
/// Draws a Double in `[0.0, 1.0)` from this simulation's random stream.
pub fn Simulation::random_double(self : Simulation) -> Double {
  self.random.next_double()
}

///|
/// Schedules an action at an absolute simulation time. Returns its event ID.
pub fn Simulation::schedule(
  self : Simulation,
  time : Int,
  priority : Int,
  action : () -> Unit,
) -> Result[Int, String] {
  if time < self.clock.now() {
    Err("cannot schedule an event before the current simulation time")
  } else {
    let event = Event::new(
      self.next_event_id,
      time,
      priority,
      self.next_sequence,
      action,
    )
    match event {
      Err(message) => Err(message)
      Ok(value) => {
        self.queue.push(value)
        self.next_event_id += 1
        self.next_sequence += 1
        Ok(value.id)
      }
    }
  }
}

///|
/// Runs all currently reachable events. Events scheduled by an action are
/// included in this run.
pub fn Simulation::run(self : Simulation) -> Int {
  self.process_until(None)
}

///|
/// Runs events with timestamps at or before `until`, then advances the clock
/// to `until`. Returns an error when asked to move the clock backwards.
pub fn Simulation::run_until(
  self : Simulation,
  until : Int,
) -> Result[Int, String] {
  if until < self.clock.now() {
    Err("run_until cannot move before the current simulation time")
  } else {
    Ok(self.process_until(Some(until)))
  }
}

///|
fn Simulation::process_until(self : Simulation, until : Int?) -> Int {
  let mut processed = 0
  let mut running = true
  while running {
    match self.queue.peek() {
      None => running = false
      Some(next) => {
        let within_limit = match until {
          None => true
          Some(limit) => next.time <= limit
        }
        if within_limit {
          match self.queue.pop() {
            None => running = false
            Some(event) => {
              let advanced = self.clock.advance_to(event.time)
              if advanced {
                event.execute()
                processed += 1
              } else {
                running = false
              }
            }
          }
        } else {
          running = false
        }
      }
    }
  }
  match until {
    None => ()
    Some(limit) => self.clock.advance_to(limit) |> ignore
  }
  processed
}
