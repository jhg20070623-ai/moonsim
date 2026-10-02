///|
/// A named sequence of stations traversed by an entity.
pub struct Route {
  priv stations : Array[String]
}

///|
/// Creates a route with at least one non-empty station name.
pub fn Route::new(stations : Array[String]) -> Result[Route, String] {
  if stations.length() == 0 {
    Err("route must contain at least one station")
  } else {
    let copied : Array[String] = Array(capacity=stations.length())
    let mut index = 0
    while index < stations.length() {
      let station = stations[index]
      if station.length() == 0 {
        return Err("route station name cannot be empty")
      }
      copied.push(station)
      index += 1
    }
    Ok(Route::{ stations: copied, })
  }
}

///|
/// Returns the number of stations in the route.
pub fn Route::length(self : Route) -> Int {
  self.stations.length()
}

///|
/// Returns a station by zero-based index.
pub fn Route::station_at(self : Route, index : Int) -> String? {
  if index < 0 || index >= self.stations.length() {
    None
  } else {
    Some(self.stations[index])
  }
}
