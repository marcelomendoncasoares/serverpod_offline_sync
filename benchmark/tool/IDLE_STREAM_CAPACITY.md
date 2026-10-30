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
   Eight client processes are used. Small opens through one worker at a time;
   the other sizes open through four. Each opening worker admits one connection
   at a time, matching the sync campaign's bounded setup rather than a burst.
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
