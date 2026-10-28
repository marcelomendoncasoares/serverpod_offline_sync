# Native PostgreSQL TLS benchmark branch

`perf-postgres-native-tls` preserves the matched native-TLS experiment, including
the server diagnostics, benchmark client, patched driver, and local validation.
Start with the [results and limits](../docs/sync-native-tls-benchmark-2026-10-28.md).
This is an experiment branch based on `perf-postgres-wire-driver`, not a package
release or a change to the existing PR stack.

## What is frozen

- `postgres_tls`: nielsenko/postgres_tls at
  `22067026c50da3447931ba71ad13fc95f230d5e8`.
- `serverpod_database`: nielsenko/serverpod at
  `010d23c755c48e99eb35295f7c280ea140412212`.
- Other Serverpod overrides: `4f2a75ab967dccd56e88261a39203fc5e59d8e80`.
- The `postgres` runtime is vendored in `vendor/postgres`, with its original
  license and [provenance](../vendor/postgres/PROVENANCE.md). It combines the
  supplied connector branch with the already-tested TCP_NODELAY, portal-close,
  and cancellation-drain behavior. It is an explicit workspace member so the
  Cloud upload includes it.
- The root `pubspec.lock` freezes this benchmark workspace. Server runtime source
  hashes from the measured deployment are in `native_tls/source-manifest.json`.

`bin/scale_server.dart` installs `nativeTlsConnector` before constructing
Serverpod. `lib/scale/tls_experiment.dart` selects the native build and provides
the identity reported by the authenticated benchmark control endpoint.

To repeat the matched Dart-TLS control, change only the two constants in
`tls_experiment.dart` to `matched-stock` and `false`, then rebuild. Keep the
dependency graph, database, configuration, workload, and CPU quota identical.
The source-hash check below is intentionally specific to the native build.

## Build and prepare

The measured server used Dart 3.13.7 on Linux x64. The measured client used Dart
3.12.2. Use `dart build cli` to bundle native assets; copying only an executable
does not preserve its required libraries.

From the repository root, with Dart 3.13.7 and the matching Serverpod CLI on PATH:

```sh
dart pub get --enforce-lockfile
dart run benchmark/tool/prepare_cloud.dart --output /tmp/offline-sync-native-export
python3 benchmark/tool/verify_native_tls_export.py /tmp/offline-sync-native-export
cd /tmp/offline-sync-native-export/benchmark
dart build cli --target bin/main.dart --output /tmp/offline-sync-native-server
```

Preparation validates the installed CLI version and prints the required version
if it differs. It creates fresh private configuration for a fresh database.
Deployment credentials and the live Cloud configuration are not in this branch.
When updating an existing prepared deployment, preserve its configuration,
passwords, migration history, and Cloud project association. The export above
does not deploy anything.

The measured runs used TLS to the same remote database, a pool limit of 100,
one instance, no persistent/console session logging, no commit hints, and the
full Person schema. Default export configuration is a starting point, not a
copy of those private deployment settings. See `SCALE.md` for authentication
and benchmark configuration.

Build the client from the repository root:

```sh
dart run benchmark/tool/build_native.dart --target bin/rounds.dart --output /tmp/native-tls-client
```

With `BENCHMARK_SECRET` supplied privately, the 64-stream workload is:

```sh
/tmp/native-tls-client/bundle/bin/rounds \
  --target "$BENCHMARK_TARGET" --run-id native-tls-64 \
  --users 32 --devices 2 --workers 8 --rounds 10 --rows 1 \
  --period-ms 4000 --sample-seconds 30 --timeout-seconds 45 \
  --startup-timeout-seconds 300 --setup-concurrency 1 \
  --schema full --workload person --write-mode insert \
  --mode continuous --no-sync-diagnostics
```

For 8 streams, use `--users 4 --workers 4 --period-ms 2000` and a new run ID.
These commands reproduce the workload. The reported phase breakdowns also
required collecting the server's sampled diagnostic events for user 0; they
are not inferred from the client latency distribution.

## Local validation

The native connector checks need Linux, OpenSSL, Python 3.11 or newer, and the
embedded PostgreSQL dependency. Certificates and keys are generated temporarily
and deleted. No live database or Cloud credentials are used.

From `benchmark/`:

```sh
dart test test/native_tls --concurrency 1
dart test test/scale/prepare_cloud_test.dart test/scale/source_export_test.dart --concurrency 1
dart build cli --target bin/native_tls_tests.dart --output /tmp/native-tls-validation
/tmp/native-tls-validation/bundle/bin/native_tls_tests
```

The 17 native checks cover TLS exchange and certificate rejection, large binary
payloads, concurrent connections, rollback/lock release, cancellation followed
by reuse, and Serverpod's connector hook. The socket tests derive from the
pinned `postgres_tls` tests; the pool-hook case derives from the pinned
`serverpod_database` tests. The echo fixture closes accepted sockets so a
standalone AOT runner exits normally. The transaction tests and TLS proxy are
the local benchmark fixtures, now using repository-relative paths.

The Cloud results in the report were measured before this source port. Publishing
the branch does not constitute another Cloud run. The export hash check verifies
the measured server, package, model, and driver runtime sources; packaging and
fixture validation is reported separately.

## Branch validation on 2026-10-28

- `dart pub get --enforce-lockfile` passed.
- The prepared Cloud export matched all 233 measured runtime source hashes.
- The exported server compiled with `dart build cli`, including the native TLS
  asset. The standalone validation bundle exited with code 0.
- All 17 native checks passed in both JIT and AOT. The later rollback/reuse
  assertion also passed on its own.
- Cloud preparation, dependency resolution, upload exclusion, source export,
  and interruption/preservation checks passed. The 16 selected workload,
  round-contract, and frame-correlation checks passed.
- Analysis of the touched benchmark code and fixtures reported no issues.

No Cloud deployment or new performance measurement was performed for this
branch publication.
