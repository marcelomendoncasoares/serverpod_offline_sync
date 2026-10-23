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
Use one dedicated server process: preflight rejects existing streams or idle
transactions. After workers stop, the runner observes cleanup for up to 30 seconds
(capped by `--timeout-seconds`). Remaining streams, idle transactions including
aborted transactions, or an unavailable final cleanup sample fail the run even
when ordinary sample failures are tolerated. The final observed cleanup metrics
are retained in `summary.json.server.cleanup` and `events.jsonl`.
An observed server-instance change fails the run. Route the scale workload to
that process; one responding replica cannot establish fleet-wide cleanup.

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

The runner reads its secret from the environment. The server prefers its
Serverpod password and falls back to the environment. Secrets are not written
into manifests or process arguments. Over `http`, the secret travels unencrypted; the runner warns
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
- Multiple load-generator hosts are not coordinated by this runner. Run them
  sequentially against the dedicated target with distinct `--run-id` values;
  overlapping runs would make global stream/transaction cleanup ambiguous.
- Process and stream metrics describe only the responding instance. A target
  that distributes requests across replicas is outside this runner's cleanup
  acceptance boundary; use separate controlled cross-process probes to measure
  the hint mechanism.

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

Install Dart, the Cloud CLI, and the Serverpod CLI at the version the project
resolves (currently `dart pub global activate serverpod_cli 4.1.0-beta.3`).
Deployment then takes two steps:

```sh
dart run benchmark/tool/prepare_cloud.dart --output /tmp/offline-sync-cloud
(cd /tmp/offline-sync-cloud/benchmark && scloud launch)
```

`prepare` creates a complete PostgreSQL workspace, resolves its dependencies,
and runs code generation. Plain `scloud launch` adds and runs its normal
`serverpod generate` hook with the `serverpod` command on your `PATH`. Serverpod
only warns when that CLI's version differs from the project's, so `prepare`
fails before reporting ready unless the two match. On failure or interruption,
`prepare` removes the incomplete output so the same command can be retried.

Follow the launch wizard to select a dedicated Cloud project with managed
PostgreSQL, and keep the preselected password import. Each preparation generates
a secret under its own password name, `benchmarkSecret_<id>`, in
`benchmark/config/passwords.yaml`, which is excluded from the upload. The wizard
only imports passwords a project lacks. A new name therefore also reaches an
existing project: launching a new export there imports its password, and the
server reads the name recorded in `benchmark/config/benchmark_build.json`.
Passwords from earlier exports stay in the project unused. They do not affect
launches, and `scloud password unset <name>` removes them if you want. No
separate dependency, configuration, or password command is required.

Use the generated password value as the load generator's `BENCHMARK_SECRET`, and
the deployed API domain as its `--target`. The server's password takes precedence
over a `BENCHMARK_SECRET` variable, which it ignores with a log message; local
runs without the password use `BENCHMARK_SECRET`.

The exported `benchmark` directory contains a conventional `bin/main.dart`,
PostgreSQL configs, generator configuration, model sources, and the workspace's
package implementations. Preparation records the source revision and dirty state
in `PREPARED.json` and `benchmark/config/benchmark_build.json`, which the server
reports. It never rewrites the original test packages and refuses an existing
output directory. Prepare into a new directory after changing source.

Only the latest schema is exported as a fresh PostgreSQL baseline. Use an empty,
dedicated Cloud database; this is not an upgrade migration for an existing test
or production database. Cloud supplies the database connection settings. The
production connection pool defaults to 10, and the server reports its effective
value. Only the standard sync module and authenticated benchmark control endpoint
are exposed; demo auth/debug endpoints are absent.

Cloud account access is required for the launch wizard. See the
[Cloud deployment guide](https://docs.serverpod.dev/cloud/concepts/deployments)
for the standard launch flow. Local preparation, packaging, and startup checks
do not establish that a hosted deployment has completed.

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

## Historical harness validation

The original harness development recorded only short functional segments were run during implementation, never a capacity
run or Cloud deployment, each with at most eight devices and about ten seconds of
scheduled work. These are historical observations, not validation of this review branch.
The original local artifacts are not included in this repository:

- SQLite (`scripts/scale-server.sh`, `dart run` client): two workers with all four
  device states, network ramp and seeded churn; and one-byte payloads with
  `--setup-concurrency 2`, where every rename was verified exactly and the
  permit peak stayed at two.
- Cloud preparation: a fresh export verified the installed Serverpod CLI,
  resolved dependencies, passed the standard generation hook, and was packaged
  with the Cloud CLI without its password file. The filtered upload resolved its
  lockfile and built a native server. Given only the export's Cloud password and
  a stale `BENCHMARK_SECRET`, the server used the password: the stale secret was
  rejected, and four devices across two users converged against PostgreSQL 16.
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


## Sync diagnostics

Diagnostics are enabled by default in the benchmark client and server. Rebuild
both from the same branch. `summary.json.syncDiagnostics` joins one-off requests
by request ID, ranks the slowest requests and engine cycles, and includes every
verification round's duration and observed mismatch reason. `events.jsonl`
contains the underlying `syncTrace`, `mergeTrace`, `syncCycleTrace`, `verifyRound`,
`clientPermitWait`, `fanoutDelivery`, `slowSql`, `databaseDiagnostics`, and
`serverProcess` records. Stream reconnect/backoff events remain in the same file.
Request IDs include the run, user, device and attempt; the user UUID is the
server-authenticated identity. `peerNodeId` identifies the actual replica.

Core instrumentation is opt-in through `OfflineSyncDiagnostics.run`; ordinary
package users do not collect traces. The benchmark's connector adds optional
correlation arguments without changing the production sync protocol. Old
clients still work. The core observer runs synchronously and must avoid I/O;
observer errors cannot fail a sync. The benchmark buffers records in memory
(4096 records or 16 MiB), exposes them only through the existing admin control
endpoint, and prints one structured Cloud log line per completed merge/request.
The collector tracks a cursor per server instance and reports missing records.
For multiple replicas, also collect centralized Cloud logs: a load-balanced
control connection cannot guarantee visiting every process.

Timing interpretation:

- `queue.userOrSpace` waits for the preceding merge sharing a user or space;
  `queue.globalCapacity` waits for the server instance's shared concurrency
  limit. Different users can wait on this global limit. Queue snapshots report
  queued requests ahead of the arrival, active merges, and the limit. Database
  locks still provide cross-process serialization.
- `connectionWaitAndBeginMicros` ends when Serverpod enters the transaction
  callback. Its public API cannot separate pool acquisition from `BEGIN`.
  `commitOrRollbackAndReleaseMicros` starts when that callback exits and includes
  transaction completion and connection release. All timings are monotonic.
- Transaction phases record elapsed time, SQL count, affected rows and SQL
  duration. SQL intervals are combined before computing `unattributedBodyMicros`,
  so parallel SQL is not double-counted as wall time. This residual includes ORM
  decoding, Dart computation, scheduling and awaits outside logged SQL. It is not
  a CPU-time measurement. The SQLite client has no statement observer; its
  residual also includes SQLite operations. Process samples show the active
  phase and last completed SQL time while a request is still running.
- Engine stages separately expose handshakes, cursor reads, outbound snapshots,
  inbound peer waits, merge application, close handshakes and polling delays.
  `cycle.repeat` records why another protocol cycle is needed; verification
  repeats record actual journal/digest mismatches. Merge callbacks are checkpoint
  reports, so gaps between callbacks are not merge execution times.
- Server wire timestamps end at an event being yielded to the transport. Client
  timestamps observe transport dispatch, event delivery and local application.
  They do not claim socket flush or one-way network latency. JSON payload bytes
  exclude transport envelopes, framing and compression. Row counts are distinct
  rows within each chunk; repeated delivery may count a row again.
- Fan-out uses independent device polling. There is no direct notification
  broadcast. `fanoutDelivery` measures a retained committed change until it is
  yielded to another device, with source and destination request IDs. Tracking
  retains at most 10,000 changes in one process; it cannot observe commits made
  on another server instance. Delivery latency is not added to the originating
  request's elapsed time.

Every second the server samples event-loop lag, process CPU/RSS and active
requests. GC events and isolate counts are collected only if a local VM service
is already enabled. An AOT Cloud build normally has none; unsupported metrics
are explicitly null, not inferred from OS threads or event-loop lag. No debug
service is enabled or exposed by the benchmark.

Before load, the coordinator attempts `CREATE EXTENSION IF NOT EXISTS
pg_stat_statements`, then captures cumulative statement and table/index scan
statistics. Lack of privileges/preloading is reported, with application SQL
logging at 100 ms as a fallback. After seed, verify and close, it retains
`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` plans for up to eight observed hot
SELECT shapes. These run in read-only transactions with a two-second statement
timeout and row-lock clauses removed. The plans describe the same read
predicates, not lock acquisition. Profiling is outside measured load phases;
compare cumulative counters between phase boundaries instead of treating them
as per-run totals. No database statistics are reset.

Use `--no-sync-diagnostics` for a client/server request-tracing overhead control.
Set `BENCHMARK_DIAGNOSTICS=off` when starting a local server to disable its
process sampler as well. The existing secret and deployment configuration need
no changes for normal instrumentation.

Serverpod session logging is a separate setting. `--no-sync-diagnostics` does
not disable database persistence or console session logs. The benchmark provides
`BENCHMARK_SESSION_LOGGING=on|off` to control both writers after framework config
loading. Leave it unset to use ordinary Serverpod configuration. To disable both
writers in a dedicated Cloud benchmark and restart the existing build:

```sh
scloud variable set BENCHMARK_SESSION_LOGGING off
scloud deploy --redeploy
```

Boundary metrics and each round manifest include `server.sessionLogging`, with
the effective writer settings and the three relevant environment values. Check
these after every deployment or capacity change. Local YAML and stored Cloud
variables alone are not proof of the running configuration. A quiet log can
also mean requests stayed below the slow-session threshold: use a deliberately
logged canary to verify disabling persistence, then restore its selection policy.
Insights can remain reachable and show older records after persistence is
disabled. Its runtime slow-query/session selection policy is separate from
whether a database or console writer is enabled.

### Serverpod SDK source dependencies

The workspace root pins the six sibling SDK packages to the reviewed Git source
in `pubspec.yaml`. That source includes prompt method-stream cancellation and
client startup changes. Use the same manifest for clients and prepared servers;
`prepare_cloud.dart` carries these overrides into its normal root manifest.
Cloud builds therefore do not depend on `pubspec_overrides.yaml`, a modified Pub
cache, or a vendored patch. The SDK regression tests live with the SDK changes.

The export test resolves the Git dependencies, checks their locked revisions,
regenerates and analyzes the exported sources, and checks upload exclusions.
Those checks run in CI. Preparing sources locally is not a deployment result.

## Established-stream rounds and fresh one-shot calls

`bin/rounds.dart` is a separate workload for replication latency. The churn
benchmark's `streamFirstMerge` and intervals between merge callbacks include
startup or idle time and must not be used as per-change latency measurements.
Build the new client with:

```sh
dart run benchmark/tool/build_native.dart --target bin/rounds.dart --output /tmp/rounds-client
```

Both modes keep one SQLite database per device and use only the public client,
session, transaction, and ORM APIs. Every device first authors a sentinel batch
that must reach every peer; warmup is excluded from measured samples. Measured
rounds insert `--rows` independent Person records in one local transaction, with
`--payload-bytes` seeded ASCII bytes in each name. Writers alternate between a
user's devices. There are no conflicting writers within a round.

```sh
# Four users, eight continuously connected devices, ten-row batches.
/tmp/rounds-client/bundle/bin/rounds --target https://YOUR-API/ \
  --mode continuous --users 4 --devices 2 --workers 4 \
  --rounds 20 --rows 10 --period-ms 2000 --run-id continuous-u4-r10

# Same rows and devices, new transport for every one-shot call.
/tmp/rounds-client/bundle/bin/rounds --target https://YOUR-API/ \
  --mode once --users 4 --devices 2 --workers 4 \
  --rounds 20 --rows 10 --period-ms 2000 --run-id once-u4-r10
```

Pass the existing shared secret through `BENCHMARK_SECRET`. Choose a fresh run
id every time. `--sync-diagnostics` defaults on; repeat a case with
`--no-sync-diagnostics` to quantify trace overhead.

- Continuous mode opens all streams before warmup. No reconnects, one-shot
  calls, or repair syncs are allowed. Each round ends only when an unthrottled
  public ORM watch observes the exact ids and domain values on every peer.
  `writeToAllPeers` includes the local write transaction; `commitToAllPeers`
  starts when that transaction returns. Both include the observation query.
- Once mode constructs a new generated client for **each** timed call, so its
  WebSocket cannot be shared with another call. SQLite stays open. The writer
  pushes first, then all peers pull concurrently. `syncOnce.push`, `.pull`, and
  `.all` measure individual calls from client construction through completion,
  including transport setup, authentication, protocol, apply, and close
  handshake. `writeToAllPeers` covers the whole push-then-pull workflow; it is
  not the duration of one `syncOnce`. Calls are not retried.
- Each user has a fixed schedule with period `--period-ms`. Users are spread
  over a period. A user waits for its round before starting another, but the
  original schedule is retained: slow service produces `scheduleLag` and
  `scheduledToAllPeers` growth. `load.keptUp` requires **every** user to finish
  within `rounds * period`. A passing correctness result alone is not a capacity
  or latency pass.
- After measurement, the server and every local replica must match the entire
  expected journal exactly, without additional synchronization. Unexpected
  stream ends, incomplete rounds, worker errors, failed samples, server restart,
  or leftover streams/idle transactions fail the run. Artifacts and SQLite
  databases are retained in `.round-benchmark/<run-id>` (or `--data-dir`).

For a stream capacity sweep, hold row count and period fixed and increase users
(e.g. 1, 4, 8, 16, 32 with two devices each). Set `--workers` no higher than users;
add workers if their loop lag or CPU becomes limiting. Also test more devices
within one user to distinguish fan-out and same-user serialization from total
stream count. Report observed open streams, mean/p95 propagation, offered load,
schedule lag, client resource use, exact verification, and cleanup. A highest
passing level is a lower bound under this workload, not a universal maximum.

`manifest.json` records timing definitions and client/server identity;
`events.jsonl` retains individual round and call samples, diagnostic traces,
server metrics and worker CPU/lag; `summary.json` contains exact nearest-rank
quantiles (unlike the churn benchmark's histogram upper bounds). Warmup rounds
have negative round numbers and are never included in these distributions.
