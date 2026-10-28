# Native PostgreSQL TLS experiment — 2026-10-28

## Results

The matched native TLS build reduced the Medium/64-stream average from 5308.2 ms to 1300.1 ms (75.5%). The table reports all exercise rounds; the offered-rate verdict is separate from correctness.

Medium/64 now kept up with the 8-round/s schedule, but its 1318.9 ms median and 1519.5 ms p95 still miss the sub-second goal.

All latency values below are milliseconds. Median is the arithmetic middle of the two center observations for even populations; p95 uses nearest rank. Each row is one run, not a confidence interval.

| Instance (CPU quota) | Streams | TLS | Rounds | Min | Median | Mean | p95 | Max | Kept up |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| medium (0.25) | 8 | Dart | 40 | 385.1 | 451.7 | 469.6 | 543.8 | 551.0 | Yes |
| medium (0.25) | 8 | Native | 40 | 365.5 | 428.9 | 438.2 | 505.9 | 533.8 | Yes |
| medium (0.25) | 64 | Dart | 320 | 511.2 | 5486.8 | 5308.2 | 6816.2 | 15780.4 | No |
| medium (0.25) | 64 | Native | 320 | 509.7 | 1318.9 | 1300.1 | 1519.5 | 1741.6 | Yes |
| xxlarge (2) | 64 | Dart | 320 | 322.8 | 349.1 | 355.2 | 398.1 | 600.2 | Yes |
| xxlarge (2) | 64 | Native | 320 | 310.2 | 334.2 | 340.3 | 383.5 | 630.7 | Yes |

| Matched workload | Mean reduction | p95 reduction | Sampled server-path reduction |
| --- | ---: | ---: | ---: |
| medium, 8 streams | 6.7% | 7.0% | 27.8% |
| medium, 64 streams | 75.5% | 77.7% | 80.2% |
| xxlarge, 64 streams | 4.2% | 3.7% | 24.0% |

### Requested branches as supplied

These native runs keep the supplied PostgreSQL branch unchanged. They include its separate portal-close exchanges, so they are not the isolated TLS comparison.

| Instance | Streams | Min | Median | Mean | p95 | Max | Kept up |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Medium | 8 | 366.4 | 438.0 | 439.8 | 467.6 | 510.3 | Yes |
| Medium | 64 | 491.4 | 3698.9 | 3466.7 | 5107.6 | 5800.1 | No |

### Where the matched Medium/64-stream time went

Means below cover the 10 correlated rounds for sampled user 0, not the entire 320-round population. All 10 merge + 3 capture application SQL calls remain. Durations partition the same sampled critical path.

| Component | Dart TLS (ms) | Native TLS (ms) |
| --- | ---: | ---: |
| Merge queue | 0.1 | 0.1 |
| Acquire connection + BEGIN, both transactions | 487.8 | 90.9 |
| Merge SQL: 10 calls | 2358.5 | 481.3 |
| Capture SQL: 3 calls | 830.7 | 151.1 |
| Non-SQL transaction body | 38.2 | 21.0 |
| Commit + connection release, both transactions | 512.1 | 86.2 |
| Other server spans and gaps | 511.2 | 109.3 |
| Transport + client residual | 298.9 | 308.4 |
| **Sampled total** | **5037.4** | **1248.4** |

### Query wall time, CPU, and memory

SQL wall/call is the sampled combined merge/capture SQL wall time divided by 13. It is not PostgreSQL execution time or a measurement of pure cryptographic CPU. RSS includes native memory; these short runs do not establish leak freedom. CPU estimates use process ticks and client-side sampling intervals and can exceed the reported fractional quota; visible throttling counters are unavailable.

| Instance / streams | TLS | Sampled server path (ms) | SQL wall/call (ms) | Exercise CPU (cores) | Exercise RSS mean / max (MiB) |
| --- | --- | ---: | ---: | ---: | ---: |
| medium / 8 | Dart | 239.2 | 8.86 | 0.176 | 83.0 / 84.3 |
| medium / 8 | Native | 172.6 | 7.99 | 0.073 | 79.4 / 80.0 |
| medium / 64 | Dart | 4738.5 | 245.32 | 0.316 | 144.9 / 149.8 |
| medium / 64 | Native | 940.0 | 48.65 | 0.211 | 107.9 / 110.0 |
| xxlarge / 64 | Dart | 121.1 | 6.12 | 0.326 | 128.0 / 130.6 |
| xxlarge / 64 | Native | 92.0 | 4.55 | 0.178 | 110.5 / 111.8 |

## Interpretation

The matched comparison changes the TLS implementation while preserving encryption, TCP_NODELAY, portal handling, sync logic, and the database endpoint. The measured effect covers the TLS implementation as a whole; this experiment does not divide it into cryptographic execution, copying, allocation, or event-loop handoffs. The native implementation performs TLS processing synchronously on the isolate thread and avoids the SecureSocket TLS worker handoff.

Established WebSocket streams are already open before exercise. The database pool is allowed to grow normally, so these results are not restricted to an artificially fixed set of prewarmed database connections. The client/network residual remains outside the sampled server path and must not be called database latency.

The two-core comparison is useful because it reduces the fractional-CPU scheduling pressure. The difference between the two capacities should not be projected linearly to thousands of active users.

At 2 cores and equal offered rate, observed exercise CPU fell from approximately 0.326 to 0.178 cores (46%), and mean RSS from 128.0 to 110.5 MiB. End-to-end mean latency improved only 4.2% there. The large Medium/64 improvement is the strongest result; small differences in the lighter-load cases require repeated runs before treating them as stable percentages.

This supports retaining native TLS as a performance candidate. The next validation should be repeated/longer controlled runs and failure/lifecycle review of the connector before adoption. Native TLS alone does not close the Medium/64 sub-second target. No additional protocol change or removal of transaction locking was needed.

## Cleanup

All eight runs (1,720 exercise rounds) passed exact convergence checks, had zero exercise-round retries, and ended with zero open sync streams and no idle-in-transaction sessions. Ordinary idle pool connections were allowed. Every sampled trace partition was valid and no diagnostic records were dropped.

The original prepared executable was restored on one Small instance with measured quota 0.1 cores. Its SHA-256 is e61d7523bf14fb3771ecaab9de26b98df2ad525b8bc7e9c2987cad615fae5ffc. All six protected configuration/secret file hashes match the pre-test snapshot. No PRs were opened and the existing review stack was not changed.


## Question and comparison

Does moving TLS encryption/decryption from Dart's SecureSocket path to the supplied synchronous native connector reduce established-stream sync latency, especially under a fractional CPU quota?

The PostgreSQL protocol driver, Serverpod, and sync logic remain in Dart. Merge serialization and the database endpoint are unchanged. This experiment replaces the TLS transport.

The requested branches are pinned to:

| Dependency | Branch | Commit |
| --- | --- | --- |
| nielsenko/postgres_tls | dist | 22067026c50da3447931ba71ad13fc95f230d5e8 |
| nielsenko/postgresql-dart | tls-connector | d392eada9e802c579719f1a1497c14d028cf3ff6 |
| nielsenko/serverpod, packages/serverpod_database | postgres-tls-connector | 010d23c755c48e99eb35295f7c280ea140412212 |

The existing Serverpod Git overrides, except serverpod_database, remain pinned to 4f2a75ab967dccd56e88261a39203fc5e59d8e80. The matched builds have identical dependency locks. Server Dart is 3.13.7. The unchanged client executable SHA-256 is 044b08b4bee651780909be4c44949c90a25a239f72c1548417289d7301e2667e.

The supplied PostgreSQL branch predates two optimizations in the deployed driver (79560a928c6b9307e89fe52f368f68dfce01eb79): TCP_NODELAY on the ordinary socket path, and closing a transaction portal in the existing Execute/Sync exchange. The native connector itself enables TCP_NODELAY, while the supplied default connector does not. Comparing those two directly would mix TLS and TCP_NODELAY effects. Adopting the branch as supplied also reintroduces a separate portal-close exchange per transaction query.

Three builds address this:

1. **Supplied native:** the user's exact dependency commits and native connector enabled.
2. **Matched stock:** the same connector API and dependencies, both existing driver optimizations retained, native connector disabled.
3. **Matched native:** identical to matched stock except that the native connector is enabled and its build identity differs.

The first matched Cloud upload omitted a driver referenced only by a path override and failed dependency resolution before starting. Both matched builds were then packaged with the patched driver as an explicit workspace member. The failed build is retained as `stock-build-failure.log`; it produced no benchmark result. Both corrected matched lockfiles are identical.

The matched driver's connection implementation differs from the deployed baseline only by the connector branch and common channel-construction extraction. The other three changed driver source files expose/propagate the connector setting. No published dependency, PR, review-stack branch, or original prepared deployment source was changed.

## Workload and controls

- One Cloud instance; Medium has a measured quota of 0.25 cores, XXL has 2 cores. Labels alone are not CPU counts.
- 8 streams = 4 users with 2 devices each; 64 streams = 32 users with 2 devices each.
- Established continuous streams, full Person schema, one inserted row per round, 10 rounds per user.
- The 8-stream schedule targets 2 rounds/s total; the 64-stream schedule targets 8 rounds/s total. `keptUp` is reported separately from correctness.
- Same original database endpoint, TLS required, pool limit 100, one instance, commit hints disabled, persistent and console session logging disabled.
- The same low-overhead server diagnostics sample user 0 in every run. No native VM timer/wire profiler and no detailed client profiler are enabled.
- Client timing is local write through application on the other device. Startup, warmup, final verification, and stream teardown are excluded from the latency distribution.
- Correctness checks require exact convergence, no failed rounds, and clean stream/transaction drainage after the run.
- Query counts count application SQL calls. Portal Close messages and BEGIN/COMMIT are not included in the 10 merge + 3 capture SQL count.
- Sampled breakdowns correlate numbered batches and authored round identities on the server's monotonic clock. SQL wall time includes network and scheduling; connection timing includes BEGIN.
- CPU and RSS comparisons use resource samples within the exercise phase. CPU is process user+system time, not crypto-only CPU. Visible cgroup throttling counters are unavailable.

## Local validation

- Supplied native connector: 17 passing JIT tests and 17 passing standalone AOT tests, with the native library bundled. The final AOT executable exits normally with code 0.
- Coverage: 4 MiB TLS echo, certificate trust and hostname rejection, SSLRequest rejection, exact 1 MiB PostgreSQL binary payload plus Unicode, concurrent queries, transaction rollback releasing a held row lock, query-timeout cancellation followed by connection reuse, and the Serverpod pool connector hook.
- The later shared rollback assertion also passed independently.
- Matched driver/native connector: all 5 real PostgreSQL checks passed.
- Source analysis passed for the supplied and matched server entries and experiment identity.

Initial fixture failures are retained in the evidence. The distribution clone omitted its local test certificates; ephemeral CA/localhost fixtures were generated. The copied echo helper also needed to close accepted sockets for a standalone executable to exit. A first cleanup patch exposed a set-iteration race during teardown; snapshotting the sets and closing late handshake completions fixed it. No native connector implementation was changed to make these tests pass.

## Evidence

Durable companion files: [computed results](benchmark-evidence/native-tls-2026-10-28/results.json), [dependency and validation manifest](benchmark-evidence/native-tls-2026-10-28/manifest.json), [driver patch retaining the existing optimizations](benchmark-evidence/native-tls-2026-10-28/retain-existing-driver-optimizations.patch), and [matched-source controls](benchmark-evidence/native-tls-2026-10-28/matched-controls.json).

Private evidence and source copies: `/tmp/sync-native-tls-20261028`.

- `manifest.json`: dependency refs, lock hashes, client identity, validation receipts.
- `postgres-matched-versus-base.diff`: matched connection implementation compared with the deployed driver.
- `campaign.py`, `cloud.py`, `analyze.py`: deployment, workload collection, and analysis.
- `*-deployed.zip`: exact uploaded source bundles; these are private and must not be published because prepared projects include deployment configuration.
- `runs/*/events.jsonl`, `*-server.jsonl`, `*-resources.json`, `*-correlated.json`: raw workload and attribution evidence.
- `results.json`: computed distributions, load verdicts, CPU/RSS, and sampled timing splits.

## Limits

Short controlled runs establish the observed performance effect for these workloads. They do not certify long-run memory stability, all TLS/security properties, platform coverage, reconnect/failover behavior, or support for thousands of simultaneously active devices. The native package is experimental and adds a native artifact/build dependency. Workload-local tests are not a production-readiness review.
