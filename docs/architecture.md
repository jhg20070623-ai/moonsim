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

The root MoonBit package contains the reusable simulation engine. The `scenarios` package owns typed scenario parameters, validation, reusable model runners, and structured results. The executable examples call those same runners. Engine tests live in `moonsim_test.mbt`; model and adapter tests live beside their packages.

## Web Lab boundary

`web_api` is a small MoonBit foreign-library package with exported JSON-string functions for a single scenario and a replicated experiment. It parses and validates the request, constructs a `ScenarioConfig`, executes the reusable MoonBit model, and serializes the actual result. Browser-only limits (10,000 entities per run and 20 replications) are checked in this adapter; the reusable engine and `ExperimentRunner` do not inherit those UI limits.

The browser page is plain HTML and CSS with a small JavaScript view layer. Its module Worker imports the compiled MoonBit JavaScript bundle and forwards JSON requests; it contains no simulation or metric calculations. The main thread only validates form input and renders the result. The static build script copies the compiled bundle and page assets into an ignored `site/` directory. GitHub Actions validates the static package and deploys it to Pages after the `main` validation job passes.

`ExperimentRunner` starts each replication with a fresh model run and consecutive seeds beginning at the requested base seed. It reports mean, minimum, and maximum completed count, cycle time, waiting time, throughput, and average WIP. These are descriptive summaries of the requested replications, not confidence intervals or inferential statistics.

The Web Lab currently has no event trace. Event timeline capture remains optional and deferred until the scheduler can expose a bounded, stable trace without adding cost to ordinary runs.

## Current limits

The scheduler uses integer ticks chosen by each model. It provides a FIFO queue and resource acquisition operations, but no process DSL, event cancellation, or event timeline. The scenario layer provides descriptive replication summaries, not statistical inference. The Web Lab configures its three built-in examples; it is not a graphical model editor or general workflow designer.
