# Unexpected stream closures in sustained follow-ups

Two five-minute Large trials with 64 participating devices failed before final verification. They use the same cached/HLC native-TLS baseline as this report; the full sustained follow-up campaign is still running. The lower latency of completed rounds does not turn these into passing capacity results.

Each trial offered one row per user every two seconds, with 32 users and two devices per user. No reconnect or repair sync was allowed. Both collectors completed without gaps or errors, and cleanup drained all streams.

| Profile | Completed / expected rounds | Median / p95 of completed rounds, ms | Last successful round before closure | Maximum sampled loop lag within 10 seconds | Nearby peak charged memory |
|---|---:|---:|---:|---:|---:|
| Person, full registry | 4755 / 4800 | 654.1 / 924.8 | 0.611 s | 7.893 ms | 101.4 MiB / 1024 MiB |
| City, isolated registry | 4717 / 4800 | 453.6 / 607.8 | 1.974 s | 63.924 ms | 108.4 MiB / 1024 MiB |

Both client errors were `Method stream WebSocket connection closed`. The sampled server retained one process instance throughout each trial. The affected user had successfully exchanged changes shortly before the close; this was not an observed long period without application traffic. These observations do not attribute the closure to a driver, server, proxy, or client.

A read-only `scloud log` query for 14:18–14:37 UTC on 2026-10-29 returned 24 INFO records about the planned 14:30 schema deployment, with no record explaining either closure. Session logging was disabled, so absence of an error record does not rule out a server error.

The pinned Serverpod client at `4f2a75ab967dccd56e88261a39203fc5e59d8e80` emits a generic `WebSocketClosedException` when the underlying socket stream finishes, without attaching its close code or reason. Its own idle-timeout path uses a separate exception. The available client message is therefore insufficient to identify the closing layer. No instrumentation or dependency was changed during these measurements.

The [observations](sustained-failure-observations.json) preserve timings, build identities, sample windows, and the hash of the private Cloud-log capture. These failures remain excluded from sustained sizing qualifications. They do not establish an exact 64-device ceiling. The runner continued with independent profiles and tiers, without heavier comparable retries.
