# Manufacturing line

This example sends 20 entities through seven sequential, single-capacity stations. Arrivals are spaced six ticks apart. Processing times are 12, 8, 6, 10, 5, 4, and 9 ticks in route order. The line and arrival pattern are example inputs; they do not represent the historical optimization figures documented separately.

Run from the repository root:

    moon run examples/manufacturing_line

The model uses MoonSim events, resources, queues, routes, and metrics. It prints cycle time, time-weighted WIP, throughput, mean station-queue wait, and utilization for each station.

Observed output:

    Entities completed: 20
    Events processed: 160
    Simulation time: 282 ticks
    Mean cycle time: 111 ticks
    Mean station queue wait: 8.142857142857142 ticks
    Average WIP: 7.872340425531915
    Throughput: 0.07092198581560284 entities/tick
    cutting utilization: 0.851063829787234
    drilling utilization: 0.5673758865248227
    welding utilization: 0.425531914893617
    painting utilization: 0.7092198581560284
    assembly utilization: 0.3546099290780142
    inspection utilization: 0.28368794326241137
    packaging utilization: 0.6382978723404256

These values are output from the current model run. Changing the arrival pattern, processing times, station capacities, or engine behavior changes the results.
