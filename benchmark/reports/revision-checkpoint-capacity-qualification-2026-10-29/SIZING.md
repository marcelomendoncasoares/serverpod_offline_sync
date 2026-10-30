# Observed capacity by workload

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
| Person, full registry | 1 | — | — | — | — | — |
| Person, full registry | 10 | — | — | — | — | — |
| Person, full registry | 50 | — | — | — | — | — |
| Person, full registry | 200 | — | — | — | — | — |
| Person, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | — | — | — | — | — |
| Town with linked parents, full registry | 10 | — | — | — | — | — |
| Town with linked parents, full registry | 50 | — | — | — | — | — |
| Town with linked parents, full registry | 200 | — | — | — | — | — |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| City, isolated registry | 1 | — | — | — | — | — |
| City, isolated registry | 10 | — | — | — | — | — |
| City, isolated registry | 50 | — | — | — | — | — |
| City, isolated registry | 200 | — | — | — | — | — |
| City, isolated registry | 1000 | — | — | — | — | — |

### Kept up, without a latency target

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | — | — | — | — | — |
| Person, full registry | 10 | — | — | — | — | — |
| Person, full registry | 50 | — | — | — | — | — |
| Person, full registry | 200 | — | — | — | — | — |
| Person, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | — | — | — | — | — |
| Town with linked parents, full registry | 10 | — | — | — | — | — |
| Town with linked parents, full registry | 50 | — | — | — | — | — |
| Town with linked parents, full registry | 200 | — | — | — | — | — |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| City, isolated registry | 1 | — | — | — | — | — |
| City, isolated registry | 10 | — | — | — | — | — |
| City, isolated registry | 50 | — | — | — | — | — |
| City, isolated registry | 200 | — | — | — | — | — |
| City, isolated registry | 1000 | — | — | — | — | — |

Person writes two text fields with nullable relations unpopulated. Town writes its name and populated City/Person references, with the linked parents seeded before exercise. City uses one persisted name field in an isolated registry. These profiles sample different costs; field counts alone do not model an arbitrary application schema.

## Five-minute one-row validation

These operating points completed at least five minutes of offered one-row traffic with exact convergence, cleanup, complete observations, and rate adherence. They use the same two-device users and two-second cadence as the short screens. A failed or incompletely observed repetition disqualifies that count. Mixed idle/active workloads remain separate. A dash means no qualifying sustained trial, not zero capacity.

Each cell is **participating devices / p95 milliseconds**. Keeping up and meeting a subsecond p95 remain separate requirements. These finite runs support a starting operating point; they do not establish long-term reliability or a maximum.

| Size / schema profile | Kept up | Kept up with p95 below one second |
|---|---:|---:|
| small / Person, full registry | — | — |
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

The largest successful trial below completed setup, the idle hold, resumed delivery and exact verification, and drained cleanly. Failed attempts remain listed with their phase. A setup failure is not a measured ceiling for already established streams; a single pass is not a reliability guarantee. Probe traffic is bounded to eight users.

| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |
|---|---:|---|---:|---|
| small | — | — | — | 512 / warmup |
| medium | — | — | — | 2048 / warmup |
| large | 128 | 502 / 540 / 790 | 130.4 | — |
| xlarge | 512 | 430 / 439 / 545 | 231.9 | — |
| xxlarge | — | — | — | 2048 / close |

## Measured overlap in one-row screens

These are the highest qualifying throughput screens from the second active-device table. The mean and peak count devices involved in unfinished application rounds, from local write through final peer application. They show how much of the configured participating population was actually overlapping.

| Size / profile | Participating devices | Offered rounds/s | Overlapping devices, mean / peak | p95 ms |
|---|---:|---:|---:|---:|

## Mixed connections and sustained controls

The controls below use one-row writes in the named schema profiles. They keep latency, correctness, offered-rate adherence, and observation completeness separate. An incomplete observation does not erase the client timings, but excludes the run from a matched speedup claim. A mixed-load pass can establish a connected-device count that a separate setup attempt failed to establish; inspect both rather than treating the first failure as a ceiling.

| Size / profile / control | Connected / active devices | Rounds | Min | Median | Mean | p95 | Max | Correct / kept up / observed |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| small / full/town-linked / 5-minute offered workload | 4 / 4 | 300 | 636 | 760 | 801 | 960 | 2345 | True / True / True |
| small / city/city / 5-minute offered workload | 8 / 8 | 600 | 397 | 589 | 623 | 883 | 1904 | True / True / True |
| medium / full/person / 5-minute offered workload | 4 / 4 | 300 | 348 | 376 | 383 | 443 | 602 | True / True / True |
| medium / full/town-linked / 5-minute offered workload | 32 / 32 | 2400 | 531 | 1267 | 1295 | 1736 | 2192 | True / True / True |
| medium / city/city / 5-minute offered workload | 32 / 32 | 2400 | 307 | 508 | 521 | 652 | 1238 | True / True / True |
| large / full/person / 5-minute offered workload | 64 / 64 | 4800 | 349 | 509 | 523 | 682 | 1221 | True / True / True |
| large / full/town-linked / 5-minute offered workload | 16 / 16 | 1200 | 339 | 369 | 377 | 413 | 982 | True / True / True |
| large / city/city / 5-minute offered workload | 64 / 64 | 4800 | 311 | 389 | 401 | 497 | 979 | True / True / True |
| xlarge / full/person / 5-minute offered workload | 128 / 128 | 0 | — | — | — | — | — | False / None / True |
| xlarge / full/person / 5-minute offered workload | 64 / 64 | 4800 | 326 | 370 | 379 | 450 | 922 | True / True / True |
| xlarge / full/town-linked / 5-minute offered workload | 64 / 64 | 4800 | 327 | 367 | 380 | 464 | 964 | True / True / True |
| xlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 293 | 334 | 345 | 420 | 819 | True / True / True |
| xxlarge / full/person / 5-minute offered workload | 128 / 128 | 9600 | 333 | 2499 | 2489 | 2814 | 3699 | True / False / True |
| xxlarge / full/person / 5-minute offered workload | 64 / 64 | 4800 | 326 | 386 | 393 | 466 | 781 | True / True / True |
| xxlarge / full/town-linked / 5-minute offered workload | 128 / 128 | 9600 | 341 | 411 | 431 | 535 | 1685 | True / True / True |
| xxlarge / city/city / 5-minute offered workload | 128 / 128 | 9600 | 283 | 329 | 339 | 422 | 933 | True / True / True |

## Applying the measurements

Size for active work and idle connections separately. For example, 1,000 connected devices with eight devices changing data are not the same workload as 1,000 devices continuously changing data. Consult the mixed-load controls before combining the two axes.

A larger change batch reduces the supported round rate. Populated relation graphs can add merge work even when the number of changed rows is unchanged. More CPU can help under concurrent load; lower database latency matters when serial database exchanges dominate. This campaign does not isolate a database-location change.

Use headroom below the observed boundary and test reconnect bursts, longer idle periods, larger retained datasets, and sustained activity. The finite screens do not measure multi-instance scaling or establish a maximum concurrent-user promise.

The [raw sizing selection](sizing.json) records each selection, its source trial IDs, and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) for failures and observations excluded from the selection.
