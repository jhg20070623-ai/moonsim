# Development Log

## 2026-10-02 — Project bootstrap and clock/event model

- **Implemented:** MoonBit module metadata, Apache-2.0 license, initial clock and event APIs, and executable unit tests.
- **Design:** Simulation time is an integer tick count so models choose their own unit and event ordering does not depend on floating-point timestamps. Clock advancement is monotonic.
- **Issue:** The official installer initially could not detect the environment architecture because `PROCESSOR_ARCHITECTURE` was unset. The runtime reported X64, so the installer was rerun with a matching process-local `AMD64` value.
- **Validation:** `moon check` and `moon test` are being run against this increment.
- **Next:** Add deterministic priority ordering and a reusable event queue.
