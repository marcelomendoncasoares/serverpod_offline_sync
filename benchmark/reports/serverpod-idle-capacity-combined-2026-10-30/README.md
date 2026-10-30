# Serverpod idle-stream capacity: combined findings

These are ordinary authenticated Serverpod method streams on the Cloud benchmark deployment. Each device owns a separate WebSocket and echoes a unique payload before and after inactivity. The endpoint executes no SQL and creates no Offline Sync session or local replica.

All five instance sizes have completed their searches.

**These are demonstrated full-lifecycle passes, not exact maximum idle capacities.** Opening failures, retained memory between cases and occasional disconnects stopped parts of the search. The non-monotonic results do not show that XXL has less hardware capacity than Large.

## Observed operating points

| Tier | RAM MiB | Visible CPU cores | Concurrent opens | 45 s full pass | 5 min full pass | Resume median / p95 ms | Prior Offline Sync strict pass |
|---|---:|---:|---:|---:|---:|---:|---:|
| Small | 256 | 0.1 | 8 | 448 | 224 | 252.1 / 319.3 | 256 |
| Medium | 512 | 0.25 | 8 | 1,024 | 1,024 | 238.9 / 304.3 | 1,024 |
| Large | 1,024 | 0.5 | 32 | 2,560 | 2,560 | 249.0 / 374.7 | 128 |
| XL | 2,048 | 1.0 | 64 | 2,560 | 1,280 | 249.2 / 305.9 | 512 |
| XXL | 4,096 | 2.0 | 64 | 1,792 | 896 | 238.5 / 310.0 | 1,024 |

## Five-minute resume latency

These are exact per-connection echo durations in milliseconds, including the client-to-Cloud network path. They are not durable sync-round times.

| Tier | Responses | Min | Median | Mean | p95 | Max |
|---|---:|---:|---:|---:|---:|---:|
| Small | 224 | 217.3 | 252.1 | 263.7 | 319.3 | 412.4 |
| Medium | 1,024 | 214.6 | 238.9 | 253.4 | 304.3 | 1,080.5 |
| Large | 2,560 | 214.8 | 249.0 | 263.7 | 374.7 | 1,196.2 |
| XL | 1,280 | 215.1 | 249.2 | 252.6 | 305.9 | 510.1 |
| XXL | 896 | 214.3 | 238.5 | 248.5 | 310.0 | 541.2 |

Across all completed passing trials, the worst recorded echo was 16,885.4 ms in `large-echo-c2560-idle45-refinement` ([case evidence](../serverpod-idle-capacity-larger-tiers-2026-10-30/README.md)). A capacity pass does not certify a sub-second latency SLA. Rare long delays are retained; their source has not been isolated.

## Fresh-instance follow-ups

The default-compression sweep above reuses each instance between cases. These additional cases start on fresh instances and retain the same server executable. They are separate measurements, not replacements for the failed sweep cases.

| Control | Target | Opened / resumed | Full pass | Failure phase | Peak cgroup MiB |
|---|---:|---:|---|---|---:|
| XL cold, 32 opens, compressed | 4,096 | 3,957 / 0 | No | open | 1,076.9 |
| XXL cold, 32 opens, compressed | 4,096 | 4,035 / 0 | No | open | 1,096.8 |
| Small compression enabled | 256 | 256 / 256 | Yes | — | 157.8 |
| Small compression disabled | 256 | 256 / 256 | Yes | — | 132.8 |
| Small compression disabled | 2,048 | 1,846 / 0 | No | open | 130.7 |

The XL/XXL confirmations use 32 simultaneous opens instead of 64 and keep ordinary WebSocket compression. They test a different admission condition; any setup failure still does not determine established idle capacity.

The two Small 256-connection cases change only compression negotiation between fresh instances. TLS, authentication, the streaming protocol, opening rate, idle interval and probing remain the same.

The 256-stream Cloud controls both passed. Peak container memory fell from 157.8 to 132.8 MiB (15.8% lower) without compression. This includes the process baseline and the complete case; it is not a per-socket heap allocation measurement.

The 2,048-connection Small test with compression disabled failed during open. Its first recorded close code was `1002` after HTTP upgrade `101`. Peak sampled container memory was 130.7 MiB of 256 MiB. Memory savings therefore did not establish a reliable larger idle capacity; the transport failure needs separate investigation.

See [the control report](../serverpod-stream-compression-2026-10-30/README.md) for exact failure messages, negotiated headers, phase memory, full latency statistics and restoration evidence. Compression remains a diagnostic option; active sync traffic and bandwidth tradeoffs were not benchmarked.


A full pass requires exact responses from every original connection, no unexpected disconnects or reconnects, stable server identity, complete observations and zero remaining streams after close. Resume probes are limited to eight at a time; this measures idle residency and eventual responsiveness, not thousands of simultaneous active requests.

The counts are demonstrated operating points, not universal or exact maximum capacities. Failed setup or cleanup does not establish an established-stream limit. The five-minute result can be lower than a 45-second pass because some later trials started with memory retained from earlier closed connections. Each source report preserves failure phase, completed opens/resumes, memory and restarts.

The [earlier Offline Sync campaign](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/perf/checkpoint-capacity-validation/benchmark/reports/revision-checkpoint-capacity-combined-2026-10-29/CAPACITY_GUIDE.md) also performed durable cross-device synchronization. It had different monitoring and shutdown concurrency. Its strict failures therefore cannot be treated as a 1,024-stream protocol limit. Its XXL 2,048-device case delivered and verified changes before failing close. Nor did it establish a 200-row batch-size cap: 1,000-row City cases kept up at lower concurrency on Large, XL and XXL.

## Memory attribution

Small and Medium reproduced opening failures with Offline Sync removed from the measured endpoint. High sampled memory and server restarts point to a shared transport/runtime constraint. No orchestrator OOM termination reason was captured, so an OOM kill is not asserted.

The [separate raw Dart WebSocket control](../dart-websocket-memory-2026-10-30/README.md) used no Serverpod, database or TLS. At 2,048 sockets it measured 504.34 MiB RSS with WebSocket compression versus 51.32 MiB without it. Actual compression negotiation and every echo/close were checked. This isolates a large cost below Serverpod, but is not itself a Cloud capacity result.

Memory stayed high after sockets closed in both local and Cloud observations. Garbage collection, allocator retention and leaks have not been separated. Disabling compression also trades memory for additional bytes during active traffic; no sync protocol or TLS change is implied.

## Method and evidence

The completed Small/Medium sweep and its three slower Large controls used eight simultaneous opens. The larger-tier continuation uses 32 on Large and 64 on XL/XXL to reduce admission time. Its source/build identity is recorded separately. The server executable, eight resume probes, 64 closes, payload, authentication and correctness checks stay the same.

The server still loads the benchmark application and its diagnostics; this is not a stripped-down minimum-memory Serverpod executable. Session persistence/console logging are disabled. The pinned Serverpod client sends a JSON ping every 20 seconds and uses a 40-second inactivity timeout; those keepalives continue during the idle interval. SQL-free metrics are collected every five seconds. Generator limitations fail a trial rather than being reported as server capacity. Visible CPU quotas come from the container cgroup; hidden ancestor limits remain unverified.

The 1,024-stream Large control opened in 149.0 s with 8 concurrent opens and 39.3 s with 32. Resume medians were 244.6 and 237.4 ms. Both passed. This is a test-admission speedup, not a server or sync-protocol performance gain.

- [serverpod-idle-capacity-2026-10-30](../serverpod-idle-capacity-2026-10-30/README.md): all cases, min/median/mean/p95/max, raw observations, independent audit and restoration evidence.
- [serverpod-idle-capacity-larger-tiers-2026-10-30](../serverpod-idle-capacity-larger-tiers-2026-10-30/README.md): all cases, min/median/mean/p95/max, raw observations, independent audit and restoration evidence.

The separate Cloud compression controls are recorded after the five-tier search and use fresh instances. Their results must be read separately from the default-compression capacity table.
