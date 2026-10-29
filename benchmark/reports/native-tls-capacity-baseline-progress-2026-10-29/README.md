# Native TLS capacity measurements

> Completed discovery baseline: 372 measured cases across Small, Medium, Large, XL, and XXL. These measurements use the cached/HLC native-TLS implementation at `e11f16b`. Sustained boundary follow-ups and the revision-checkpoint Cloud comparison remain in progress. Failures and incomplete observations are retained. The new pruning policy applies to subsequent campaigns; historical heavier and slower-cadence trials remain visible here.

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

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
| small-city-city-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 587.0 | 688.9 | 673.2 | 793.8 | 793.8 | True / True |
| small-city-city-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 623.0 | 735.6 | 834.0 | 1224.1 | 1225.2 | True / True |
| small-city-city-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 976.4 | 5012.2 | 5902.5 | 9406.0 | 17098.0 | True / False |
| small-city-city-r1-c16-a16-spread-t2 | 16 / 16 | 1 | 64 | 759.1 | 2449.7 | 2391.5 | 2894.1 | 2992.4 | True / False |
| small-city-city-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 567.3 | 681.6 | 689.9 | 786.5 | 786.5 | True / True |
| small-city-city-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 928.1 | 1125.1 | 1144.4 | 1521.3 | 1624.4 | True / True |
| small-city-city-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 1288.3 | 5810.9 | 5764.9 | 7014.1 | 7512.1 | True / False |
| small-city-city-r10-c16-a16-spread-t2 | 16 / 16 | 10 | 64 | 678.9 | 3002.6 | 2936.1 | 3705.4 | 3890.7 | True / False |
| small-city-city-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 787.5 | 896.0 | 902.2 | 990.6 | 990.6 | True / True |
| small-city-city-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 1585.2 | 2671.4 | 2698.9 | 3225.3 | 3412.4 | True / False |
| small-city-city-r50-c4-a4-spread-t2 | 4 / 4 | 50 | 16 | 862.2 | 1011.2 | 1034.8 | 1272.7 | 1272.7 | True / True |
| small-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 2051.2 | 2175.7 | 2187.3 | 2362.0 | 2362.0 | True / False |
| small-city-city-r200-c2-a2-period10s-t2 | 2 / 2 | 200 | 4 | 2154.4 | 2403.5 | 2365.8 | 2501.7 | 2501.7 | True / True |
| small-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 7932.7 | 10415.9 | 10261.8 | 11527.3 | 11527.3 | True / False |
| small-city-city-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 8783.9 | 10083.8 | 9862.9 | 10500.3 | 10500.3 | True / False |
| small-city-city-r1-c8-a8-registry-control-t2 | 8 / 8 | 1 | 120 | 519.2 | 798.4 | 805.4 | 1040.0 | 1235.5 | True / True |
| small-city-city-r50-c4-a4-registry-control-t2 | 4 / 4 | 50 | 40 | 850.5 | 1042.4 | 1092.5 | 1442.9 | 1640.0 | True / True |
| medium-full-reference | 8 / 8 | 1 | 40 | 345.5 | 355.7 | 364.3 | 430.7 | 433.9 | True / True |
| medium-full-idle-c64-w4-t2 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| medium-full-idle-c256-w4-t2 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| medium-full-idle-c1024-w4-t2 | 1024 / 0 | 1 | 0 | — | — | — | — | — | False / True |
| medium-full-person-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 335.3 | 346.3 | 364.5 | 420.8 | 420.8 | True / True |
| medium-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 299.0 | 373.3 | 369.4 | 401.8 | 448.6 | True / True |
| medium-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 333.0 | 819.6 | 813.0 | 1055.4 | 1250.0 | True / True |
| medium-full-person-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 287 | 482.5 | 4098.9 | 4883.2 | 8585.4 | 22544.8 | False / None |
| medium-full-person-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 384.0 | 3507.8 | 3424.6 | 4093.5 | 4301.5 | True / False |
| medium-full-person-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 337.8 | 413.1 | 400.7 | 516.4 | 516.4 | True / True |
| medium-full-person-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 318.8 | 400.1 | 385.7 | 431.7 | 483.0 | True / True |
| medium-full-person-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 372.3 | 2026.9 | 1850.8 | 2444.5 | 2525.9 | True / False |
| medium-full-person-r10-c16-a16-spread-t2 | 16 / 16 | 10 | 64 | 309.4 | 377.3 | 384.5 | 464.2 | 519.1 | True / True |
| medium-full-person-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 511.6 | 551.9 | 564.1 | 689.3 | 689.3 | True / True |
| medium-full-person-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 487.2 | 521.2 | 573.9 | 903.9 | 1213.0 | True / True |
| medium-full-person-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 652.8 | 4450.8 | 4246.7 | 5186.7 | 5508.3 | True / False |
| medium-full-person-r50-c16-a16-spread-t2 | 16 / 16 | 50 | 64 | 571.8 | 2010.4 | 1830.1 | 2390.8 | 2517.8 | True / False |
| medium-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 979.3 | 1170.8 | 1158.9 | 1281.0 | 1281.0 | True / True |
| medium-full-person-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 1186.0 | 3168.9 | 3098.4 | 3574.9 | 3933.2 | True / False |
| medium-full-person-r200-c4-a4-spread-t2 | 4 / 4 | 200 | 16 | 1029.0 | 1166.9 | 1195.6 | 1491.5 | 1491.5 | True / True |
| medium-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 4913.4 | 6154.9 | 6073.0 | 6576.7 | 6576.7 | True / False |
| medium-full-person-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 4463.9 | 4566.9 | 4573.6 | 4696.6 | 4696.6 | True / True |
| medium-full-town-linked-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 357.7 | 367.5 | 367.8 | 375.8 | 375.8 | True / True |
| medium-full-town-linked-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 353.9 | 371.2 | 373.6 | 409.0 | 409.1 | True / True |
| medium-full-town-linked-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 419.3 | 1823.3 | 1630.3 | 2181.9 | 2287.2 | True / False |
| medium-full-town-linked-r1-c16-a16-spread-t2 | 16 / 16 | 1 | 64 | 335.3 | 413.8 | 442.0 | 670.0 | 926.2 | True / True |
| medium-full-town-linked-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 399.2 | 407.4 | 439.8 | 606.5 | 606.5 | True / True |
| medium-full-town-linked-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 394.6 | 409.1 | 435.0 | 585.2 | 602.6 | True / True |
| medium-full-town-linked-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 472.1 | 2890.0 | 2764.9 | 3309.8 | 3683.0 | True / False |
| medium-full-town-linked-r10-c16-a16-spread-t2 | 16 / 16 | 10 | 64 | 455.3 | 608.3 | 614.0 | 734.0 | 797.1 | True / True |
| medium-full-town-linked-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 648.3 | 666.7 | 686.6 | 852.3 | 852.3 | True / True |
| medium-full-town-linked-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 534.8 | 627.6 | 641.3 | 726.9 | 729.5 | True / True |
| medium-full-town-linked-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 1030.2 | 5786.5 | 5623.8 | 6585.3 | 6989.1 | True / False |
| medium-full-town-linked-r50-c16-a16-spread-t2 | 16 / 16 | 50 | 64 | 716.9 | 2820.6 | 2762.0 | 3284.4 | 3504.2 | True / False |
| medium-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1413.1 | 2823.7 | 2639.8 | 3663.1 | 3663.1 | True / False |
| medium-full-town-linked-r200-c2-a2-period10s-t2 | 2 / 2 | 200 | 4 | 1435.8 | 1540.9 | 1588.0 | 1834.4 | 1834.4 | True / True |
| medium-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 6721.8 | 11938.2 | 12057.6 | 18120.4 | 18120.4 | True / False |
| medium-full-town-linked-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 6360.5 | 6927.0 | 7273.9 | 8881.2 | 8881.2 | True / True |
| medium-city-city-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 297.3 | 309.3 | 325.3 | 387.5 | 387.5 | True / True |
| medium-city-city-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 292.1 | 351.1 | 341.1 | 371.8 | 380.1 | True / True |
| medium-city-city-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 336.6 | 706.2 | 747.2 | 1187.0 | 1303.9 | True / True |
| medium-city-city-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 266 | 365.7 | 3695.9 | 4542.3 | 8801.4 | 22707.9 | False / None |
| medium-city-city-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 339.5 | 3411.7 | 3365.4 | 4425.6 | 4671.2 | True / False |
| medium-city-city-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 333.4 | 350.5 | 364.6 | 439.8 | 439.8 | True / True |
| medium-city-city-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 306.9 | 330.3 | 350.8 | 411.5 | 481.4 | True / True |
| medium-city-city-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 367.2 | 2008.0 | 1813.3 | 2343.1 | 2489.0 | True / False |
| medium-city-city-r10-c16-a16-spread-t2 | 16 / 16 | 10 | 64 | 307.4 | 361.1 | 360.1 | 413.3 | 447.7 | True / True |
| medium-city-city-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 473.9 | 514.5 | 514.6 | 556.8 | 556.8 | True / True |
| medium-city-city-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 434.0 | 447.1 | 484.5 | 558.5 | 646.6 | True / True |
| medium-city-city-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 507.0 | 3788.7 | 3703.0 | 4500.4 | 5004.7 | True / False |
| medium-city-city-r50-c16-a16-spread-t2 | 16 / 16 | 50 | 64 | 426.7 | 826.8 | 820.1 | 936.7 | 985.8 | True / True |
| medium-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 938.9 | 958.6 | 972.1 | 1045.2 | 1045.2 | True / True |
| medium-city-city-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 1023.7 | 2325.5 | 2219.5 | 2709.3 | 2778.1 | True / False |
| medium-city-city-r200-c4-a4-spread-t2 | 4 / 4 | 200 | 16 | 814.9 | 883.7 | 883.3 | 1004.1 | 1004.1 | True / True |
| medium-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3368.3 | 4202.8 | 4174.1 | 4682.3 | 4682.3 | True / False |
| medium-city-city-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2891.4 | 3366.7 | 3353.7 | 3789.8 | 3789.8 | True / True |
| medium-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 344.0 | 373.4 | 386.6 | 449.3 | 972.7 | True / True |
| medium-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 316.8 | 377.2 | 378.3 | 411.4 | 483.4 | True / True |
| medium-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 341.4 | 376.1 | 406.7 | 470.1 | 1074.2 | True / True |
| medium-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 423.2 | 445.2 | 467.6 | 542.5 | 854.7 | True / True |
| medium-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 473.3 | 667.7 | 679.6 | 772.8 | 978.4 | True / True |
| medium-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 321.2 | 376.4 | 387.0 | 434.7 | 692.9 | True / True |
| medium-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 328.1 | 393.6 | 384.4 | 418.1 | 433.5 | True / True |
| medium-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 369.8 | 432.3 | 437.4 | 534.1 | 538.2 | True / True |
| medium-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 311.3 | 361.8 | 368.7 | 440.2 | 512.6 | True / True |
| medium-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 285.3 | 307.6 | 316.5 | 391.8 | 406.5 | True / True |
| large-full-reference | 8 / 8 | 1 | 40 | 313.4 | 324.1 | 329.2 | 352.0 | 365.0 | True / True |
| large-full-idle-c64-w4-t2 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| large-full-idle-c256-w4-t2 | 256 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| large-full-person-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 310.8 | 337.3 | 338.4 | 380.9 | 380.9 | True / True |
| large-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 304.3 | 328.4 | 335.8 | 456.7 | 482.1 | True / True |
| large-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 305.5 | 324.3 | 326.9 | 359.1 | 421.7 | True / True |
| large-full-person-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 368.1 | 3515.8 | 3405.4 | 4116.1 | 4416.2 | True / False |
| large-full-person-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 345.5 | 649.8 | 677.0 | 951.4 | 1083.9 | True / True |
| large-full-person-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 328.6 | 338.1 | 341.4 | 371.3 | 371.3 | True / True |
| large-full-person-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 322.7 | 344.2 | 345.8 | 375.1 | 380.8 | True / True |
| large-full-person-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 319.3 | 342.4 | 346.3 | 374.3 | 420.5 | True / True |
| large-full-person-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 394.8 | 4487.2 | 4361.8 | 4901.1 | 5181.8 | True / False |
| large-full-person-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 340.3 | 1907.7 | 1725.7 | 2310.1 | 2480.9 | True / False |
| large-full-person-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 408.6 | 449.4 | 484.7 | 640.2 | 640.2 | True / True |
| large-full-person-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 388.3 | 413.3 | 422.7 | 477.9 | 484.0 | True / True |
| large-full-person-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 429.9 | 853.6 | 873.4 | 1192.1 | 1289.2 | True / True |
| large-full-person-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 1540.3 | 9258.9 | 8976.3 | 9879.1 | 11331.2 | True / False |
| large-full-person-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 472.6 | 4182.1 | 3930.1 | 4468.7 | 4672.3 | True / False |
| large-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 730.3 | 764.9 | 777.4 | 832.6 | 832.6 | True / True |
| large-full-person-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 700.5 | 804.4 | 825.0 | 1051.1 | 1216.2 | True / True |
| large-full-person-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 1222.2 | 5852.0 | 5699.9 | 6491.6 | 6763.6 | True / False |
| large-full-person-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 913.8 | 2808.6 | 2712.7 | 3388.4 | 3663.8 | True / False |
| large-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3324.6 | 3525.4 | 3563.4 | 3968.8 | 3968.8 | True / False |
| large-full-person-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2777.5 | 2904.2 | 2964.1 | 3270.2 | 3270.2 | True / True |
| large-full-town-linked-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 336.3 | 346.5 | 361.1 | 447.7 | 447.7 | True / True |
| large-full-town-linked-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 329.6 | 354.3 | 361.4 | 432.3 | 447.6 | True / True |
| large-full-town-linked-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 323.1 | 349.1 | 352.5 | 386.1 | 408.3 | True / True |
| large-full-town-linked-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 425.1 | 4425.6 | 4264.7 | 5069.0 | 5317.6 | True / False |
| large-full-town-linked-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 393.2 | 1770.7 | 1660.0 | 2206.0 | 2512.7 | True / False |
| large-full-town-linked-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 366.8 | 383.5 | 397.3 | 444.6 | 444.6 | True / True |
| large-full-town-linked-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 348.1 | 373.5 | 374.7 | 417.0 | 481.1 | True / True |
| large-full-town-linked-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 347.8 | 411.2 | 413.3 | 469.4 | 545.2 | True / True |
| large-full-town-linked-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 420.7 | 5725.6 | 5529.5 | 6279.9 | 6601.2 | True / False |
| large-full-town-linked-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 473.4 | 2812.2 | 2670.8 | 3135.3 | 3308.2 | True / False |
| large-full-town-linked-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 451.8 | 480.1 | 482.7 | 517.2 | 517.2 | True / True |
| large-full-town-linked-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 412.9 | 469.4 | 469.1 | 518.0 | 626.1 | True / True |
| large-full-town-linked-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 545.9 | 2874.9 | 2674.7 | 3297.8 | 3506.8 | True / False |
| large-full-town-linked-r50-c16-a16-spread-t2 | 16 / 16 | 50 | 64 | 439.3 | 517.0 | 559.0 | 824.0 | 890.3 | True / True |
| large-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 906.1 | 1063.9 | 1053.7 | 1223.2 | 1223.2 | True / True |
| large-full-town-linked-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 847.4 | 4342.1 | 4019.1 | 6104.9 | 6151.2 | True / False |
| large-full-town-linked-r200-c4-a4-spread-t2 | 4 / 4 | 200 | 16 | 881.7 | 2073.3 | 2005.6 | 3315.4 | 3315.4 | True / False |
| large-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3802.7 | 6960.4 | 6936.8 | 10227.8 | 10227.8 | True / False |
| large-full-town-linked-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 3367.8 | 3604.8 | 3632.2 | 3951.4 | 3951.4 | True / True |
| large-city-city-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 304.6 | 309.8 | 325.0 | 414.1 | 414.1 | True / True |
| large-city-city-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 300.2 | 315.8 | 320.6 | 345.6 | 487.2 | True / True |
| large-city-city-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 297.0 | 321.9 | 326.5 | 390.1 | 444.3 | True / True |
| large-city-city-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 314.1 | 3594.9 | 3369.5 | 3984.3 | 4105.1 | True / False |
| large-city-city-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 314.9 | 504.0 | 567.7 | 1094.6 | 1292.8 | True / True |
| large-city-city-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 310.1 | 318.0 | 328.5 | 374.5 | 374.5 | True / True |
| large-city-city-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 302.4 | 320.1 | 323.9 | 381.9 | 387.9 | True / True |
| large-city-city-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 300.8 | 324.6 | 343.8 | 450.5 | 775.5 | True / True |
| large-city-city-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 413.1 | 4223.2 | 4030.0 | 4662.4 | 4919.3 | True / False |
| large-city-city-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 368.7 | 1489.4 | 1348.4 | 1632.1 | 1724.5 | True / True |
| large-city-city-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 376.9 | 387.3 | 404.8 | 512.8 | 512.8 | True / True |
| large-city-city-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 354.2 | 378.7 | 378.2 | 394.8 | 399.3 | True / True |
| large-city-city-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 403.1 | 520.9 | 601.0 | 1061.9 | 1287.4 | True / True |
| large-city-city-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 662.7 | 7871.3 | 7614.4 | 8487.7 | 8802.5 | True / False |
| large-city-city-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 424.1 | 3626.8 | 3352.4 | 3918.0 | 4130.2 | True / False |
| large-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 590.2 | 604.5 | 610.8 | 635.7 | 635.7 | True / True |
| large-city-city-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 565.0 | 590.0 | 602.7 | 673.7 | 816.9 | True / True |
| large-city-city-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 860.8 | 4569.1 | 4424.4 | 5005.6 | 5183.4 | True / False |
| large-city-city-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 674.6 | 2158.5 | 1932.3 | 2426.0 | 2566.0 | True / False |
| large-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 2197.9 | 2387.7 | 2395.3 | 2711.0 | 2711.0 | True / False |
| large-city-city-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 1737.8 | 1842.1 | 1902.6 | 2188.4 | 2188.4 | True / True |
| large-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 305.8 | 331.3 | 338.3 | 364.8 | 752.8 | True / True |
| large-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 318.6 | 342.0 | 361.5 | 447.0 | 790.7 | True / True |
| large-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 312.5 | 334.2 | 338.1 | 358.8 | 460.9 | True / True |
| large-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 330.9 | 363.4 | 374.2 | 454.8 | 545.3 | True / True |
| large-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 373.4 | 446.1 | 451.1 | 524.1 | 653.4 | True / True |
| large-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 309.6 | 328.9 | 336.8 | 356.7 | 751.3 | True / True |
| large-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 317.9 | 324.2 | 335.9 | 386.1 | 506.9 | True / True |
| large-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 337.5 | 364.8 | 384.7 | 450.9 | 950.3 | True / True |
| large-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 331.3 | 359.1 | 365.1 | 398.8 | 708.1 | True / True |
| large-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 308.2 | 323.7 | 340.6 | 396.9 | 759.8 | True / True |
| xlarge-full-reference | 8 / 8 | 1 | 40 | 315.2 | 329.4 | 344.2 | 423.8 | 451.1 | True / True |
| xlarge-full-idle-c64-w4-t2 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c256-w4-t2 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c1024-w4-t2 | 1024 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c4096-w4-t2 | 4096 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-full-person-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 323.1 | 358.9 | 356.1 | 378.8 | 378.8 | True / True |
| xlarge-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 316.2 | 342.1 | 347.4 | 395.3 | 491.2 | True / True |
| xlarge-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 311.9 | 332.3 | 338.5 | 384.8 | 610.2 | True / True |
| xlarge-full-person-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 356.4 | 1831.6 | 1749.4 | 2742.9 | 2976.1 | True / False |
| xlarge-full-person-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 314.2 | 350.5 | 358.4 | 417.9 | 656.7 | True / True |
| xlarge-full-person-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 341.5 | 374.5 | 379.8 | 465.0 | 465.0 | True / True |
| xlarge-full-person-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 369.1 | 404.1 | 433.8 | 683.9 | 822.4 | True / True |
| xlarge-full-person-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 328.0 | 360.8 | 364.9 | 399.3 | 629.3 | True / True |
| xlarge-full-person-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 360.4 | 2668.2 | 2592.3 | 3927.8 | 4190.6 | True / False |
| xlarge-full-person-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 348.4 | 405.6 | 466.7 | 745.5 | 867.3 | True / True |
| xlarge-full-person-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 415.5 | 440.2 | 460.3 | 606.5 | 606.5 | True / True |
| xlarge-full-person-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 402.6 | 430.1 | 429.2 | 468.0 | 506.3 | True / True |
| xlarge-full-person-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 421.3 | 457.6 | 486.1 | 669.0 | 721.1 | True / True |
| xlarge-full-person-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 482.0 | 5389.4 | 5314.3 | 6398.7 | 6762.7 | True / False |
| xlarge-full-person-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 435.0 | 2342.8 | 2046.5 | 2630.2 | 2728.5 | True / False |
| xlarge-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 658.8 | 688.0 | 697.0 | 765.2 | 765.2 | True / True |
| xlarge-full-person-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 686.2 | 727.1 | 729.3 | 767.4 | 771.1 | True / True |
| xlarge-full-person-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 765.1 | 3365.5 | 3208.3 | 3801.9 | 3986.7 | True / False |
| xlarge-full-person-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 715.3 | 788.4 | 797.8 | 891.2 | 964.4 | True / True |
| xlarge-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 2565.6 | 2851.3 | 2909.9 | 3687.2 | 3687.2 | True / False |
| xlarge-full-person-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2252.6 | 2487.0 | 2565.5 | 3035.4 | 3035.4 | True / True |
| xlarge-full-town-linked-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 341.7 | 368.3 | 363.3 | 375.0 | 375.0 | True / True |
| xlarge-full-town-linked-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 334.2 | 354.7 | 357.1 | 389.0 | 405.1 | True / True |
| xlarge-full-town-linked-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 333.3 | 366.4 | 370.7 | 413.8 | 517.6 | True / True |
| xlarge-full-town-linked-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 430.9 | 2418.9 | 2234.7 | 2977.4 | 3106.9 | True / False |
| xlarge-full-town-linked-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 351.0 | 417.6 | 429.7 | 550.9 | 613.0 | True / True |
| xlarge-full-town-linked-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 364.9 | 373.3 | 378.2 | 418.6 | 418.6 | True / True |
| xlarge-full-town-linked-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 362.0 | 380.8 | 382.2 | 409.0 | 419.8 | True / True |
| xlarge-full-town-linked-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 352.8 | 380.6 | 386.4 | 433.4 | 505.5 | True / True |
| xlarge-full-town-linked-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 405.2 | 3475.7 | 3284.4 | 4208.6 | 4482.3 | True / False |
| xlarge-full-town-linked-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 373.1 | 429.2 | 506.5 | 862.4 | 996.6 | True / True |
| xlarge-full-town-linked-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 428.1 | 458.9 | 460.9 | 498.2 | 498.2 | True / True |
| xlarge-full-town-linked-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 418.4 | 464.8 | 464.2 | 518.3 | 522.2 | True / True |
| xlarge-full-town-linked-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 460.2 | 736.9 | 796.8 | 1401.8 | 1545.1 | True / True |
| xlarge-full-town-linked-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 585.7 | 7602.6 | 7337.1 | 8335.2 | 9042.1 | True / False |
| xlarge-full-town-linked-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 512.2 | 3436.9 | 3339.6 | 4361.5 | 4555.5 | True / False |
| xlarge-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 807.7 | 873.8 | 880.7 | 1001.0 | 1001.0 | True / True |
| xlarge-full-town-linked-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 729.7 | 1928.3 | 2110.6 | 3727.3 | 3800.8 | True / False |
| xlarge-full-town-linked-r200-c4-a4-spread-t2 | 4 / 4 | 200 | 16 | 733.3 | 907.4 | 1007.6 | 1585.9 | 1585.9 | True / True |
| xlarge-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 2457.2 | 4359.8 | 4885.4 | 7952.9 | 7952.9 | True / False |
| xlarge-full-town-linked-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2770.8 | 3141.8 | 3209.9 | 3785.3 | 3785.3 | True / True |
| xlarge-city-city-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 307.6 | 312.9 | 320.9 | 373.0 | 373.0 | True / True |
| xlarge-city-city-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 304.4 | 326.2 | 338.3 | 442.1 | 456.7 | True / True |
| xlarge-city-city-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 302.6 | 320.6 | 322.0 | 348.0 | 493.7 | True / True |
| xlarge-city-city-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 297.4 | 350.4 | 396.6 | 663.2 | 888.2 | True / True |
| xlarge-city-city-r1-c512-a512-spread-t2 | 512 / 512 | 1 | 2048 | 426.6 | 7613.2 | 7486.2 | 8866.8 | 9313.5 | True / False |
| xlarge-city-city-r1-c256-a256-spread-t2 | 256 / 256 | 1 | 1024 | 362.0 | 3579.4 | 3289.9 | 4364.1 | 4726.9 | True / False |
| xlarge-city-city-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 328.6 | 341.7 | 342.4 | 354.6 | 354.6 | True / True |
| xlarge-city-city-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 310.4 | 333.2 | 337.7 | 377.0 | 460.8 | True / True |
| xlarge-city-city-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 309.9 | 333.7 | 337.3 | 384.1 | 448.0 | True / True |
| xlarge-city-city-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 326.1 | 1924.7 | 1566.3 | 2190.5 | 2355.4 | True / False |
| xlarge-city-city-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 313.3 | 341.0 | 355.8 | 479.8 | 721.2 | True / True |
| xlarge-city-city-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 355.6 | 377.5 | 378.8 | 408.2 | 408.2 | True / True |
| xlarge-city-city-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 374.8 | 387.7 | 395.0 | 432.5 | 545.3 | True / True |
| xlarge-city-city-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 347.6 | 371.4 | 374.0 | 398.7 | 453.8 | True / True |
| xlarge-city-city-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 424.0 | 3903.4 | 3732.7 | 4438.8 | 4798.2 | True / False |
| xlarge-city-city-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 372.3 | 421.8 | 431.2 | 518.6 | 588.8 | True / True |
| xlarge-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 533.1 | 574.6 | 574.0 | 611.2 | 611.2 | True / True |
| xlarge-city-city-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 503.2 | 544.2 | 551.2 | 599.6 | 679.6 | True / True |
| xlarge-city-city-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 577.0 | 1701.9 | 1609.6 | 2452.2 | 2546.2 | True / False |
| xlarge-city-city-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 508.7 | 546.2 | 550.3 | 586.0 | 628.4 | True / True |
| xlarge-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 1262.8 | 1414.5 | 1560.2 | 2058.2 | 2058.2 | True / True |
| xlarge-city-city-r1000-c8-a8-spread-t2 | 8 / 8 | 1000 | 32 | 2250.7 | 3205.2 | 3145.3 | 3582.6 | 3881.9 | True / False |
| xlarge-city-city-r1000-c4-a4-spread-t2 | 4 / 4 | 1000 | 16 | 1711.4 | 2019.2 | 2054.9 | 2618.0 | 2618.0 | True / False |
| xlarge-city-city-r5000-c2-a2-spread-t2 | 2 / 2 | 5000 | 8 | 6080.4 | 6759.0 | 6758.1 | 7764.3 | 7764.3 | True / False |
| xlarge-city-city-r5000-c2-a2-period10s-t2 | 2 / 2 | 5000 | 4 | 4646.3 | 4997.2 | 5354.9 | 6778.7 | 6778.7 | True / True |
| xlarge-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 319.6 | 345.5 | 351.9 | 408.2 | 737.3 | True / True |
| xlarge-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 318.8 | 332.9 | 343.3 | 382.7 | 788.0 | True / True |
| xlarge-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 319.0 | 340.2 | 343.9 | 381.6 | 426.3 | True / True |
| xlarge-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 343.9 | 366.0 | 379.1 | 475.7 | 640.9 | True / True |
| xlarge-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 351.3 | 402.7 | 419.1 | 544.0 | 849.4 | True / True |
| xlarge-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 299.0 | 328.0 | 329.1 | 348.8 | 424.6 | True / True |
| xlarge-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 331.1 | 349.6 | 353.8 | 392.5 | 458.0 | True / True |
| xlarge-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 329.3 | 344.8 | 348.1 | 371.0 | 439.6 | True / True |
| xlarge-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 345.0 | 369.1 | 379.4 | 460.1 | 576.7 | True / True |
| xlarge-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 310.2 | 334.6 | 336.5 | 357.0 | 383.8 | True / True |
| xxlarge-full-reference | 8 / 8 | 1 | 40 | 327.6 | 343.8 | 357.5 | 420.6 | 516.1 | True / True |
| xxlarge-full-idle-c64-w4-t2 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c256-w4-t2 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c1024-w4-t2 | 1024 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c4096-w4-t2 | 4096 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| xxlarge-full-person-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 326.5 | 348.9 | 343.8 | 356.8 | 356.8 | True / True |
| xxlarge-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 325.8 | 348.3 | 377.8 | 511.8 | 552.6 | True / True |
| xxlarge-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 311.1 | 337.1 | 349.3 | 413.7 | 646.8 | True / True |
| xxlarge-full-person-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 344.1 | 462.3 | 818.8 | 2067.1 | 2588.9 | True / True |
| xxlarge-full-person-r1-c512-a512-spread-t2 | 512 / 512 | 1 | 2048 | 712.4 | 9076.1 | 8725.3 | 10338.4 | 10842.2 | True / False |
| xxlarge-full-person-r1-c256-a256-spread-t2 | 256 / 256 | 1 | 1024 | 526.9 | 4389.2 | 4209.5 | 4902.2 | 5223.7 | True / False |
| xxlarge-full-person-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 358.2 | 371.8 | 371.8 | 388.8 | 388.8 | True / True |
| xxlarge-full-person-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 348.1 | 382.6 | 380.4 | 413.7 | 426.5 | True / True |
| xxlarge-full-person-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 345.5 | 369.2 | 372.2 | 407.4 | 429.2 | True / True |
| xxlarge-full-person-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 406.6 | 2402.2 | 2373.7 | 3103.6 | 3780.5 | False / False |
| xxlarge-full-person-r10-c64-a64-spread-t2 | 64 / 64 | 10 | 256 | 364.6 | 440.0 | 840.5 | 2485.5 | 2748.4 | True / True |
| xxlarge-full-person-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 422.8 | 426.1 | 429.4 | 438.7 | 438.7 | True / True |
| xxlarge-full-person-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 416.4 | 435.5 | 441.2 | 486.5 | 496.7 | True / True |
| xxlarge-full-person-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 417.2 | 480.3 | 502.7 | 636.3 | 795.4 | True / True |
| xxlarge-full-person-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 516.2 | 3085.9 | 2833.2 | 3513.2 | 3799.4 | True / False |
| xxlarge-full-person-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 434.2 | 531.1 | 549.4 | 721.0 | 872.8 | True / True |
| xxlarge-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 712.3 | 730.9 | 734.3 | 767.2 | 767.2 | True / True |
| xxlarge-full-person-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 661.2 | 719.7 | 725.9 | 764.7 | 857.7 | True / True |
| xxlarge-full-person-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 730.0 | 2089.1 | 1894.6 | 2404.8 | 2518.4 | True / False |
| xxlarge-full-person-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 692.1 | 759.5 | 771.0 | 904.1 | 938.8 | True / True |
| xxlarge-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 2507.1 | 2838.0 | 2882.4 | 3352.3 | 3352.3 | True / False |
| xxlarge-full-person-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2163.8 | 2363.5 | 2375.1 | 2609.8 | 2609.8 | True / True |
| xxlarge-full-town-linked-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 346.5 | 369.2 | 372.4 | 410.8 | 410.8 | True / True |
| xxlarge-full-town-linked-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 332.5 | 348.2 | 352.8 | 379.9 | 400.9 | True / True |
| xxlarge-full-town-linked-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 323.5 | 357.7 | 386.0 | 633.4 | 899.5 | True / True |
| xxlarge-full-town-linked-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 346.6 | 409.7 | 420.9 | 508.9 | 689.8 | True / True |
| xxlarge-full-town-linked-r1-c512-a512-spread-t2 | 512 / 512 | 1 | 0 | — | — | — | — | — | False / None |
| xxlarge-full-town-linked-r1-c256-a256-spread-t2 | 256 / 256 | 1 | 1024 | 402.5 | 2898.1 | 2727.4 | 3355.9 | 3689.3 | True / False |
| xxlarge-full-town-linked-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 365.2 | 398.2 | 398.5 | 422.1 | 422.1 | True / True |
| xxlarge-full-town-linked-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 354.2 | 378.1 | 387.5 | 448.5 | 658.3 | True / True |
| xxlarge-full-town-linked-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 347.7 | 389.7 | 412.4 | 556.0 | 660.1 | True / True |
| xxlarge-full-town-linked-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 370.4 | 680.3 | 674.6 | 870.1 | 916.1 | True / True |
| xxlarge-full-town-linked-r10-c512-a512-spread-t2 | 512 / 512 | 10 | 2048 | 580.4 | 8463.2 | 8106.9 | 8900.6 | 9281.0 | True / False |
| xxlarge-full-town-linked-r10-c256-a256-spread-t2 | 256 / 256 | 10 | 1024 | 393.9 | 4273.5 | 4069.5 | 5098.8 | 5301.2 | True / False |
| xxlarge-full-town-linked-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 435.9 | 446.3 | 449.4 | 481.1 | 481.1 | True / True |
| xxlarge-full-town-linked-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 410.2 | 438.6 | 447.9 | 488.9 | 599.2 | True / True |
| xxlarge-full-town-linked-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 436.8 | 495.9 | 540.5 | 932.9 | 1257.4 | True / True |
| xxlarge-full-town-linked-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 488.7 | 4558.2 | 4295.0 | 4838.4 | 5107.3 | True / False |
| xxlarge-full-town-linked-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 496.2 | 2136.4 | 1915.5 | 2394.7 | 2504.5 | True / False |
| xxlarge-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 721.9 | 865.0 | 850.3 | 941.2 | 941.2 | True / True |
| xxlarge-full-town-linked-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 730.5 | 1945.0 | 2081.0 | 3457.8 | 3556.4 | True / False |
| xxlarge-full-town-linked-r200-c4-a4-spread-t2 | 4 / 4 | 200 | 16 | 763.3 | 1016.5 | 1079.1 | 1549.7 | 1549.7 | True / True |
| xxlarge-full-town-linked-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3046.4 | 4592.8 | 4587.4 | 6414.9 | 6414.9 | True / False |
| xxlarge-full-town-linked-r1000-c2-a2-period10s-t2 | 2 / 2 | 1000 | 4 | 2141.2 | 2673.2 | 2631.7 | 3039.3 | 3039.3 | True / True |
| xxlarge-city-city-r1-c2-a2-spread-t2 | 2 / 2 | 1 | 8 | 323.9 | 346.2 | 352.4 | 412.1 | 412.1 | True / True |
| xxlarge-city-city-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 296.7 | 318.9 | 320.2 | 334.0 | 383.4 | True / True |
| xxlarge-city-city-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 299.2 | 319.4 | 325.3 | 354.8 | 471.0 | True / True |
| xxlarge-city-city-r1-c128-a128-spread-t2 | 128 / 128 | 1 | 512 | 293.8 | 333.6 | 342.6 | 422.9 | 574.8 | True / True |
| xxlarge-city-city-r1-c512-a512-spread-t2 | 512 / 512 | 1 | 2048 | 384.7 | 5738.1 | 5501.2 | 6511.6 | 7170.9 | True / False |
| xxlarge-city-city-r1-c256-a256-spread-t2 | 256 / 256 | 1 | 1024 | 313.4 | 2615.5 | 2306.6 | 3235.1 | 3372.1 | True / False |
| xxlarge-city-city-r10-c2-a2-spread-t2 | 2 / 2 | 10 | 8 | 326.4 | 353.4 | 353.7 | 381.3 | 381.3 | True / True |
| xxlarge-city-city-r10-c8-a8-spread-t2 | 8 / 8 | 10 | 32 | 310.7 | 336.0 | 340.3 | 370.1 | 421.1 | True / True |
| xxlarge-city-city-r10-c32-a32-spread-t2 | 32 / 32 | 10 | 128 | 294.5 | 334.0 | 334.4 | 359.5 | 391.5 | True / True |
| xxlarge-city-city-r10-c128-a128-spread-t2 | 128 / 128 | 10 | 512 | 325.8 | 393.9 | 427.7 | 656.1 | 786.3 | True / True |
| xxlarge-city-city-r10-c512-a512-spread-t2 | 512 / 512 | 10 | 2048 | 398.5 | 7295.8 | 6965.1 | 8053.5 | 8569.8 | True / False |
| xxlarge-city-city-r10-c256-a256-spread-t2 | 256 / 256 | 10 | 1024 | 366.3 | 3873.5 | 3579.5 | 4540.3 | 4973.4 | True / False |
| xxlarge-city-city-r50-c2-a2-spread-t2 | 2 / 2 | 50 | 8 | 378.3 | 396.3 | 397.5 | 414.7 | 414.7 | True / True |
| xxlarge-city-city-r50-c8-a8-spread-t2 | 8 / 8 | 50 | 32 | 356.2 | 379.9 | 389.1 | 430.9 | 572.3 | True / True |
| xxlarge-city-city-r50-c32-a32-spread-t2 | 32 / 32 | 50 | 128 | 352.0 | 384.6 | 389.7 | 439.9 | 500.6 | True / True |
| xxlarge-city-city-r50-c128-a128-spread-t2 | 128 / 128 | 50 | 512 | 410.4 | 3095.0 | 3061.3 | 4124.3 | 4670.1 | True / False |
| xxlarge-city-city-r50-c64-a64-spread-t2 | 64 / 64 | 50 | 256 | 386.9 | 474.5 | 580.0 | 1006.7 | 1149.2 | True / True |
| xxlarge-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 554.5 | 587.1 | 585.0 | 607.7 | 607.7 | True / True |
| xxlarge-city-city-r200-c8-a8-spread-t2 | 8 / 8 | 200 | 32 | 540.0 | 592.4 | 592.7 | 638.9 | 649.6 | True / True |
| xxlarge-city-city-r200-c32-a32-spread-t2 | 32 / 32 | 200 | 128 | 700.0 | 2473.9 | 2315.2 | 2970.9 | 3102.9 | True / False |
| xxlarge-city-city-r200-c16-a16-spread-t2 | 16 / 16 | 200 | 64 | 501.5 | 614.5 | 640.5 | 806.0 | 847.0 | True / True |
| xxlarge-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 1459.4 | 1800.3 | 1852.4 | 2410.5 | 2410.5 | True / True |
| xxlarge-city-city-r1000-c8-a8-spread-t2 | 8 / 8 | 1000 | 32 | 1820.3 | 3277.0 | 3310.1 | 4292.0 | 4517.5 | True / False |
| xxlarge-city-city-r1000-c4-a4-spread-t2 | 4 / 4 | 1000 | 16 | 1824.7 | 2173.3 | 2222.1 | 2722.5 | 2722.5 | True / False |
| xxlarge-city-city-r5000-c2-a2-spread-t2 | 2 / 2 | 5000 | 8 | 6072.3 | 6338.0 | 6414.4 | 6851.9 | 6851.9 | True / False |
| xxlarge-city-city-r5000-c2-a2-period10s-t2 | 2 / 2 | 5000 | 4 | 5412.1 | 6019.2 | 6055.0 | 6769.4 | 6769.4 | True / True |
| xxlarge-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 328.0 | 351.5 | 357.2 | 395.9 | 560.5 | True / True |
| xxlarge-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 346.5 | 372.2 | 387.1 | 459.8 | 859.9 | True / True |
| xxlarge-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 355.9 | 383.0 | 391.3 | 423.7 | 862.3 | True / True |
| xxlarge-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 365.0 | 393.0 | 396.5 | 418.7 | 490.6 | True / True |
| xxlarge-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 423.2 | 476.6 | 473.6 | 506.1 | 539.3 | True / True |
| xxlarge-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 318.0 | 338.4 | 338.1 | 356.4 | 450.4 | True / True |
| xxlarge-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 348.3 | 360.1 | 380.1 | 477.0 | 482.1 | True / True |
| xxlarge-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 367.7 | 378.6 | 378.7 | 394.2 | 408.9 | True / True |
| xxlarge-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 387.5 | 411.7 | 413.2 | 438.7 | 517.4 | True / True |
| xxlarge-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 293.2 | 308.3 | 312.1 | 334.1 | 448.9 | True / True |

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
| medium-full-idle-c64-w4-t2 | 64 | 64 | True | 32 | 1002.1 / 1024.9 / 1196.8 | 114.9 | True |
| medium-full-idle-c256-w4-t2 | 256 | 256 | True | 128 | 1004.6 / 1012.0 / 1205.9 | 190.0 | True |
| medium-full-idle-c1024-w4-t2 | 1024 | 1024 | True | 512 | 1579.7 / 1606.0 / 2101.8 | 475.9 | False |
| large-full-idle-c64-w4-t2 | 64 | 64 | True | 32 | 521.5 / 512.3 / 614.2 | 119.9 | True |
| large-full-idle-c256-w4-t2 | 256 | 254 | False | 0 | — | 156.9 | False |
| xlarge-full-idle-c64-w4-t2 | 64 | 64 | True | 32 | 394.1 / 522.4 / 1080.3 | 114.3 | True |
| xlarge-full-idle-c256-w4-t2 | 256 | 256 | True | 128 | 365.7 / 375.1 / 461.0 | 178.5 | True |
| xlarge-full-idle-c1024-w4-t2 | 1024 | 1024 | True | 512 | 392.2 / 403.9 / 505.2 | 473.2 | True |
| xlarge-full-idle-c4096-w4-t2 | 4096 | 2048 | False | 0 | — | 984.9 | False |
| xxlarge-full-idle-c64-w4-t2 | 64 | 64 | True | 32 | 434.2 / 436.2 / 511.3 | 116.1 | True |
| xxlarge-full-idle-c256-w4-t2 | 256 | 256 | True | 128 | 370.4 / 384.2 / 474.7 | 177.7 | True |
| xxlarge-full-idle-c1024-w4-t2 | 1024 | 1024 | True | 512 | 378.2 / 384.7 / 460.2 | 433.2 | True |
| xxlarge-full-idle-c4096-w4-t2 | 4096 | 3824 | False | 0 | — | 1475.3 | False |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.
