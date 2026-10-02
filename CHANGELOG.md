# Changelog

## Unreleased

- Add a runnable seven-station manufacturing line with computed flow metrics.
- Add architecture, roadmap, and historical case-study background documentation.
- Add GitHub Actions checks for formatting, type checking, and tests.
- Add a runnable logistics example comparing all three batch policies and recording measured wait and timeout statistics.
- Add completion and zero-WIP guards to all three examples and run them in CI.
- Initialize the MoonBit module and add a monotonic simulation clock with validated event actions.
- Add a binary-heap event queue ordered by time, priority, and insertion sequence.
- Add `Simulation::schedule`, `run`, and inclusive `run_until` processing.
- Add reusable capacity-limited resources with guarded acquire/release and utilization accounting.
- Add a generic FIFO queue with monotonic timestamps and observed waiting-time statistics.
- Add entities with cycle-time tracking and reusable station routes.
- Add fixed-time and fixed-count batch release policies.
- Add a hybrid batch policy that releases on quantity or oldest-item timeout.
- Add a seedable ChaCha8 random source and simulation-level deterministic draws.
- Document event-ordering and random-stream reproducibility guarantees.
- Add time-weighted entity, WIP, throughput, waiting-time, and queue-length metrics.
- Add a runnable basic queue model with measured cycle time and utilization.
