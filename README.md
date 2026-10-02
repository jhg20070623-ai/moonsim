# MoonSim

MoonSim is a lightweight and reproducible discrete-event simulation engine written in MoonBit.

MoonSim targets manufacturing, logistics, queueing, and process simulation. The current core provides a monotonic integer-tick clock, validated event actions, a stable priority queue, a scheduler with `run()` and `run_until()`, capacity-limited resources with utilization tracking, a generic FIFO queue with waiting-time statistics, route-following entities, fixed-time/fixed-count/hybrid batch policies, a reproducible seeded random stream, and metrics for cycle time, waiting time, WIP, throughput, and queue length.

## Features

- Integer-tick simulation clock and deterministic event ordering.
- Capacity-limited resources and generic FIFO queues with waiting statistics.
- Entities that follow reusable named routes.
- Fixed-time, fixed-batch, and hybrid batch trigger policies.
- Seeded random values and collection of cycle time, waiting time, WIP, throughput, and queue length.

The package is under active development. It focuses on a small core that examples can compose; it does not provide a visual model editor or a built-in manufacturing workflow.

## Quick start

Create a simulation with @moonsim.Simulation::with_seed(42), schedule actions, and call run(). For a complete queueing model, run:

    moon run examples/basic_queue

## Architecture

The scheduler owns the simulation clock and stable event heap. Event actions update resource, queue, entity, and metrics state at integer timestamps. Models are composed by scheduling actions; MoonSim does not hard-code a particular production line or logistics process.

## Deterministic simulation

Simulation time uses integer ticks, and event ordering uses timestamp, priority, insertion sequence, and event ID. Use `Simulation::with_seed(seed)` for a repeatable random stream. See [reproducibility notes](docs/reproducibility.md) for the exact guarantee.

## Examples

- [Basic queue](examples/basic_queue/README.md): arrivals, FIFO waiting, one capacity-limited machine, service completion, and collected metrics.
- [Manufacturing line](examples/manufacturing_line/README.md): 20 entities routed through seven capacity-limited stations.
- [Logistics batching](examples/logistics_batching/README.md): a measured comparison of fixed-time, fixed-batch, and hybrid releases.
- See the [roadmap](docs/roadmap.md) and [historical case-study background](docs/case-study-background.md).

## Build and test

Install the MoonBit toolchain from [moonbitlang.com](https://www.moonbitlang.com/download), then run from the repository root:

```sh
moon fmt
moon check
moon test
moon run cmd/main
```

## License

MoonSim is licensed under Apache-2.0. See [LICENSE](LICENSE).
