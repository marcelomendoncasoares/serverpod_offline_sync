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
| small-full-idle-c512-fresh | 512 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| small-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 576.2 | 586.2 | 599.9 | 676.2 | 676.2 | True / True |
| small-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 561.0 | 732.3 | 926.3 | 1734.7 | 2048.0 | True / False |
| small-full-person-r1-c4-a4-spread | 4 / 4 | 1 | 16 | 504.8 | 635.2 | 646.8 | 817.7 | 817.7 | True / True |
| small-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 596.2 | 688.4 | 729.9 | 1025.1 | 1025.1 | True / True |
| small-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 743.7 | 1685.6 | 1749.3 | 2688.0 | 2854.9 | True / False |
| small-full-person-r10-c4-a4-spread | 4 / 4 | 10 | 16 | 666.0 | 763.0 | 770.4 | 944.3 | 944.3 | True / True |
| small-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 1107.8 | 1258.3 | 1256.7 | 1379.5 | 1379.5 | True / True |
| small-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 1628.6 | 3379.1 | 3257.3 | 3901.1 | 4292.0 | True / False |
| small-full-person-r50-c4-a4-spread | 4 / 4 | 50 | 16 | 1359.9 | 1832.6 | 1789.5 | 2260.3 | 2260.3 | True / True |
| small-full-person-r1-c8-a8-calibration-t2 | 8 / 8 | 1 | 40 | 548.6 | 654.7 | 734.5 | 1052.9 | 1354.8 | True / True |
| small-full-person-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 522.5 | 620.8 | 644.0 | 821.2 | 821.2 | True / True |
| small-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 528.2 | 642.0 | 671.6 | 923.9 | 955.7 | True / True |
| small-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 585.4 | 5498.7 | 6516.8 | 12003.6 | 21514.9 | True / False |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|
| small-full-idle-c16 | 16 | 16 | True | 8 | 2565.2 / 2445.3 / 2767.7 | 126.5 | True |
| small-full-idle-c64 | 64 | 64 | True | 32 | 2902.3 / 2868.5 / 3393.5 | 159.6 | True |
| small-full-idle-c256 | 256 | 256 | True | 128 | 3318.2 / 3321.2 / 3909.5 | 223.2 | True |
| small-full-idle-c1024 | 1024 | 36 | False | 0 | — | 231.7 | False |
| small-full-idle-c512-fresh | 512 | 372 | False | 0 | — | 233.7 | False |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. The 1,024-device Small attempt failed during startup after 36 stream-start events; Cloud logs show a subsequent graceful shutdown and restart. The same executable recovered cleanly. A subsequent 512-device attempt on the recovered process failed during startup after 372 stream-start events; its last sampled event-loop lag was 6.5 seconds at 234 MiB of cgroup memory. That process also restarted and recovered with the same executable and clean streams/transactions.
