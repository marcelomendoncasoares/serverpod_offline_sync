# Native TLS and PostgreSQL pipelining experiment

`perf-postgres-pipeline` continues the native TLS benchmark from
`perf-postgres-native-tls` (`e8fd7dfc`). The earlier branch retains the previous
matched driver and [native TLS results](../docs/sync-native-tls-benchmark-2026-10-28.md).
This branch tests the supplied pipelining driver and allows independent merge
reads to overlap. It does not alter the existing PR stack or package releases.

## Frozen dependencies

The requested branch heads were resolved on 2026-10-28 and pinned:

| Dependency | Requested ref | Commit |
| --- | --- | --- |
| `nielsenko/postgres_tls` | `dist` | `22067026c50da3447931ba71ad13fc95f230d5e8` |
| `nielsenko/postgresql-dart` | `cloud-test` | `3a05c58697454816f386017f9c9ad89191a08929` |
| `nielsenko/serverpod`, `packages/serverpod_database` | `postgres-pipeline-depth` | `242ee66cc4b3176ac5c1bc3ed2b3c40cbd996d29` |

Other Serverpod overrides remain at `4f2a75ab967dccd56e88261a39203fc5e59d8e80`.
The root lockfile freezes the workspace. The PostgreSQL runtime is a byte-for-byte copy of the supplied Git commit in
`vendor/postgres`, with its original license and [provenance](../vendor/postgres/PROVENANCE.md).
Upstream force-pushed `cloud-test` during the experiment, making the initial
commit unavailable to a clean Cloud checkout. Vendoring preserves that tested
snapshot; it does not include the subsequent `9c4cbc0` revision. The previous
matched implementation remains on the native TLS branch.

Before constructing Serverpod, `bin/scale_server.dart` installs
`nativeTlsConnector` and sets `postgresPipelineDepth = 8` through the experiment
constant in `lib/scale/tls_experiment.dart`. The authenticated runtime endpoint
reports the variant, native connector, pipeline depth, executable hash and CPU
quota.

## Concurrent merge reads

After acquiring the existing clock and space locks, a PostgreSQL merge starts
two independent chains together: source-node/space-node lookup, and conflict
metadata/projection-proof reads. `Future.wait` waits for both, including on
failure, before writes or rollback. Each chain retains its own dependencies.
SQLite remains sequential. Lock acquisition, writes, projection application,
cursor persistence and commit retain their existing order.

A depth of eight is a maximum on one connection, not eight database connections
or eight parallel PostgreSQL executors. The narrow sync change exposes at most
two simultaneous calls in its read phase. Most operations remain dependent.
Diagnostics report `maxConcurrentSql`, summed query duration, and the union of
query intervals as `sqlWallMicros`; only the latter belongs in a wall-time split.
Concurrent calls can also be queued inside a depth-one driver, so the diagnostic
peak alone does not prove pipelining. The native wire test checks actual sends
and replies.

## Build and prepare

Use Dart 3.13.7 and the matching Serverpod CLI. From the repository root:

```sh
dart pub get --enforce-lockfile
dart run benchmark/tool/prepare_cloud.dart --output /tmp/offline-sync-pipeline-export
python3 benchmark/tool/verify_native_tls_export.py /tmp/offline-sync-pipeline-export
cd /tmp/offline-sync-pipeline-export/benchmark
dart build cli --target bin/main.dart --output /tmp/offline-sync-pipeline-server
```

Use `dart build cli` to preserve native assets. Preparation creates a private
workspace and configuration for a fresh database; it does not deploy. When
using an existing Cloud project, preserve its private config, passwords,
migrations and project association. None of those credentials is in Git.
The verifier checks the 233 exported runtime Dart files and dependency pins
against this experiment's depth-eight concurrent build.

The benchmark uses one streaming endpoint and the existing immutable client.
For a newly built client, from the repository root:

```sh
dart run benchmark/tool/build_native.dart --target bin/rounds.dart --output /tmp/pipeline-client
```

With `BENCHMARK_SECRET` supplied privately, the 64-stream workload is:

```sh
/tmp/pipeline-client/bundle/bin/rounds \
  --target "$BENCHMARK_TARGET" --run-id pipeline-64 \
  --users 32 --devices 2 --workers 8 --rounds 10 --rows 1 \
  --period-ms 4000 --sample-seconds 30 --timeout-seconds 45 \
  --startup-timeout-seconds 300 --setup-concurrency 1 \
  --schema full --workload person --write-mode insert \
  --mode continuous --no-sync-diagnostics
```

For eight streams use four users, four workers, a 2000 ms period and a fresh run
ID. The comparison keeps database placement, pool size, logging, client binary,
workload and CPU quota fixed. Detailed server profiling samples only user zero.

To repeat the depth-one control, change the experiment constant to one and its
variant to `pipeline1-concurrent`. The sequential control uses the merge source
from `e8fd7dfc` with the same new dependencies. The previous native-driver
control uses that commit's dependency graph. Keep all other inputs identical.

## Validation

Native checks need Linux, OpenSSL, Python and embedded PostgreSQL. They create
and remove their own certificates and database; no Cloud secret is needed.
From `benchmark/`:

```sh
dart test test/native_tls --concurrency 1
dart build cli --target bin/native_tls_tests.dart --output /tmp/pipeline-validation
/tmp/pipeline-validation/bundle/bin/native_tls_tests
dart test test/scale/diagnostics_integration_test.dart test/scale/prepare_cloud_test.dart test/scale/source_export_test.dart --concurrency 1
```

The 23 native checks include eight exchanges in flight, depth-one serialization,
correct result association, rollback after a middle statement fails, connection
reuse, and the driver's timeout behavior with another query in flight. The
instrumented integration check exercises actual sync and observes overlapping
SQL calls, exact convergence and stream cleanup.

Run the existing PostgreSQL correctness contracts with depth eight from
`test/serverpod_offline_sync_test_server/`:

```sh
dart test ../../benchmark/test/pipeline --concurrency 1
```

These wrappers invoke the existing admission/cancellation, insert batching,
domain batching and multi-space transaction contracts. Run them sequentially:
the existing Serverpod fixtures share a fixed API port.

The driver intentionally avoids sending a query cancellation when a later
statement is already in flight, since it could cancel that later statement.
A configured query timeout may therefore complete successfully after its soft
deadline; the hard fallback can close the connection. This behavior is verified
in the native test and remains an upstream driver/API consideration before
production adoption.
