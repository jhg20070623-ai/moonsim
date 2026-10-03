# Roadmap

This roadmap describes work that is available in the repository today and a small set of follow-up engineering tasks. It is not a promise that every possible simulation feature will be added.

## Available now

- Deterministic integer-tick event scheduling, including `run_until`.
- Capacity-limited resources, FIFO queues, routes, and entities.
- Fixed-time, fixed-batch, and hybrid batch trigger policies.
- Seeded random source and core flow metrics.
- Runnable queueing, manufacturing, and logistics batching examples.
- Queue dequeue results can include the measured wait duration through `dequeue_with_wait`; the existing FIFO API and queue aggregates remain available.
- Basic queue, manufacturing, and logistics examples record dequeue waits in the shared Metrics collector and have regression coverage.
- Typed `ScenarioConfig` validation and reusable MoonBit runners for Basic Queue, Manufacturing Line, and Logistics Batching.
- Structured `SimulationResult` values and JSON input/output functions for the browser adapter.
- `ExperimentRunner` with independent consecutive-seed replications and mean/min/max summaries.
- MoonSim Web Lab with parameter controls, KPI output, manufacturing utilization bars, three-policy logistics charts, and JSON download.
- Web simulations run in a Worker; browser API limits are 10,000 entities per run and 20 replications, based on the documented local benchmark.
- Static Web Lab build and smoke checks pass in MoonBit CI. The validated main deployment is available at [MoonSim Web Lab](https://jhg20070623-ai.github.io/moonsim/); run [#37126484162](https://github.com/jhg20070623-ai/moonsim/actions/runs/37126484162) completed both validation and Pages deployment.

## Next engineering steps

- Consider bounded event traces and scenario sharing only after the current Web API and page remain stable.
- Expand browser benchmarking to lower-power devices before changing the documented request bounds.
- Add new scenario models only when they exercise reusable engine behavior and have testable invariants.

## Out of scope for v0.2.0

- A graphical model editor.
- Claims that example output reproduces an external factory or historical optimization.
- Built-in optimization, statistical inference, confidence intervals, or hypothesis tests.
- User accounts, databases, cloud simulation, AI agents, live PLC/ROS/Unity integration, or 3D views.
