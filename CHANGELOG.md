# Changelog

## Unreleased

- Initialize the MoonBit module and add a monotonic simulation clock with validated event actions.
- Add a binary-heap event queue ordered by time, priority, and insertion sequence.
- Add `Simulation::schedule`, `run`, and inclusive `run_until` processing.
- Add reusable capacity-limited resources with guarded acquire/release and utilization accounting.
- Add a generic FIFO queue with monotonic timestamps and observed waiting-time statistics.
- Add entities with cycle-time tracking and reusable station routes.
- Add fixed-time and fixed-count batch release policies.
- Add a hybrid batch policy that releases on quantity or oldest-item timeout.
