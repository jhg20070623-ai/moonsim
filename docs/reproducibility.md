# Reproducibility

MoonSim uses integer ticks for simulation time and orders events by `(time, priority, insertion sequence, event ID)`. This avoids floating-point timestamp comparisons and makes tie handling explicit.

## Random streams

Create a random source with `RandomSource::new(non_negative_seed)` or a simulation with `Simulation::with_seed(seed)`. `Simulation::new()` uses seed `0`. Equal seeds produce equal draw sequences when the model consumes random values in the same order.

MoonSim expands the integer seed into a 32-byte key with SplitMix64 and uses the MoonBit core ChaCha8 generator. Bounded integer draws use the core generator's unbiased range operation. The supported guarantee is repeatability for the same MoonSim and MoonBit core versions; upgrading the core random implementation may change generated sequences and should be recorded with experiment results.

## Model requirements

Reproducibility also depends on keeping model inputs and event scheduling stable:

- Use the same seed, model parameters, entity inputs, and MoonSim revision.
- Schedule logically simultaneous events with explicit priorities when their relative order matters.
- Avoid external side effects or nondeterministic values inside event actions.
- Record the MoonBit toolchain and dependency versions with benchmark output.

The random source is for simulation experiments. It is not exposed as a cryptographic security API.

## Replication summaries

`ExperimentRunner::new(base_seed, run_count)` creates one fresh scenario run for each seed from `base_seed` through `base_seed + run_count - 1`. The returned mean/min/max values are computed directly from those runs. They describe that finite seed range; they are not confidence intervals or statistical conclusions. Preserve the parameters, base seed, replication count, MoonSim revision, and MoonBit toolchain when sharing an exported result.
