# Observed capacity by workload

CPU accounting has unresolved discrepancies in the source observations. Do not infer an enforced CPU ceiling, headroom, or throttling from those counters. See [CPU accounting observations](../revision-checkpoint-capacity-2026-10-29/RESOURCE_ACCOUNTING.md), [CPU accounting observations](../revision-checkpoint-capacity-qualification-2026-10-29/RESOURCE_ACCOUNTING.md).

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
| Person, full registry | 1 | — | 8 / 436 | 64 / 478 | 128 / 548 | 128 / 413 |
| Person, full registry | 10 | 2 / 983 | 16 / 577 | 16 / 404 | 32 / 390 | 128 / 442 |
| Person, full registry | 50 | — | 8 / 607 | 16 / 450 | 64 / 568 | 64 / 522 |
| Person, full registry | 200 | — | — | 8 / 780 | 16 / 725 | 32 / 918 |
| Person, full registry | 1000 | — | — | — | — | — |
| Person, full registry | 5000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | — | 8 / 600 | 16 / 389 | 64 / 449 | 128 / 421 |
| Town with linked parents, full registry | 10 | — | 16 / 682 | 16 / 408 | 64 / 432 | 32 / 403 |
| Town with linked parents, full registry | 50 | — | 8 / 802 | 16 / 522 | 32 / 499 | 64 / 643 |
| Town with linked parents, full registry | 200 | — | — | 8 / 961 | 8 / 811 | 16 / 842 |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 5000 | — | — | — | — | — |
| City, isolated registry | 1 | 2 / 900 | 32 / 616 | 64 / 397 | 128 / 411 | 128 / 450 |
| City, isolated registry | 10 | 8 / 902 | 8 / 463 | 64 / 721 | 128 / 575 | 128 / 420 |
| City, isolated registry | 50 | 2 / 999 | 16 / 702 | 32 / 533 | 64 / 553 | 32 / 382 |
| City, isolated registry | 200 | — | 2 / 886 | 16 / 701 | 32 / 648 | 32 / 698 |
| City, isolated registry | 1000 | — | — | — | — | — |
| City, isolated registry | 5000 | — | — | — | — | — |

### Kept up, without a latency target

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | 8 / 2200 | 32 / 1650 | 64 / 478 | 128 / 548 | 128 / 413 |
| Person, full registry | 10 | 8 / 2292 | 16 / 577 | 16 / 404 | 128 / 1639 | 128 / 442 |
| Person, full registry | 50 | 4 / 2102 | 16 / 1169 | 16 / 450 | 64 / 568 | 64 / 522 |
| Person, full registry | 200 | — | 4 / 1239 | 8 / 780 | 16 / 725 | 32 / 918 |
| Person, full registry | 1000 | — | — | — | — | — |
| Person, full registry | 5000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | 4 / 1298 | 32 / 1398 | 16 / 389 | 64 / 449 | 128 / 421 |
| Town with linked parents, full registry | 10 | 4 / 1375 | 16 / 682 | 16 / 408 | 64 / 432 | 128 / 1975 |
| Town with linked parents, full registry | 50 | 2 / 1863 | 8 / 802 | 16 / 522 | 32 / 499 | 64 / 643 |
| Town with linked parents, full registry | 200 | — | 4 / 1604 | 8 / 961 | 16 / 1338 | 16 / 842 |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 5000 | — | — | — | — | — |
| City, isolated registry | 1 | 8 / 1069 | 32 / 616 | 64 / 397 | 128 / 411 | 128 / 450 |
| City, isolated registry | 10 | 8 / 902 | 32 / 1138 | 64 / 721 | 128 / 575 | 128 / 420 |
| City, isolated registry | 50 | 4 / 1258 | 16 / 702 | 32 / 533 | 64 / 553 | 128 / 1438 |
| City, isolated registry | 200 | 2 / 1977 | 8 / 1145 | 16 / 701 | 32 / 648 | 32 / 698 |
| City, isolated registry | 1000 | — | — | 4 / 2173 | 4 / 2192 | 8 / 2201 |
| City, isolated registry | 5000 | — | — | — | — | — |

Person writes two text fields with nullable relations unpopulated. Town writes its name and populated City/Person references, with the linked parents seeded before exercise. City uses one persisted name field in an isolated registry. These profiles sample different costs; field counts alone do not model an arbitrary application schema.

## Five-minute one-row validation

These operating points completed at least five minutes of offered one-row traffic with exact convergence, cleanup, complete observations, and rate adherence. They use the same two-device users and two-second cadence as the short screens. A failed or incompletely observed repetition disqualifies that count. Mixed idle/active workloads remain separate. A dash means no qualifying sustained trial, not zero capacity.

Each cell is **participating devices / p95 milliseconds**. Keeping up and meeting a subsecond p95 remain separate requirements. These finite runs support a starting operating point; they do not establish long-term reliability or a maximum.

| Size / schema profile | Kept up | Kept up with p95 below one second |
|---|---:|---:|
| small / Person, full registry | 8 / 1990 | — |
| small / Town with linked parents, full registry | 4 / 960 | 4 / 960 |
| small / City, isolated registry | 8 / 883 | 8 / 883 |
| medium / Person, full registry | 4 / 443 | 4 / 443 |
| medium / Town with linked parents, full registry | 32 / 1736 | — |
| medium / City, isolated registry | 32 / 652 | 32 / 652 |
| large / Person, full registry | 64 / 682 | 64 / 682 |
| large / Town with linked parents, full registry | 16 / 413 | 16 / 413 |
| large / City, isolated registry | 64 / 497 | 64 / 497 |
| xlarge / Person, full registry | 64 / 450 | 64 / 450 |
| xlarge / Town with linked parents, full registry | 64 / 464 | 64 / 464 |
| xlarge / City, isolated registry | 128 / 420 | 128 / 420 |
| xxlarge / Person, full registry | 64 / 466 | 64 / 466 |
| xxlarge / Town with linked parents, full registry | 128 / 535 | 128 / 535 |
| xxlarge / City, isolated registry | 128 / 422 | 128 / 422 |

## Connected but idle devices

The largest successful trial below completed setup, the idle hold, resumed delivery and exact verification, and drained cleanly. Failed attempts remain listed with their phase. A setup failure is not a measured ceiling for already established streams; a single pass is not a reliability guarantee. Resumed-delivery probes cover every idle user, with at most eight users being probed at once in these trials.

| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |
|---|---:|---|---:|---|
| small | 256 | 2798 / 2827 / 3480 | 204.3 | 1024 / warmup, 512 / warmup |
| medium | 1024 | 1446 / 1454 / 1903 | 443.2 | 4096 / init, 2048 / warmup |
| large | 128 | 502 / 540 / 790 | 130.4 | 256 / exercise |
| xlarge | 512 | 430 / 439 / 545 | 231.9 | 1024 / exercise |
| xxlarge | 1024 | 363 / 371 / 441 | 447.8 | 4096 / warmup, 2048 / close |

## Measured overlap in one-row screens

These are the highest qualifying throughput screens from the second active-device table. The mean and peak count devices involved in unfinished application rounds, from local write through final peer application. They show how much of the configured participating population was actually overlapping.

| Size / profile | Participating devices | Offered rounds/s | Overlapping devices, mean / peak | p95 ms |
|---|---:|---:|---:|---:|
| small / Person, full registry | 8 | 2 | 5.3 / 8 | 2200 |
| small / Town with linked parents, full registry | 4 | 1 | 1.8 / 4 | 1298 |
| small / City, isolated registry | 8 | 2 | 2.3 / 6 | 1069 |
| medium / Person, full registry | 32 | 8 | 15.3 / 32 | 1650 |
| medium / Town with linked parents, full registry | 32 | 8 | 17.8 / 26 | 1398 |
| medium / City, isolated registry | 32 | 8 | 8.1 / 12 | 616 |
| large / Person, full registry | 64 | 16 | 12.7 / 18 | 478 |
| large / Town with linked parents, full registry | 16 | 4 | 2.8 / 6 | 389 |
| large / City, isolated registry | 64 | 16 | 10.6 / 16 | 397 |
| xlarge / Person, full registry | 128 | 32 | 24.5 / 46 | 548 |
| xlarge / Town with linked parents, full registry | 64 | 16 | 11.6 / 20 | 449 |
| xlarge / City, isolated registry | 128 | 32 | 21.0 / 38 | 411 |
| xxlarge / Person, full registry | 128 | 32 | 22.4 / 32 | 413 |
| xxlarge / Town with linked parents, full registry | 128 | 32 | 23.4 / 30 | 421 |
| xxlarge / City, isolated registry | 128 | 32 | 21.6 / 36 | 450 |

## Mixed connections and sustained controls

The controls below use one-row writes in the named schema profiles. They keep latency, correctness, offered-rate adherence, and observation completeness separate. An incomplete observation does not erase the client timings, but excludes the run from a matched speedup claim. A mixed-load pass can establish a connected-device count that a separate setup attempt failed to establish; inspect both rather than treating the first failure as a ceiling.

| Size / profile / control | Connected / active devices | Rounds | Min | Median | Mean | p95 | Max | Correct / kept up / observed |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| small / full/person / 5-minute offered workload | 8 / 8 | 600 | 689 | 1105 | 1199 | 1990 | 2317 | True / True / True |
| small / full/person / mixed | 64 / 8 | 120 | 936 | 1358 | 1399 | 1835 | 2349 | True / True / True |
| small / full/person / mixed | 256 / 8 | 120 | 981 | 2000 | 2004 | 2593 | 2998 | True / False / True |
| small / full/town-linked / 5-minute offered workload | 4 / 4 | 300 | 636 | 760 | 801 | 960 | 2345 | True / True / True |
| small / city/city / 5-minute offered workload | 8 / 8 | 600 | 397 | 589 | 623 | 883 | 1904 | True / True / True |
| medium / full/person / 5-minute offered workload | 8 / 8 | 136 | 349 | 375 | 391 | 466 | 559 | False / None / True |
| medium / full/person / mixed | 64 / 8 | 120 | 345 | 374 | 385 | 454 | 469 | False / True / True |
| medium / full/person / 5-minute offered workload | 4 / 4 | 300 | 348 | 376 | 383 | 443 | 602 | True / True / True |
| medium / full/town-linked / 5-minute offered workload | 32 / 32 | 2400 | 531 | 1267 | 1295 | 1736 | 2192 | True / True / True |
| medium / city/city / 5-minute offered workload | 32 / 32 | 2400 | 307 | 508 | 521 | 652 | 1238 | True / True / True |
| large / full/person / 5-minute offered workload | 8 / 8 | 600 | 299 | 330 | 336 | 372 | 919 | True / True / True |
| large / full/person / mixed | 64 / 8 | 120 | 311 | 329 | 332 | 348 | 556 | True / True / True |
| large / full/person / mixed | 256 / 8 | 120 | 315 | 326 | 342 | 442 | 678 | True / True / True |
| large / full/person / 5-minute offered workload | 64 / 64 | 4800 | 349 | 509 | 523 | 682 | 1221 | True / True / True |
| large / full/town-linked / 5-minute offered workload | 16 / 16 | 1200 | 339 | 369 | 377 | 413 | 982 | True / True / True |
| large / city/city / 5-minute offered workload | 64 / 64 | 4800 | 311 | 389 | 401 | 497 | 979 | True / True / True |
| xlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 300 | 326 | 331 | 365 | 628 | True / True / True |
| xlarge / full/person / mixed | 64 / 8 | 120 | 312 | 344 | 344 | 374 | 442 | True / True / True |
| xlarge / full/person / mixed | 256 / 8 | 120 | 302 | 331 | 337 | 373 | 557 | True / True / True |
| xlarge / full/person / 5-minute offered workload | 128 / 128 | 0 | — | — | — | — | — | False / None / True |
| xlarge / full/person / 5-minute offered workload | 64 / 64 | 4800 | 326 | 370 | 379 | 450 | 922 | True / True / True |
| xlarge / full/town-linked / 5-minute offered workload | 64 / 64 | 4800 | 327 | 367 | 380 | 464 | 964 | True / True / True |
| xlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 293 | 334 | 345 | 420 | 819 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 8 / 8 | 600 | 321 | 350 | 359 | 407 | 559 | True / True / True |
| xxlarge / full/person / mixed | 64 / 8 | 120 | 329 | 363 | 366 | 396 | 475 | True / True / True |
| xxlarge / full/person / mixed | 256 / 8 | 120 | 324 | 356 | 367 | 450 | 584 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 128 / 128 | 9600 | 333 | 2499 | 2489 | 2814 | 3699 | True / False / True |
| xxlarge / full/person / 5-minute offered workload | 64 / 64 | 4800 | 326 | 386 | 393 | 466 | 781 | True / True / True |
| xxlarge / full/town-linked / 5-minute offered workload | 128 / 128 | 9600 | 341 | 411 | 431 | 535 | 1685 | True / True / True |
| xxlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 283 | 329 | 339 | 422 | 933 | True / True / True |

## Applying the measurements

Size for active work and idle connections separately. For example, 1,000 connected devices with eight devices changing data are not the same workload as 1,000 devices continuously changing data. Consult the mixed-load controls before combining the two axes.

A larger change batch reduces the supported round rate. Populated relation graphs can add merge work even when the number of changed rows is unchanged. More CPU can help under concurrent load; lower database latency matters when serial database exchanges dominate. This campaign does not isolate a database-location change.

Use headroom below the observed boundary and test reconnect bursts, longer idle periods, larger retained datasets, and sustained activity. The finite screens do not measure multi-instance scaling or establish a maximum concurrent-user promise.

The [raw sizing selection](sizing.json) records each selection, its source trial IDs, and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) for failures and observations excluded from the selection.
