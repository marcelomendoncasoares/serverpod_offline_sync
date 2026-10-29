# Observed capacity by workload

The completed [connection refinements](../native-tls-capacity-connection-refinements-2026-10-29/README.md) extend the verified idle trials to 1,024 devices on Large and 2,048 on XL/XXL. The discovery-only tables below preserve their original observations.

> Completed discovery baseline: 372 measured cases across Small, Medium, Large, XL, and XXL. These measurements use the cached/HLC native-TLS implementation at `e11f16b`. Sustained boundary follow-ups and the revision-checkpoint Cloud comparison remain in progress. Failures and incomplete observations are retained. The new pruning policy applies to subsequent campaigns; historical heavier and slower-cadence trials remain visible here.

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
| small / Town with linked parents, full registry | — | — |
| small / City, isolated registry | — | — |
| medium / Person, full registry | 8 / 449 | 8 / 449 |
| medium / Town with linked parents, full registry | — | — |
| medium / City, isolated registry | — | — |
| large / Person, full registry | — | — |
| large / Town with linked parents, full registry | — | — |
| large / City, isolated registry | — | — |
| xlarge / Person, full registry | 8 / 408 | 8 / 408 |
| xlarge / Town with linked parents, full registry | — | — |
| xlarge / City, isolated registry | — | — |
| xxlarge / Person, full registry | 8 / 396 | 8 / 396 |
| xxlarge / Town with linked parents, full registry | — | — |
| xxlarge / City, isolated registry | — | — |

## Connected but idle devices

The largest successful trial below completed setup, the idle hold, resumed delivery and exact verification, and drained cleanly. Failed attempts remain listed with their phase. A setup failure is not a measured ceiling for already established streams; a single pass is not a reliability guarantee. Probe traffic is bounded to eight users.

| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |
|---|---:|---|---:|---|
| small | 256 | 3318 / 3321 / 3910 | 223.2 | 1024 / warmup, 512 / warmup |
| medium | 256 | 1005 / 1012 / 1206 | 190.0 | 1024 / close |
| large | 64 | 521 / 512 / 614 | 119.9 | 256 / warmup |
| xlarge | 1024 | 392 / 404 / 505 | 473.2 | 4096 / warmup |
| xxlarge | 1024 | 378 / 385 / 460 | 433.2 | 4096 / warmup |

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
| medium / full/person / 5-minute offered workload | 8 / 8 | 600 | 344 | 373 | 387 | 449 | 973 | True / True / True |
| medium / full/person / mixed | 64 / 8 | 120 | 317 | 377 | 378 | 411 | 483 | True / True / True |
| medium / full/person / mixed | 256 / 8 | 120 | 341 | 376 | 407 | 470 | 1074 | True / True / True |
| large / full/person / 5-minute offered workload | 8 / 8 | 600 | 306 | 331 | 338 | 365 | 753 | True / True / False |
| large / full/person / mixed | 64 / 8 | 120 | 319 | 342 | 361 | 447 | 791 | True / True / True |
| large / full/person / mixed | 256 / 8 | 120 | 312 | 334 | 338 | 359 | 461 | True / True / True |
| xlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 320 | 345 | 352 | 408 | 737 | True / True / True |
| xlarge / full/person / mixed | 64 / 8 | 120 | 319 | 333 | 343 | 383 | 788 | True / True / True |
| xlarge / full/person / mixed | 256 / 8 | 120 | 319 | 340 | 344 | 382 | 426 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 328 | 352 | 357 | 396 | 560 | True / True / True |
| xxlarge / full/person / mixed | 64 / 8 | 120 | 346 | 372 | 387 | 460 | 860 | True / True / True |
| xxlarge / full/person / mixed | 256 / 8 | 120 | 356 | 383 | 391 | 424 | 862 | True / True / True |

## Applying the measurements

Size for active work and idle connections separately. For example, 1,000 connected devices with eight devices changing data are not the same workload as 1,000 devices continuously changing data. Consult the mixed-load controls before combining the two axes.

A larger change batch reduces the supported round rate. Populated relation graphs can add merge work even when the number of changed rows is unchanged. More CPU can help under concurrent load; lower database latency matters when serial database exchanges dominate. This campaign does not isolate a database-location change.

Use headroom below the observed boundary and test reconnect bursts, longer idle periods, larger retained datasets, and sustained activity. The finite screens do not measure multi-instance scaling or establish a maximum concurrent-user promise.

The [raw sizing selection](sizing.json) records each selection, its source trial IDs, and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) for failures and observations excluded from the selection.
