# Native TLS capacity measurements

Read the [CPU accounting qualification](RESOURCE_ACCOUNTING.md) and [Cloud artifact provenance](ARTIFACT_PROVENANCE.json). These are single-campaign observations; exact starting domain-table counts are recorded per case.

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| small-full-idle-c512-qualification | 512 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| small-full-town-linked-r1-c4-a4-qualification-t2 | 4 / 4 | 1 | 300 | 635.6 | 760.5 | 800.6 | 959.5 | 2345.3 | True / True |
| small-city-city-r1-c8-a8-qualification-t2 | 8 / 8 | 1 | 600 | 396.6 | 589.2 | 623.5 | 883.2 | 1904.3 | True / True |
| medium-full-idle-c2048-qualification | 2048 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| medium-full-person-r1-c4-a4-qualification-t2 | 4 / 4 | 1 | 300 | 347.6 | 375.9 | 383.5 | 442.7 | 602.3 | True / True |
| medium-full-town-linked-r1-c32-a32-qualification-t2 | 32 / 32 | 1 | 2400 | 530.6 | 1267.2 | 1295.0 | 1736.3 | 2191.6 | True / True |
| medium-city-city-r1-c32-a32-qualification-t2 | 32 / 32 | 1 | 2400 | 306.9 | 508.4 | 521.2 | 651.5 | 1238.1 | True / True |
| large-full-idle-c128-qualification | 128 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| large-full-person-r1-c64-a64-qualification-t2 | 64 / 64 | 1 | 4800 | 348.6 | 508.6 | 523.2 | 682.4 | 1221.0 | True / True |
| large-full-town-linked-r1-c16-a16-qualification-t2 | 16 / 16 | 1 | 1200 | 339.2 | 369.2 | 377.0 | 412.5 | 981.6 | True / True |
| large-city-city-r1-c64-a64-qualification-t2 | 64 / 64 | 1 | 4800 | 310.7 | 389.4 | 400.8 | 497.3 | 979.5 | True / True |
| xlarge-full-idle-c512-qualification | 512 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-person-r1-c128-a128-qualification-t2 | 128 / 128 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-full-person-r1-c64-a64-qualification-t2 | 64 / 64 | 1 | 4800 | 326.2 | 370.3 | 379.0 | 449.5 | 922.3 | True / True |
| xlarge-full-town-linked-r1-c64-a64-qualification-t2 | 64 / 64 | 1 | 4800 | 326.7 | 367.1 | 379.6 | 463.7 | 963.5 | True / True |
| xlarge-city-city-r1-c128-a128-qualification-t2 | 128 / 128 | 1 | 9600 | 292.9 | 334.3 | 344.9 | 419.6 | 818.8 | True / True |
| xxlarge-full-idle-c2048-qualification | 2048 / 0 | 1 | 0 | — | — | — | — | — | False / True |
| xxlarge-full-person-r1-c128-a128-qualification-t2 | 128 / 128 | 1 | 9600 | 332.8 | 2499.5 | 2488.7 | 2813.8 | 3698.8 | True / False |
| xxlarge-full-person-r1-c64-a64-qualification-t2 | 64 / 64 | 1 | 4800 | 326.3 | 385.7 | 393.1 | 465.6 | 781.0 | True / True |
| xxlarge-full-town-linked-r1-c128-a128-qualification-t2 | 128 / 128 | 1 | 9600 | 340.6 | 411.4 | 431.4 | 535.4 | 1685.0 | True / True |
| xxlarge-city-city-r1-c128-a128-qualification-t2 | 128 / 128 | 1 | 9600 | 282.5 | 328.7 | 339.4 | 422.1 | 932.7 | True / True |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|
| small-full-idle-c512-qualification | 512 | 390 | False | 0 | — | 235.8 | False |
| medium-full-idle-c2048-qualification | 2048 | 1248 | False | 0 | — | 475.7 | False |
| large-full-idle-c128-qualification | 128 | 128 | True | 64 | 502.5 / 540.2 / 789.8 | 130.4 | True |
| xlarge-full-idle-c512-qualification | 512 | 512 | True | 256 | 430.1 / 439.4 / 545.2 | 231.9 | True |
| xxlarge-full-idle-c2048-qualification | 2048 | 2048 | True | 1024 | 457.3 / 494.7 / 715.0 | 744.6 | False |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.
