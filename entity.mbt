///|
/// An entity in a model, identified independently of any specific route.
pub struct Entity {
  id : Int
  created_at : Int
  mut route_position : Int
}

///|
/// Creates an entity at a non-negative simulation time.
pub fn Entity::new(id : Int, created_at : Int) -> Result[Entity, String] {
  if id < 0 {
    Err("entity ID must be non-negative")
  } else if created_at < 0 {
    Err("entity creation time must be non-negative")
  } else {
    Ok(Entity::{ id, created_at, route_position: -1, })
  }
}

///|
/// Returns the entity identifier.
pub fn Entity::id(self : Entity) -> Int {
  self.id
}

///|
/// Returns when the entity entered the model.
pub fn Entity::created_at(self : Entity) -> Int {
  self.created_at
}

///|
/// Returns the index of the current route station, or -1 before the route starts.
pub fn Entity::route_position(self : Entity) -> Int {
  self.route_position
}

///|
/// Returns the current station from a route, if the entity has entered one.
pub fn Entity::current_station(self : Entity, route : Route) -> String? {
  route.station_at(self.route_position)
}

///|
/// Enters the next station in `route`. Returns None after the final station.
pub fn Entity::advance_route(self : Entity, route : Route) -> String? {
  let next_position = self.route_position + 1
  if next_position >= route.length() {
    None
  } else {
    self.route_position = next_position
    route.station_at(next_position)
  }
}

///|
/// Returns elapsed time since creation, rejecting timestamps before creation.
pub fn Entity::cycle_time_at(self : Entity, now : Int) -> Result[Int, String] {
  if now < self.created_at {
    Err("entity cycle time cannot precede creation")
  } else {
    Ok(now - self.created_at)
  }
}
