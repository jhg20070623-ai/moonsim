# Basic Queue Example

This example models a single machine, a FIFO waiting line, deterministic arrivals, and a constant service duration.

## Inputs

- Arrival times: `0, 1, 3, 7, 8` ticks
- Machine capacity: `1`
- Service time: `2` ticks per entity
- Random seed: not used by this deterministic model

## Run

From the repository root:

```sh
moon run examples/basic_queue
```

The program reports values calculated from the event simulation. Re-run it after changing the inputs to compare the resulting queue and machine metrics.

## Output from the current model

```text
Events processed: 10
Completed entities: 5
Simulation time: 11 ticks
Mean cycle time: 2.6 ticks
Mean queue wait: 1 ticks
Throughput: 0.45454545454545453 entities/tick
Machine utilization: 0.9090909090909091
```
