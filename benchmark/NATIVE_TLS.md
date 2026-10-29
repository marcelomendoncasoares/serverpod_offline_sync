# Native PostgreSQL TLS integration

This follow-up to [PR #200](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/200)
enables native TLS in the benchmark server. It retains the measured driver's
TCP_NODELAY, inline portal close, and cancellation drainage. PostgreSQL queries,
transactions, and the sync protocol still run through the Dart driver.
There is no pipelining or concurrent merge-query change in this integration.

The server selects the connector before constructing `Serverpod`:

```dart
import 'package:postgres_tls/postgres_tls.dart';
import 'package:serverpod/serverpod.dart';

postgresTlsConnector = nativeTlsConnector;
```

The connector applies to PostgreSQL connections requiring TLS. It does not
change the database's SSL requirement, transaction isolation, or merge locking.
The native package uses synchronous native TLS processing on the isolate,
avoiding Dart SecureSocket's TLS worker handoff.

## Pinned sources

| Package | Source |
| --- | --- |
| `postgres` | [e1079785acfe2b5734e594032c7f748d1ca23a8e](https://github.com/marcelomendoncasoares/postgresql-dart/commit/e1079785acfe2b5734e594032c7f748d1ca23a8e) |
| `postgres_tls` | [22067026c50da3447931ba71ad13fc95f230d5e8](https://github.com/nielsenko/postgres_tls/tree/22067026c50da3447931ba71ad13fc95f230d5e8) |
| `serverpod_database` | [010d23c755c48e99eb35295f7c280ea140412212](https://github.com/nielsenko/serverpod/tree/010d23c755c48e99eb35295f7c280ea140412212/packages/serverpod_database) |

The driver's `lib/` tree is byte-identical to the matched native TLS experiment
preserved on `perf-postgres-native-tls` at `e8fd7dfc`. Its support branch
`perf/native-tls-connector` adds the connector from `nielsenko/postgresql-dart`
at `d392eada` on top of the wire-optimized `79560a9` driver. Using only the
original connector branch would lose the existing wire optimizations. The five
other Serverpod Git pins stay at `4f2a75ab`.

The root overrides apply to this development and benchmark workspace. They do
not propagate into applications consuming published Offline Sync packages;
`postgres_tls` is a dependency of the private benchmark package only.
Application adoption requires the compatible driver/Serverpod dependencies and
the same bootstrap assignment. This remains a draft integration pending upstream
dependency review and supported releases, including a distributable native TLS
package. It is not a package-release approval.

## Performance evidence

The [controlled Cloud experiment](../docs/sync-native-tls-benchmark-2026-10-28.md)
compares otherwise matched Dart/native TLS builds at the same offered rate:

| Capacity / established streams | Mean, Dart → native | p95, Dart → native |
| --- | ---: | ---: |
| Medium, actual 0.25 CPU / 64 | 5308 → 1300 ms | 6816 → 1520 ms |
| Two CPUs / 64 | 355 → 340 ms | 398 → 384 ms |

Medium's mean improved 75.5% and the native build kept up with eight rounds/s.
At two CPUs the mean gain was 4.2%, while observed process CPU fell about 46%.
These are short workload-specific observations, not a capacity guarantee.
All 1,720 measured rounds across the eight experiment runs converged and drained.

The subsequent [Small-instance campaign](../docs/sync-small-native-tls-benchmark-2026-10-29.md)
deployed this PR at `c6fe9d8d`. Without pipelining, four streams averaged 672 ms
(p95 828 ms), and three eight-stream runs averaged 848–861 ms (p95 1005–1061 ms).
All 240 native exercise rounds converged and every run kept up with its offered
rate. Fresh Dart TLS controls varied from 1136 to 2238 ms; the report preserves
that variability and distinguishes correctness from falling behind the schedule.

The Medium/two-CPU table above describes the earlier matched experiment. The
Small campaign measures the packaged PR runtime; local checks and CI are
separate validation. The full experiment snapshot and later pipeline branch
remain separate references.

## Validation and deployment packaging

On Linux, with Python 3.11+ and OpenSSL available, run from `benchmark/`:

```sh
dart test test/native_tls --concurrency=1
dart build cli --target bin/native_tls_tests.dart --output build/native-tls
build/native-tls/bundle/bin/native_tls_tests
dart test test/scale/prepare_cloud_test.dart --concurrency=1
```

CI runs the native checks in both JIT and standalone AOT modes. They cover TLS
record boundaries, certificate/hostname rejection, SSLRequest rejection, the
Serverpod pool hook, real PostgreSQL payloads, rollback releasing locks, query
cancellation and connection reuse, and concurrent connections. Test certificates
are generated temporarily. The TLS proxy forwards PostgreSQL's separate plaintext
CancelRequest connection as well as the encrypted query connection.

The focused integration checks on 2026-10-28 passed with Dart 3.12.2: 17 native
TLS tests in JIT mode and the same 17 in standalone AOT mode, plus 16 Cloud export
tests. With the new Git pins, 62 existing PostgreSQL sync/transaction checks passed
using their normal test transport. Benchmark analysis and repository formatting
passed. The driver support branch also passed its three connector routing and
late-socket cleanup checks. These local results are separate from hosted CI and
the earlier Cloud performance measurements.

`tool/prepare_cloud.dart` retains `postgres_tls` as a production dependency and
copies the immutable root Git overrides into the exported manifest. The export
test resolves those exact sources and analyzes the generated server.
Build standalone executables with `dart build cli` and distribute the complete
bundle, including native libraries; copying only the executable is insufficient.

The experimental native package adds platform-specific artifacts. Current local
validation covers Linux x64. Longer soak tests, supported-platform coverage,
reconnect/failover behavior, and independent native TLS/security review remain
adoption work. Existing SSL verification policy is unchanged by this bootstrap
setting; custom Dart `SecurityContext` settings do not apply to this connector.
