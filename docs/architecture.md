# Architecture

MoonSim is a small discrete-event simulation library. Models use integer ticks and schedule actions that update application state when the event queue reaches the corresponding time.

## Event loop

Simulation owns the simulation clock, event IDs, insertion sequence numbers, a deterministic event heap, and a seeded random source. Events are ordered by timestamp, numeric priority, insertion sequence, and finally ID. run() drains scheduled events; run_until(t) processes events at or before t.

## Model building blocks

- Resource tracks capacity, active use, and busy-unit time.
- Queue[T] is FIFO and records the wait duration of dequeued items.
- Entity holds an ID, creation tick, and route position.
- Route stores an ordered sequence of station names.
- BatchPolicy evaluates fixed-time, fixed-count, or hybrid release thresholds.
- Metrics records entity flow, observed waiting times, time-weighted WIP, and queue length.

These types do not impose a model-specific process. Examples compose them by scheduling callbacks that move entities, request capacity, enqueue work, and record observations.

## Package layout

The root MoonBit package contains the reusable core API. Each runnable model lives in its own executable package under examples/. Engine tests live in moonsim_test.mbt.

## Current limits

The first iteration uses one integer time unit chosen by the model. It provides a FIFO queue and single-resource acquisition operations; higher-level process semantics, replication analysis, cancellation, and graphical model tooling are not part of the current core.
