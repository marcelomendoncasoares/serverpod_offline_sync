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

## Preparing the Cloud server

The test project's checked-in SQL targets SQLite. Prepare a separate, complete
Dart workspace whose server entry point and SQL target PostgreSQL:

```sh
dart run benchmark/tool/prepare_cloud.dart --output /tmp/offline-sync-cloud
cd /tmp/offline-sync-cloud
dart pub get
```

The server project directory is `/tmp/offline-sync-cloud/benchmark`, with a
conventional `bin/main.dart`, production config, generated models and the
workspace's package implementations. The exporter copies source and records the
source revision; it never rewrites the original test packages. It refuses an
existing output directory. Prepare again into a new directory after changing
source. Only the latest schema is exported as a fresh PostgreSQL baseline; use
an empty dedicated Cloud database. This exporter is not an upgrade migration
for an existing test or production database.

Once Cloud is configured, link that exported `benchmark` directory to a dedicated
project with managed PostgreSQL. Configure `BENCHMARK_SECRET` as an environment
secret before starting the server. Cloud supplies the `SERVERPOD_DATABASE_*`
connection settings; the production config explicitly selects PostgreSQL. The
benchmark server exposes only the standard sync module and an authenticated
benchmark control endpoint. Passwordless demo auth/debug endpoints are absent.

Follow the current [Cloud deployment guide](https://docs.serverpod.dev/cloud/concepts/deployments)
for project setup and deployment, and the
[secret configuration guide](https://docs.serverpod.dev/cloud/concepts/passwords-secrets-env-vars)
for `BENCHMARK_SECRET`. Use the API domain as the runner's `--target`. Preview the
packaged file tree before deploying. Cloud deployment is intentionally not run as
part of this implementation; account/project configuration is still required.
With multiple server replicas, sampled process and stream metrics represent only
the responding instance. They are not cluster totals; collect per-instance Cloud
telemetry as well, or use a single replica when studying connection populations.

For a native client build, including the SQLite native libraries:

```sh
cd benchmark
dart build cli --target bin/scale.dart --output ../.scale-benchmark/client-build
cd ..
.scale-benchmark/client-build/bundle/bin/scale --target https://YOUR-API/ \
  --users 1000 --devices 2:4 --workers 8 --duration 300 --ramp-ms 100 \
  --sample-seconds 15 --timeout-seconds 1800
```

This is an example for a later deliberate capacity run, not a validated capacity
claim. Keep the entire `bundle` directory together. Serverpod's native hooks
require [`dart build cli`](https://docs.serverpod.dev/upgrading/upgrade-to-four),
not a bare executable compilation. To validate the exported server locally,
run `dart build cli --target bin/main.dart` from its `benchmark` directory and
start the bundled executable from that same directory with
`--mode=production --apply-migrations` and PostgreSQL connection variables.

The `merge` events also report the age of the newest merged HLC. This is a
wall-clock diagnostic affected by clock skew, not per-operation replication
latency or acknowledgement latency. Negative values are retained. The final
convergence duration measures drain time after scheduled activity stops.

## Local validation

Only short functional segments were run during implementation, never a capacity
run or Cloud deployment:

- SQLite: two users/four devices, then two workers/seven devices with all four
  device states and reconnects. Both runs converged with their complete receipts.
- PostgreSQL 16: native server and client bundles, two workers/four devices,
  six seconds of scheduled activity. All users converged; observed streams
  returned to zero and database/relation metrics were populated.
- Invalid credentials failed before worker creation. A one-second startup
  deadline and a SIGTERM during activity each produced a failed report and an
  exit event for both workers. The temporary server exited cleanly and its
  isolated PostgreSQL process stopped.
- Nine Dart tests cover topology/configuration, token substitution, snapshot
  comparison and missing receipts, latency summaries, and SQLite device
  isolation plus persistence across close/reopen. Run them with
  `dart test benchmark/test/scale --concurrency=1` from the repository root.

These checks establish operation of the harness on small inputs. They do not
establish throughput, memory limits, or reliability at thousands of devices.
