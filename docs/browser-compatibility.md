# Browser compatibility results

Test date: 2026-10-03  
Scope: MoonSim Web Lab v0.2.1 branch, local end-to-end checks against the built static site.

## Browser matrix

| Browser | Version reported by browser | Result |
|---|---:|---|
| Microsoft Edge Stable | 154.0.4258.48 | PASS |
| Chromium (Playwright) | 153.0.8010.12 | PASS |
| Firefox (Playwright) | 155.0 | PASS |

The three browsers were run on the same Windows development environment. They are separate runs against the same built Web Lab and local MoonBit JavaScript module; this is not a hosted-device or operating-system compatibility matrix.

## Scenarios exercised

| Scenario | Checks |
|---|---|
| Basic Queue | Default run completes five entities; waiting time is finite and non-negative; throughput is positive; all five KPI cards render; downloaded JSON parses and contains the successful request and response. |
| Experiment Runner | Three replications use base seed 42 and return run count 3; the page renders all five summary KPI cards. Mean, minimum, and maximum are finite and ordered for each metric. The engine uses the configured consecutive seed range 42–44. |
| Manufacturing Line | Default 20-entity model completes 20 with WIP 0, positive cycle time and throughput, seven station utilization values in `[0, 1]`, and seven chart rows. WS2 processing time is changed from 8 to 16; the exported request reflects 16 and returned metrics change. |
| Logistics Batching | FixedTime, FixedBatch, and Hybrid each complete all 17 entities with WIP 0, non-negative waiting time, positive batch count, and overdue count in `[0, 17]`. The policy table contains all three policies. Timeout counters exercise the configured time-triggered and quantity-triggered behavior. |
| Responsive layout and browser errors | At a 375-pixel viewport, page width does not exceed viewport width. No unhandled page exceptions or console error messages were observed. |

## Determinism comparison

The default manufacturing configuration was compared across Edge, Chromium, and Firefox. Completion count and WIP matched exactly. Cycle time, waiting time, throughput, and every station utilization matched within absolute tolerance `1e-9`; no output values were rounded before comparison. All comparisons passed.

## CI behavior

The workflow requires the Chromium E2E job before Pages deployment. Firefox runs in a separate advisory job with `continue-on-error: true`, so a Firefox-only intermittent failure does not block the main validation or Pages deployment. The local Firefox run above passed. Public CI evidence is recorded in the v0.2.1 release-readiness report after the branch workflow completes.

This matrix establishes smoke coverage for the named desktop browsers and a narrow mobile-width layout check. Safari/WebKit, physical mobile devices, assistive-technology testing, and low-power performance benchmarking were not run and are not claimed here.
