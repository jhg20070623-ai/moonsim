///|
fn main raise {
  let sim = @moonsim.Simulation::new()
  let machine = @moonsim.Resource::new("machine", 1).unwrap()
  let queue : @moonsim.Queue[@moonsim.Entity] = @moonsim.Queue::new()
  let metrics = @moonsim.Metrics::new(0).unwrap()
  let service_time = 2
  let arrivals = [0, 1, 3, 7, 8]

  let mut entity_id = 0
  for arrival_time in arrivals {
    schedule_arrival(
      sim, entity_id, arrival_time, machine, queue, metrics, service_time,
    )
    entity_id += 1
  }

  let processed = sim.run()
  if metrics.entity_completed_count() != arrivals.length() ||
    metrics.wip() != 0 ||
    queue.length() != 0 ||
    machine.used() != 0 {
    fail("basic queue did not complete all entities and drain")
  }
  let now = sim.now()
  println("Events processed: \{processed}")
  println("Completed entities: \{metrics.entity_completed_count()}")
  println("Simulation time: \{now} ticks")
  println("Mean cycle time: \{metrics.mean_cycle_time()} ticks")
  println("Mean queue wait: \{metrics.mean_waiting_time()} ticks")
  println("Throughput: \{metrics.throughput(now).unwrap()} entities/tick")
  println("Machine utilization: \{machine.utilization_at(now).unwrap()}")
}

///|
fn schedule_arrival(
  sim : @moonsim.Simulation,
  entity_id : Int,
  arrival_time : Int,
  machine : @moonsim.Resource,
  queue : @moonsim.Queue[@moonsim.Entity],
  metrics : @moonsim.Metrics,
  service_time : Int,
) -> Unit {
  sim.schedule(arrival_time, 0, fn() {
    let entity = @moonsim.Entity::new(entity_id, arrival_time).unwrap()
    metrics.record_entity_created(entity).unwrap() |> ignore
    if machine.acquire(sim.now()).unwrap() {
      start_service(sim, entity, machine, queue, metrics, service_time)
    } else {
      queue.enqueue(entity, sim.now()).unwrap() |> ignore
      metrics.record_queue_length(queue.length(), sim.now()).unwrap() |> ignore
    }
  })
  |> ignore
}

///|
fn start_service(
  sim : @moonsim.Simulation,
  entity : @moonsim.Entity,
  machine : @moonsim.Resource,
  queue : @moonsim.Queue[@moonsim.Entity],
  metrics : @moonsim.Metrics,
  service_time : Int,
) -> Unit {
  let completion_time = sim.now() + service_time
  sim.schedule(completion_time, 0, fn() {
    let now = sim.now()
    machine.release(now).unwrap() |> ignore
    metrics.record_entity_completed(entity, now).unwrap() |> ignore
    match queue.dequeue_with_wait(now).unwrap() {
      None =>
        metrics.record_queue_length(queue.length(), now).unwrap() |> ignore
      Some((next, waiting_time)) => {
        metrics.record_waiting_time(waiting_time, now).unwrap() |> ignore
        metrics.record_queue_length(queue.length(), now).unwrap() |> ignore
        machine.acquire(now).unwrap() |> ignore
        start_service(sim, next, machine, queue, metrics, service_time)
      }
    }
  })
  |> ignore
}
