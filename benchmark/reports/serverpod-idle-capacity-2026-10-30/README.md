# Ordinary Serverpod idle streaming capacity

This is the initial Small/Medium campaign plus three slower Large controls. See [the opening-rate transition](OPENING_RATE_TRANSITION.md) for the clean handoff to the continued larger-tier campaign.

This experiment measures a regular authenticated bidirectional Serverpod method stream. Each connection echoes a unique String before and after inactivity. The endpoint does no Offline Sync work and executes no SQL. Every simulated device has its own Client and WebSocket.

All counts are observed operating points on one instance. Passing the largest attempted count establishes a lower bound; setup, transport and close failures do not by themselves identify a hardware limit.

## Comparison with the earlier sync campaign

The [previous Offline Sync report](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/perf/checkpoint-capacity-validation/benchmark/reports/revision-checkpoint-capacity-combined-2026-10-29/CAPACITY_GUIDE.md) used a 45-second idle interval followed by durable changes between two devices per user. The regular-stream control screens the same idle duration and also qualifies selected counts for five minutes. Its echo latency is not a sync-round latency.

| Tier | Offline Sync: strict 45 s pass | Regular stream: 45 s pass | Regular stream: 5 min pass | 5 min probe median / p95 ms | Next unsuccessful target |
|---|---:|---:|---:|---:|---|
| Small | 256 | 448 | 224 | 252.1 / 319.3 | 640 (open) |
| Medium | 1,024 | 1,024 | 1,024 | 238.9 / 304.3 | 1,792 (open) |

The prior 1,024-device strict maximum was not proof of a 1,024-stream framework limit: its XXL 2,048-device trial delivered and verified all users, then failed during close. Likewise, the prior report did not establish a 200-row batch limit: City workloads with 1,000 rows kept up on Large, XL and XXL at lower concurrency. Throughput, correctness and lifecycle success are separate measurements.

## Every measured case

Latencies are milliseconds from sending a resume message to receiving the identical message on the same connection. All streams are probed, with at most eight simultaneous probes. Warmup/setup is excluded.

| Case | Verdict / phase | Opened / resumed | Idle s | Min | Median | Mean | p95 | Max | Peak cgroup MiB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| small-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 217.2 | 249.7 | 253.3 | 307.6 | 356.2 | 95.9 |
| small-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 214.7 | 274.9 | 277.9 | 389.4 | 497.9 | 189.7 |
| small-echo-c1024-idle45-screen | FAIL / open | 401 / 0 | 45 | — | — | — | — | — | 234.9 |
| small-echo-c640-idle45-refinement | FAIL / open | 608 / 0 | 45 | — | — | — | — | — | 226.3 |
| small-echo-c448-idle45-refinement | PASS | 448 / 448 | 45 | 217.3 | 283.3 | 363.4 | 675.5 | 3,497.5 | 211.8 |
| small-echo-c448-idle300-qualification | FAIL / open | 88 / 0 | 300 | — | — | — | — | — | 233.6 |
| small-echo-c224-idle300-qualification | PASS | 224 / 224 | 300 | 217.3 | 252.1 | 263.7 | 319.3 | 412.4 | 220.2 |
| medium-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 219.7 | 248.0 | 245.4 | 262.3 | 282.8 | 96.8 |
| medium-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 217.5 | 249.7 | 248.5 | 278.3 | 336.8 | 173.1 |
| medium-echo-c1024-idle45-screen | PASS | 1024 / 1024 | 45 | 214.9 | 247.9 | 249.1 | 296.9 | 428.2 | 425.2 |
| medium-echo-c4096-idle45-screen | FAIL / open | 725 / 0 | 45 | — | — | — | — | — | 476.9 |
| medium-echo-c2560-idle45-refinement | FAIL / open | 1530 / 0 | 45 | — | — | — | — | — | 470.3 |
| medium-echo-c1792-idle45-refinement | FAIL / open | 1521 / 0 | 45 | — | — | — | — | — | 474.7 |
| medium-echo-c1024-idle300-qualification | PASS | 1024 / 1024 | 300 | 214.6 | 238.9 | 253.4 | 304.3 | 1,080.5 | 408.0 |
| large-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 217.1 | 238.0 | 241.9 | 260.6 | 270.0 | 95.8 |
| large-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 215.8 | 241.9 | 253.9 | 357.2 | 594.8 | 185.2 |
| large-echo-c1024-idle45-screen | PASS | 1024 / 1024 | 45 | 215.8 | 244.6 | 249.8 | 297.8 | 428.8 | 435.9 |

## Interpretation and controls

- Setup is bounded to the per-tier opening-worker counts multiplied by openConcurrencyPerWorker in manifest.json (one if omitted). Connection establishment does not include Offline Sync startup or a user lookup in PostgreSQL.
- Authentication uses the existing benchmark admin credential. No replica database or per-user domain data is created by these clients. The server still loads the benchmark application; this removes Offline Sync from the measured endpoint, not from the process baseline.
- Normal Serverpod keepalives remain enabled. There are no application messages during the idle interval, no automatic reconnects, and no retries.
- SQL-free server metrics are sampled every five seconds. The earlier campaign used a separate diagnostics collector and periodic database metrics; monitoring overhead is not identical.
- Shutdown is bounded to 64 simultaneous closes. The earlier sync runner closed all devices together. A transport-control shutdown pass therefore does not resolve a possible burst-teardown defect in the sync campaign.
- The server executable, Dart client executable and source revision are recorded in [manifest.json](manifest.json). Serverpod and driver dependencies stay pinned. PostgreSQL TLS is native and pipelining remains disabled, although the echo endpoint does not use the database.
- [results.json](results.json) preserves all verdicts, failures, actual server connection counts and generator observations. [samples.jsonl](samples.jsonl) preserves every open/probe timing and client resource sample. [resource-boundaries.json](resource-boundaries.json) records memory, file descriptors and stream counts at each lifecycle boundary.
- Cases on a tier reuse the instance until a restart or resize. Some opening failures occurred with memory still high after the preceding case closed. A five-minute qualification can therefore fail during opening even after the same count passed a shorter case. The two columns are observed full-lifecycle passes, not independently measured maximum idle capacities.
- A changed server instance and high sampled memory support memory pressure as a candidate cause. No orchestrator OOM termination reason was captured. High memory after close also does not by itself prove a leak: garbage collection and allocator retention were not separated.
- Failed-case opened counts are successful warmup receipts, not necessarily simultaneous residency. Error and EOF can both be counted for one connection, and shutdown following the first fault can emit additional failure events. Do not interpret event counts as independent connection failures.
- More idle streams do not imply the same number of simultaneous syncs. A native endpoint with no database work is a control for transport capacity, not a substitute for an application workload.

## Restoration

The campaign restoration flag is clear. Consult the restoration receipt for the independently verified executable, instance size and cleanup.
