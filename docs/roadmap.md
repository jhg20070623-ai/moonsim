# Roadmap

This is a working project roadmap, not a promise that every item is already implemented.

## Available now

- Deterministic integer-tick event scheduling, including run_until.
- Capacity-limited resources, FIFO queues, routes, and entities.
- Fixed-time, fixed-batch, and hybrid batch trigger policies.
- Seeded random source and core flow metrics.
- Runnable queueing, manufacturing, and logistics batching examples.

## Next engineering steps

- Improve per-entity queue wait integration with the aggregate Metrics collector.
- Add targeted tests for manufacturing and batching example behavior.
- Verify the new GitHub Actions workflow on the public repository.
- Consider priority queues, cancellation, and replication summaries only after the current API and examples are stable.

## Out of scope for this initial iteration

- A graphical model editor.
- Claims that example output reproduces an external factory or historical optimization.
- Built-in optimization or statistical inference.
