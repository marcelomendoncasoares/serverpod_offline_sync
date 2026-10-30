# Fresh-instance admission and WebSocket compression controls

These follow the [five-tier ordinary Serverpod stream sweep](../serverpod-idle-capacity-combined-2026-10-30/README.md). The server executable and SQL-free authenticated echo endpoint are unchanged. Each case starts on a fresh instance. A diagnostic connector uses Serverpod's existing method-stream manager and records the actual HTTP upgrade response, negotiated compression and WebSocket close code.

## Cold admission confirmations

XL and XXL retry the previously unsuccessful 4,096-connection count with 32 simultaneous opens instead of 64. This changes both admission rate and process history, so it is a confirmation under different conditions, not an isolated measurement of either variable. Successful upgrades must report HTTP 101 and negotiated permessage-deflate. The planned idle interval is five minutes; a setup failure never reaches it.

| Tier | Target | Successful warmups | Resumed | Verdict / phase | Peak cgroup MiB | Peak server FDs | Restart |
|---|---:|---:|---:|---|---:|---:|---|
| XL | 4,096 | 3,957 | 0 | FAIL / open | 1,076.9 | 3,987 | No |
| XXL | 4,096 | 4,035 | 0 | FAIL / open | 1,096.8 | 4,079 | No |

Successful warmups during an aborted case are not a count of simultaneously resident sockets. No retry or reconnect is permitted. Any unexpected fault fails the case; other workers may still finish opening work before shutdown. Subsequent error, EOF and cleanup records are not independent connection failures.

- XL: first fault `Method stream connection attempt timed out`. Non-101 HTTP statuses: none captured. WebSocket close codes: none captured.
- XXL: first fault `Method stream connection attempt timed out`. Non-101 HTTP statuses: none captured. WebSocket close codes: none captured.

These failed openings never reached the planned idle interval. A timeout without an HTTP response or WebSocket close code does not locate the fault within the client, network, Cloud ingress or server. Memory and restart observations are recorded above; a hardware or framework connection ceiling has not been isolated.

The process file-descriptor limit was not collected. Peaks near 4,096 descriptors make that limit worth checking, alongside Cloud ingress and the generator network path, but do not prove descriptor exhaustion. Earlier sweep failures also occurred with fewer descriptors. Worker descriptor peaks are retained in results.json.

## Compression comparison on Small

The first two cases use 256 connections, eight simultaneous opens, 45 seconds idle, eight simultaneous resume probes and 64 closes. Each starts on a fresh Small instance. The third case attempts 2,048 uncompressed connections for five minutes only after the 256-connection uncompressed case passes. TLS and the streaming protocol are unchanged.

| Compression | Connections | Idle s | Verdict / phase | Before MiB | Open MiB | After idle MiB | After close MiB | Peak MiB |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| enabled | 256 | 45 | PASS | 76.2 | 142.5 | 152.1 | 156.8 | 157.8 |
| disabled | 256 | 45 | PASS | 76.1 | 97.0 | 129.3 | 132.7 | 132.8 |
| disabled | 2,048 | 300 | FAIL / open | 76.1 | — | — | — | 130.7 |

The 2,048-connection disabled case failed with `Method stream WebSocket connection closed`. The first recorded socket close code was `1002` and its upgrade status was `101`. This case does not establish a successful idle capacity, regardless of how many opening receipts were recorded.

At the completed-open boundary, container memory fell from 142.5 to 97.0 MiB (31.9% lower). Later allocations and collection affect the idle and full-case peaks; this is a whole-container comparison rather than a per-connection heap measurement.

Memory in this table is the visible container cgroup measurement, in MiB. Process RSS and file descriptors are retained in [resource-boundaries.json](resource-boundaries.json). Missing boundaries mean the phase did not finish. A high value after close does not distinguish garbage collection, allocator retention or a leak.

| Case | Echoes | Min ms | Median ms | Mean ms | p95 ms | Max ms | Idle CPU cores |
|---|---:|---:|---:|---:|---:|---:|---:|
| small-echo-c256-idle45-compression-enabled | 256 | 216.8 | 271.6 | 307.2 | 521.4 | 713.1 | 0.082 |
| small-echo-c256-idle45-compression-disabled | 256 | 216.8 | 251.0 | 255.4 | 302.9 | 391.7 | 0.040 |

Echo timings include the client-to-Cloud network path. Probing eight connections at a time checks every surviving original stream, but does not simulate thousands of active requests at once.

Disabling compression can save per-socket memory at the cost of additional wire bytes for compressible active payloads. These echo controls do not quantify that traffic tradeoff for actual sync data. This is a diagnostic configuration, not an adopted production change.

## Reproduction and evidence

- [admission-controls.json](admission-controls.json) and [compression-controls.json](compression-controls.json) record handshake checks and the first transport failures.
- [results.json](results.json) preserves complete verdicts, failure phases, resource peaks, build identities and generator checks.
- [samples.jsonl](samples.jsonl) preserves every successful opening and echo receipt. [MEASUREMENT_AUDIT.json](MEASUREMENT_AUDIT.json) independently checks those measurements and exact stream identities.
- [manifest.json](manifest.json) names the distinct server/client revisions and executable hashes. See the [replay instructions](../../tool/IDLE_STREAM_CAPACITY.md).

The runner verified restoration of the original Small deployment. See [RESTORATION.json](RESTORATION.json).
