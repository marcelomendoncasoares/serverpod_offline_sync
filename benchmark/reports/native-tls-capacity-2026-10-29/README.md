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
| small-full-person-r1-c16-a16-spread-t2 | 16 / 16 | 1 | 64 | 653.5 | 2610.5 | 2547.9 | 2997.7 | 3180.7 | True / False |
| small-full-person-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 698.1 | 761.6 | 1006.2 | 2803.8 | 2803.8 | True / True |
| small-full-person-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 842.8 | 1600.5 | 1500.9 | 2037.8 | 2140.4 | True / True |
| small-full-person-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 1457.3 | 6645.5 | 6495.6 | 7995.9 | 8792.1 | True / False |
| small-full-person-r10-c16-a16-spread-t2 | 16 / 16 | 10 | 64 | 1136.5 | 3391.4 | 3368.8 | 4184.1 | 4295.4 | True / False |
| small-full-person-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 1067.8 | 1305.0 | 1281.4 | 1448.7 | 1448.7 | True / True |
| small-full-person-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 1471.2 | 3310.2 | 3192.6 | 3799.9 | 3904.4 | True / False |
| small-full-person-r50-c4-a4-spread-t2 | 4 / 4 | 50 | 16 | 1032.7 | 1143.5 | 1190.0 | 1528.1 | 1528.1 | True / True |
| small-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 2506.8 | 2892.0 | 2850.1 | 3167.5 | 3167.5 | True / False |
| small-full-person-r200-c2-a2-period10s-t2 | 2 / 2 | 200 | 4 | 2516.3 | 2810.3 | 2788.4 | 3016.9 | 3016.9 | True / True |
| small-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 11858.3 | 15763.3 | 15540.9 | 17112.2 | 17112.2 | True / False |
| small-full-person-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 11436.9 | 16087.0 | 15271.7 | 17475.7 | 17475.7 | True / False |
| small-full-town-linked-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 722.8 | 821.8 | 823.1 | 1019.8 | 1019.8 | True / True |
| small-full-town-linked-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 661.3 | 1247.5 | 1327.6 | 2158.8 | 2461.5 | True / True |
| small-full-town-linked-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 1932.0 | 6119.1 | 5989.7 | 6819.4 | 7021.0 | True / False |
| small-full-town-linked-r1-c16-a16-spread-t2 | 16 / 16 | 1 | 64 | 783.5 | 3200.0 | 3057.6 | 3638.0 | 3810.4 | True / False |
| small-full-town-linked-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 809.6 | 906.8 | 914.7 | 1063.7 | 1063.7 | True / True |
| small-full-town-linked-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 701.3 | 2385.1 | 2283.7 | 2897.7 | 2898.6 | True / False |
| small-full-town-linked-r10-c4-a4-spread-t2 | 4 / 4 | 10 | 16 | 728.1 | 887.3 | 1002.4 | 1927.7 | 1927.7 | True / True |
| small-full-town-linked-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 1321.4 | 1463.7 | 1546.8 | 2124.7 | 2124.7 | True / True |
| small-full-town-linked-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 2042.9 | 4495.7 | 4428.5 | 5291.6 | 5602.6 | True / False |
| small-full-town-linked-r50-c4-a4-spread-t2 | 4 / 4 | 50 | 16 | 1646.9 | 2290.2 | 2320.8 | 2979.4 | 2979.4 | True / False |
| small-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 3674.0 | 6902.2 | 7042.0 | 10543.5 | 10543.5 | True / False |
| small-full-town-linked-r200-c2-a2-period10s-t2 | 2 / 2 | 200 | 4 | 3379.0 | 4028.7 | 3973.6 | 4458.1 | 4458.1 | True / True |
| small-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 7 | 16715.0 | 31253.6 | 31195.4 | 44704.9 | 44704.9 | False / None |
| small-full-town-linked-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 14934.2 | 26259.1 | 24970.9 | 32431.1 | 32431.1 | False / False |
| small-full-person-r1-c8-a8-soak-t2 | 8 / 8 | 1 | 600 | 468.8 | 879.5 | 934.7 | 1327.9 | 2186.4 | True / True |
| small-full-person-r1-c64-a8-mixed-t2 | 64 / 8 | 1 | 120 | 558.0 | 902.6 | 943.5 | 1315.6 | 1458.0 | True / True |
| small-full-city-r1-c8-a8-registry-control-t2 | 8 / 8 | 1 | 120 | 549.0 | 872.2 | 1023.8 | 1847.2 | 2342.8 | True / True |
| small-full-city-r50-c4-a4-registry-control-t2 | 4 / 4 | 50 | 40 | 941.0 | 1222.9 | 1352.2 | 1921.9 | 2306.2 | True / True |

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
