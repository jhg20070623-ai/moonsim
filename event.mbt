///|
/// A scheduled action. Lower numeric priorities run first; events with equal
/// time and priority retain their insertion order through `sequence`.
pub struct Event {
  id : Int
  time : Int
  priority : Int
  sequence : Int
  action : () -> Unit
}

///|
/// Creates an event. IDs, times, and insertion sequence numbers must be
/// non-negative so the scheduler can maintain a well-defined total order.
pub fn Event::new(
  id : Int,
  time : Int,
  priority : Int,
  sequence : Int,
  action : () -> Unit,
) -> Result[Event, String] {
  if id < 0 {
    Err("event id must be non-negative")
  } else if time < 0 {
    Err("event time must be non-negative")
  } else if sequence < 0 {
    Err("event sequence must be non-negative")
  } else {
    Ok(Event::{ id, time, priority, sequence, action, })
  }
}

///|
/// Runs the event's action.
pub fn Event::execute(self : Event) -> Unit {
  (self.action)()
}
