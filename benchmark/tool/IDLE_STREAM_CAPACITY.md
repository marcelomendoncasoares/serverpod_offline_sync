# Ordinary Serverpod streaming capacity

This control removes Offline Sync from the connection path. Each simulated device
owns one generated Serverpod client, one WebSocket and one bidirectional method
stream. `benchmark.echo` returns each String unchanged, without opening a local
replica, subscribing to Offline Sync, accessing PostgreSQL or polling for changes.
It uses the same Serverpod dependency pins and Cloud application as the sync
campaign. Admin-token authentication requires no database lookup; the endpoint
is not public. Session logging stays disabled.

## Procedure

1. Start with no open sync or echo streams and no idle database transactions.
2. Open connections gradually, checking a unique 128-byte echo on every stream.
   Eight client processes are used. The private config's `openWorkers` map
   controls how many workers open concurrently on each tier. The config's
   `openConcurrencyPerWorker` map sets each worker's admission limit, defaulting
   to one. The initial Small/Medium sweep uses eight simultaneous opens. The
   continued larger-tier sweep uses 32 on Large and 64 on XL/XXL. The completed
   slower controls remain recorded separately. The prior sync campaign used one
   opening worker on Small and four on the other tiers. Probe concurrency stays
   eight and close concurrency stays 64 regardless of opening parallelism.
3. Settle for five seconds, then keep every connection open without application
   messages for 45 seconds. Normal transport keepalives continue. Sample server
   resources through an authenticated SQL-free control every five seconds.
4. Echo a new unique payload on **every** existing connection, with one probe per
   worker at a time. Record minimum, median, mean, p95 and maximum request/response
   time. This is a transport echo, not a two-device durable synchronization round.
5. Close the streams with at most 64 shutdowns in progress, then require zero
   server streams. Unexpected endings, mismatches, missing receipts, sampling
   errors and server restarts fail the strict verdict. Preserve the phase and
   number actually opened/resumed separately.
6. Increase the requested count until failure. Stop larger counts on that tier,
   refine below the failure, and qualify the best passing count with five minutes
   of inactivity. If that longer case fails, reduce the qualification count.

Small, Medium, Large, XL and XXL are traversed automatically on one instance.
The default screen points are 64, 256, 1,024, 4,096, 8,192 and 16,384. Passing the
last point is a lower bound on capacity, not a measured maximum. Setup or teardown
failure also does not establish a maximum number of established idle streams.
CPU quota metadata has the same unresolved ancestor/accounting caveat as the
earlier campaign. Generator CPU, memory and event-loop lag remain separate from
server observations; host memory pressure aborts a case without proving a server
limit.

## Replay

Build the client with the campaign's pinned Dart SDK and dependency lock:

```sh
cd benchmark
dart build cli --target bin/idle_streams.dart --output /private/idle-client
```

Prepare a deployment with the new endpoint using `prepare_cloud.dart`, preserving
the existing Cloud project's private configuration. Supply a private JSON config
based on the capacity runner configuration, additionally naming
`originalProjectDirectory`, `originalServerExecutableSha256`, the prepared
candidate's `sourceRevision`, the idle client's `client` and `clientSha256`, and
fresh `evidenceDirectory` and `reportDirectory` paths. The candidate uses the
already migrated full-schema capacity database. No databases are created or
deleted by this runner.

```sh
python3 benchmark/tool/idle_capacity.py --config /private/idle-capacity.json
```

The command snapshots compute, relevant environment variables and protected-file
hashes, deploys the candidate, visits all tiers, exports measurements and restores
the original deployment in `finally`. A project lock excludes simultaneous
campaigns. Completed cases can be reused only with identical parameters and build
identities; incomplete receipts require inspection. After a hard termination,
restore explicitly:

```sh
python3 benchmark/tool/idle_capacity.py --config /private/idle-capacity.json --action restore
```

`results.json`, `samples.jsonl`, `tiers.json` and `manifest.json` contain the public
measurements. Raw server identity/configuration, deployment archives and logs stay
in the private evidence directory. Review and sanitize failures before publishing.
The source reference and executable hashes distinguish this control from the
previous Offline Sync executable.

Validation exercises an actual database-free Serverpod server, authenticated and
unauthenticated streams, a complete multiprocess run, wrong responses, unexpected
idle closure and cancellation cleanup. Python regressions check tier traversal,
stopping, longer qualification and refusal to repeat incomplete cases.

## Compression attribution control

`stream_compression_capacity.py` runs separate Small controls on fresh instances:
256 connections with default WebSocket compression, 256 without compression,
and, only if the latter passes, 2,048 without compression for five minutes.
Use a fresh private config and output directories with a client built from the
compression-probe revision. The server executable stays identical to the main
sweep. Do not run this concurrently with another campaign.

```sh
python3 benchmark/tool/stream_compression_capacity.py --config /private/compression-capacity.json
```

The diagnostic client injects a WebSocket connector into the existing Serverpod
method-stream manager. Authentication, messages and the stream protocol remain
the same. Only WebSocket compression negotiation changes. This adapter is not
used by production clients or by the main sweep's default `sdk` mode.

Every successful connection records the actual upgrade response's
`Sec-WebSocket-Extensions` header. The pinned Dart SDK's `WebSocket.extensions`
getter always returns an empty string and cannot verify negotiation. Tests check
both compressed and uncompressed streams against a real database-free Serverpod
server. The Cloud control also checks every recorded handshake before accepting
its attribution result. Its restoration procedure is the same as the main sweep.

Optional `admissionControls` entries in this private config name an instance
`size` and a `connections` count to confirm for five minutes before the Small
comparison. These use normal compression, a fresh resized instance and the
config's explicit opening limit. They are intended to revisit a failed setup
count at a slower admission rate, not to advance to a heavier count after a
failure. Every successful upgrade must report HTTP 101 and negotiated deflate;
failed upgrade HTTP statuses are recorded separately. The 2026-10-30 run uses
this to check XL and XXL at 4,096 streams with 32 concurrent opens after HTTP
upgrade failures in the 64-open sweeps with substantial memory still available.

For a separate local attribution check, compile `websocket_memory.dart` to an AOT
executable, then pass it an output JSON path. It starts a fresh plain Dart
WebSocket server process for each 256/2,048-connection compression-on/off case,
checks every exact echo and negotiated mode, and records server RSS before,
while connected and after closing. There is no Serverpod dependency or TLS in
this local control. Its five-second idle periods are not Cloud qualifications.

```sh
dart compile exe benchmark/tool/websocket_memory.dart -o /private/websocket-memory
/private/websocket-memory /private/websocket-memory.json
```

After either Cloud campaign, audit raw receipts and export sanitized resource
boundaries independently of the measurement runner:

```sh
python3 benchmark/tool/idle_capacity_audit.py --config /private/idle-capacity.json
python3 benchmark/tool/idle_capacity_profile.py --config /private/idle-capacity.json
```
