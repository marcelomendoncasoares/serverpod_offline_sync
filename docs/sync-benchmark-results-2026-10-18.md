# Sync benchmark results — 2026-10-18

> Historical evidence through 19 October 2026. No tests, benchmarks or
> deployments were rerun for this review split. Deployment states, source
> commits and configuration below describe those experiments. Private paths
> and deployment identities use stable aliases; `evidence://` references
> identify original artifacts that are not bundled in this repository.
> Build and setup references concern the companion code reviews linked in the
> [evidence index](../benchmark/results/README.md). Historical patch descriptions
> are not installation instructions.

Follow-up: [attempts 23–26](sync-optimization-followup-2026-10-19.md) complete proposals 2–5 below; proposal 1 is deferred. The follow-up repairs Medium timing correlation, records a rejected preparation change, measures retained-heap savings, and validates optional cross-pod commit hints. Its raw-clock populations are separate from this historical report. See the [current handoff](sync-performance-handoff.md) for deployment and remaining work.

The local **32.4 ms p95** belongs to one-row inserts across 64 established streams on the earlier placement-comparison build. The Cloud **545.7 ms is a mean**, for 50-row updates across eight streams on the final build; its p95 is **651.4 ms**. The final Cloud one-row, 64-stream result is **596.7 ms mean / 848.5 ms p95**. These are different workloads and must be compared using the matching rows below.

This report consolidates the latest measurements through attempt 22. The [performance handoff](sync-performance-handoff.md) contains implementation details, earlier results and reproduction commands. The [optimization ledger](../benchmark/results/2026-10-16-sync-optimization.json) records each attempt, including rejected changes and failed runs.

## Measurement definitions

- Latency runs measure **local write start to exact application on every peer**, after continuous streams have opened and completed warmup. They include local persistence, both network directions, server merge/capture and peer application.
- All latency values are **milliseconds**. `N` is the number of measured rounds. Rounds/s is the aggregate **offered** rate across users. Every user has two devices; one stream corresponds to one device.
- An insert round creates one row. An update round edits the indicated number of rows, changing two fields per row. These are conflict-free personal-space workloads.
- Pooled statistics are calculated from the combined raw observations, including outliers. Percentiles are not averages of per-run percentiles.
- Headline latency comparisons have detailed tracing disabled. Selective profiles are separate and carry their measured overhead and attribution limits.
- The client executable is held fixed within each optimization comparison. The later Medium capacity client has bounded warmup and current package sources, so comparisons across those client generations are not isolated server speed measurements.
- These are established-stream results. **Fresh syncOnce on the final code and Small-instance performance were not measured.**

## Cloud: final code on two actual CPU cores

One XXL instance had a verified two-core quota. Each update row pools two repetitions. All rows below passed exact convergence, met their offered rate and drained streams and unfinished transactions.

| Workload | Server version | Streams / users | Offered rounds/s | N | Min | Mean | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Insert 1 row | Final | 64 / 32 | 32 | 2560 | 388.2 | 596.7 | 564.2 | 848.5 | 1598.9 |
| Update 10 rows | Before authored-update batching | 8 / 4 | 2.67 | 160 | 382.6 | 525.5 | 489.3 | 585.6 | 2340.7 |
| Update 10 rows | Final | 8 / 4 | 2.67 | 160 | 351.0 | 458.2 | 455.3 | 531.8 | 819.4 |
| Update 50 rows | Before authored-update batching | 8 / 4 | 1.33 | 160 | 628.7 | 770.7 | 763.2 | 852.6 | 1171.6 |
| Update 50 rows | Final | 8 / 4 | 1.33 | 160 | 438.2 | 545.7 | 542.8 | 651.4 | 963.3 |

Authored-update batching saves **67.3 ms mean (12.8%)** for ten-row updates and **225.1 ms mean (29.2%)** for fifty-row updates. The corresponding p95 reductions are **53.8 ms (9.2%)** and **201.3 ms (23.6%)**. Sampled merge statement counts fall from **19 to 10** and **59 to 10**; outbound capture remains three statements. Transaction-control commands are separate from these counts.

Cloud instance and time variability remain possible confounders. The local paired controls below independently support the batching mechanism. The final insert run is a regression check; **no insert speed saving is credited**. It is slower than the earlier Cloud reference below, but those separate runs do not isolate the effect of the update change. The earlier suspected insert penalty did not reproduce in the retained longer controls.

Evidence: `domain-write-comparison.json`, `long-insert-comparison.json` and their raw runs under the evidence directory listed below.

## Placement comparison and subsequent direct-local checks

All cases use 64 streams / 32 users, one insert per round and 32 offered rounds/s. All met the offered rate. The first four rows use matching application sources from attempts 16–17, before the final schema-lifetime and authored-update changes.

| Placement / build | N | Min | Mean | Median | p95 | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Same machine, direct database | 3840 | 23.4 | 28.1 | 27.5 | 32.4 | 215.1 |
| Same machine, zero-delay proxy; pooled controls | 2560 | 27.1 | 32.0 | 30.5 | 38.7 | 195.7 |
| Same machine, calibrated database response delay | 1280 | 142.7 | 160.4 | 157.9 | 174.8 | 362.8 |
| Cloud reference, two cores | 3840 | 336.0 | 484.4 | 478.8 | 591.7 | 858.6 |
| Direct local, schema-lifetime fix validation 1 | 1280 | 22.8 | 26.9 | 25.5 | 29.8 | 261.8 |
| Direct local, schema-lifetime fix validation 2 | 1280 | 22.9 | 26.5 | 25.7 | 30.8 | 84.4 |

The final two rows are later validation runs with selective diagnostics, before authored-update batching. They establish successful startup and convergence after the schema-lifetime fix; they are not a controlled steady-state speed comparison with the first row.

The local server is pinned to two physical cores, with PostgreSQL and clients on separate cores, but has **no CPU quota**. Local Dart is 3.12.2; the hosted runtime is 3.13.5. Hardware, runtime, TLS and client-to-server distance differ between local and Cloud.

The calibrated proxy adds 3 ms to each database response chunk, scheduled from its arrival rather than serially accumulating chunk delays. With the same local executables and PostgreSQL cluster, this adds **128.3 ms to average sync latency** versus the pooled zero-delay controls. Warmed SELECT 1 medians are 0.63/0.79 ms in the surrounding controls, 6.88 ms with the delay, and 6.29 ms in the Cloud reference. Local PostgreSQL execution of SELECT 1 is approximately 0.003 ms.

These query durations include driver exchanges and scheduling. In particular, the driver awaits portal cleanup inside transactions; they are **not pure network RTT measurements**. The result proves sensitivity to repeated database responses. It does not isolate database geography as most of the Cloud/local gap: the sampled Cloud transport/client residual is 231.4 ms, versus approximately 11 ms locally, and sampled Cloud CPU consumption is also higher.

Evidence: `placement-comparison.json`, `schema-lifetime-comparison.json`, and `local/driver-exchange-evidence.json`.

## Local: isolate authored-update batching with database delay

Both arms use the same machine, PostgreSQL cluster and native client, with the same 3 ms response-chunk delay. Each run uses eight streams / four users and meets its offered rate.

| Workload | Server version | Offered rounds/s | N | Min | Mean | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Update 10 rows | Before batching | 4 | 48 | 163.9 | 179.5 | 167.8 | 203.1 | 453.3 |
| Update 10 rows | Final | 4 | 48 | 134.4 | 137.2 | 136.4 | 141.6 | 142.7 |
| Update 50 rows | Before batching | 2.67 | 48 | 354.4 | 360.7 | 358.4 | 375.0 | 381.0 |
| Update 50 rows | Final | 2.67 | 48 | 180.2 | 184.3 | 183.2 | 189.7 | 193.8 |

Mean savings are **42.3 ms (23.5%)** and **176.4 ms (48.9%)**, respectively. These controls demonstrate the benefit of removing per-row SQL calls under response latency. Their smaller sample sizes and different offered rates mean these percentages must not be added to or substituted for the hosted savings.

Evidence: `local-domain-comparison.json`.

## Medium: final code under active load

One Medium instance exposes a **0.25-core CPU quota** and 512 MB configured memory. These runs use the same final server executable as the two-core final measurements, with the later bounded-warmup client. Four workers warm one user each at a time; every device authors a sentinel, and the parent verifies the full stream count before measurement.

| Workload | Streams / users | Offered rounds/s | N | Min | Mean | Median | p95 | Max | Offered rate met |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Insert 1 row | 8 / 4 | 2.67 | 160 | 431.9 | 627.4 | 584.6 | 957.9 | 1266.0 | Yes |
| Insert 1 row | 64 / 32 | 8 | 960 | 702.1 | 6260.9 | 6207.6 | 7500.2 | 12739.2 | **No** |
| Update 10 rows | 8 / 4 | 2 | 80 | 523.0 | 679.7 | 660.5 | 842.2 | 1205.9 | Yes |

All three completed workloads converge exactly and drain cleanly. The 64-stream case misses its offered rate, so **128 active streams were skipped**. Exact convergence does not establish sustained throughput.

The original client also completed eight streams: mean 712.2 ms, median 668.7 ms, p95 960.3 ms. Its simultaneous 64-stream warmup failed at a 45-second sentinel timeout, reaching 46 streams with 30 unexpected ends and **zero measured exercise rounds**. Cleanup still reached zero streams and idle transactions. These failed and earlier-client cases remain in the ledger; bounded startup is not credited as a server speed saving.

Evidence: `medium-capacity-comparison.json`, including `failed` and `skipped` cases.

## Medium: idle stream capacity

Connections open at an aggregate scheduled rate of two per second. No application writes are requested during the quiet exercise interval. All three cases pass convergence checks and cleanup.

| Streams / users | Observed quiet seconds | Mean quiet CPU cores | Peak process RSS, MiB | Changes transferred during quiet interval | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 64 / 32 | 58.7 | 0.010 | 149.7 | 0 | Passed |
| 256 / 128 | 59.0 | 0.026 | 294.1 | 0 | Passed |
| 512 / 256 | 58.5 | 0.055 | 551.1 | 0 | Passed |

Peak RSS includes setup and verification. The 256- and 512-stream cases reuse one pod. **RSS is not cgroup-charged memory**, and the actual memory hard limit was not inspected. The 512-stream result reaches the configured memory size and establishes no comfortable memory headroom; these values are not per-stream allocation estimates.

Zero application changes does not mean zero WebSocket keepalive bytes. CPU includes benchmark telemetry. Raw scale summaries label these idle cases as an offered-load shortfall because initial offline residency contributes less than one nominal operation while actual operations are zero. No writes were requested; the raw label and fractional counts are retained, and these cases are not interpreted as active throughput measurements.

Evidence: the `idle` cases in `medium-capacity-comparison.json`.

## What the profiles establish

An earlier two-core selective profile pairs all 160 selected rounds without missing events. It uses the one-row, 64-stream workload before the final update batching. Sampling adds **26.4 ms mean (5.5%)** versus pooled untraced controls, so these timings describe the sample rather than the final untraced population.

| Component | Mean elapsed ms |
| --- | ---: |
| Merge SQL calls | 159.7 |
| Outbound capture SQL calls | 59.6 |
| Other server work and waits | 50.4 |
| Transport and client residual, both directions | 231.4 |
| **Total for sampled rounds** | **501.1** |

Mean merge-admission wait is 0.03 ms, included in other server work. The merge has ten statements and capture has three, plus transaction control. SQL elapsed time includes database execution, transport and driver/process scheduling; the residual includes client work and is not a pure network measurement. This partition is not an exact explanation of the final p95 observation.

The separate Medium 64-stream profile retains 40 complete rounds, but its inferred critical path exceeds the client duration in 22 rounds. **That partition is rejected**, with the inconsistent samples retained. Independent server counters average 4,044 ms across ten merge SQL calls and 1,176 ms across three capture calls; admission wait averages 0.04 ms. Event-loop lag averages 7.72 ms and reaches 490 ms. These are not an additive partition of the untraced 7.50-second p95. The visible CPU quota is known, but Cloud throttled-time counters and VM-service GC/isolate data were unavailable.

Evidence: `sampling-comparison.json`, `overhead-on-decomposition.json`, `medium-staged64-profile-server-only.json`, and the retained rejected `medium-staged64-profile-invalid-anchor-decomposition.json`.

## Next optimization experiments

The following are proposed experiments, with **no savings credited yet**. Repairing Medium correlation is a measurement prerequisite, not a performance improvement. Preserve the existing change → correctness validation → measurement → record → commit sequence, with unchanged clients within each comparison and separate untraced headline runs.

### 1. Remove the separate PostgreSQL portal-close wait

This is the most concrete next latency experiment. In the pinned `postgres` 3.5.20 driver, `_PreparedStatement.run` waits for `_closePendingPortals` after the result completes. Successful extended queries inside a transaction enqueue their portal for that separate close exchange. Parse, bind and execute are already sent together; there is no separate prepare exchange to eliminate on this path.

Prototype sending portal Close with the fully consumed query, before Sync, so cleanup can complete in the same exchange. PostgreSQL documents this message ordering and extended-query pipelining; this supports investigating the design, but does not prove that changing this driver's state machine is safe. Error responses must still drain through ReadyForQuery, and streaming/cancelled results need correct cleanup. See the [PostgreSQL protocol documentation](https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY).

Validate successful and failed transactions, rollback, cancellation races, subsequent connection reuse, result-stream lifetimes and bounded resource cleanup. Then compare query exchange counts and whole sync rounds using direct-local, calibrated-delay and Cloud controls. Preserve same-space locks and repeatable-read capture. The 128.3 ms delay sensitivity makes this worth measuring; it does not predict that all of that time can be recovered.

Source inspected: `postgres-3.5.20/lib/src/v3/connection.dart`, particularly `_PreparedStatement.run`, `_closePendingPortals`, the aggregated Execute/Sync send and ReadyForQuery handling. The exact inspected source hash is retained in `local/driver-exchange-evidence.json`.

### 2. Reduce CPU cost under Medium's quota

The active 64-stream case takes seconds and fails eight offered rounds/s, while admission wait is negligible in the independent sampled counters. CPU scheduling, allocation and observer overhead deserve a controlled investigation alongside database response latency.

First replace inferred cross-stream matching with explicit round/frame identity and monotonic timing anchors. Separately measure benchmark telemetry overhead, then reproduce with a real 0.25-core quota and profile CPU and allocations. Core affinity alone does not reproduce that quota. Identify whether result decoding, parameter encoding, diagnostics, stream dispatch or repeated membership preparation dominates before changing those paths. Do not infer an exact throttling fraction from the approximate process CPU samples.

This experiment targets active throughput and tail latency. Keeping persistent session logs off is already part of the measured configuration; it is not a new optimization to credit.

### 3. Reduce repeated outbound preparation without weakening authorization

`_SyncSession._send` in [session.dart](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/packages/serverpod_offline_sync/lib/src/sync/session.dart) reconciles membership before each capture. The authoritative branch in [space_state.dart](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/packages/serverpod_offline_sync/lib/src/sync/space_state.dart) reads current grants. Capture then performs its own complete, consistent read of eligible changes. Measure that preparation separately from the three capture statements before attempting to consolidate it.

A candidate is to derive both the announced grants and eligible outbound work from one consistent capture result, avoiding redundant preparation where the protocol permits it. Sharing immutable capture or serialization work among devices may also help fan-out, but requires exact matching of authorization, cursors and snapshot identity, plus bounded memory. Neither optimization may cache grants indefinitely, skip revocations, advance a checkpoint past an unseen older fact, or keep a transaction open while waiting for a peer.

This is a higher-risk follow-up to the driver experiment. The previous joined source-lookup experiment was rejected after measurement; do not reintroduce it merely to reduce a statement count.

### 4. Measure and reduce retained memory per stream

The 512-stream run peaks at 551.1 MiB process RSS. Establish retained heap and charged-memory baselines, then inspect session contexts, subscriptions, schema data, queued frames and cleanup after disconnect. Share immutable structures only when the profile identifies actual duplication.

Both complete outbound captures and inbound batches remain buffered. One unacknowledged batch is not a byte bound. Before large-backlog capacity claims, measure peak memory versus payload bytes and investigate bounded buffering/backpressure while preserving the complete-snapshot/checkpoint guarantee. The current idle RSS measurements do not establish which objects dominate or prove a leak.

This targets the production device-count goal more directly than another small median reduction. It should be measured independently from active-write latency.

### 5. Add prompt cross-process wakeups before claiming multi-pod latency

[sync_recovery.dart](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/packages/serverpod_offline_sync/lib/src/database/sync_recovery.dart) schedules a recovery scan 1.2 seconds after the preceding scan finishes. Local commits already send immediate hints; commits on another process can wait for this polling cycle. The latest benchmark uses one pod, so this does not explain its measured steady-state latency.

A separate multi-pod experiment should use commit-triggered wakeup hints, with the durable revision/checkpoint scan retained for reconnects and missed hints. PostgreSQL LISTEN/NOTIFY is one candidate if the deployed connection topology supports a dedicated listener: notifications issued inside a transaction are delivered only after commit. See [PostgreSQL NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html). Another available inter-pod messaging mechanism could serve the same hint role. Hints must never authorize data access or replace durable change recovery.

Measure two devices deliberately placed on different pods, listener interruption/reconnection, membership revocation and missed notifications. This addresses an unmeasured scaling limitation; no benefit to the current single-pod result is assumed.

## Comparison discipline and remaining coverage

Start with the portal-close prototype and the Medium timing repair. Use separate commits and comparisons for each behavior; follow with quota/heap profiling before larger capture changes. Record absolute and percentage savings for the same workload, plus regressions, CPU, memory, offered-rate adherence and cleanup. Do not add savings percentages across workloads or builds.

Run the benchmark client near the same Cloud server when infrastructure permits, then vary database placement while keeping the server and client fixed. The current local control removes both remote database and remote client transport effects. It cannot establish the database's share of the entire hosted gap.

Remeasure fresh syncOnce on the current single streaming protocol, then cover conflict-heavy traffic, large backlogs, reconnect bursts and multiple pods. The final code's fresh syncOnce and Small capacity are unknown. No HTTP alternative or compatibility protocol is proposed.

Same-space database locking remains the cross-process serialization boundary, with clock-before-space ordering. Admission prevents same-user/space contention from consuming pool connections; unrelated users do not share that serialization queue, but do share global limits and process/database resources. Complete repeatable-read capture, rollback on cancellation and releasing transactions before peer waits remain required.

## Provenance and validation

- Report source: core `0bbe4d2c69f9411e758cdc30b64393f0d6d10688`, branch `fix/sync-merge-admission`; companion `96695a7f76d0eef7d787d186f3cc005cdeb03e21`, branch `fix/deployed-sync-benchmark`.
- Retained runtime changes include shared schema rebuild lifetime (`cbb69d5`) and authored domain update batching (`d9beeb3`). Earlier placement rows predate those changes, as labeled above.
- Final measured Cloud executable SHA-256: `ce2bdf2a4983441a2e4364127d123510a9282b0e648a9a3a706cc74186d009cf`. Final deployment upload: `uploadId-3615880cbcd5`; build: `buildId-759bb38a8c42`.
- Detailed evidence directory: `evidence://sync-sampled-20261018T173847Z`. Referenced JSON files retain exact commands, raw-event paths, source/client/executable identities and cleanup. The checked-in ledger and handoff retain the conclusions if temporary evidence is later removed.
- Completed latency runs pass exact convergence and drain to zero streams and idle transactions. No sampled database lock waits were observed. The Medium offered-rate failure and startup failure remain explicit.
- Implementation validation includes 55 focused merge checks, 96 schema/admission/cancellation/clock checks, 27 instrumentation checks and nine harness checks. Fatal-info analysis passed for the changes. Full CI was not run. This report adds no new runtime validation claim.
- At the end of measurement, Cloud was restored to **one Small instance, 0.1 CPU cores and 256 MB configured memory**, verified at `2026-10-18T20:04:35.781458+00:00`, with the same executable and zero streams or idle transactions. This is a recorded receipt, not a new live check made while writing this report. Small performance was not benchmarked.
- Session persistence and console logging were disabled through the benchmark override. All 19 protected configuration/secret files and all 193 managed deployment runtime files matched the retained verification receipts.
