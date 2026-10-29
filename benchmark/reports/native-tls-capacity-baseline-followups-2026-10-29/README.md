# Native TLS capacity measurements

This completed follow-up report adds four idle-connection refinements and fifteen sustained trials to the [combined baseline report](../native-tls-capacity-baseline-combined-2026-10-29/README.md). Failures and missed offered rates remain in the results. CPU accounting has unresolved discrepancies; see the [accounting observations](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md) before interpreting CPU utilization or headroom.

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| large-full-idle-c256-w4-repeat-t2 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| large-full-idle-c1024-w4-followup-t2 | 1024 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c2048-w4-followup-t2 | 2048 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c2048-w4-followup-t2 | 2048 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-person-r1-c8-a8-boundary-soak-t2 | 8 / 8 | 1 | 600 | 666.3 | 980.1 | 1001.6 | 1282.9 | 2286.8 | True / True |
| small-full-town-linked-r1-c8-a8-boundary-soak-t2 | 8 / 8 | 1 | 600 | 727.2 | 1917.2 | 1934.0 | 2339.5 | 3508.1 | True / True |
| small-city-city-r1-c8-a8-boundary-soak-t2 | 8 / 8 | 1 | 600 | 461.1 | 867.2 | 939.4 | 1361.0 | 2658.7 | True / True |
| medium-full-person-r1-c32-a32-boundary-soak-t2 | 32 / 32 | 1 | 2400 | 384.2 | 1328.9 | 1430.9 | 2090.3 | 2879.0 | True / True |
| medium-full-town-linked-r1-c16-a16-boundary-soak-t2 | 16 / 16 | 1 | 1200 | 359.1 | 481.9 | 500.6 | 645.7 | 1136.9 | True / True |
| medium-city-city-r1-c32-a32-boundary-soak-t2 | 32 / 32 | 1 | 2400 | 376.0 | 730.7 | 756.4 | 1009.7 | 1709.0 | True / True |
| large-full-person-r1-c64-a64-boundary-soak-t2 | 64 / 64 | 1 | 4755 | 395.9 | 654.1 | 671.9 | 924.8 | 1626.1 | False / False |
| large-full-town-linked-r1-c32-a32-boundary-soak-t2 | 32 / 32 | 1 | 2400 | 340.4 | 375.0 | 387.0 | 457.7 | 994.7 | True / True |
| large-city-city-r1-c64-a64-boundary-soak-t2 | 64 / 64 | 1 | 4717 | 326.1 | 453.6 | 468.9 | 607.8 | 1214.4 | False / None |
| xlarge-full-person-r1-c64-a64-boundary-soak-t2 | 64 / 64 | 1 | 4800 | 338.4 | 401.8 | 424.3 | 563.8 | 2470.7 | True / True |
| xlarge-full-town-linked-r1-c64-a64-boundary-soak-t2 | 64 / 64 | 1 | 4800 | 327.0 | 379.3 | 390.1 | 469.4 | 804.9 | True / True |
| xlarge-city-city-r1-c128-a128-boundary-soak-t2 | 128 / 128 | 1 | 9600 | 300.4 | 365.0 | 414.6 | 705.0 | 1346.7 | True / True |
| xxlarge-full-person-r1-c128-a128-boundary-soak-t2 | 128 / 128 | 1 | 9600 | 423.0 | 3589.2 | 3583.0 | 4023.6 | 4934.7 | True / False |
| xxlarge-full-town-linked-r1-c128-a128-boundary-soak-t2 | 128 / 128 | 1 | 9561 | 340.2 | 426.8 | 468.8 | 777.5 | 1138.0 | False / False |
| xxlarge-city-city-r1-c128-a128-boundary-soak-t2 | 128 / 128 | 1 | 9600 | 293.1 | 341.6 | 354.1 | 447.3 | 843.8 | True / True |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|
| large-full-idle-c256-w4-repeat-t2 | 256 | 256 | True | 128 | 509.8 / 528.1 / 634.3 | 163.5 | True |
| large-full-idle-c1024-w4-followup-t2 | 1024 | 1024 | True | 512 | 692.9 / 698.8 / 919.0 | 399.0 | True |
| xlarge-full-idle-c2048-w4-followup-t2 | 2048 | 2048 | True | 1024 | 501.7 / 531.0 / 742.4 | 739.8 | True |
| xxlarge-full-idle-c2048-w4-followup-t2 | 2048 | 2048 | True | 1024 | 471.3 / 489.5 / 621.0 | 740.5 | True |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.
