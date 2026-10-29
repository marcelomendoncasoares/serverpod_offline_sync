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
| large | — | — |
| xlarge | — | — |
| xxlarge | — | — |

## Active devices

Each cell shows **devices / p95 milliseconds** for the highest tested count that qualified. The first table additionally requires p95 below one second. Both require exact convergence, cleanup, complete observations, and keeping up with the offered rate. If repetitions disagree, that count does not qualify. A dash means no qualifying measurement; it does not mean zero capacity. Longer controls and different offered rates are retained in the [complete measurements](README.md).

### Kept up with p95 below one second

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | 8 / 876 | 32 / 858 | — | — | — |
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
| City, isolated registry | 200 | — | 2 / 891 | — | — | — |
| City, isolated registry | 1000 | — | — | — | — | — |

### Kept up, without a latency target

| Schema profile | Rows | Small | Medium | Large | XL | XXL |
|---|---:|---:|---:|---:|---:|---:|
| Person, full registry | 1 | 8 / 876 | 32 / 858 | — | — | — |
| Person, full registry | 10 | — | — | — | — | — |
| Person, full registry | 50 | — | — | — | — | — |
| Person, full registry | 200 | — | 2 / 1277 | — | — | — |
| Person, full registry | 1000 | — | — | — | — | — |
| Town with linked parents, full registry | 1 | — | — | — | — | — |
| Town with linked parents, full registry | 10 | — | — | — | — | — |
| Town with linked parents, full registry | 50 | — | — | — | — | — |
| Town with linked parents, full registry | 200 | — | 2 / 1254 | — | — | — |
| Town with linked parents, full registry | 1000 | — | — | — | — | — |
| City, isolated registry | 1 | — | — | — | — | — |
| City, isolated registry | 10 | — | — | — | — | — |
| City, isolated registry | 50 | — | — | — | — | — |
| City, isolated registry | 200 | — | 2 / 891 | — | — | — |
| City, isolated registry | 1000 | — | — | — | — | — |

Person writes two text fields with nullable relations unpopulated. Town writes its name and populated City/Person references, with the linked parents seeded before exercise. City uses one persisted name field in an isolated registry. These profiles sample different costs; field counts alone do not model an arbitrary application schema.

## Five-minute one-row validation

These operating points completed at least five minutes of offered one-row traffic with exact convergence, cleanup, complete observations, and rate adherence. They use the same two-device users and two-second cadence as the short screens. A failed or incompletely observed repetition disqualifies that count. Mixed idle/active workloads remain separate. A dash means no qualifying sustained trial, not zero capacity.

Each cell is **participating devices / p95 milliseconds**. Keeping up and meeting a subsecond p95 remain separate requirements. These finite runs support a starting operating point; they do not establish long-term reliability or a maximum.

| Size / schema profile | Kept up | Kept up with p95 below one second |
|---|---:|---:|
| small / Person, full registry | — | — |
| small / Town with linked parents, full registry | — | — |
| small / City, isolated registry | — | — |
| medium / Person, full registry | — | — |
| medium / Town with linked parents, full registry | — | — |
| medium / City, isolated registry | — | — |
| large / Person, full registry | — | — |
| large / Town with linked parents, full registry | — | — |
| large / City, isolated registry | — | — |
| xlarge / Person, full registry | — | — |
| xlarge / Town with linked parents, full registry | — | — |
| xlarge / City, isolated registry | — | — |
| xxlarge / Person, full registry | — | — |
| xxlarge / Town with linked parents, full registry | — | — |
| xxlarge / City, isolated registry | — | — |

## Connected but idle devices

The largest successful trial below completed setup, the idle hold, resumed delivery and exact verification, and drained cleanly. Failed attempts remain listed with their phase. A setup failure is not a measured ceiling for already established streams; a single pass is not a reliability guarantee. Probe traffic is bounded to eight users.

| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |
|---|---:|---|---:|---|
| small | — | — | — | — |
| medium | — | — | — | — |
| large | — | — | — | — |
| xlarge | — | — | — | — |
| xxlarge | — | — | — | — |

## Measured overlap in one-row screens

These are the highest qualifying throughput screens from the second active-device table. The mean and peak count devices involved in unfinished application rounds, from local write through final peer application. They show how much of the configured participating population was actually overlapping.

| Size / profile | Participating devices | Offered rounds/s | Overlapping devices, mean / peak | p95 ms |
|---|---:|---:|---:|---:|
| small / Person, full registry | 8 | 2 | 2.8 / 4 | 876 |
| medium / Person, full registry | 32 | 8 | 10.4 / 16 | 858 |

## Mixed connections and sustained controls

The controls below use one-row writes in the named schema profiles. They keep latency, correctness, offered-rate adherence, and observation completeness separate. An incomplete observation does not erase the client timings, but excludes the run from a matched speedup claim. A mixed-load pass can establish a connected-device count that a separate setup attempt failed to establish; inspect both rather than treating the first failure as a ceiling.

| Size / profile / control | Connected / active devices | Rounds | Min | Median | Mean | p95 | Max | Correct / kept up / observed |
|---|---:|---:|---:|---:|---:|---:|---:|---|

## Applying the measurements

Size for active work and idle connections separately. For example, 1,000 connected devices with eight devices changing data are not the same workload as 1,000 devices continuously changing data. Consult the mixed-load controls before combining the two axes.

A larger change batch reduces the supported round rate. Populated relation graphs can add merge work even when the number of changed rows is unchanged. More CPU can help under concurrent load; lower database latency matters when serial database exchanges dominate. This campaign does not isolate a database-location change.

Use headroom below the observed boundary and test reconnect bursts, longer idle periods, larger retained datasets, and sustained activity. The finite screens do not measure multi-instance scaling or establish a maximum concurrent-user promise.

The [raw sizing selection](sizing.json) records each selection, its source trial IDs, and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) for failures and observations excluded from the selection.
