///|
/// A min-heap ordered by event time, numeric priority, then insertion sequence.
pub struct EventQueue {
  priv items : Array[Event]
}

///|
/// Creates an empty event queue.
pub fn EventQueue::new() -> EventQueue {
  EventQueue::{ items: [], }
}

///|
/// Returns the number of pending events.
pub fn EventQueue::length(self : EventQueue) -> Int {
  self.items.length()
}

///|
/// Returns whether the queue has no pending events.
pub fn EventQueue::is_empty(self : EventQueue) -> Bool {
  self.items.length() == 0
}

///|
/// Returns the next event without removing it.
pub fn EventQueue::peek(self : EventQueue) -> Event? {
  if self.items.length() == 0 {
    None
  } else {
    Some(self.items[0])
  }
}

///|
/// Adds an event while preserving the queue's total ordering.
pub fn EventQueue::push(self : EventQueue, event : Event) -> Unit {
  self.items.push(event)
  let mut index = self.items.length() - 1
  while index > 0 {
    let parent = (index - 1) / 2
    if event_precedes(self.items[index], self.items[parent]) {
      swap_events(self.items, index, parent)
      index = parent
    } else {
      break
    }
  }
}

///|
/// Removes and returns the next event, or None when the queue is empty.
pub fn EventQueue::pop(self : EventQueue) -> Event? {
  let count = self.items.length()
  if count == 0 {
    None
  } else {
    let first = self.items[0]
    let last = self.items[count - 1]
    self.items.truncate(count - 1)
    if count > 1 {
      self.items[0] = last
      sift_down(self.items)
    }
    Some(first)
  }
}

///|
fn event_precedes(left : Event, right : Event) -> Bool {
  if left.time != right.time {
    left.time < right.time
  } else if left.priority != right.priority {
    left.priority < right.priority
  } else if left.sequence != right.sequence {
    left.sequence < right.sequence
  } else {
    left.id < right.id
  }
}

///|
fn swap_events(items : Array[Event], left : Int, right : Int) -> Unit {
  let temp = items[left]
  items[left] = items[right]
  items[right] = temp
}

///|
fn sift_down(items : Array[Event]) -> Unit {
  let count = items.length()
  let mut index = 0
  let mut moving = true
  while moving {
    let left = index * 2 + 1
    if left >= count {
      moving = false
    } else {
      let right = left + 1
      let child = if right < count && event_precedes(items[right], items[left]) {
        right
      } else {
        left
      }
      if event_precedes(items[child], items[index]) {
        swap_events(items, index, child)
        index = child
      } else {
        moving = false
      }
    }
  }
}
