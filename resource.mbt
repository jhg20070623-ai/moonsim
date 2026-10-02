///|
/// A capacity-limited resource with busy-unit-time accounting.
pub struct Resource {
  name : String
  capacity : Int
  mut used : Int
  mut last_update : Int
  mut busy_unit_time : Int
}

///|
/// Creates a resource with positive capacity.
pub fn Resource::new(name : String, capacity : Int) -> Result[Resource, String] {
  if capacity <= 0 {
    Err("resource capacity must be positive")
  } else {
    Ok(Resource::{ name, capacity, used: 0, last_update: 0, busy_unit_time: 0, })
  }
}

///|
/// Returns the resource name.
pub fn Resource::name(self : Resource) -> String {
  self.name
}

///|
/// Returns the resource capacity.
pub fn Resource::capacity(self : Resource) -> Int {
  self.capacity
}

///|
/// Returns the number of resource units currently in use.
pub fn Resource::used(self : Resource) -> Int {
  self.used
}

///|
/// Attempts to acquire one unit at `now`. Returns false when all units are in use.
pub fn Resource::acquire(self : Resource, now : Int) -> Result[Bool, String] {
  match self.record_time(now) {
    Err(message) => Err(message)
    Ok(_) =>
      if self.used == self.capacity {
        Ok(false)
      } else {
        self.used += 1
        Ok(true)
      }
  }
}

///|
/// Releases one unit at `now`. Returns false when no unit is in use.
pub fn Resource::release(self : Resource, now : Int) -> Result[Bool, String] {
  match self.record_time(now) {
    Err(message) => Err(message)
    Ok(_) =>
      if self.used == 0 {
        Ok(false)
      } else {
        self.used -= 1
        Ok(true)
      }
  }
}

///|
/// Returns time-weighted utilization over `[0, now]` as a value from 0.0 to 1.0.
pub fn Resource::utilization_at(
  self : Resource,
  now : Int,
) -> Result[Double, String] {
  if now < self.last_update {
    Err("resource utilization time cannot move backwards")
  } else if now == 0 {
    Ok(0.0)
  } else {
    let accumulated = self.busy_unit_time + self.used * (now - self.last_update)
    let capacity_time = self.capacity * now
    Ok(accumulated.to_double() / capacity_time.to_double())
  }
}

///|
fn Resource::record_time(self : Resource, now : Int) -> Result[Unit, String] {
  if now < self.last_update {
    Err("resource operation time cannot move backwards")
  } else {
    self.busy_unit_time += self.used * (now - self.last_update)
    self.last_update = now
    Ok(())
  }
}
