///|
struct QueueEntry[T] {
  value : T
  enqueued_at : Int
}

///|
/// A FIFO queue that records wait time for each successfully dequeued item.
pub struct Queue[T] {
  priv mut entries : Array[QueueEntry[T]]
  priv mut head : Int
  priv mut last_operation_time : Int
  priv mut total_waiting_time : Int
  priv mut dequeued_count : Int
}

///|
/// Creates an empty FIFO queue.
pub fn[T] Queue::new() -> Queue[T] {
  Queue::{
    entries: [],
    head: 0,
    last_operation_time: 0,
    total_waiting_time: 0,
    dequeued_count: 0,
  }
}

///|
/// Adds an item at the current simulation time.
pub fn[T] Queue::enqueue(
  self : Queue[T],
  value : T,
  now : Int,
) -> Result[Unit, String] {
  match self.record_time(now) {
    Err(message) => Err(message)
    Ok(_) => {
      self.entries.push(QueueEntry::{ value, enqueued_at: now, })
      Ok(())
    }
  }
}

///|
/// Removes the oldest item and records its wait. Empty queues return None.
pub fn[T] Queue::dequeue(self : Queue[T], now : Int) -> Result[T?, String] {
  match self.record_time(now) {
    Err(message) => Err(message)
    Ok(_) =>
      if self.head >= self.entries.length() {
        Ok(None)
      } else {
        let entry = self.entries[self.head]
        self.head += 1
        self.total_waiting_time += now - entry.enqueued_at
        self.dequeued_count += 1
        self.compact_if_needed()
        Ok(Some(entry.value))
      }
  }
}

///|
/// Returns the number of items waiting in the queue.
pub fn[T] Queue::length(self : Queue[T]) -> Int {
  self.entries.length() - self.head
}

///|
/// Returns the number of items successfully dequeued.
pub fn[T] Queue::dequeued_count(self : Queue[T]) -> Int {
  self.dequeued_count
}

///|
/// Returns total waiting time for successfully dequeued items.
pub fn[T] Queue::total_waiting_time(self : Queue[T]) -> Int {
  self.total_waiting_time
}

///|
/// Returns mean wait in time ticks, or zero when no item has been dequeued.
pub fn[T] Queue::average_waiting_time(self : Queue[T]) -> Double {
  if self.dequeued_count == 0 {
    0.0
  } else {
    self.total_waiting_time.to_double() / self.dequeued_count.to_double()
  }
}

///|
fn[T] Queue::record_time(self : Queue[T], now : Int) -> Result[Unit, String] {
  if now < self.last_operation_time {
    Err("queue operation time cannot move backwards")
  } else {
    self.last_operation_time = now
    Ok(())
  }
}

///|
fn[T] Queue::compact_if_needed(self : Queue[T]) -> Unit {
  let remaining = self.entries.length() - self.head
  if remaining == 0 {
    self.entries = []
    self.head = 0
  } else if self.head >= 64 && self.head * 2 >= self.entries.length() {
    let compacted : Array[QueueEntry[T]] = Array(capacity=remaining)
    let mut index = self.head
    while index < self.entries.length() {
      compacted.push(self.entries[index])
      index += 1
    }
    self.entries = compacted
    self.head = 0
  }
}
