# MoonSim v0.2.1 demo script

Internal recording guide, approximately 75 seconds. Demonstrate the published Web Lab and describe only behavior visible in the current version.

| Time | On-screen action | Narration |
|---|---|---|
| 0:00–0:08 | Open the MoonSim Web Lab. Point out the scenario selector and result area. | “MoonSim is a discrete-event simulation engine implemented in MoonBit. This page runs the existing models in the browser.” |
| 0:08–0:20 | Run Basic Queue. Show completed entities, cycle time, waiting time, WIP, throughput, and resource utilization. | “The Basic Queue model returns its measured flow metrics. These values come from the simulation result.” |
| 0:20–0:43 | Select Manufacturing Line and run the 20-entity, seven-station preset. Show completed count, zero WIP, cycle time, throughput, and utilization bars. | “The manufacturing example routes 20 entities through seven capacity-limited stations. The page displays the result and each station’s utilization.” |
| 0:43–0:55 | Change WS2 processing time from 8 to 16 and rerun. | “Changing an input runs the model again. The exported request records the new value, and the returned result is recalculated.” |
| 0:55–1:08 | Select Logistics Batching and run. Show policy charts and result table. | “The logistics example compares fixed-time, fixed-batch, and hybrid release policies with the same arrivals and seed.” |
| 1:08–1:15 | Click Download JSON, then show the README link to examples and reproducibility notes. | “You can download the request and response as JSON and reproduce a run using its inputs and seed.” |

Recording notes: capture only the Web Lab content, not the desktop or unrelated windows. Do not imply that the sample model is calibrated to an external factory, that the three models cover every production case, or that the browser page is a graphical model editor.
