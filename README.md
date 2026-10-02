# MoonSim

MoonSim is a lightweight and reproducible discrete-event simulation engine written in MoonBit.

MoonSim targets manufacturing, logistics, queueing, and process simulation. The current core provides a monotonic integer-tick clock, validated event actions, a stable priority queue, a scheduler with `run()` and `run_until()`, capacity-limited resources with utilization tracking, a generic FIFO queue with waiting-time statistics, route-following entities, fixed-time/fixed-count/hybrid batch policies, and a reproducible seeded random stream.

## Development status

This repository is at the start of development. The current API is intentionally small and does not yet claim to provide a complete simulator.

## Deterministic simulation

Simulation time uses integer ticks, and event ordering uses timestamp, priority, insertion sequence, and event ID. Use `Simulation::with_seed(seed)` for a repeatable random stream. See [reproducibility notes](docs/reproducibility.md) for the exact guarantee.

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
