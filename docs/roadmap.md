# Roadmap

This is a working project roadmap, not a promise that every item is already implemented.

## Available now

- Deterministic integer-tick event scheduling, including run_until.
- Capacity-limited resources, FIFO queues, routes, and entities.
- Fixed-time, fixed-batch, and hybrid batch trigger policies.
- Seeded random source and core flow metrics.
- Runnable queueing, manufacturing, and logistics batching examples.
- Queue dequeue results can include the measured wait duration through
  `dequeue_with_wait`; the existing FIFO API and Queue-level aggregates remain
  available.
- Basic queue, manufacturing, and logistics examples record dequeue waits in
  the shared Metrics collector.
- Manufacturing and batching examples have regression tests for completion,
  queue draining, metric bounds, capacity, and policy trigger behavior.
- GitHub Actions workflow `MoonBit CI` is active on the public repository; runs
  #37104594725 and #37105960682 completed successfully.

## Next engineering steps

- Consider priority queues, cancellation, and replication summaries only after the current API and examples are stable.

## Out of scope for this initial iteration

- A graphical model editor.
- Claims that example output reproduces an external factory or historical optimization.
- Built-in optimization or statistical inference.
