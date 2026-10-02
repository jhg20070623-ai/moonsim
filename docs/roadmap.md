# Roadmap

This is a working project roadmap, not a promise that every item is already implemented.

## Available now

- Deterministic integer-tick event scheduling, including run_until.
- Capacity-limited resources, FIFO queues, routes, and entities.
- Fixed-time, fixed-batch, and hybrid batch trigger policies.
- Seeded random source and core flow metrics.
- Runnable queueing and manufacturing examples. The logistics comparison is in progress.

## Next engineering steps

- Complete the logistics batching comparison and document its assumptions and observed output.
- Improve per-entity queue wait recording and model-level invariants.
- Add targeted tests for manufacturing and batching example behavior.
- Consider priority queues, cancellation, and replication summaries only after the current API and examples are stable.

## Out of scope for this initial iteration

- A graphical model editor.
- Claims that example output reproduces an external factory or historical optimization.
- Built-in optimization or statistical inference.
