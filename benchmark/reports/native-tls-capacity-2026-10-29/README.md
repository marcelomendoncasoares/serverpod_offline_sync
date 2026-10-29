# Native TLS capacity measurements

Status: measuring. The matrix is incomplete until every size and workload is measured.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| small-full-person-r1-c8-a8-reference | 8 / 8 | 1 | 40 | 573.6 | 683.5 | 700.9 | 908.2 | 971.8 | True / True |
| small-full-idle-c16 | 16 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-idle-c64 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-idle-c256 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-idle-c1024 | 1024 / 0 | 1 | 0 | — | — | — | — | — | False / None |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|
| small-full-idle-c16 | 16 | 16 | True | 8 | 2565.2 / 2445.3 / 2767.7 | 126.5 | True |
| small-full-idle-c64 | 64 | 64 | True | 32 | 2902.3 / 2868.5 / 3393.5 | 159.6 | True |
| small-full-idle-c256 | 256 | 256 | True | 128 | 3318.2 / 3321.2 / 3909.5 | 223.2 | True |
| small-full-idle-c1024 | 1024 | 36 | False | 0 | — | 231.7 | False |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. The 1,024-device Small attempt failed during startup after 36 stream-start events; Cloud logs show a subsequent graceful shutdown and restart. The same executable recovered cleanly.
