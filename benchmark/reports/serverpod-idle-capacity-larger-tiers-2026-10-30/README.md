# Ordinary Serverpod idle streaming capacity

This experiment measures a regular authenticated bidirectional Serverpod method stream. Each connection echoes a unique String before and after inactivity. The endpoint does no Offline Sync work and executes no SQL. Every simulated device has its own Client and WebSocket.

All counts are observed operating points on one instance. Passing the largest attempted count establishes a lower bound; setup, transport and close failures do not by themselves identify a hardware limit.

## Comparison with the earlier sync campaign

The [previous Offline Sync report](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/perf/checkpoint-capacity-validation/benchmark/reports/revision-checkpoint-capacity-combined-2026-10-29/CAPACITY_GUIDE.md) used a 45-second idle interval followed by durable changes between two devices per user. The regular-stream control screens the same idle duration and also qualifies selected counts for five minutes. Its echo latency is not a sync-round latency.

| Tier | Offline Sync: strict 45 s pass | Regular stream: 45 s pass | Regular stream: 5 min pass | 5 min probe median / p95 ms | Next unsuccessful target |
|---|---:|---:|---:|---:|---|
| Large | 128 | 2,560 | 2,560 | 249.0 / 374.7 | 3,328 (open) |
| XL | 512 | 2,560 | 1,280 | 249.2 / 305.9 | 3,328 (open) |
| XXL | 1,024 | 1,792 | 896 | 238.5 / 310.0 | 2,560 (probe) |

The prior 1,024-device strict maximum was not proof of a 1,024-stream framework limit: its XXL 2,048-device trial delivered and verified all users, then failed during close. Likewise, the prior report did not establish a 200-row batch limit: City workloads with 1,000 rows kept up on Large, XL and XXL at lower concurrency. Throughput, correctness and lifecycle success are separate measurements.

## Every measured case

Latencies are milliseconds from sending a resume message to receiving the identical message on the same connection. All streams are probed, with at most eight simultaneous probes. Warmup/setup is excluded.

| Case | Verdict / phase | Opened / resumed | Idle s | Min | Median | Mean | p95 | Max | Peak cgroup MiB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| large-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 219.4 | 249.4 | 244.2 | 257.4 | 260.2 | 95.8 |
| large-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 216.7 | 236.2 | 240.0 | 256.4 | 412.7 | 178.0 |
| large-echo-c1024-idle45-screen | PASS | 1024 / 1024 | 45 | 215.8 | 237.4 | 246.8 | 266.9 | 905.4 | 408.8 |
| large-echo-c4096-idle45-screen | FAIL / open | 2990 / 0 | 45 | — | — | — | — | — | 970.7 |
| large-echo-c2560-idle45-refinement | PASS | 2560 / 2560 | 45 | 215.6 | 243.1 | 291.2 | 317.4 | 16,885.4 | 765.4 |
| large-echo-c3328-idle45-refinement | FAIL / open | 1793 / 0 | 45 | — | — | — | — | — | 970.3 |
| large-echo-c2560-idle300-qualification | PASS | 2560 / 2560 | 300 | 214.8 | 249.0 | 263.7 | 374.7 | 1,196.2 | 770.2 |
| xlarge-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 218.4 | 250.4 | 248.7 | 284.7 | 352.1 | 93.9 |
| xlarge-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 216.5 | 247.7 | 253.1 | 326.4 | 410.7 | 178.2 |
| xlarge-echo-c1024-idle45-screen | PASS | 1024 / 1024 | 45 | 215.1 | 238.7 | 253.1 | 328.3 | 749.7 | 401.7 |
| xlarge-echo-c4096-idle45-screen | FAIL / open | 3902 / 0 | 45 | — | — | — | — | — | 1,221.5 |
| xlarge-echo-c2560-idle45-refinement | PASS | 2560 / 2560 | 45 | 214.1 | 241.3 | 252.3 | 321.7 | 521.2 | 1,349.0 |
| xlarge-echo-c3328-idle45-refinement | FAIL / open | 1107 / 0 | 45 | — | — | — | — | — | 1,519.0 |
| xlarge-echo-c2560-idle300-qualification | FAIL / open | 2400 / 0 | 300 | — | — | — | — | — | 1,900.0 |
| xlarge-echo-c1280-idle300-qualification | PASS | 1280 / 1280 | 300 | 215.1 | 249.2 | 252.6 | 305.9 | 510.1 | 421.1 |
| xxlarge-echo-c64-idle45-screen | PASS | 64 / 64 | 45 | 218.8 | 246.5 | 245.6 | 267.3 | 316.2 | 96.1 |
| xxlarge-echo-c256-idle45-screen | PASS | 256 / 256 | 45 | 216.4 | 237.9 | 240.4 | 256.5 | 269.5 | 179.9 |
| xxlarge-echo-c1024-idle45-screen | PASS | 1024 / 1024 | 45 | 214.0 | 237.1 | 241.7 | 257.5 | 415.8 | 406.6 |
| xxlarge-echo-c4096-idle45-screen | FAIL / open | 3258 / 0 | 45 | — | — | — | — | — | 1,170.3 |
| xxlarge-echo-c2560-idle45-refinement | FAIL / probe | 2560 / 2199 | 45 | 215.4 | 240.9 | 247.1 | 292.0 | 479.1 | 1,535.1 |
| xxlarge-echo-c1792-idle45-refinement | PASS | 1792 / 1792 | 45 | 215.8 | 238.5 | 247.4 | 304.9 | 517.4 | 1,735.5 |
| xxlarge-echo-c1792-idle300-qualification | FAIL / open | 1782 / 0 | 300 | — | — | — | — | — | 1,934.7 |
| xxlarge-echo-c896-idle300-qualification | PASS | 896 / 896 | 300 | 214.3 | 238.5 | 248.5 | 310.0 | 541.2 | 2,029.8 |

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
