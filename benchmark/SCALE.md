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

Load generators are supported on Linux, where every check here ran. macOS is
untested; process CPU, file descriptor and thread metrics are Linux-only. The
runner refuses to start on Windows.

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
server migrations and benchmark-only configs under `.scale-benchmark/server`, and
records the checkout revision in `config/benchmark_build.json`.
`BENCHMARK_SERVER_DIR` selects another runtime directory; `DART` selects the Dart
executable. Standard `SERVERPOD_*` environment settings override configuration.
The normal test server entry point and its SQLite configuration are untouched.

## Workload

The seed controls user device counts, state schedules, churn phases, IDs,
payloads, and operation selection. This is a live network exercise inspired by
DST, not a deterministic simulation of the operating system, wall clock, or
server scheduling. Its workload is independent of the test-only DST world.

Each user begins with `--seed-rows` cities. Devices create towns, edit shared
cities concurrently, rename/move/delete their own towns, and read pages through
generated ORM APIs. Every write transaction also creates an immutable Person
receipt, and that overhead is part of the measured workload. Town names are
`--payload-bytes` of seeded random ASCII, new on every insert and rename, so
PostgreSQL compression cannot hide storage growth. `--interval-ms` sets think
time plus seeded jitter. This is a closed-loop generator: slow operations and
state transitions reduce offered load, and the summary reports by how much.

Devices start their workload (including their first network connect) one
`--ramp-ms` apart within each worker; the ramp is part of `--duration` and must
end before it. At each `--churn-seconds` epoch a device becomes an online writer
(`--active`), connected without local writes (`--idle`), closed client and
database (`--closed`), or an offline writer (remaining probability). Fractions
are probabilities, not quotas. Every device has a seeded phase within the churn
period, so transitions are spread out; `--aligned-churn` instead switches all
devices together, a deliberate reconnect storm. `--churn-seconds 0` holds the
first assignment. Closed devices reopen the same database. All-offline schedules
are valid: their writes reach the server only during verification.

Within each worker, every network call made outside the workload (user
provisioning, seed and verification syncs, server snapshots) takes a permit from
one pool of `--setup-concurrency` permits, however many users and devices are
involved; database opens are limited to the same number. Initialization and
seeding share `--startup-timeout-seconds`.

## Verification and failure policy

Verification reconnects every device and uses only normal `syncOnce` calls until
every replica matches the server and both match the devices' own write journals:

- receipts and towns must equal the journal exactly (IDs and written fields),
  so a dropped insert cannot be offset by a resurrected delete;
- city IDs must equal the seeded IDs, and each city name must be the final edit
  of some device that edited it, or the seed name if none did. Field merges keep
  the highest authored HLC, and each device's clock is monotonic and has seen
  the seed, so any other value is a lost or reordered write;
- row counts must match, and matching empty replicas cannot pass.

A user that does not converge within `--timeout-seconds` fails the run, and its
`convergence` event lists the problems and a bounded town diff.

A failed local operation (including a missing own row), a worker exit before the
close phase (detected immediately, with its exit code), a phase deadline, or
failed convergence fails the run. Two policies are explicit:

- A dropped continuous stream is reconnected with seeded exponential backoff,
  starting at `--reconnect-ms` and capped at 30 seconds, while the device stays
  in a streaming state. Every unexpected end or error is counted, and the run
  fails if they exceed `--max-unexpected-stream-ends` (default 0, strict).
- Failed server or worker samples are recorded and counted, and the run fails
  if they exceed `--max-sample-failures` (default 0, strict). The preflight
  sample, which also checks credentials, must always succeed.

On failure or interruption, workers are stopped before waiting for telemetry.

## Reports

Each invocation retains `manifest.json`, `events.jsonl`, `summary.json`,
`workers.log`, and every device database in a fresh run directory. An existing
run ID is rejected. Server data is retained too: use a dedicated database, and
reset it externally between independent baseline trials. Reusing a user namespace
is rejected rather than silently joining old data.

The manifest records options, device counts per user and per worker, Dart/OS
information, resource warnings, and provenance:

- `loadGenerator`: for `dart run`, the script and its checkout revision and
  dirty state; for a native bundle, the executable SHA-256 plus the build stamp
  from `tool/build_native.dart` when its recorded hash matches;
- `invocationDirectory`: git facts for the current directory, which need not be
  the code that ran;
- `server`: the server's instance ID, run mode, dialect, connection pool size,
  executable identity, and prepared source revision. No connection secrets.

Secrets are read from the environment and are not written into manifests or
process arguments. Over `http`, the secret travels unencrypted; the runner warns
for non-loopback targets. Use `https` for deployed servers.

`events.jsonl` contains per-device operation journals, epoch `assignment`s and
state transitions, per-device state `residency`, local operation and sync
latency, stream starts/ends/reconnects, convergence evidence, worker samples
(RSS, CPU ticks, open files, threads, event-loop lag, device states, SQLite
file/WAL/SHM bytes), server samples, and storage per device. Latency is tagged
by phase so setup, seed and drain costs do not become workload costs.

`summary.json` separates what was measured where:

- `operations`: local SQLite commits by device state. Offline writes are local
  only; `localCommittedWritesPerSecond` is null when the workload did not finish.
- `server.workload` and `server.verificationDrain`: differences between exact
  boundary samples taken after the seed, workload and verification phases
  (streams, rows added, storage), with rates over the samples' own interval.
  They are omitted when the two samples came from different instances.
- `load`: nominal operation attempts (writer residency divided by mean think
  time) versus attempts achieved.
- `generator`: per-worker event-loop lag during the workload, whole-process CPU
  cores, peak RSS/open files/threads and their marginal cost per device (above
  the worker's footprint before any device opened), with an `assessment`.
  Workload lag p99 above 100 ms on a worker or the coordinator marks possible
  generator saturation; under 80% of nominal attempts marks an offered-load
  shortfall; a worker without workload measurements makes the assessment
  `insufficient measurements`. Process CPU includes SQLite helper isolates and
  VM threads, so it is context, not saturation evidence. These heuristics point
  where to look; they do not prove saturation, and they never fail the run.
- `deviceStates`: initial assignments, all assignments, actual transitions,
  and device-seconds per state, where `transition` is time spent stopping
  streams and opening or closing databases.
- `streams` and `telemetry`: the counts behind the two policies above, taken
  from individual events so interrupted runs still report them.
- `latencies`: histograms with 10% geometric buckets; p50/p95/p99 are bucket
  upper bounds over successful operations only, and failures are counted with
  their own maximum. Raw durations remain in the JSONL.

The benchmark server observes the package's original endpoint dispatch and forwards
every stream event unchanged. `open` is the count of currently executing sync
streams; `active` exchanged at least one nonempty merge chunk in the preceding two
seconds; `idle` is the remainder. `openedTotal`, `closedTotal`, failures, and
inbound/outbound change counts are cumulative. These are sync-method streams, not
physical TCP socket counts. Each user authentication (every stream open,
including verification syncs) costs one AuthUser lookup, a benchmark artifact.

Boundary samples (preflight, the end of every phase, and after close) count rows
exactly. Periodic samples on PostgreSQL use `pg_stat_user_tables` estimates to
avoid full scans during the workload; SQLite counts are always exact. Samples
also include whole-database bytes, relation/index sizes, live/dead row estimates,
connection/wait states, and their own collection time. Table counts include
earlier retained runs; compare boundaries rather than absolute values.

### Limitations

- `mergeReport` events carry the age of the engine's checkpoint high-water mark
  after a merge cycle, including cycles that only pushed. That is a clock-skewed
  diagnostic, not replication latency. `streamFirstMerge` and
  `reconnectFirstMerge` time a stream start to its first completed merge cycle,
  when the engine reports one; `streamDowntime` times a drop to the first merge
  after reconnecting. There is no per-change end-to-end replication latency.
- Several load-generator hosts can target one server only as independent runs.
  Give each host its own `--run-id` (user namespaces must not overlap). Nothing
  synchronizes their start or merges their reports. Every coordinator samples
  the server, so raise `--sample-seconds` on all but one host, and remember that
  server counters cover all hosts' traffic while each summary covers one host.
- With multiple server replicas, process and stream metrics describe only the
  responding instance; workload deltas need both boundaries from one instance.

## Sizing the load generator

Each device runs real engine and ORM code on its worker's single Dart isolate,
plus a SQLite writer and reader pool. On Linux x64 with native bundles, a device
has measured roughly 25 open files, and each additional device about 6 MiB of
worker memory; the runner warns when the open-file soft limit or available
memory look too small (raise `ulimit -n` or add workers). These are estimates
from small runs. The summary's per-device figures divide growth since the
worker started by its device count, so with only a few devices they also carry
one-time runtime growth (tens of MiB), and under `dart run` the JIT as well.

Calibrate before trusting latencies: increase devices per worker step by step
and keep the largest load where `generator.assessment` stays at
`no saturation signal` and `load.achievedRatio` and local operation latencies
stay stable as devices are added. Small, noisy local probes measured tens of
milliseconds of process CPU per operation; treat that only as a reason to
calibrate, not as a capacity figure.

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
source revision and dirty state in `PREPARED.json` and in
`benchmark/config/benchmark_build.json`, which the server reports. It never
rewrites the original test packages. It refuses an existing output directory.
Prepare again into a new directory after changing source. Only the latest schema
is exported as a fresh PostgreSQL baseline; use an empty dedicated Cloud
database. This exporter is not an upgrade migration for an existing test or
production database.

Once Cloud is configured, link that exported `benchmark` directory to a dedicated
project with managed PostgreSQL. Configure `BENCHMARK_SECRET` as an environment
secret before starting the server. Launch from the exported server directory
with automatic pre-deploy scripts disabled:

```sh
cd /tmp/offline-sync-cloud/benchmark
scloud launch --no-pre-deploy-scripts
```

The export already contains generated code and does not include the original
code-generation configuration. Do not run `serverpod generate` in it. A default
`scloud launch` can add that command as a pre-deploy hook. If a previous launch
already created `scloud.yaml`, remove `serverpod generate` from
`project.scripts.pre_deploy` there (use `pre_deploy: []` if it is the only hook);
`--no-pre-deploy-scripts` does not remove hooks from an existing configuration.

Cloud supplies the `SERVERPOD_DATABASE_*`
connection settings; the production config explicitly selects PostgreSQL. Its
pool of 10 connections can be changed with `SERVERPOD_DATABASE_MAX_CONNECTION_COUNT`,
and the server reports the effective value. The benchmark server exposes only the
standard sync module and an authenticated benchmark control endpoint.
Passwordless demo auth/debug endpoints are absent.

Follow the current [Cloud deployment guide](https://docs.serverpod.dev/cloud/concepts/deployments)
for project setup and deployment, and the
[secret configuration guide](https://docs.serverpod.dev/cloud/concepts/passwords-secrets-env-vars)
for `BENCHMARK_SECRET`. Use the API domain as the runner's `--target`. Preview the
packaged file tree before deploying. Cloud deployment is intentionally not run as
part of this implementation; account/project configuration is still required.

For native bundles, including the SQLite native libraries, build with the
stamping wrapper around `dart build cli`:

```sh
dart run benchmark/tool/build_native.dart --output .scale-benchmark/client-build
.scale-benchmark/client-build/bundle/bin/scale --target https://YOUR-API/ \
  --users 200 --devices 2:4 --workers 8 --duration 300 --ramp-ms 50 \
  --sample-seconds 15 --timeout-seconds 600
```

This is an example shape for a later deliberate run after calibration, not a
validated capacity claim. Keep the entire `bundle` directory together, including
`build-info.json`. Serverpod's native hooks require
[`dart build cli`](https://docs.serverpod.dev/upgrading/upgrade-to-four), not a
bare executable compilation. `--target bin/scale_server.dart` builds the server
bundle the same way. To validate an exported server locally, start that bundle
from the exported `benchmark` directory with `--mode=production --apply-migrations`
and PostgreSQL connection variables.

## Local validation

Only short functional segments were run during implementation, never a capacity
run or Cloud deployment, each with at most eight devices and about ten seconds of
scheduled work. See `.scale-benchmark/review/` for the review rounds and their
evidence:

- SQLite (`scripts/scale-server.sh`, `dart run` client): two workers with all four
  device states, network ramp and seeded churn; and one-byte payloads with
  `--setup-concurrency 2`, where every rename was verified exactly and the
  permit peak stayed at two.
- PostgreSQL 16: stamped native client and server bundles against a fresh
  export, two workers and five devices with 4 KiB payloads. Periodic samples
  used estimates, boundaries exact counts, and the town relation outgrew its
  raw live payload, so compression did not hide storage.
- A native server restarted mid-workload: devices reconnected with backoff and
  converged; the strict defaults failed the run on the counted stream ends and
  missed samples, and raised limits passed it.
- Invalid credentials failed at preflight before workers started; SIGTERM
  during the workload stopped both workers and still wrote a failed summary. Run the harness tests from the repository root with
`dart test benchmark/test/scale --concurrency=1`; CI runs them through
`melos test`. They cover topology and churn scheduling, token classification,
the verification oracle (including compensating and stale-value errors), worker
lifecycle with real processes, telemetry races, stream metrics, payloads, and
summary policies.

These checks establish operation of the harness on small inputs. They do not
establish throughput, memory limits, or reliability at thousands of devices.
