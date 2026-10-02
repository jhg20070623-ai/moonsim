# Development Log

## 2026-10-02 — Project bootstrap and clock/event model

- **Implemented:** MoonBit module metadata, Apache-2.0 license, initial clock and event APIs, and executable unit tests.
- **Design:** Simulation time is an integer tick count so models choose their own unit and event ordering does not depend on floating-point timestamps. Clock advancement is monotonic.
- **Issue:** The official installer initially could not detect the environment architecture because `PROCESSOR_ARCHITECTURE` was unset. The runtime reported X64, so the installer was rerun with a matching process-local `AMD64` value.
- **Validation:** `moon check` and `moon test` are being run against this increment.
- **Next:** Add deterministic priority ordering and a reusable event queue.

## 2026-10-02 — Deterministic priority event queue

- **Implemented:** A binary min-heap event queue ordered by integer time, lower numeric priority, insertion sequence, and event ID as a final tie-breaker.
- **Design:** The heap is implemented in MoonBit with no external dependency. The sequence key preserves FIFO order for otherwise equal events.
- **Issue:** The official core includes a priority queue, but its generic comparison interface is unnecessary for closures stored in events; a focused heap avoids imposing comparison traits on callbacks.
- **Validation:** A test checks mixed timestamps/priorities and FIFO ordering for same-time same-priority events.
- **Next:** Add the simulation scheduler and run loop.

## 2026-10-02 — Simulation scheduler and run loop

- **Implemented:** Event IDs and insertion sequence allocation, absolute-time scheduling, full `run()`, and inclusive `run_until()` with clock advancement to the requested boundary.
- **Design:** Scheduling into the past and moving the run boundary backwards return descriptive errors. Events exactly on the `run_until` boundary execute.
- **Issue:** The scheduler relies on queue-owned insertion sequence values. The current event constructor remains public for low-level queue use; later APIs may narrow that surface.
- **Validation:** Tests cover ID assignment, deterministic execution ordering, queue draining, `run_until` boundary semantics, and invalid time requests.
- **Next:** Add reusable capacity-limited resources.

## 2026-10-02 — Resource capacity model

- **Implemented:** Named resources with positive capacity, multi-unit acquire/release, time-weighted busy-unit accounting, and utilization queries.
- **Design:** Failed capacity requests and releases at zero do not change usage; elapsed busy time is still accounted through the attempted operation time.
- **Issue:** Resource operations receive simulation time explicitly so the resource stays independent of the scheduler.
- **Validation:** Tests cover capacity greater than one, full-resource rejection, under-release rejection, utilization, invalid capacity, and backwards timestamps.
- **Next:** Add a FIFO queue with waiting-time statistics.

## 2026-10-02 — FIFO queue and waiting statistics

- **Implemented:** Generic FIFO enqueue/dequeue, queue length, total/mean waiting time, and successful dequeue count.
- **Design:** Queue operations take explicit integer simulation time and reject time reversal. Wait statistics include only items that were actually removed; an empty dequeue does not affect them.
- **Issue:** A head cursor avoids shifting on each removal; consumed storage is cleared or compacted to prevent indefinite retention of old entries.
- **Validation:** Tests cover FIFO behavior, waiting time totals and averages, empty dequeue, and timestamp reversal.
- **Next:** Add entities and reusable process routes.

## 2026-10-02 — Entities and routes

- **Implemented:** Entities with stable IDs, creation times, route progress, and cycle-time queries; routes are validated station sequences shared independently of the entity model.
- **Design:** Route station storage is copied and hidden so callers cannot mutate a route after construction. Entity route progress starts before station zero and stops at the final station.
- **Issue:** Entity metadata is omitted until a concrete typed metadata use case exists; the core does not expose an untyped map prematurely.
- **Validation:** Tests cover route traversal, final-station completion, cycle time, invalid timestamps, and empty route inputs.
- **Next:** Add batching policies.

## 2026-10-02 — Fixed-time and fixed-batch policies

- **Implemented:** Policy constructors and trigger checks for fixed-time and fixed-count batch release.
- **Design:** Fixed-time duration is measured from the oldest waiting item; empty batches never trigger. Fixed-batch ignores elapsed time and triggers once the count reaches its threshold.
- **Issue:** Policies are decision rules only; models remain responsible for scheduling timeout events and clearing a released batch.
- **Validation:** Tests cover threshold boundaries, empty batches, oversized batches, and invalid configuration/observations.
- **Next:** Add a hybrid policy that triggers on either threshold.

## 2026-10-02 — Hybrid batching policy

- **Implemented:** A policy that releases when a batch reaches its item threshold or the oldest item reaches its timeout.
- **Design:** A timeout cannot release an empty batch; quantity threshold takes effect regardless of elapsed wait.
- **Issue:** Timeout scheduling remains the responsibility of the simulation model using the scheduler.
- **Validation:** Tests cover both trigger paths, empty batches, and invalid thresholds.
- **Next:** Add deterministic seeded random draws.

## 2026-10-02 — Seeded random source

- **Implemented:** A `RandomSource` backed by MoonBit core's ChaCha8 generator, integer seed expansion, bounded unbiased integer draws, and `[0,1)` Double draws. Simulations can be created with `with_seed` and draw from their owned stream.
- **Design:** A stable SplitMix64 expansion turns one non-negative integer seed into the standard library's required 32-byte ChaCha8 key. The random package is part of MoonBit core, not an external dependency.
- **Issue:** Repeatability is defined for the same MoonSim and MoonBit core versions; future generator changes will be documented because they change generated sequences.
- **Validation:** Equal seeds produce equal integer and Double sequences; bounded draw ranges and invalid seed/limit inputs are checked.
- **Documentation:** `docs/reproducibility.md` records event ordering, seed expansion, and version scope.
- **Next:** Add simulation metrics.

## 2026-10-02 — Simulation metrics

- **Implemented:** Entity creation/completion counts, cycle time, waiting-time summaries, current/maximum WIP, throughput, and current/maximum/time-weighted queue length. Resource utilization remains available from `Resource::utilization_at`.
- **Design:** WIP and queue averages use time-weighted areas between observation changes. Throughput is completed entities divided by elapsed observation ticks. Metrics record explicit entity and queue observations; they do not infer missing events.
- **Issue:** Metrics are opt-in and must be updated by model actions; this keeps the engine from fabricating measurements.
- **Validation:** Tests verify formulas with hand-computable observations and ensure invalid counts/timestamps do not corrupt collector state.
- **Next:** Add the basic queue example using only current engine APIs.
