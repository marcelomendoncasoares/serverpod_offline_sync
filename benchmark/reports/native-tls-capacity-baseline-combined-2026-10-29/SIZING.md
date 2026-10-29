# Observed capacity by workload

CPU accounting has unresolved discrepancies in the source observations. Do not infer an enforced CPU ceiling, headroom, or throttling from those counters. See [CPU accounting observations](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md).

These are measured workload screens, not production capacity guarantees. Use them to choose a starting configuration, then repeat a sustained test with your schema, database placement, row sizes, and activity pattern. All results belong to the exact server and client builds in [manifest.json](manifest.json).

The active-device tables measure incremental rounds on established continuous streams. Connection setup, initial synchronization, final verification, and teardown are separate phases in the complete measurements. Connected devices and devices participating in active rounds are different quantities. Two devices share one user; each active user offers one round every two seconds, with at most one round outstanding. The eight-round screens use 128 bytes of seeded payload per row plus identifiers. Timings include local commit and delivery to every peer. Participating-device counts describe the offered workload; measured overlap below counts devices belonging to unfinished rounds. Database transaction concurrency is a separate measurement.

Each user writes to a separate personal space shared by that user's devices. These measurements therefore exercise concurrency across independent spaces. Many users writing to one shared space still serialize through that space's transaction lock and need a separate workload test; these tables do not establish capacity for that pattern.

## Observed process budgets

These are the visible cgroup limits reported by the running server, not the host processor count. Unmeasured sizes remain blank.

| Size | CPU quota, cores | Memory limit, MiB |
|---|---:|---:|
| small | 0.1 | 256 |
| medium | 0.25 | 512 |
| large | 0.5 | 1024 |
| xlarge | 1 | 2048 |
| xxlarge | 2 | 4096 |

## Active devices

Each cell shows **devices / p95 milliseconds** for the highest tested count that qualified. The first table additionally requires p95 below one second. Both require exact convergence, cleanup, complete observations, and keeping up with the offered rate. If repetitions disagree, that count does not qualify. A dash means no qualifying measurement; it does not mean zero capacity. Longer controls and different offered rates are retained in the [complete measurements](README.md).

### Kept up with p95 below one second

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | 8 / 924 | 8 / 402 | 64 / 951 | 64 / 418 | 32 / 414 |
| Person, full registry | 10 | — | 16 / 464 | 32 / 374 | 64 / 745 | 32 / 407 |
| Person, full registry | 50 | — | 8 / 904 | 8 / 478 | 32 / 669 | 64 / 721 |
| Person, full registry | 200 | — | — | 2 / 833 | 16 / 891 | 16 / 904 |
| Person, full registry | 1000 | — | — | — | — | — |
| Person, full registry | 5000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | — | 16 / 670 | 32 / 386 | 64 / 551 | 128 / 509 |
| Town with linked parents, full registry | 10 | — | 16 / 734 | 32 / 469 | 64 / 862 | 128 / 870 |
| Town with linked parents, full registry | 50 | — | 8 / 727 | 16 / 824 | 8 / 518 | 32 / 933 |
| Town with linked parents, full registry | 200 | — | — | — | — | 2 / 941 |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 5000 | — | — | — | — | — |
| City, isolated registry | 1 | 2 / 794 | 8 / 372 | 32 / 390 | 128 / 663 | 128 / 423 |
| City, isolated registry | 10 | 2 / 787 | 16 / 413 | 32 / 451 | 64 / 480 | 128 / 656 |
| City, isolated registry | 50 | 2 / 991 | 16 / 937 | 8 / 395 | 64 / 519 | 32 / 440 |
| City, isolated registry | 200 | — | — | 8 / 674 | 16 / 586 | 16 / 806 |
| City, isolated registry | 1000 | — | — | — | — | — |
| City, isolated registry | 5000 | — | — | — | — | — |

### Kept up, without a latency target

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | 8 / 924 | 32 / 1055 | 64 / 951 | 64 / 418 | 128 / 2067 |
| Person, full registry | 10 | 8 / 2038 | 16 / 464 | 32 / 374 | 64 / 745 | 64 / 2486 |
| Person, full registry | 50 | 4 / 1528 | 8 / 904 | 32 / 1192 | 32 / 669 | 64 / 721 |
| Person, full registry | 200 | — | 4 / 1491 | 8 / 1051 | 16 / 891 | 16 / 904 |
| Person, full registry | 1000 | — | — | — | — | — |
| Person, full registry | 5000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | 8 / 2159 | 16 / 670 | 32 / 386 | 64 / 551 | 128 / 509 |
| Town with linked parents, full registry | 10 | 4 / 1928 | 16 / 734 | 32 / 469 | 64 / 862 | 128 / 870 |
| Town with linked parents, full registry | 50 | 2 / 2125 | 8 / 727 | 16 / 824 | 32 / 1402 | 32 / 933 |
| Town with linked parents, full registry | 200 | — | — | 2 / 1223 | 4 / 1586 | 4 / 1550 |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 5000 | — | — | — | — | — |
| City, isolated registry | 1 | 8 / 1224 | 32 / 1187 | 64 / 1095 | 128 / 663 | 128 / 423 |
| City, isolated registry | 10 | 8 / 1521 | 16 / 413 | 64 / 1632 | 64 / 480 | 128 / 656 |
| City, isolated registry | 50 | 4 / 1273 | 16 / 937 | 32 / 1062 | 64 / 519 | 64 / 1007 |
| City, isolated registry | 200 | — | 4 / 1004 | 8 / 674 | 16 / 586 | 16 / 806 |
| City, isolated registry | 1000 | — | — | — | 2 / 2058 | 2 / 2411 |
| City, isolated registry | 5000 | — | — | — | — | — |

Person writes two text fields with nullable relations unpopulated. Town writes its name and populated City/Person references, with the linked parents seeded before exercise. City uses one persisted name field in an isolated registry. These profiles sample different costs; field counts alone do not model an arbitrary application schema.

## Five-minute one-row validation

These operating points completed at least five minutes of offered one-row traffic with exact convergence, cleanup, complete observations, and rate adherence. They use the same two-device users and two-second cadence as the short screens. A failed or incompletely observed repetition disqualifies that count. Mixed idle/active workloads remain separate. A dash means no qualifying sustained trial, not zero capacity.

Each cell is **participating devices / p95 milliseconds**. Keeping up and meeting a subsecond p95 remain separate requirements. These finite runs support a starting operating point; they do not establish long-term reliability or a maximum.

| Size / schema profile | Kept up | Kept up with p95 below one second |
|---|---:|---:|
| small / Person, full registry | — | — |
| small / Town with linked parents, full registry | 8 / 2339 | — |
| small / City, isolated registry | 8 / 1361 | — |
| medium / Person, full registry | 32 / 2090 | 8 / 449 |
| medium / Town with linked parents, full registry | 16 / 646 | 16 / 646 |
| medium / City, isolated registry | 32 / 1010 | — |
| large / Person, full registry | — | — |
| large / Town with linked parents, full registry | 32 / 458 | 32 / 458 |
| large / City, isolated registry | — | — |
| xlarge / Person, full registry | 64 / 564 | 64 / 564 |
| xlarge / Town with linked parents, full registry | 64 / 469 | 64 / 469 |
| xlarge / City, isolated registry | 128 / 705 | 128 / 705 |
| xxlarge / Person, full registry | 8 / 396 | 8 / 396 |
| xxlarge / Town with linked parents, full registry | — | — |
| xxlarge / City, isolated registry | 128 / 447 | 128 / 447 |

## Connected but idle devices

The largest successful trial below completed setup, the idle hold, resumed delivery and exact verification, and drained cleanly. Failed attempts remain listed with their phase. A setup failure is not a measured ceiling for already established streams; a single pass is not a reliability guarantee. Probe traffic is bounded to eight users.

| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |
|---|---:|---|---:|---|
| small | 256 | 3318 / 3321 / 3910 | 223.2 | 1024 / warmup, 512 / warmup |
| medium | 256 | 1005 / 1012 / 1206 | 190.0 | 1024 / close |
| large | 1024 | 693 / 699 / 919 | 399.0 | 256 / warmup |
| xlarge | 2048 | 502 / 531 / 742 | 739.8 | 4096 / warmup |
| xxlarge | 2048 | 471 / 489 / 621 | 740.5 | 4096 / warmup |

## Measured overlap in one-row screens

These are the highest qualifying throughput screens from the second active-device table. The mean and peak count devices involved in unfinished application rounds, from local write through final peer application. They show how much of the configured participating population was actually overlapping.

| Size / profile | Participating devices | Offered rounds/s | Overlapping devices, mean / peak | p95 ms |
|---|---:|---:|---:|---:|
| small / Person, full registry | 8 | 2 | 2.7 / 4 | 924 |
| small / Town with linked parents, full registry | 8 | 2 | 5.1 / 8 | 2159 |
| small / City, isolated registry | 8 | 2 | 3.3 / 6 | 1224 |
| medium / Person, full registry | 32 | 8 | 12.5 / 20 | 1055 |
| medium / Town with linked parents, full registry | 16 | 4 | 3.5 / 8 | 670 |
| medium / City, isolated registry | 32 | 8 | 11.6 / 22 | 1187 |
| large / Person, full registry | 64 | 16 | 21.0 / 34 | 951 |
| large / Town with linked parents, full registry | 32 | 8 | 5.6 / 8 | 386 |
| large / City, isolated registry | 64 | 16 | 17.8 / 40 | 1095 |
| xlarge / Person, full registry | 64 | 16 | 11.3 / 18 | 418 |
| xlarge / Town with linked parents, full registry | 64 | 16 | 13.5 / 20 | 551 |
| xlarge / City, isolated registry | 128 | 32 | 24.9 / 52 | 663 |
| xxlarge / Person, full registry | 128 | 32 | 51.4 / 128 | 2067 |
| xxlarge / Town with linked parents, full registry | 128 | 32 | 26.3 / 42 | 509 |
| xxlarge / City, isolated registry | 128 | 32 | 21.5 / 36 | 423 |

## Mixed connections and sustained controls

The controls below use one-row writes in the named schema profiles. They keep latency, correctness, offered-rate adherence, and observation completeness separate. An incomplete observation does not erase the client timings, but excludes the run from a matched speedup claim. A mixed-load pass can establish a connected-device count that a separate setup attempt failed to establish; inspect both rather than treating the first failure as a ceiling.

| Size / profile / control | Connected / active devices | Rounds | Min | Median | Mean | p95 | Max | Correct / kept up / observed |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| small / full/person / 5-minute offered workload | 8 / 8 | 600 | 469 | 879 | 935 | 1328 | 2186 | True / True / False |
| small / full/person / mixed | 64 / 8 | 120 | 558 | 903 | 943 | 1316 | 1458 | True / True / True |
| small / full/person / 5-minute offered workload | 8 / 8 | 600 | 666 | 980 | 1002 | 1283 | 2287 | True / True / True |
| small / full/town-linked / 5-minute offered workload | 8 / 8 | 600 | 727 | 1917 | 1934 | 2339 | 3508 | True / True / True |
| small / city/city / 5-minute offered workload | 8 / 8 | 600 | 461 | 867 | 939 | 1361 | 2659 | True / True / True |
| medium / full/person / 5-minute offered workload | 8 / 8 | 600 | 344 | 373 | 387 | 449 | 973 | True / True / True |
| medium / full/person / mixed | 64 / 8 | 120 | 317 | 377 | 378 | 411 | 483 | True / True / True |
| medium / full/person / mixed | 256 / 8 | 120 | 341 | 376 | 407 | 470 | 1074 | True / True / True |
| medium / full/person / 5-minute offered workload | 32 / 32 | 2400 | 384 | 1329 | 1431 | 2090 | 2879 | True / True / True |
| medium / full/town-linked / 5-minute offered workload | 16 / 16 | 1200 | 359 | 482 | 501 | 646 | 1137 | True / True / True |
| medium / city/city / 5-minute offered workload | 32 / 32 | 2400 | 376 | 731 | 756 | 1010 | 1709 | True / True / True |
| large / full/person / 5-minute offered workload | 8 / 8 | 600 | 306 | 331 | 338 | 365 | 753 | True / True / False |
| large / full/person / mixed | 64 / 8 | 120 | 319 | 342 | 361 | 447 | 791 | True / True / True |
| large / full/person / mixed | 256 / 8 | 120 | 312 | 334 | 338 | 359 | 461 | True / True / True |
| large / full/person / 5-minute offered workload | 64 / 64 | 4755 | 396 | 654 | 672 | 925 | 1626 | False / False / True |
| large / full/town-linked / 5-minute offered workload | 32 / 32 | 2400 | 340 | 375 | 387 | 458 | 995 | True / True / True |
| large / city/city / 5-minute offered workload | 64 / 64 | 4717 | 326 | 454 | 469 | 608 | 1214 | False / None / True |
| xlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 320 | 345 | 352 | 408 | 737 | True / True / True |
| xlarge / full/person / mixed | 64 / 8 | 120 | 319 | 333 | 343 | 383 | 788 | True / True / True |
| xlarge / full/person / mixed | 256 / 8 | 120 | 319 | 340 | 344 | 382 | 426 | True / True / True |
| xlarge / full/person / 5-minute offered workload | 64 / 64 | 4800 | 338 | 402 | 424 | 564 | 2471 | True / True / True |
| xlarge / full/town-linked / 5-minute offered workload | 64 / 64 | 4800 | 327 | 379 | 390 | 469 | 805 | True / True / True |
| xlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 300 | 365 | 415 | 705 | 1347 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 328 | 352 | 357 | 396 | 560 | True / True / True |
| xxlarge / full/person / mixed | 64 / 8 | 120 | 346 | 372 | 387 | 460 | 860 | True / True / True |
| xxlarge / full/person / mixed | 256 / 8 | 120 | 356 | 383 | 391 | 424 | 862 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 128 / 128 | 9600 | 423 | 3589 | 3583 | 4024 | 4935 | True / False / True |
| xxlarge / full/town-linked / 5-minute offered workload | 128 / 128 | 9561 | 340 | 427 | 469 | 777 | 1138 | False / False / True |
| xxlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 293 | 342 | 354 | 447 | 844 | True / True / True |

## Applying the measurements

Size for active work and idle connections separately. For example, 1,000 connected devices with eight devices changing data are not the same workload as 1,000 devices continuously changing data. Consult the mixed-load controls before combining the two axes.

A larger change batch reduces the supported round rate. Populated relation graphs can add merge work even when the number of changed rows is unchanged. More CPU can help under concurrent load; lower database latency matters when serial database exchanges dominate. This campaign does not isolate a database-location change.

Use headroom below the observed boundary and test reconnect bursts, longer idle periods, larger retained datasets, and sustained activity. The finite screens do not measure multi-instance scaling or establish a maximum concurrent-user promise.

The [raw sizing selection](sizing.json) records each selection, its source trial IDs, and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) for failures and observations excluded from the selection.
