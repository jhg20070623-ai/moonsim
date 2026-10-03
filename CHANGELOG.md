# Changelog

Notable project changes are recorded here.

## v0.2.1 — 2026-10-03

- Add Playwright end-to-end coverage for Basic Queue, Manufacturing Line, Logistics Batching, Experiment Runner, JSON downloads, changed inputs, and the responsive Web Lab layout.
- Compare deterministic manufacturing outputs in Edge, Chromium, and Firefox; run Chromium as a required CI check and Firefox as a separate advisory job.
- Add real browser screenshots and an under-10-MiB Web Lab demo GIF.
- Improve keyboard focus visibility and respect reduced-motion preferences.
- Update CI to current stable GitHub Actions majors and pin the runner to Ubuntu 26.04; document the runtime decisions.
- Add browser compatibility results, release readiness, and a short internal demo script.

## v0.2.0 — 2026-10-03

- Add typed, parameterized runners and structured JSON results for Basic Queue, Manufacturing Line, and Logistics Batching.
- Add consecutive-seed ExperimentRunner summaries with mean, minimum, and maximum metrics.
- Add browser JSON exports, a Worker-based MoonSim Web Lab, resource and logistics comparison charts, and JSON result downloads.
- Add measured browser bounds, browser/static package smoke checks, and a GitHub Pages deployment job gated on successful CI validation.

## v0.1.0

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
