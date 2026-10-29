# Native TLS capacity measurements

Read the [matched comparison and qualifications](COMPARISON_NOTES.md), [guarded percentage comparison](comparison/README.md), and [artifact provenance](ARTIFACT_PROVENANCE.json). Original-deployment restoration remains pending until the complete campaign finishes.

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| medium-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 323.8 | 356.9 | 389.9 | 587.4 | 906.4 | True / True |
| medium-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 353.9 | 680.5 | 673.1 | 858.4 | 930.9 | True / True |
| medium-full-person-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 391.6 | 3020.4 | 2980.8 | 4197.4 | 4588.2 | True / False |
| medium-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1039.2 | 1081.7 | 1109.5 | 1276.9 | 1276.9 | True / True |
| medium-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3550.4 | 3782.2 | 3819.0 | 4162.3 | 4162.3 | True / False |
| medium-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1128.1 | 1209.8 | 1207.5 | 1253.8 | 1253.8 | True / True |
| medium-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 4747.5 | 5011.2 | 5040.3 | 5526.4 | 5526.4 | True / False |
| medium-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 785.3 | 858.3 | 845.4 | 891.4 | 891.4 | True / True |
| medium-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 2303.7 | 2536.7 | 2597.9 | 3187.3 | 3187.3 | True / False |
| small-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 477.8 | 691.8 | 703.7 | 875.6 | 879.2 | True / True |
| small-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1955.1 | 2249.4 | 2212.7 | 2331.9 | 2331.9 | True / False |
| small-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 2749.1 | 2970.5 | 2951.5 | 3100.9 | 3100.9 | True / False |
| small-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1814.6 | 1943.8 | 1959.4 | 2386.3 | 2386.3 | True / False |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.

## Skipped heavier cases

These cases were not measured because an equal or lighter comparable load did not pass. They do not establish a measured capacity limit. See `skipped-cases.json` for parameters and blocking verdicts.

| Skipped case | Blocking measurement |
|---|---|
| small-full-person-r1000-c2-a2-spread-t2 | small-full-person-r200-c2-a2-spread-t2 |
| small-full-town-linked-r1000-c2-a2-spread-t2 | small-full-town-linked-r200-c2-a2-spread-t2 |
| small-city-city-r1000-c2-a2-spread-t2 | small-city-city-r200-c2-a2-spread-t2 |
