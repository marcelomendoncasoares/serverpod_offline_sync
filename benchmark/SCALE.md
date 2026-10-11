# Deployed offline-sync benchmark

Run against the dedicated benchmark server with Dart 3.12.2 or newer:

```sh
dart pub get
export BENCHMARK_SECRET='<same random secret configured on the benchmark server, at least 24 characters>'
dart run benchmark/bin/scale.dart --target https://YOUR-API/
```

Defaults are deliberately small: two users, two devices each, one worker process,
and 20 seconds of scheduled activity. `--help` lists every tuning option. This
is separate from the existing local microbenchmarks.

Each device owns an authenticated generated Serverpod client and a SQLite file
under `<data-dir>/<run-id>/databases/user-N/device-M.sqlite`. All devices for a
user sync the same personal space. Different users have distinct authenticated
identities. Worker processes partition users; each worker drives its devices
concurrently. No Flutter, mocks, direct merge calls, or modified package code is
involved. Existing test source, generated code, migrations, and configs are reused
without changes.

For a small local smoke run, start the server in another terminal:

```sh
export BENCHMARK_SECRET='<a local secret of at least 24 characters>'
scripts/scale-server.sh
```

Then run the client against `http://localhost:8180/`. The script stages the existing
server migrations and benchmark-only configs under `.scale-benchmark/server`.
`BENCHMARK_SERVER_DIR` selects another runtime directory; `DART` selects the Dart
executable. Standard `SERVERPOD_*` environment settings override configuration.
The normal test server entry point and its SQLite configuration are untouched.

## Workload and verification

The seed controls user device counts, state assignments, IDs, and operation
selection. This is a live network exercise inspired by DST, not a deterministic
simulation of the operating system, wall clock, or server scheduling. Its workload
is independent of the test-only DST world, which directly drives engine internals.

Each user begins with `--seed-rows` cities. Devices create towns, edit shared cities
concurrently, rename/move/delete their own towns, and read pages through generated
ORM APIs. Every write transaction also creates an immutable Person receipt. The
receipt overhead is included in the measured workload. `--payload-bytes` controls
town name size, and `--interval-ms` controls per-device think time plus seeded
jitter. This is a closed-loop load generator: slow operations reduce offered load.

At each `--churn-seconds` epoch, devices become online writers (`--active`),
connected without local writes (`--idle`), closed clients and databases
(`--closed`), or offline writers (remaining probability). Connected idle devices
still receive other devices' changes. Fractions are probabilities, not guaranteed
quotas. `--churn-seconds 0` holds the first assignment. Closed devices reopen the
same database. The final verification reconnects every device and uses only normal
`syncOnce` calls until domain snapshots match the server. It independently checks
all committed receipt IDs and expected live row counts; matching empty replicas
cannot pass. A failed operation, unexpected stream termination, missing measurement,
worker exit, timeout, or failed convergence makes the command exit nonzero.

## Reports

Each invocation retains `manifest.json`, `events.jsonl`, `summary.json`,
`workers.log`, and every device database in a fresh run directory. An existing
run ID is rejected. Server data is retained too: use a dedicated database, and
reset it externally between independent baseline trials. Reusing a user namespace
is rejected rather than silently joining old data.

The manifest records options, actual device counts, revision, dirty-tree status,
Dart/OS information, and timestamps. Secrets are read from the environment and are
not written into manifests or process arguments.

`events.jsonl` contains per-device operation journals, local operation and sync
latency, convergence evidence, process RSS/CPU ticks, device states, SQLite file,
WAL and SHM bytes, server table counts, and server storage samples. Samples and
latency are tagged by phase so setup/seed/drain costs do not become workload costs.
The summary has throughput and bounded-memory latency histograms; p50/p95/p99 are
bucket upper bounds with 10% geometric bucket spacing. Raw durations remain in the
JSONL for exact offline analysis.

The benchmark server observes the package's original endpoint dispatch and forwards
every stream event unchanged. `open` is the count of currently executing sync
streams; `active` exchanged at least one nonempty merge chunk in the preceding two
seconds; `idle` is the remainder. `openedTotal`, `closedTotal`, failures, and
inbound/outbound change counts are cumulative. These are sync-method streams, not
physical TCP socket counts. Process/stream counters are per server instance and
include an instance ID. PostgreSQL storage samples include whole-database bytes,
relation/index sizes, estimated live/dead rows, and connection/wait states. Table
counts are exact and include earlier retained runs; compare baseline and later
samples. Metrics queries consume database resources and report their collection
latency. Increase `--sample-seconds` when profiling larger databases.

Large runs should tune worker count, startup ramp, sampling cadence, local disk,
and file descriptor limits based on the load-generator host. Thousands of devices
are supported by the topology parameters, not claimed as locally validated capacity.
The current local validation is only a small functional probe. Cloud deployment
and a real capacity benchmark are separate work.
