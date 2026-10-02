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
