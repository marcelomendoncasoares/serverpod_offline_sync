# Native TLS capacity measurements

Read the [CPU accounting qualification](RESOURCE_ACCOUNTING.md) and [Cloud artifact provenance](ARTIFACT_PROVENANCE.json). These are single-campaign observations; exact starting domain-table counts are recorded per case.

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| small-full-reference | 8 / 8 | 1 | 40 | 648.4 | 768.4 | 836.1 | 1147.6 | 1164.3 | True / True |
| small-full-idle-c64-w1 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-idle-c256-w1 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| small-full-idle-c1024-w1 | 1024 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| small-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 818.1 | 917.3 | 910.3 | 1017.4 | 1017.4 | True / True |
| small-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 804.0 | 1202.0 | 1347.9 | 2199.6 | 2282.8 | True / True |
| small-full-person-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 894.4 | 4198.1 | 4386.0 | 6500.4 | 10847.2 | True / False |
| small-full-person-r1-c16-a16-spread | 16 / 16 | 1 | 64 | 756.7 | 2312.4 | 2257.7 | 2600.7 | 2704.9 | True / False |
| small-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 680.6 | 835.7 | 835.2 | 982.9 | 982.9 | True / True |
| small-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 992.1 | 1579.6 | 1577.4 | 2291.6 | 2413.4 | True / True |
| small-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 923.2 | 1187.4 | 1199.2 | 1491.9 | 1491.9 | True / True |
| small-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 1497.5 | 2551.4 | 2563.4 | 3180.8 | 3391.9 | True / False |
| small-full-person-r50-c4-a4-spread | 4 / 4 | 50 | 16 | 1002.4 | 1322.6 | 1438.4 | 2101.8 | 2101.8 | True / True |
| small-full-person-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 2125.2 | 2633.9 | 2634.7 | 3337.4 | 3337.4 | True / False |
| small-full-town-linked-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 726.2 | 872.2 | 921.3 | 1326.0 | 1326.0 | True / True |
| small-full-town-linked-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 1108.1 | 1715.7 | 1806.2 | 2594.8 | 2900.0 | True / False |
| small-full-town-linked-r1-c4-a4-spread | 4 / 4 | 1 | 16 | 689.9 | 809.5 | 895.7 | 1298.5 | 1298.5 | True / True |
| small-full-town-linked-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 901.2 | 999.5 | 1099.7 | 1501.2 | 1501.2 | True / True |
| small-full-town-linked-r10-c4-a4-spread | 4 / 4 | 10 | 16 | 799.1 | 990.8 | 1013.7 | 1375.3 | 1375.3 | True / True |
| small-full-town-linked-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 1353.7 | 1506.8 | 1532.5 | 1863.0 | 1863.0 | True / True |
| small-full-town-linked-r50-c4-a4-spread | 4 / 4 | 50 | 16 | 1903.2 | 2556.4 | 2577.6 | 3188.2 | 3188.2 | True / False |
| small-full-town-linked-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 3153.9 | 3408.6 | 3488.5 | 4025.2 | 4025.2 | True / False |
| small-city-city-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 482.3 | 777.5 | 727.1 | 900.0 | 900.0 | True / True |
| small-city-city-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 383.2 | 495.0 | 581.0 | 1069.3 | 1365.5 | True / True |
| small-city-city-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 495.9 | 4014.0 | 4792.2 | 8594.1 | 15348.0 | True / False |
| small-city-city-r1-c16-a16-spread | 16 / 16 | 1 | 64 | 654.3 | 1803.2 | 1727.6 | 2150.9 | 2310.7 | True / False |
| small-city-city-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 600.8 | 696.4 | 684.8 | 816.6 | 816.6 | True / True |
| small-city-city-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 408.3 | 606.0 | 651.5 | 901.8 | 903.8 | True / True |
| small-city-city-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 787.2 | 841.6 | 856.4 | 998.8 | 998.8 | True / True |
| small-city-city-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 873.1 | 2140.6 | 2035.5 | 2576.6 | 2798.1 | True / False |
| small-city-city-r50-c4-a4-spread | 4 / 4 | 50 | 16 | 709.4 | 823.4 | 891.8 | 1257.8 | 1257.8 | True / True |
| small-city-city-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 1553.0 | 1625.3 | 1666.6 | 1977.5 | 1977.5 | True / True |
| small-city-city-r200-c4-a4-spread | 4 / 4 | 200 | 16 | 1965.6 | 2571.6 | 2794.2 | 4558.5 | 4558.5 | True / False |
| small-city-city-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 5633.4 | 6273.5 | 6222.8 | 7068.9 | 7068.9 | True / False |
| small-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 688.5 | 1104.9 | 1198.8 | 1990.2 | 2316.7 | True / True |
| small-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 936.2 | 1358.2 | 1398.9 | 1835.3 | 2349.3 | True / True |
| small-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 980.7 | 2000.2 | 2004.5 | 2593.2 | 2998.3 | True / False |
| small-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 812.2 | 2104.4 | 2113.2 | 2698.3 | 2945.5 | True / False |
| small-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 1059.8 | 1575.8 | 1588.5 | 1973.7 | 2284.9 | True / True |
| small-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 688.6 | 1099.8 | 1176.4 | 1682.7 | 2083.2 | True / True |
| small-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 687.3 | 798.1 | 803.4 | 993.3 | 1103.5 | True / True |
| small-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 825.4 | 929.8 | 990.2 | 1421.2 | 1520.7 | True / True |
| small-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 601.1 | 1008.7 | 1088.8 | 1682.7 | 2366.0 | True / True |
| small-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 644.9 | 1018.1 | 1012.0 | 1339.4 | 1547.5 | True / True |
| medium-full-reference | 8 / 8 | 1 | 40 | 343.8 | 360.8 | 381.9 | 441.1 | 813.3 | True / True |
| medium-full-idle-c64-w4 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| medium-full-idle-c256-w4 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| medium-full-idle-c1024-w4 | 1024 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| medium-full-idle-c4096-w4 | 4096 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| medium-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 325.8 | 402.8 | 387.1 | 417.7 | 417.7 | True / True |
| medium-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 364.6 | 385.0 | 393.6 | 435.9 | 580.1 | True / True |
| medium-full-person-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 377.3 | 933.5 | 983.2 | 1650.2 | 1917.3 | True / True |
| medium-full-person-r1-c128-a128-spread | 128 / 128 | 1 | 330 | 573.2 | 4178.0 | 5025.0 | 9111.0 | 23620.4 | False / None |
| medium-full-person-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 432.5 | 3200.1 | 3013.9 | 3502.4 | 3642.5 | True / False |
| medium-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 373.3 | 403.1 | 405.5 | 435.9 | 435.9 | True / True |
| medium-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 374.3 | 402.7 | 404.9 | 430.8 | 530.7 | True / True |
| medium-full-person-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 424.4 | 1750.4 | 1680.0 | 2188.9 | 2356.0 | True / False |
| medium-full-person-r10-c16-a16-spread | 16 / 16 | 10 | 64 | 324.2 | 407.5 | 426.2 | 576.7 | 755.0 | True / True |
| medium-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 502.2 | 584.5 | 579.5 | 616.8 | 616.8 | True / True |
| medium-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 493.8 | 555.4 | 548.8 | 607.5 | 630.8 | True / True |
| medium-full-person-r50-c16-a16-spread | 16 / 16 | 50 | 64 | 588.4 | 1003.1 | 985.9 | 1168.5 | 1263.9 | True / True |
| medium-full-person-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 939.2 | 1060.4 | 1083.6 | 1275.5 | 1275.5 | True / True |
| medium-full-person-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 1138.4 | 2392.2 | 2326.8 | 2835.7 | 3014.3 | True / False |
| medium-full-person-r200-c4-a4-spread | 4 / 4 | 200 | 16 | 947.6 | 1071.7 | 1076.9 | 1239.3 | 1239.3 | True / True |
| medium-full-person-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 3492.7 | 3819.2 | 3912.0 | 4407.4 | 4407.4 | True / False |
| medium-full-town-linked-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 384.3 | 435.1 | 433.8 | 480.3 | 480.3 | True / True |
| medium-full-town-linked-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 341.0 | 410.2 | 426.3 | 599.7 | 752.6 | True / True |
| medium-full-town-linked-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 394.6 | 1199.4 | 1164.0 | 1398.4 | 1560.2 | True / True |
| medium-full-town-linked-r1-c128-a128-spread | 128 / 128 | 1 | 390 | 709.5 | 6196.5 | 7016.5 | 10885.9 | 24871.9 | False / None |
| medium-full-town-linked-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 529.5 | 4094.8 | 3907.2 | 4760.5 | 5020.8 | True / False |
| medium-full-town-linked-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 409.4 | 426.0 | 434.8 | 516.7 | 516.7 | True / True |
| medium-full-town-linked-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 417.8 | 452.3 | 457.3 | 535.7 | 548.0 | True / True |
| medium-full-town-linked-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 524.9 | 2401.1 | 2326.8 | 2778.4 | 3003.3 | True / False |
| medium-full-town-linked-r10-c16-a16-spread | 16 / 16 | 10 | 64 | 395.0 | 512.8 | 524.9 | 682.3 | 738.1 | True / True |
| medium-full-town-linked-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 671.6 | 679.4 | 696.0 | 781.6 | 781.6 | True / True |
| medium-full-town-linked-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 583.6 | 687.4 | 691.1 | 801.7 | 881.9 | True / True |
| medium-full-town-linked-r50-c16-a16-spread | 16 / 16 | 50 | 64 | 758.0 | 2383.3 | 2278.5 | 2692.8 | 2882.6 | True / False |
| medium-full-town-linked-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 1188.6 | 1279.5 | 1384.2 | 1815.3 | 1815.3 | True / True |
| medium-full-town-linked-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 1473.8 | 3298.5 | 3208.8 | 3733.6 | 3814.0 | True / False |
| medium-full-town-linked-r200-c4-a4-spread | 4 / 4 | 200 | 16 | 1144.9 | 1233.7 | 1292.9 | 1604.4 | 1604.4 | True / True |
| medium-full-town-linked-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 5019.7 | 5252.2 | 5382.1 | 5987.9 | 5987.9 | True / False |
| medium-city-city-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 301.1 | 310.5 | 328.5 | 375.9 | 375.9 | True / True |
| medium-city-city-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 306.5 | 332.3 | 335.3 | 357.6 | 430.8 | True / True |
| medium-city-city-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 385.5 | 514.5 | 519.8 | 615.8 | 782.0 | True / True |
| medium-city-city-r1-c128-a128-spread | 128 / 128 | 1 | 334 | 480.4 | 3942.9 | 4485.4 | 7979.8 | 22169.9 | False / None |
| medium-city-city-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 393.0 | 2892.3 | 2691.2 | 3290.3 | 3596.0 | True / False |
| medium-city-city-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 325.1 | 375.9 | 369.8 | 381.3 | 381.3 | True / True |
| medium-city-city-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 350.3 | 371.2 | 384.7 | 463.1 | 561.1 | True / True |
| medium-city-city-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 425.1 | 956.4 | 926.8 | 1137.8 | 1322.9 | True / True |
| medium-city-city-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 447.9 | 507.1 | 502.2 | 559.3 | 559.3 | True / True |
| medium-city-city-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 442.7 | 466.4 | 498.3 | 661.3 | 764.6 | True / True |
| medium-city-city-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 491.1 | 2817.3 | 2683.4 | 3177.9 | 3338.2 | True / False |
| medium-city-city-r50-c16-a16-spread | 16 / 16 | 50 | 64 | 488.4 | 593.5 | 597.5 | 702.2 | 801.5 | True / True |
| medium-city-city-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 777.8 | 817.6 | 826.4 | 885.8 | 885.8 | True / True |
| medium-city-city-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 752.1 | 956.6 | 959.5 | 1145.2 | 1155.8 | True / True |
| medium-city-city-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 1314.0 | 3448.8 | 3375.4 | 4249.5 | 4952.7 | True / False |
| medium-city-city-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 2234.0 | 2469.6 | 2722.2 | 3614.9 | 3614.9 | True / False |
| medium-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 136 | 349.2 | 375.5 | 390.8 | 466.4 | 559.4 | False / None |
| medium-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 345.2 | 374.4 | 384.8 | 454.3 | 468.9 | False / True |
| medium-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 373.8 | 464.6 | 469.0 | 572.4 | 1162.6 | True / True |
| medium-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 471.3 | 661.5 | 644.0 | 762.3 | 860.7 | True / True |
| medium-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 295.3 | 370.6 | 375.6 | 393.1 | 977.0 | True / True |
| medium-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 335.5 | 365.8 | 388.7 | 511.6 | 535.2 | True / True |
| medium-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 383.0 | 401.3 | 430.4 | 570.4 | 594.7 | True / True |
| medium-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 299.8 | 329.6 | 352.8 | 406.1 | 1003.0 | True / True |
| medium-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 303.7 | 367.9 | 362.9 | 384.6 | 441.1 | True / True |
| large-full-reference | 8 / 8 | 1 | 40 | 314.2 | 331.0 | 332.0 | 350.2 | 361.8 | True / True |
| large-full-idle-c64-w4 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| large-full-idle-c256-w4 | 256 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| large-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 301.9 | 324.4 | 326.5 | 356.6 | 356.6 | True / True |
| large-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 306.1 | 342.3 | 357.5 | 444.4 | 455.3 | True / True |
| large-full-person-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 300.3 | 328.0 | 329.0 | 370.3 | 449.4 | True / True |
| large-full-person-r1-c128-a128-spread | 128 / 128 | 1 | 509 | 396.6 | 2939.1 | 2818.6 | 3295.7 | 3518.9 | False / False |
| large-full-person-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 338.1 | 404.2 | 405.9 | 478.4 | 529.2 | True / True |
| large-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 336.6 | 355.4 | 388.6 | 638.4 | 638.4 | True / True |
| large-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 321.2 | 362.6 | 383.1 | 520.8 | 524.6 | True / True |
| large-full-person-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 319.7 | 353.0 | 354.3 | 386.1 | 533.8 | False / True |
| large-full-person-r10-c16-a16-spread | 16 / 16 | 10 | 64 | 320.3 | 348.4 | 352.5 | 403.7 | 453.7 | True / True |
| large-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 384.5 | 400.0 | 404.7 | 434.6 | 434.6 | True / True |
| large-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 381.1 | 412.4 | 419.4 | 479.7 | 547.7 | True / True |
| large-full-person-r50-c16-a16-spread | 16 / 16 | 50 | 64 | 375.2 | 411.0 | 412.3 | 450.0 | 528.3 | True / True |
| large-full-person-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 686.6 | 758.5 | 745.8 | 808.7 | 808.7 | True / True |
| large-full-person-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 637.3 | 701.4 | 708.1 | 779.9 | 792.7 | True / True |
| large-full-person-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 765.9 | 2105.7 | 1977.6 | 2365.4 | 2447.8 | True / False |
| large-full-person-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 2050.2 | 2319.7 | 2456.4 | 3186.9 | 3186.9 | True / False |
| large-full-town-linked-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 343.4 | 363.1 | 390.8 | 616.2 | 616.2 | True / True |
| large-full-town-linked-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 327.0 | 350.6 | 352.4 | 381.8 | 412.5 | True / True |
| large-full-town-linked-r1-c32-a32-spread | 32 / 32 | 1 | 0 | — | — | — | — | — | False / None |
| large-full-town-linked-r1-c16-a16-spread | 16 / 16 | 1 | 64 | 327.3 | 354.3 | 358.6 | 388.9 | 518.4 | True / True |
| large-full-town-linked-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 360.9 | 370.0 | 369.8 | 390.1 | 390.1 | True / True |
| large-full-town-linked-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 338.5 | 365.2 | 364.9 | 389.4 | 390.5 | True / True |
| large-full-town-linked-r10-c16-a16-spread | 16 / 16 | 10 | 64 | 339.6 | 364.5 | 368.6 | 408.1 | 421.8 | True / True |
| large-full-town-linked-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 432.6 | 461.9 | 460.9 | 483.7 | 483.7 | True / True |
| large-full-town-linked-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 406.3 | 440.4 | 450.9 | 510.1 | 574.5 | True / True |
| large-full-town-linked-r50-c16-a16-spread | 16 / 16 | 50 | 64 | 404.7 | 433.7 | 450.6 | 522.1 | 844.2 | True / True |
| large-full-town-linked-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 777.3 | 838.5 | 832.6 | 881.3 | 881.3 | True / True |
| large-full-town-linked-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 736.8 | 789.3 | 804.9 | 960.8 | 962.5 | True / True |
| large-full-town-linked-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 840.5 | 2976.1 | 2906.6 | 3734.5 | 3817.4 | True / False |
| large-full-town-linked-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 2639.8 | 2831.2 | 2907.1 | 3415.2 | 3415.2 | True / False |
| large-city-city-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 292.2 | 355.5 | 359.7 | 448.0 | 448.0 | True / True |
| large-city-city-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 288.6 | 310.7 | 313.7 | 373.8 | 383.5 | True / True |
| large-city-city-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 290.3 | 323.4 | 332.4 | 431.1 | 518.1 | True / True |
| large-city-city-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 345.9 | 2707.6 | 2472.5 | 3013.1 | 3479.9 | True / False |
| large-city-city-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 287.3 | 329.3 | 336.4 | 397.1 | 497.7 | True / True |
| large-city-city-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 299.9 | 312.9 | 313.4 | 328.3 | 328.3 | True / True |
| large-city-city-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 297.5 | 317.9 | 320.3 | 346.1 | 352.0 | True / True |
| large-city-city-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 295.3 | 331.3 | 333.0 | 392.1 | 538.1 | True / True |
| large-city-city-r10-c64-a64-spread | 64 / 64 | 10 | 256 | 341.0 | 423.3 | 460.2 | 721.3 | 865.1 | True / True |
| large-city-city-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 355.9 | 377.7 | 384.6 | 424.3 | 424.3 | True / True |
| large-city-city-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 324.2 | 357.4 | 356.8 | 376.0 | 385.3 | True / True |
| large-city-city-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 331.8 | 369.4 | 390.6 | 533.1 | 646.4 | True / True |
| large-city-city-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 418.4 | 2697.0 | 2534.6 | 3357.2 | 3499.4 | True / False |
| large-city-city-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 541.9 | 595.6 | 591.6 | 612.1 | 612.1 | True / True |
| large-city-city-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 531.2 | 577.8 | 600.0 | 747.6 | 759.8 | True / True |
| large-city-city-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 639.1 | 3255.6 | 3147.2 | 4011.2 | 4198.2 | True / False |
| large-city-city-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 496.2 | 551.6 | 567.0 | 701.2 | 717.7 | True / True |
| large-city-city-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1356.5 | 1615.4 | 1650.4 | 2017.9 | 2017.9 | True / True |
| large-city-city-r1000-c8-a8-spread | 8 / 8 | 1000 | 32 | 1567.2 | 3617.6 | 3644.1 | 4973.3 | 4988.0 | True / False |
| large-city-city-r1000-c4-a4-spread | 4 / 4 | 1000 | 16 | 1368.8 | 1592.4 | 1681.8 | 2173.3 | 2173.3 | True / True |
| large-city-city-r5000-c2-a2-spread | 2 / 2 | 5000 | 8 | 5891.4 | 6823.1 | 6877.3 | 7989.2 | 7989.2 | True / False |
| large-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 299.5 | 330.5 | 335.5 | 372.2 | 919.0 | True / True |
| large-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 311.1 | 328.7 | 332.0 | 348.4 | 556.3 | True / True |
| large-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 314.8 | 325.7 | 342.4 | 442.1 | 678.5 | True / True |
| large-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 316.9 | 337.1 | 345.8 | 390.9 | 546.0 | True / True |
| large-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 335.9 | 425.0 | 410.7 | 461.2 | 520.0 | True / True |
| large-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 293.6 | 324.6 | 326.0 | 347.3 | 489.0 | True / True |
| large-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 311.0 | 331.5 | 330.5 | 351.6 | 390.7 | True / True |
| large-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 331.2 | 361.2 | 368.3 | 423.4 | 450.2 | True / True |
| large-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 296.2 | 325.2 | 328.4 | 349.4 | 519.2 | True / True |
| large-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 285.5 | 314.7 | 317.0 | 344.6 | 534.8 | True / True |
| xlarge-full-reference | 8 / 8 | 1 | 40 | 333.8 | 357.2 | 362.5 | 382.1 | 471.6 | True / True |
| xlarge-full-idle-c64-w4 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c256-w4 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xlarge-full-idle-c1024-w4 | 1024 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 315.8 | 327.3 | 327.3 | 345.4 | 345.4 | True / True |
| xlarge-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 310.8 | 338.7 | 339.5 | 359.0 | 367.1 | True / True |
| xlarge-full-person-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 312.6 | 345.9 | 348.0 | 383.6 | 521.5 | True / True |
| xlarge-full-person-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 309.2 | 364.9 | 390.2 | 548.3 | 762.2 | True / True |
| xlarge-full-person-r1-c512-a512-spread | 512 / 512 | 1 | 2048 | 419.7 | 6700.3 | 6376.9 | 7370.1 | 7676.2 | True / False |
| xlarge-full-person-r1-c256-a256-spread | 256 / 256 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 347.2 | 369.8 | 371.5 | 410.9 | 410.9 | True / True |
| xlarge-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 338.8 | 364.8 | 366.5 | 394.5 | 481.7 | True / True |
| xlarge-full-person-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 324.6 | 358.3 | 358.2 | 389.6 | 400.7 | True / True |
| xlarge-full-person-r10-c128-a128-spread | 128 / 128 | 10 | 512 | 361.7 | 969.1 | 1005.8 | 1639.0 | 1767.1 | True / True |
| xlarge-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 410.6 | 450.6 | 455.8 | 559.0 | 559.0 | True / True |
| xlarge-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 398.7 | 420.6 | 422.9 | 460.6 | 485.1 | True / True |
| xlarge-full-person-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 396.4 | 463.4 | 483.3 | 618.2 | 642.5 | True / True |
| xlarge-full-person-r50-c128-a128-spread | 128 / 128 | 50 | 512 | 527.1 | 3312.2 | 3122.4 | 3537.9 | 3755.8 | True / False |
| xlarge-full-person-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 413.5 | 482.6 | 494.9 | 567.5 | 744.5 | True / True |
| xlarge-full-person-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 724.4 | 774.7 | 792.4 | 943.1 | 943.1 | True / True |
| xlarge-full-person-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 650.7 | 708.1 | 724.7 | 853.2 | 1123.5 | True / True |
| xlarge-full-person-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 727.3 | 1952.5 | 1797.8 | 2302.6 | 2659.0 | True / False |
| xlarge-full-person-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 637.1 | 691.4 | 691.3 | 724.8 | 777.2 | True / True |
| xlarge-full-person-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1915.5 | 2086.0 | 2221.9 | 2804.7 | 2804.7 | True / False |
| xlarge-full-town-linked-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 331.9 | 336.0 | 361.9 | 527.8 | 527.8 | True / True |
| xlarge-full-town-linked-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 324.7 | 362.8 | 361.0 | 378.8 | 485.5 | True / True |
| xlarge-full-town-linked-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 326.1 | 350.5 | 371.3 | 513.2 | 641.5 | True / True |
| xlarge-full-town-linked-r1-c128-a128-spread | 128 / 128 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-full-town-linked-r1-c64-a64-spread | 64 / 64 | 1 | 256 | 323.8 | 357.7 | 369.7 | 449.1 | 784.2 | True / True |
| xlarge-full-town-linked-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 353.1 | 368.5 | 380.0 | 465.7 | 465.7 | True / True |
| xlarge-full-town-linked-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 340.4 | 377.5 | 394.2 | 580.3 | 598.2 | True / True |
| xlarge-full-town-linked-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 334.0 | 373.0 | 376.9 | 411.6 | 485.0 | True / True |
| xlarge-full-town-linked-r10-c64-a64-spread | 64 / 64 | 10 | 256 | 348.5 | 384.3 | 388.2 | 431.9 | 503.3 | True / True |
| xlarge-full-town-linked-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 445.5 | 471.1 | 484.5 | 571.1 | 571.1 | True / True |
| xlarge-full-town-linked-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 416.1 | 452.0 | 450.0 | 477.4 | 482.5 | True / True |
| xlarge-full-town-linked-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 407.2 | 451.0 | 456.0 | 499.4 | 562.5 | True / True |
| xlarge-full-town-linked-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 532.7 | 1548.0 | 1462.3 | 2284.8 | 2382.7 | True / False |
| xlarge-full-town-linked-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 740.9 | 775.0 | 788.0 | 862.3 | 862.3 | True / True |
| xlarge-full-town-linked-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 699.3 | 741.9 | 749.8 | 810.7 | 844.3 | True / True |
| xlarge-full-town-linked-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 784.9 | 3062.6 | 2893.4 | 3292.3 | 3410.8 | True / False |
| xlarge-full-town-linked-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 719.6 | 801.2 | 891.3 | 1337.5 | 1448.7 | True / True |
| xlarge-full-town-linked-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 2053.8 | 2249.6 | 2264.5 | 2576.3 | 2576.3 | True / False |
| xlarge-city-city-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 317.7 | 339.0 | 340.3 | 382.3 | 382.3 | True / True |
| xlarge-city-city-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 295.4 | 321.5 | 320.1 | 347.9 | 350.1 | True / True |
| xlarge-city-city-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 295.0 | 318.1 | 321.0 | 343.5 | 395.4 | True / True |
| xlarge-city-city-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 284.7 | 323.6 | 334.5 | 410.7 | 665.6 | True / True |
| xlarge-city-city-r1-c512-a512-spread | 512 / 512 | 1 | 2048 | 677.7 | 6203.9 | 5902.0 | 6660.6 | 6926.5 | True / False |
| xlarge-city-city-r1-c256-a256-spread | 256 / 256 | 1 | 0 | — | — | — | — | — | False / None |
| xlarge-city-city-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 322.9 | 330.7 | 331.6 | 343.5 | 343.5 | True / True |
| xlarge-city-city-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 304.0 | 333.4 | 333.8 | 362.7 | 433.2 | True / True |
| xlarge-city-city-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 302.2 | 329.2 | 331.7 | 358.3 | 426.1 | True / True |
| xlarge-city-city-r10-c128-a128-spread | 128 / 128 | 10 | 512 | 309.1 | 411.0 | 421.9 | 574.6 | 613.0 | True / True |
| xlarge-city-city-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 364.8 | 371.2 | 373.8 | 390.8 | 390.8 | True / True |
| xlarge-city-city-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 339.4 | 361.5 | 365.9 | 404.1 | 453.0 | True / True |
| xlarge-city-city-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 336.9 | 367.7 | 368.4 | 398.5 | 452.6 | True / True |
| xlarge-city-city-r50-c128-a128-spread | 128 / 128 | 50 | 512 | 419.0 | 2772.5 | 2541.9 | 3154.8 | 3301.0 | True / False |
| xlarge-city-city-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 341.7 | 387.4 | 406.7 | 553.3 | 725.9 | True / True |
| xlarge-city-city-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 515.0 | 565.8 | 573.6 | 648.8 | 648.8 | True / True |
| xlarge-city-city-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 490.8 | 530.7 | 537.9 | 618.2 | 654.6 | True / True |
| xlarge-city-city-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 502.5 | 557.8 | 567.2 | 647.8 | 780.5 | True / True |
| xlarge-city-city-r200-c64-a64-spread | 64 / 64 | 200 | 256 | 585.2 | 3301.6 | 3138.4 | 3692.2 | 4227.3 | True / False |
| xlarge-city-city-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1189.7 | 1259.1 | 1428.6 | 2069.4 | 2069.4 | True / True |
| xlarge-city-city-r1000-c8-a8-spread | 8 / 8 | 1000 | 32 | 1177.5 | 2075.4 | 2091.6 | 2596.7 | 2612.5 | True / False |
| xlarge-city-city-r1000-c4-a4-spread | 4 / 4 | 1000 | 16 | 1067.7 | 1190.8 | 1360.0 | 2192.2 | 2192.2 | True / True |
| xlarge-city-city-r5000-c2-a2-spread | 2 / 2 | 5000 | 8 | 4253.0 | 4524.9 | 4669.8 | 5339.9 | 5339.9 | True / False |
| xlarge-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 300.5 | 325.8 | 331.1 | 364.8 | 628.4 | True / True |
| xlarge-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 312.3 | 344.0 | 344.4 | 373.6 | 442.2 | True / True |
| xlarge-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 302.4 | 330.7 | 337.1 | 373.0 | 556.6 | True / True |
| xlarge-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 327.2 | 343.5 | 349.1 | 371.3 | 539.7 | True / True |
| xlarge-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 335.0 | 371.8 | 381.3 | 439.3 | 620.7 | True / True |
| xlarge-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 292.4 | 316.5 | 320.8 | 343.1 | 460.0 | True / True |
| xlarge-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 296.6 | 311.4 | 314.4 | 357.0 | 368.4 | True / True |
| xlarge-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 325.7 | 358.6 | 355.4 | 397.1 | 411.6 | True / True |
| xlarge-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 320.4 | 347.8 | 355.2 | 439.2 | 497.9 | True / True |
| xlarge-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 285.6 | 307.3 | 308.9 | 342.6 | 381.6 | True / True |
| xxlarge-full-reference | 8 / 8 | 1 | 40 | 329.1 | 343.6 | 348.8 | 378.8 | 424.9 | True / True |
| xxlarge-full-idle-c64-w4 | 64 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c256-w4 | 256 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c1024-w4 | 1024 / 0 | 1 | 0 | — | — | — | — | — | True / True |
| xxlarge-full-idle-c4096-w4 | 4096 / 0 | 1 | 0 | — | — | — | — | — | False / None |
| xxlarge-full-person-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 324.4 | 336.1 | 335.7 | 346.1 | 346.1 | True / True |
| xxlarge-full-person-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 307.0 | 328.1 | 330.1 | 350.9 | 352.9 | True / True |
| xxlarge-full-person-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 298.6 | 328.6 | 331.5 | 363.4 | 430.4 | True / True |
| xxlarge-full-person-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 308.7 | 350.9 | 357.0 | 412.7 | 542.0 | True / True |
| xxlarge-full-person-r1-c512-a512-spread | 512 / 512 | 1 | 2048 | 1456.4 | 4588.3 | 4469.8 | 5003.6 | 5411.6 | True / False |
| xxlarge-full-person-r1-c256-a256-spread | 256 / 256 | 1 | 0 | — | — | — | — | — | False / None |
| xxlarge-full-person-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 326.4 | 356.9 | 386.1 | 625.7 | 625.7 | True / True |
| xxlarge-full-person-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 320.8 | 347.1 | 348.7 | 370.0 | 432.0 | True / True |
| xxlarge-full-person-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 316.6 | 348.7 | 351.6 | 378.8 | 487.4 | True / True |
| xxlarge-full-person-r10-c128-a128-spread | 128 / 128 | 10 | 512 | 336.9 | 390.0 | 393.3 | 442.3 | 549.8 | True / True |
| xxlarge-full-person-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 417.3 | 425.6 | 426.4 | 436.5 | 436.5 | True / True |
| xxlarge-full-person-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 380.7 | 409.2 | 410.5 | 444.6 | 449.4 | True / True |
| xxlarge-full-person-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 379.1 | 411.3 | 412.8 | 440.2 | 485.2 | True / True |
| xxlarge-full-person-r50-c128-a128-spread | 128 / 128 | 50 | 512 | 439.6 | 2192.4 | 2076.5 | 2931.9 | 3211.0 | True / False |
| xxlarge-full-person-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 402.4 | 449.9 | 454.5 | 522.3 | 561.9 | True / True |
| xxlarge-full-person-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 650.2 | 678.9 | 687.4 | 757.8 | 757.8 | True / True |
| xxlarge-full-person-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 634.8 | 667.2 | 670.5 | 706.5 | 712.5 | True / True |
| xxlarge-full-person-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 727.5 | 807.8 | 820.6 | 918.5 | 993.1 | True / True |
| xxlarge-full-person-r200-c64-a64-spread | 64 / 64 | 200 | 256 | 853.8 | 3161.1 | 3075.6 | 3746.3 | 4129.9 | True / False |
| xxlarge-full-person-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1781.3 | 1873.4 | 2034.4 | 2641.9 | 2641.9 | True / False |
| xxlarge-full-town-linked-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 338.2 | 347.7 | 358.5 | 422.4 | 422.4 | True / True |
| xxlarge-full-town-linked-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 311.8 | 345.4 | 344.3 | 371.9 | 380.9 | True / True |
| xxlarge-full-town-linked-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 310.4 | 342.0 | 343.5 | 370.8 | 452.4 | True / True |
| xxlarge-full-town-linked-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 330.9 | 369.1 | 373.2 | 421.1 | 562.2 | True / True |
| xxlarge-full-town-linked-r1-c512-a512-spread | 512 / 512 | 1 | 2048 | 468.5 | 4905.3 | 4723.0 | 5777.2 | 6090.3 | True / False |
| xxlarge-full-town-linked-r1-c256-a256-spread | 256 / 256 | 1 | 1024 | 352.4 | 2264.3 | 2046.2 | 2864.7 | 3010.8 | True / False |
| xxlarge-full-town-linked-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 360.9 | 368.5 | 368.0 | 378.0 | 378.0 | True / True |
| xxlarge-full-town-linked-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 322.6 | 351.5 | 361.0 | 469.9 | 470.5 | True / True |
| xxlarge-full-town-linked-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 328.3 | 357.0 | 360.7 | 403.2 | 469.0 | True / True |
| xxlarge-full-town-linked-r10-c128-a128-spread | 128 / 128 | 10 | 512 | 338.1 | 458.4 | 731.4 | 1974.7 | 2421.7 | True / True |
| xxlarge-full-town-linked-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 431.6 | 438.5 | 444.1 | 461.5 | 461.5 | True / True |
| xxlarge-full-town-linked-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 402.7 | 435.6 | 434.4 | 459.7 | 472.0 | True / True |
| xxlarge-full-town-linked-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 396.7 | 444.2 | 467.3 | 606.2 | 864.2 | True / True |
| xxlarge-full-town-linked-r50-c128-a128-spread | 128 / 128 | 50 | 512 | 560.9 | 3388.4 | 3222.7 | 3624.7 | 3745.7 | True / False |
| xxlarge-full-town-linked-r50-c64-a64-spread | 64 / 64 | 50 | 256 | 463.5 | 548.2 | 556.8 | 643.3 | 697.5 | True / True |
| xxlarge-full-town-linked-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 709.7 | 736.1 | 741.7 | 797.4 | 797.4 | True / True |
| xxlarge-full-town-linked-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 659.7 | 719.8 | 725.0 | 810.6 | 815.3 | True / True |
| xxlarge-full-town-linked-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 772.1 | 2319.0 | 2136.1 | 2563.1 | 2675.2 | True / False |
| xxlarge-full-town-linked-r200-c16-a16-spread | 16 / 16 | 200 | 64 | 697.3 | 762.2 | 769.9 | 841.8 | 1127.8 | True / True |
| xxlarge-full-town-linked-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1945.6 | 2172.6 | 2224.7 | 2704.9 | 2704.9 | True / False |
| xxlarge-city-city-r1-c2-a2-spread | 2 / 2 | 1 | 8 | 308.6 | 318.3 | 317.5 | 322.5 | 322.5 | True / True |
| xxlarge-city-city-r1-c8-a8-spread | 8 / 8 | 1 | 32 | 293.3 | 321.3 | 321.0 | 337.3 | 339.7 | True / True |
| xxlarge-city-city-r1-c32-a32-spread | 32 / 32 | 1 | 128 | 293.7 | 319.6 | 321.0 | 346.0 | 395.6 | True / True |
| xxlarge-city-city-r1-c128-a128-spread | 128 / 128 | 1 | 512 | 287.4 | 329.8 | 343.8 | 449.9 | 558.6 | True / True |
| xxlarge-city-city-r1-c512-a512-spread | 512 / 512 | 1 | 2048 | 366.1 | 4142.2 | 3957.0 | 4416.6 | 4638.2 | True / False |
| xxlarge-city-city-r1-c256-a256-spread | 256 / 256 | 1 | 0 | — | — | — | — | — | False / None |
| xxlarge-city-city-r10-c2-a2-spread | 2 / 2 | 10 | 8 | 325.3 | 330.5 | 355.7 | 441.0 | 441.0 | True / True |
| xxlarge-city-city-r10-c8-a8-spread | 8 / 8 | 10 | 32 | 295.0 | 325.4 | 322.1 | 342.1 | 352.0 | True / True |
| xxlarge-city-city-r10-c32-a32-spread | 32 / 32 | 10 | 128 | 293.6 | 323.3 | 327.9 | 369.9 | 438.8 | True / True |
| xxlarge-city-city-r10-c128-a128-spread | 128 / 128 | 10 | 512 | 296.0 | 347.2 | 354.3 | 420.4 | 516.6 | True / True |
| xxlarge-city-city-r50-c2-a2-spread | 2 / 2 | 50 | 8 | 355.2 | 378.0 | 390.7 | 517.7 | 517.7 | True / True |
| xxlarge-city-city-r50-c8-a8-spread | 8 / 8 | 50 | 32 | 328.2 | 350.3 | 351.7 | 374.9 | 384.8 | True / True |
| xxlarge-city-city-r50-c32-a32-spread | 32 / 32 | 50 | 128 | 320.0 | 355.9 | 357.5 | 382.0 | 539.6 | True / True |
| xxlarge-city-city-r50-c128-a128-spread | 128 / 128 | 50 | 512 | 418.4 | 766.7 | 818.0 | 1437.8 | 1534.6 | True / True |
| xxlarge-city-city-r200-c2-a2-spread | 2 / 2 | 200 | 8 | 491.5 | 524.9 | 530.2 | 595.6 | 595.6 | True / True |
| xxlarge-city-city-r200-c8-a8-spread | 8 / 8 | 200 | 32 | 488.7 | 522.1 | 522.7 | 553.9 | 567.4 | True / True |
| xxlarge-city-city-r200-c32-a32-spread | 32 / 32 | 200 | 128 | 509.1 | 552.9 | 570.9 | 698.2 | 797.4 | True / True |
| xxlarge-city-city-r200-c128-a128-spread | 128 / 128 | 200 | 512 | 639.6 | 5458.0 | 5379.4 | 6674.6 | 6887.0 | True / False |
| xxlarge-city-city-r200-c64-a64-spread | 64 / 64 | 200 | 256 | 541.8 | 2596.4 | 2450.6 | 3467.9 | 3589.5 | True / False |
| xxlarge-city-city-r1000-c2-a2-spread | 2 / 2 | 1000 | 8 | 1122.1 | 1218.4 | 1371.0 | 1966.1 | 1966.1 | True / True |
| xxlarge-city-city-r1000-c8-a8-spread | 8 / 8 | 1000 | 32 | 1068.6 | 1298.8 | 1448.0 | 2201.0 | 2250.5 | True / True |
| xxlarge-city-city-r1000-c32-a32-spread | 32 / 32 | 1000 | 128 | 3069.3 | 5661.8 | 5633.3 | 6786.5 | 7040.9 | True / False |
| xxlarge-city-city-r1000-c16-a16-spread | 16 / 16 | 1000 | 64 | 1308.3 | 3128.3 | 2987.4 | 3689.1 | 3978.5 | True / False |
| xxlarge-city-city-r5000-c2-a2-spread | 2 / 2 | 5000 | 8 | 4150.1 | 4448.2 | 4582.4 | 5495.2 | 5495.2 | True / False |
| xxlarge-full-person-r1-c8-a8-soak | 8 / 8 | 1 | 600 | 321.0 | 350.2 | 358.5 | 407.3 | 558.9 | True / True |
| xxlarge-full-person-r1-c64-a8-mixed | 64 / 8 | 1 | 120 | 328.9 | 363.3 | 366.0 | 396.2 | 474.8 | True / True |
| xxlarge-full-person-r1-c256-a8-mixed | 256 / 8 | 1 | 120 | 324.2 | 355.6 | 366.6 | 449.6 | 583.7 | True / True |
| xxlarge-full-person-r1-c16-a16-fanout | 16 / 16 | 1 | 80 | 341.0 | 367.5 | 375.2 | 403.4 | 845.0 | True / True |
| xxlarge-full-person-r1-c8-a8-burst | 8 / 8 | 1 | 120 | 365.3 | 445.0 | 444.4 | 489.7 | 576.4 | True / True |
| xxlarge-full-person-r1-c8-a8-update | 8 / 8 | 1 | 120 | 310.3 | 333.9 | 335.1 | 363.6 | 408.0 | True / True |
| xxlarge-full-town-r1-c2-a2-nullable | 2 / 2 | 1 | 30 | 308.4 | 320.1 | 320.8 | 335.2 | 347.6 | True / True |
| xxlarge-full-town-linked-r1-c2-a2-control | 2 / 2 | 1 | 30 | 325.3 | 349.3 | 356.7 | 401.4 | 547.4 | True / True |
| xxlarge-full-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 358.3 | 384.2 | 387.9 | 408.3 | 634.7 | True / True |
| xxlarge-city-city-r1-c8-a8-registry-control | 8 / 8 | 1 | 120 | 291.6 | 313.6 | 318.0 | 344.3 | 586.7 | True / True |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|
| small-full-idle-c64-w1 | 64 | 64 | True | 32 | 2414.4 / 2450.1 / 2799.4 | 121.0 | True |
| small-full-idle-c256-w1 | 256 | 256 | True | 128 | 2798.2 / 2826.5 / 3479.7 | 204.3 | True |
| small-full-idle-c1024-w1 | 1024 | 298 | False | 0 | — | 237.3 | False |
| medium-full-idle-c64-w4 | 64 | 64 | True | 32 | 945.6 / 920.8 / 1010.9 | 109.7 | True |
| medium-full-idle-c256-w4 | 256 | 256 | True | 128 | 981.6 / 961.7 / 1120.7 | 178.7 | True |
| medium-full-idle-c1024-w4 | 1024 | 1024 | True | 512 | 1445.7 / 1454.3 / 1902.6 | 443.2 | True |
| medium-full-idle-c4096-w4 | 4096 | 0 | False | 0 | — | 475.1 | False |
| large-full-idle-c64-w4 | 64 | 64 | True | 32 | 511.6 / 509.4 / 611.1 | 110.7 | True |
| large-full-idle-c256-w4 | 256 | 256 | False | 0 | — | 176.4 | False |
| xlarge-full-idle-c64-w4 | 64 | 64 | True | 32 | 405.6 / 424.1 / 505.8 | 114.3 | True |
| xlarge-full-idle-c256-w4 | 256 | 256 | True | 128 | 370.3 / 374.3 / 455.6 | 180.7 | True |
| xlarge-full-idle-c1024-w4 | 1024 | 1024 | False | 0 | — | 473.2 | False |
| xxlarge-full-idle-c64-w4 | 64 | 64 | True | 32 | 405.4 / 407.0 / 487.4 | 115.2 | True |
| xxlarge-full-idle-c256-w4 | 256 | 256 | True | 128 | 352.9 / 373.9 / 509.9 | 176.0 | True |
| xxlarge-full-idle-c1024-w4 | 1024 | 1024 | True | 512 | 363.3 / 371.4 / 440.7 | 447.8 | True |
| xxlarge-full-idle-c4096-w4 | 4096 | 2048 | False | 0 | — | 949.2 | False |

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.

## Skipped heavier cases

These cases were not measured because an equal or lighter comparable load did not pass. They do not establish a measured capacity limit. See `skipped-cases.json` for parameters and blocking verdicts.

| Skipped case | Blocking measurement |
|---|---|
| small-full-idle-c4096-w1 | small-full-idle-c1024-w1 |
| small-full-idle-c8192-w1 | small-full-idle-c1024-w1 |
| small-full-person-r1-c128-a128-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r1-c512-a512-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r10-c32-a32-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r10-c128-a128-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r10-c512-a512-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r10-c16-a16-spread | small-full-person-r1-c16-a16-spread |
| small-full-person-r50-c32-a32-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r50-c128-a128-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r50-c512-a512-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r200-c8-a8-spread | small-full-person-r50-c8-a8-spread |
| small-full-person-r200-c32-a32-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r200-c128-a128-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r200-c512-a512-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r1000-c2-a2-spread | small-full-person-r200-c2-a2-spread |
| small-full-person-r1000-c8-a8-spread | small-full-person-r50-c8-a8-spread |
| small-full-person-r1000-c32-a32-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r1000-c128-a128-spread | small-full-person-r1-c32-a32-spread |
| small-full-person-r1000-c512-a512-spread | small-full-person-r1-c32-a32-spread |
| small-full-town-linked-r1-c32-a32-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1-c128-a128-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1-c512-a512-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r10-c8-a8-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r10-c32-a32-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r10-c128-a128-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r10-c512-a512-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r50-c8-a8-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r50-c32-a32-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r50-c128-a128-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r50-c512-a512-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r200-c8-a8-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r200-c32-a32-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r200-c128-a128-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r200-c512-a512-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1000-c2-a2-spread | small-full-town-linked-r200-c2-a2-spread |
| small-full-town-linked-r1000-c8-a8-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1000-c32-a32-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1000-c128-a128-spread | small-full-town-linked-r1-c8-a8-spread |
| small-full-town-linked-r1000-c512-a512-spread | small-full-town-linked-r1-c8-a8-spread |
| small-city-city-r1-c128-a128-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r1-c512-a512-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r10-c32-a32-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r10-c128-a128-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r10-c512-a512-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r10-c16-a16-spread | small-city-city-r1-c16-a16-spread |
| small-city-city-r50-c32-a32-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r50-c128-a128-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r50-c512-a512-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r200-c8-a8-spread | small-city-city-r50-c8-a8-spread |
| small-city-city-r200-c32-a32-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r200-c128-a128-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r200-c512-a512-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r1000-c8-a8-spread | small-city-city-r50-c8-a8-spread |
| small-city-city-r1000-c32-a32-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r1000-c128-a128-spread | small-city-city-r1-c32-a32-spread |
| small-city-city-r1000-c512-a512-spread | small-city-city-r1-c32-a32-spread |
| medium-full-idle-c8192-w4 | medium-full-idle-c4096-w4 |
| medium-full-person-r1-c512-a512-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r10-c128-a128-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r10-c512-a512-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r50-c32-a32-spread | medium-full-person-r10-c32-a32-spread |
| medium-full-person-r50-c128-a128-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r50-c512-a512-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r200-c32-a32-spread | medium-full-person-r10-c32-a32-spread |
| medium-full-person-r200-c128-a128-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r200-c512-a512-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r1000-c8-a8-spread | medium-full-person-r200-c8-a8-spread |
| medium-full-person-r1000-c32-a32-spread | medium-full-person-r10-c32-a32-spread |
| medium-full-person-r1000-c128-a128-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-person-r1000-c512-a512-spread | medium-full-person-r1-c128-a128-spread |
| medium-full-town-linked-r1-c512-a512-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r10-c128-a128-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r10-c512-a512-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r50-c32-a32-spread | medium-full-town-linked-r10-c32-a32-spread |
| medium-full-town-linked-r50-c128-a128-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r50-c512-a512-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r200-c32-a32-spread | medium-full-town-linked-r10-c32-a32-spread |
| medium-full-town-linked-r200-c128-a128-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r200-c512-a512-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r1000-c8-a8-spread | medium-full-town-linked-r200-c8-a8-spread |
| medium-full-town-linked-r1000-c32-a32-spread | medium-full-town-linked-r10-c32-a32-spread |
| medium-full-town-linked-r1000-c128-a128-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-full-town-linked-r1000-c512-a512-spread | medium-full-town-linked-r1-c128-a128-spread |
| medium-city-city-r1-c512-a512-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r10-c128-a128-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r10-c512-a512-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r10-c64-a64-spread | medium-city-city-r1-c64-a64-spread |
| medium-city-city-r50-c128-a128-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r50-c512-a512-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r200-c32-a32-spread | medium-city-city-r50-c32-a32-spread |
| medium-city-city-r200-c128-a128-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r200-c512-a512-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r1000-c8-a8-spread | medium-city-city-r1000-c2-a2-spread |
| medium-city-city-r1000-c32-a32-spread | medium-city-city-r50-c32-a32-spread |
| medium-city-city-r1000-c128-a128-spread | medium-city-city-r1-c128-a128-spread |
| medium-city-city-r1000-c512-a512-spread | medium-city-city-r1-c128-a128-spread |
| medium-full-person-r1-c256-a8-mixed | medium-full-person-r1-c64-a8-mixed |
| large-full-idle-c1024-w4 | large-full-idle-c256-w4 |
| large-full-idle-c4096-w4 | large-full-idle-c256-w4 |
| large-full-idle-c8192-w4 | large-full-idle-c256-w4 |
| large-full-person-r1-c512-a512-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r10-c128-a128-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r10-c512-a512-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r50-c32-a32-spread | large-full-person-r10-c32-a32-spread |
| large-full-person-r50-c128-a128-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r50-c512-a512-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r200-c32-a32-spread | large-full-person-r10-c32-a32-spread |
| large-full-person-r200-c128-a128-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r200-c512-a512-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r1000-c8-a8-spread | large-full-person-r1000-c2-a2-spread |
| large-full-person-r1000-c32-a32-spread | large-full-person-r10-c32-a32-spread |
| large-full-person-r1000-c128-a128-spread | large-full-person-r1-c128-a128-spread |
| large-full-person-r1000-c512-a512-spread | large-full-person-r1-c128-a128-spread |
| large-full-town-linked-r1-c128-a128-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r1-c512-a512-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r10-c32-a32-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r10-c128-a128-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r10-c512-a512-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r50-c32-a32-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r50-c128-a128-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r50-c512-a512-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r200-c32-a32-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r200-c128-a128-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r200-c512-a512-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r1000-c8-a8-spread | large-full-town-linked-r1000-c2-a2-spread |
| large-full-town-linked-r1000-c32-a32-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r1000-c128-a128-spread | large-full-town-linked-r1-c32-a32-spread |
| large-full-town-linked-r1000-c512-a512-spread | large-full-town-linked-r1-c32-a32-spread |
| large-city-city-r1-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r10-c128-a128-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r10-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r50-c128-a128-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r50-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r200-c128-a128-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r200-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r1000-c32-a32-spread | large-city-city-r200-c32-a32-spread |
| large-city-city-r1000-c128-a128-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r1000-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r5000-c8-a8-spread | large-city-city-r1000-c8-a8-spread |
| large-city-city-r5000-c32-a32-spread | large-city-city-r200-c32-a32-spread |
| large-city-city-r5000-c128-a128-spread | large-city-city-r1-c128-a128-spread |
| large-city-city-r5000-c512-a512-spread | large-city-city-r1-c128-a128-spread |
| xlarge-full-idle-c4096-w4 | xlarge-full-idle-c1024-w4 |
| xlarge-full-idle-c8192-w4 | xlarge-full-idle-c1024-w4 |
| xlarge-full-person-r10-c512-a512-spread | xlarge-full-person-r1-c512-a512-spread |
| xlarge-full-person-r10-c256-a256-spread | xlarge-full-person-r1-c256-a256-spread |
| xlarge-full-person-r50-c512-a512-spread | xlarge-full-person-r1-c512-a512-spread |
| xlarge-full-person-r200-c128-a128-spread | xlarge-full-person-r50-c128-a128-spread |
| xlarge-full-person-r200-c512-a512-spread | xlarge-full-person-r1-c512-a512-spread |
| xlarge-full-person-r1000-c8-a8-spread | xlarge-full-person-r1000-c2-a2-spread |
| xlarge-full-person-r1000-c32-a32-spread | xlarge-full-person-r200-c32-a32-spread |
| xlarge-full-person-r1000-c128-a128-spread | xlarge-full-person-r50-c128-a128-spread |
| xlarge-full-person-r1000-c512-a512-spread | xlarge-full-person-r1-c512-a512-spread |
| xlarge-full-town-linked-r1-c512-a512-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r10-c128-a128-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r10-c512-a512-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r50-c128-a128-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r50-c512-a512-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r200-c128-a128-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r200-c512-a512-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r1000-c8-a8-spread | xlarge-full-town-linked-r1000-c2-a2-spread |
| xlarge-full-town-linked-r1000-c32-a32-spread | xlarge-full-town-linked-r200-c32-a32-spread |
| xlarge-full-town-linked-r1000-c128-a128-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-full-town-linked-r1000-c512-a512-spread | xlarge-full-town-linked-r1-c128-a128-spread |
| xlarge-city-city-r10-c512-a512-spread | xlarge-city-city-r1-c512-a512-spread |
| xlarge-city-city-r10-c256-a256-spread | xlarge-city-city-r1-c256-a256-spread |
| xlarge-city-city-r50-c512-a512-spread | xlarge-city-city-r1-c512-a512-spread |
| xlarge-city-city-r200-c128-a128-spread | xlarge-city-city-r50-c128-a128-spread |
| xlarge-city-city-r200-c512-a512-spread | xlarge-city-city-r1-c512-a512-spread |
| xlarge-city-city-r1000-c32-a32-spread | xlarge-city-city-r1000-c8-a8-spread |
| xlarge-city-city-r1000-c128-a128-spread | xlarge-city-city-r50-c128-a128-spread |
| xlarge-city-city-r1000-c512-a512-spread | xlarge-city-city-r1-c512-a512-spread |
| xlarge-city-city-r5000-c8-a8-spread | xlarge-city-city-r1000-c8-a8-spread |
| xlarge-city-city-r5000-c32-a32-spread | xlarge-city-city-r1000-c8-a8-spread |
| xlarge-city-city-r5000-c128-a128-spread | xlarge-city-city-r50-c128-a128-spread |
| xlarge-city-city-r5000-c512-a512-spread | xlarge-city-city-r1-c512-a512-spread |
| xxlarge-full-idle-c8192-w4 | xxlarge-full-idle-c4096-w4 |
| xxlarge-full-person-r10-c512-a512-spread | xxlarge-full-person-r1-c512-a512-spread |
| xxlarge-full-person-r10-c256-a256-spread | xxlarge-full-person-r1-c256-a256-spread |
| xxlarge-full-person-r50-c512-a512-spread | xxlarge-full-person-r1-c512-a512-spread |
| xxlarge-full-person-r200-c128-a128-spread | xxlarge-full-person-r50-c128-a128-spread |
| xxlarge-full-person-r200-c512-a512-spread | xxlarge-full-person-r1-c512-a512-spread |
| xxlarge-full-person-r1000-c8-a8-spread | xxlarge-full-person-r1000-c2-a2-spread |
| xxlarge-full-person-r1000-c32-a32-spread | xxlarge-full-person-r1000-c2-a2-spread |
| xxlarge-full-person-r1000-c128-a128-spread | xxlarge-full-person-r50-c128-a128-spread |
| xxlarge-full-person-r1000-c512-a512-spread | xxlarge-full-person-r1-c512-a512-spread |
| xxlarge-full-town-linked-r10-c512-a512-spread | xxlarge-full-town-linked-r1-c512-a512-spread |
| xxlarge-full-town-linked-r10-c256-a256-spread | xxlarge-full-town-linked-r1-c256-a256-spread |
| xxlarge-full-town-linked-r50-c512-a512-spread | xxlarge-full-town-linked-r1-c512-a512-spread |
| xxlarge-full-town-linked-r200-c128-a128-spread | xxlarge-full-town-linked-r50-c128-a128-spread |
| xxlarge-full-town-linked-r200-c512-a512-spread | xxlarge-full-town-linked-r1-c512-a512-spread |
| xxlarge-full-town-linked-r1000-c8-a8-spread | xxlarge-full-town-linked-r1000-c2-a2-spread |
| xxlarge-full-town-linked-r1000-c32-a32-spread | xxlarge-full-town-linked-r200-c32-a32-spread |
| xxlarge-full-town-linked-r1000-c128-a128-spread | xxlarge-full-town-linked-r50-c128-a128-spread |
| xxlarge-full-town-linked-r1000-c512-a512-spread | xxlarge-full-town-linked-r1-c512-a512-spread |
| xxlarge-city-city-r10-c512-a512-spread | xxlarge-city-city-r1-c512-a512-spread |
| xxlarge-city-city-r10-c256-a256-spread | xxlarge-city-city-r1-c256-a256-spread |
| xxlarge-city-city-r50-c512-a512-spread | xxlarge-city-city-r1-c512-a512-spread |
| xxlarge-city-city-r50-c256-a256-spread | xxlarge-city-city-r1-c256-a256-spread |
| xxlarge-city-city-r200-c512-a512-spread | xxlarge-city-city-r1-c512-a512-spread |
| xxlarge-city-city-r1000-c128-a128-spread | xxlarge-city-city-r200-c128-a128-spread |
| xxlarge-city-city-r1000-c512-a512-spread | xxlarge-city-city-r1-c512-a512-spread |
| xxlarge-city-city-r5000-c8-a8-spread | xxlarge-city-city-r5000-c2-a2-spread |
| xxlarge-city-city-r5000-c32-a32-spread | xxlarge-city-city-r1000-c32-a32-spread |
| xxlarge-city-city-r5000-c128-a128-spread | xxlarge-city-city-r200-c128-a128-spread |
| xxlarge-city-city-r5000-c512-a512-spread | xxlarge-city-city-r1-c512-a512-spread |
