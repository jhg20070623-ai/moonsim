# MoonSim

MoonSim is a lightweight and reproducible discrete-event simulation engine written in MoonBit.

MoonSim targets manufacturing, logistics, queueing, and process simulation. The current core provides a monotonic integer-tick simulation clock, validated event actions, and a stable priority event queue. The run loop, resources, queues, routing, batching, seeded randomness, and metrics will be added as tested milestones.

## Development status

This repository is at the start of development. The current API is intentionally small and does not yet claim to provide a complete simulator.

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
