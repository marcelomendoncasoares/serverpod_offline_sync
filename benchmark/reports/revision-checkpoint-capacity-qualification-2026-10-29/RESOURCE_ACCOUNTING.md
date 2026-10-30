# CPU accounting limitation

The completed Small sustained controls expose inconsistent CPU evidence. The visible cgroup reports a quota of 0.10 cores, while the process counters imply about 0.20 cores over each five-minute workload. The discrepancy is larger than a short boundary-sampling effect.

| Workload | Sample window, seconds | Process tick delta | Assumed ticks/s | Inferred CPU, cores | Reported quota, cores |
|---|---:|---:|---:|---:|---:|
| small-city-city-r1-c8-a8-boundary-soak-t2 | 301.091 | 6117 | 100 | 0.203 | 0.1 |
| small-full-person-r1-c8-a8-boundary-soak-t2 | 303.996 | 6282 | 100 | 0.207 | 0.1 |
| small-full-town-linked-r1-c8-a8-boundary-soak-t2 | 301.000 | 6281 | 100 | 0.209 | 0.1 |

The calculation is `(last user ticks + last system ticks - first user ticks - first system ticks) / 100 / elapsed wall seconds`. Each example uses samples from one unchanged server instance. The [raw examples](resource-accounting.json) retain the endpoints and values used in the calculation.

The benchmark reads `/proc/self/stat` and assumes 100 clock ticks per second. The visible cgroup-v1 files report a 10,000-microsecond quota and a 100,000-microsecond period, but provide no throttling counters. The current evidence does not establish which exposed accounting or enforcement assumption explains the discrepancy. No correction factor has been applied.

Treat the CPU quota column as the value reported inside the container and process CPU values as unvalidated estimates. Neither establishes a CPU utilization percentage or a hard enforced capacity limit. Instance names, measured memory, end-to-end timings, exact convergence, and offered-rate verdicts remain separately recorded. This limitation does not change those latency or correctness observations.

The benchmark implementation and deployment remain unchanged while measurements are running. Any CPU-accounting calibration must be a separate diagnostic step; it must not silently alter the ongoing comparison.
