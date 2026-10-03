# Browser Limits and Benchmark

MoonSim Web Lab bounds browser requests to **10,000 entities per run** and **20 replications per experiment**. The MoonBit browser adapter rejects larger requests with a JSON error before simulation work starts; the form also checks these values before posting work to its Worker.

## Measurement

The benchmark calls the compiled MoonBit JavaScript JSON API from a real browser page. Each workload gets one warm-up followed by repeated timed runs. Timings include input JSON serialization, MoonSim execution, output JSON parsing, and a completion-count check. They exclude chart rendering and download time. Replication timing covers 20 fresh manufacturing simulations at the 10,000-entity limit. The policy comparison timing covers all three logistics policies, each at 10,000 entities.

The measured environment was Windows 11 build 26200, Microsoft Edge 154.0.0.0 (headless Chromium 154.0.0.0), AMD Ryzen 9 8945HX, and 32 reported logical processors. These results describe this machine and browser only; they are not performance guarantees for other devices.

| Workload | Entities | Warm-up | Median timed run | Timed samples |
| --- | ---: | ---: | ---: | --- |
| Basic Queue | 10,000 | 3.7 ms | 3.2 ms | 3.2, 3.1, 3.2, 4.0, 3.0 ms |
| Manufacturing Line | 10,000 | 24.1 ms | 21.2 ms | 21.2, 20.8, 22.9, 21.7, 18.9 ms |
| Logistics Batching, one policy | 10,000 | 5.5 ms | 6.3 ms | 5.9, 6.3, 6.3, 5.7, 6.6 ms |
| Logistics Batching, all policies | 10,000 per policy | 22.9 ms | 17.8 ms | 20.4, 17.8, 18.7, 17.0, 17.3 ms |
| Manufacturing Line, 20 replications | 10,000 per replication | 406.6 ms | 405.6 ms | 423.1, 403.9, 405.6 ms |

## Browser behavior

- Each direct scenario request is capped at 10,000 entities.
- A replication experiment is capped at 20 runs; seeds increase from the user-supplied base seed.
- The logistics comparison runs Fixed Time, Fixed Batch, and Hybrid sequentially with the same arrivals and seed. Each policy is one direct run and is capped at 10,000 entities.
- Simulation calls run inside a Web Worker so the main page does not execute the model synchronously.
- The reusable MoonBit `ExperimentRunner` has no browser-specific limit. The bounds live in the Web API adapter and user interface.

The benchmark can be repeated after building the JavaScript target by serving the repository root and opening `scripts/browser-benchmark.html`. `scripts/browser-smoke.mjs` exercises the deployed static site with Edge or Chrome and checks a worker run, a replicated experiment, the seven-station utilization chart, all three logistics policies, and JSON download.
