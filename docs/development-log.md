# Development Log

## 2026-10-03 — MoonSim Web Lab v0.2.0

- **Experiment Runner:** Added independent replications using consecutive seeds from a user-selected base seed. The MoonBit summary reports mean, minimum, and maximum completed count, cycle time, waiting time, throughput, and average WIP; it does not claim inferential statistics.
- **Browser request bounds:** The MoonBit JSON adapter rejects more than 10,000 entities per run or more than 20 replications. Limits were selected after a warmed Microsoft Edge benchmark and are recorded in `docs/browser-limits.md`.
- **Web Lab:** Added a plain HTML/CSS/JavaScript page using the MoonBit JSON exports in a module Worker. It provides the three existing scenario models, editable parameters, KPI cards, seven-station utilization bars, fixed-time/fixed-batch/hybrid comparison charts, replication summaries, validation feedback, and JSON export.
- **Static packaging and CI:** `scripts/build-web.mjs` packages the generated MoonBit JavaScript module with the page. CI builds and smoke-checks this static output; a dependent Pages deployment job is configured for validated pushes to `main`.
- **Browser validation:** A real Edge browser smoke run exercised the Worker API, three-seed replication, all seven utilization bars, all three logistics policies and charts, and downloaded result JSON.
- **Local validation:** `moon fmt`, `moon check`, and `moon test` passed; 62 tests passed. The JavaScript API smoke test, built-site smoke test, and Edge browser smoke passed. The three CLI examples were rerun successfully.
- **Public validation:** Feature-branch validation passed in [MoonBit CI run #37126084668](https://github.com/jhg20070623-ai/moonsim/actions/runs/37126084668) and pull-request check [#37126121775](https://github.com/jhg20070623-ai/moonsim/actions/runs/37126121775). PR [#1](https://github.com/jhg20070623-ai/moonsim/pull/1) merged as `0e90868`. Main validation passed in [run #37126484162](https://github.com/jhg20070623-ai/moonsim/actions/runs/37126484162), as did its Pages deployment job.
- **Pages setup:** The first deployment attempt found no Pages site configured. The repository Pages source was enabled for GitHub Actions, then the failed job was rerun successfully. The public page `https://jhg20070623-ai.github.io/moonsim/` returned HTTP 200.
- **Release state:** The v0.2.0 implementation is merged and deployed. This release-readiness audit is being recorded before creating the v0.2.0 tag.

## 2026-10-03 · Acceptance hardening

- **Metrics integration:** Added `Queue::dequeue_with_wait`, which returns the dequeued value with its measured queue wait. The existing `dequeue` API and Queue-level aggregates remain available. All three examples now record the same dequeue measurement in the shared Metrics collector.
- **Regression tests:** Extracted callable model functions for manufacturing and batching examples. Tests cover 20/20 manufacturing completions, drained WIP and queues, valid station utilization, positive cycle time and throughput, and peak resource usage within capacity. Batching tests cover all three policies completing 17/17 entities, drained WIP and queues, non-negative waits, valid overdue and partial-batch counts, and the configured time/quantity trigger paths.
- **Local validation:** `moon fmt`, `moon check`, and `moon test` passed; 25 tests passed. `moon run examples/basic_queue`, `moon run examples/manufacturing_line`, and `moon run examples/logistics_batching` all completed successfully.
- **Public CI:** GitHub Actions run [#37104594725](https://github.com/jhg20070623-ai/moonsim/actions/runs/37104594725) passed format, type check, tests, and examples. After the Metrics and regression-test commits were pushed, [run #37105960682](https://github.com/jhg20070623-ai/moonsim/actions/runs/37105960682) also completed successfully on `main`.
- **Next:** Complete the release-readiness audit and record its findings.

## 2026-10-02 — Logistics batching example

- **Implemented:** A runnable comparison of FixedTime(5), FixedBatch(3), and Hybrid(3, 5) using the same 17 scheduled arrivals and the MoonSim BatchPolicy trigger API.
- **Model assumptions:** Released batches share a two-tick delivery delay. A residual FixedBatch is released at end of intake; overdue means waiting strictly more than five ticks.
- **Metrics:** The example computes each entity's waiting time, completed count, throughput, batch count, timeout releases, overdue entities, and end-of-intake partial batches. Its README records observed output.
- **Validation:** The comparison ran for all three policies, all three reported 17 completions with zero WIP, and the full moon fmt/check/test suite passed.
- **Next:** Verify CI behavior on GitHub after the workflow can be pushed.

## 2026-10-02 — Manufacturing line and CI

- **Implemented:** A seven-station model using 12/8/6/10/5/4/9 tick processing times, 20 entities, and six-tick arrival spacing. Each entity follows a Route and traverses per-station Resource and Queue state.
- **Metrics:** The runnable model prints cycle time, time-weighted WIP, throughput, mean station queue wait, and per-station utilization. Its README records observed output and the input assumptions.
- **Data provenance:** Historical optimization figures are in a separate background note and explicitly identified as owner-supplied data, not MoonSim output.
- **CI:** Added a GitHub Actions workflow using MoonBit's published installer script and running formatting, type checking, and tests.
- **Validation:** The manufacturing example completed 20/20 entities with zero WIP; moon fmt, moon check, and moon test passed before commit.
- **Next:** Build the logistics batching comparison.

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

## 2026-10-02 — Basic queue example

- **Implemented:** A runnable arrival/queue/resource/service/leave model with five entities and a single-server resource.
- **Design:** The example schedules actual service-completion events and updates queue and metrics state from event actions; displayed values are produced by the model.
- **Issue:** The core exposes composable pieces rather than a built-in entity process DSL, so the example uses small helper functions to wire events.
- **Validation:** `moon run examples/basic_queue` completed ten events; the example README records that observed output and its inputs.
- **Next:** Add a generic seven-station manufacturing line example.
