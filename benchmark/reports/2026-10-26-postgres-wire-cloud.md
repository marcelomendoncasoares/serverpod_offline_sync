# PostgreSQL wire changes: Cloud comparison — 2026-10-26

The two driver changes reduce mean end-to-end latency at 64 established streams on two cores from **497 ms to 357 ms**, and **350 ms on repeat**. The same 13 SQL calls in the sampled server path fall from **202 ms to 57 ms**. The client/transport residual now dominates that healthy path.

The improvement does **not** make Medium sustain the 64-stream workload. Its mean falls from **6.99 s to 5.75 s**, then **4.95 s on repeat**, but both candidate runs miss the offered eight rounds per second. Small now completes its 8-stream smoke test, where the baseline times out during warmup, but averages **2.22 s** and also misses its offered rate. The deployment is left on **Small**.

## Changes and provenance

| Repository | Change | Review reference |
| --- | --- | --- |
| PostgreSQL Dart driver | Enable TCP_NODELAY before TLS; send Close(portal) between Execute and Sync | [Draft PR #477](https://github.com/isoos/postgresql-dart/pull/477), commit `79560a928c6b9307e89fe52f368f68dfce01eb79` |
| Serverpod | Consume that exact driver in five dependency templates and generated manifests; cover query/transaction lifecycle | [Draft PR #5917](https://github.com/serverpod/serverpod/pull/5917), commit `c2c60aea863457a42d05c4c0c4d1252ffb48999f` |
| Offline sync | Pin the driver in the development/benchmark workspace and validate exported dependency resolution | [PR #200](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/200), dependency commit `4ec43bad28f81b6a729a97a93f02ec84f5cd3b70` |

PR #200 is appended using `gh stack` to GitHub stack #199: **#194 → #195 → #200**, with #194's existing base `perf/sync-core-integration` preserved. The earlier stack branches were not rewritten.

TCP_NODELAY removes TCP's small-write buffering delay; it can increase small-packet overhead. Inline portal cleanup removes a separate driver exchange inside transactions. The driver still waits for ReadyForQuery and cancellation-channel drainage. TLS, commit boundaries, row-lock lifetime, named prepared-statement lifetime, and the streaming sync protocol remain intact. Unix sockets do not receive a TCP option. No stack-trace suppression, pool-policy change, HTTP sync endpoint, or protocol fallback is included.

The Cloud candidate changes only the PostgreSQL dependency. All six SDK pins stay at `4f2a75ab967dccd56e88261a39203fc5e59d8e80`; the lock changes only `postgres`. The prepared application's source is byte-identical before/after generation. Existing benchmark-only diagnostics are identical in both deployments; they are from the retained capacity-investigation harness, above the same PR #195 package runtime. This is not a benchmark of upgrading Serverpod to its current main branch.

| Identity | Value |
| --- | --- |
| Baseline executable SHA-256 | `ab7d8f602fd96493b16e2d4a5c903beba597f08925731cc6375a6a281056565c` |
| Candidate executable SHA-256 | `e61d7523bf14fb3771ecaab9de26b98df2ad525b8bc7e9c2987cad615fae5ffc` |
| Candidate deployment | `2214d8c2-727d-4f50-a8d8-1ae5fdceb316` |
| Candidate build | `78879c6c-be61-4d12-96a6-3d3a463e7f94` |
| Dart | 3.13.7, native AOT, both deployments |

The uploaded archive's immutable Git ref, resolved lock, and Cloud build log all identify the reviewed driver. The final running executable is independently read through runtime diagnostics. Secrets and the six protected configuration files are unchanged; all six Cloud environment entries are unchanged.

## Workload and interpretation

These are incremental rounds on **already-established continuous streams**. A measurement begins before a local Person insert and ends when every peer's public ORM watch observes the exact expected values. Each user has two devices and alternates writers; each round carries one row with the full schema. Setup, warmup, and final convergence verification are outside the latency population. Exact server/replica journal convergence is checked without a repair sync.

| Streams / users | Exercise rounds | Period per user | Offered total rate | Workers |
| --- | ---: | ---: | ---: | ---: |
| 8 / 4 | 40 | 2 s | 2 rounds/s | 4 |
| 64 / 32 | 320 | 4 s | 8 rounds/s | 8 |

The same compiled client, startup concurrency of one, 45-second round deadline, PostgreSQL database location, pool of 100, and single podlet are used throughout. Persistent and console session logging are disabled at runtime. Cross-process commit hints are disabled. One user's detailed server traces are sampled; SQL metrics are sampled every 30 seconds. Configuration and actual cgroup CPU quota are checked after each resize.

The table uses raw successful exercise durations: arithmetic mean and median, and nearest-rank p95. Repeats are separate populations. “Kept up” is the client's offered-rate check, separate from exact convergence. A pass with “no” is not a capacity pass. The campaign ran on October 26 local time / October 26–27 UTC.

## Full latency distributions

All durations are milliseconds.

| Instance | Streams | Driver | n | Min | Median | Mean | p95 | Max | Kept up |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | :---: |
| XXLarge / 2 cores | 8 | Baseline | 40 | 365.1 | 453.7 | 465.7 | 560.4 | 590.3 | yes |
| XXLarge / 2 cores | 8 | Both changes | 40 | 318.3 | 348.1 | 348.5 | 375.5 | 418.7 | yes |
| XXLarge / 2 cores | 64 | Baseline | 320 | 376.8 | 487.8 | 497.0 | 622.8 | 693.8 | yes |
| XXLarge / 2 cores | 64 | Both changes | 320 | 309.7 | 345.8 | 356.9 | 435.2 | 530.9 | yes |
| XXLarge / 2 cores | 64 | Both changes repeat | 320 | 305.0 | 337.0 | 350.1 | 427.5 | 488.2 | yes |
| Medium / 0.25 core | 8 | Baseline | 40 | 540.4 | 651.7 | 654.7 | 739.7 | 765.7 | yes |
| Medium / 0.25 core | 8 | Both changes | 40 | 398.9 | 458.5 | 474.2 | 591.3 | 708.8 | yes |
| Medium / 0.25 core | 64 | Baseline | 320 | 977.2 | 6,991.9 | 6,989.4 | 9,177.4 | 13,909.5 | **no** |
| Medium / 0.25 core | 64 | Both changes | 320 | 507.6 | 5,527.8 | 5,754.4 | 7,379.5 | 18,751.5 | **no** |
| Medium / 0.25 core | 64 | Both changes repeat | 320 | 509.3 | 5,195.4 | 4,954.8 | 6,909.5 | 7,412.5 | **no** |
| Small / 0.10 core | 8 | Baseline | 0 | — | — | — | — | — | warmup failed |
| Small / 0.10 core | 8 | Both changes | 40 | 1,395.0 | 2,200.7 | 2,215.3 | 2,525.2 | 2,696.7 | **no** |

All **2,120 measured rounds** succeeded and converged. The baseline Small trial has no measured exercise rounds: warmup timed out and streams ended. Every trial, including that failure, drained to zero open streams and zero idle-in-transaction sessions.

The first Medium candidate has a worse maximum, **18.75 s versus 13.91 s** before. Its repeat maximum is 7.41 s. The lower averages do not justify claiming that overload tails are solved.

## Savings by matched comparison

Positive percentages mean lower latency, relative to the matching baseline. These are combined-change savings, not additive contributions of the two individual changes; this Cloud campaign does not separately toggle them.

| Candidate | Mean reduction | Median reduction | p95 reduction |
| --- | ---: | ---: | ---: |
| xxlarge-8 | 25.2% | 23.3% | 33.0% |
| xxlarge-64 | 28.2% | 29.1% | 30.1% |
| xxlarge-64r | 29.6% | 30.9% | 31.4% |
| medium-8 | 27.6% | 29.7% | 20.1% |
| medium-64 | 17.7% | 20.9% | 19.6% |
| medium-64r | 29.1% | 25.7% | 24.7% |

The initial isolation work justified these two changes independently. This campaign validates their final reviewed implementation together on Cloud. It does not combine the earlier local percentages with these Cloud percentages.

## Where the time goes

The following partitions the **mean of ten explicitly correlated rounds from one sampled user** in each run. Matching uses authored round/writer identity, request and batch IDs, and same-isolate monotonic timestamps. Every included partition is complete and nonnegative. This is not a decomposition of the full-population p95.

| Mean phase, ms | 2 cores baseline | 2 cores candidate | Medium baseline | Medium candidate |
| --- | ---: | ---: | ---: | ---: |
| Merge admission queue | 0.1 | 0.0 | 0.1 | 0.1 |
| Connection acquisition + BEGIN | 9.2 | 8.4 | 417.0 | 689.6 |
| Merge SQL: 10 statements | 144.5 | 40.4 | 3,815.2 | 2,502.8 |
| Peer capture SQL: 3 statements | 57.4 | 17.0 | 1,247.9 | 830.2 |
| COMMIT + release | 9.6 | 7.9 | 429.2 | 475.6 |
| Other server work, fan-out and scheduling | 31.4 | 14.9 | 434.5 | 643.4 |
| Client/transport residual | 259.4 | 279.4 | 294.1 | 315.0 |
| **Sampled total** | 511.6 | 368.0 | 6,637.9 | 5,456.7 |

At two cores, the sampled server path shrinks from **252.2 ms to 88.6 ms**, a **64.9% reduction**. The same 13 data statements shrink from **201.9 ms to 57.4 ms**, or **15.53 ms to 4.41 ms per call**. Merge calls average 14.45 → 4.04 ms; capture calls average 19.14 → 5.66 ms. BEGIN and COMMIT are outside those 13 counts. The origin device's echo capture and background work add SQL elsewhere on the server, so 13 is not a whole-server query count.

SQL spans include driver processing, network waits, and scheduling, not just PostgreSQL execution. Connection acquisition includes BEGIN; commit includes connection release. The residual includes local write/apply work, both client/server network directions, and uninstrumented boundaries. **The 279 ms candidate residual is not a measured pure network RTT.** Database location is fixed in this comparison; these results do not isolate its contribution from driver costs.

Medium still spends several seconds in database-call and transaction-boundary spans. Its sampled merge admission queue is below 0.1 ms, so this does not show different users being serialized by the merge queue. They share CPU and database resources. The healthy two-core run samples about 0.24 cores of process CPU, versus 0.36 before; the repeat samples 0.22 cores. That is already close to Medium's entire 0.25-core budget before allowing for bursts and observation uncertainty. CPU/scheduling pressure remains the leading explanation, supported by the prior local quota controls, rather than a new lock contention problem. Cloud exposes the configured quota but not usable throttled-period counters, so no measured Cloud throttle percentage is claimed.

Ten trials have valid correlated phase evidence. Baseline Medium/8 lost final stream traces before instance replacement, so its latency distribution is retained but no phase breakdown is invented. Baseline XXLarge/8 final traces were recovered from the same live instance after teardown. The collector was then changed only to drain bounded final traces after measurement and cleanup; observation during exercise is unchanged.

## Client and transport split — follow-up on October 27 UTC

Client frame timestamps now divide the earlier residual into local writes, upload preparation, combined transport and boundary overhead, and peer application/observation. The original tables and findings above retain their original populations. The following are **fresh measurements of the same deployed server executable**, with no server redeploy or production code change; differences from the preceding runs are not claimed as additional optimization savings.

The workload is unchanged: established continuous streams, two devices per user, one Person row per round, 10 rounds per user, 2 rounds/s at 8 streams and 8 rounds/s at 64 streams. The new client uses Dart 3.12.2, matching the previous client. Its source is the retained capacity harness at `7b21811736298ee53137168b7073926766f3fb8f` plus benchmark-only observations. The six SDK pins, server executable, database location, pool, logging settings, and disabled commit hints are unchanged. Only user index 0 records client frame boundaries. The same new binary is used for controls with that observation disabled.

The expanded table partitions **10 correlated rounds from one user in each run**, in milliseconds. It is a mean phase breakdown, not a decomposition of population p95. The bold client rows replace the earlier combined residual; rounding can slightly change displayed sums.

| Mean phase, ms | Medium, 8 streams | 2 cores, 64 streams | Medium, 64 streams |
| --- | ---: | ---: | ---: |
| Merge admission queue | <0.1 | <0.1 | <0.1 |
| Connection acquisition + BEGIN | 29.7 | 7.2 | 454.4 |
| Merge SQL: 10 statements | 94.7 | 36.6 | 2,321.2 |
| Peer download SQL: 3 statements | 51.4 | 15.9 | 767.4 |
| COMMIT + connection release | 40.6 | 7.7 | 573.0 |
| Other server work, fan-out and scheduling | 51.1 | 14.2 | 488.4 |
| **Local write transaction** | 3.7 | 3.9 | 4.6 |
| **Client upload preparation** | 1.6 | 1.7 | 1.9 |
| **Upload + download transport and boundary overhead** | 246.2 | 258.5 | 305.7 |
| **Peer apply + public ORM observation** | 4.7 | 4.6 | 4.7 |
| **Total sampled latency** | 523.7 | 350.2 | 4,921.4 |

The two-core repeat has a sampled total of **356.2 ms**: **89.8 ms** in the server path, **10.4 ms** in the three measured client-work phases, and **256.1 ms** in combined transport/boundary overhead. The full-population means are lower than these one-user sample means; both populations are retained below.

| Instance / streams | Client timing | n | Min | Median | Mean | p95 | Max | Kept up |
| --- | :---: | ---: | ---: | ---: | ---: | ---: | ---: | :---: |
| Medium / 8 | on | 40 | 455.8 | 481.3 | 497.5 | 558.7 | 608.2 | yes |
| Medium / 8 | off | 40 | 445.6 | 475.0 | 502.3 | 553.9 | 788.2 | yes |
| Medium / 64 | on | 320 | 534.0 | 5,314.6 | 5,142.6 | 6,826.2 | 9,598.6 | **no** |
| 2 cores / 64 | off | 320 | 303.3 | 332.3 | 333.9 | 353.7 | 432.0 | yes |
| 2 cores / 64 | on | 320 | 302.2 | 330.5 | 333.3 | 354.0 | 524.6 | yes |
| 2 cores / 64 repeat | on | 320 | 303.6 | 331.2 | 334.0 | 356.6 | 456.7 | yes |

Additional findings, following those above:

1. **Client processing accounts for about 10 ms on the healthy path.** The two-core sample spends 3.9 ms in the local write, 1.7 ms preparing the upload, and 4.6 ms applying the peer download and observing exact values through the public ORM. The repeat is similar. The selected user's Medium/8 client work totals 9.9 ms. These measurements do not show a large client-side polling or protocol wait on established streams. Stream startup and syncOnce are outside this workload.
2. **The remaining healthy delay closely matches the client-to-Cloud transport round trip.** A separate, database-free Serverpod ping/pong control on one established TLS WebSocket averages **255.6 ms**, with median 255.4 ms, p95 257.3 ms, min 254.6 ms and max 257.3 ms over 20 pings, excluding two warmup pings and connection setup. That is close to the sync transport/boundary residual of **258.5 ms**, or **256.1 ms on repeat**. Those residuals are 73.8% and 71.9% of the corresponding sampled totals. This supports network/transport as the main remaining component on the healthy two-core path. Ping also includes transport dispatch, so these figures do not isolate propagation time or each network direction.
3. **A closer database cannot remove the client-to-server portion.** On the two-core sample, all 13 measured SQL calls total 52.4 ms and transaction acquisition/commit/release another 14.8 ms. SQL includes driver, database network and scheduling. The much larger 258.5 ms client/transport portion lies outside that measured server work. The next location comparison should distinguish client-to-server placement from server-to-database placement.
4. **Medium/64 remains constrained in the server path.** The sampled server work takes 4,604.5 ms, about 93.6% of the 4,921.4 ms total. Client processing still totals only 11.2 ms. The 305.7 ms transport/boundary residual can include extra scheduling before merge entry or after yield under CPU pressure. It does not establish that the network became slower. Admission queue time remains below 0.1 ms; this still does not indicate cross-user serialization in that queue.
5. **The timing observations show no material population-wide slowdown in these short controls.** Medium/8 averages 497.5 ms with client timing and 502.3 ms without it. Two cores/64 averages 333.3 ms with timing, 334.0 ms on repeat, and 333.9 ms without it. These controls support the measurements' usefulness; they do not prove zero observer overhead or a new performance gain.

Correlation uses authored round/writer identity and the numbered upload/download batches. All client boundaries share the round's `CLOCK_MONOTONIC_RAW` clock. The transport residual is the client's upload-boundary-to-download-boundary duration minus the server's merge-entry-to-download-yield duration. Independent machine timestamps are never aligned. That residual includes both network directions, SDK encoding/decoding and delivery, and short server boundaries outside the measured span. Peer apply time also includes the public ORM observation query. Negative partitions and missing/ambiguous boundaries are rejected, never clamped or guessed.

All **1,360 additional measured rounds** converged, and all six trials drained streams and idle transactions. All 60 correlated server partitions are valid; 40 have the new client split. The benchmark observations passed 28 focused Dart checks, including real PostgreSQL/SQLite transport correlation for alternating writers, plus five Python partition checks and static analysis. One initial test command used the repository root with benchmark-relative paths and failed to locate its test files; the corrected command runs from `benchmark/`. The deployed server executable is unchanged and the final Cloud size is **Small**, with six protected configuration files unchanged.

Evidence: [results](client-delay-split/results.json), [raw round durations](client-delay-split/rounds.json), [correlated phases and client boundaries](client-delay-split/profiles.json), [WebSocket ping samples](client-delay-split/ping.json), and [provenance](client-delay-split/provenance.json). Run `rounds` with `--client-profile-user 0 --no-sync-diagnostics` and configure server sampling for the same user to reproduce the split with `tool/profile_rounds.py`. The new client timing option does not enable full per-SQL client traces.

## Correctness and validation

- Driver: 467 tests pass in UTC, including real PostgreSQL TLS/Unix transports, wire ordering, large results, row locks, cancellation, rollback/reuse, errors, replication, and supported COPY behavior. A date/time expectation failed under São Paulo time on unchanged upstream as well; the controlled full run uses UTC. No support was added for previously unsupported COPY streaming directions.
- Serverpod: 131 targeted PostgreSQL transaction, unsafe-query, and row-lock tests pass against the frozen driver. All 14 new lifecycle assertions also pass after resolving the actual published Git commit. Ordinary uncaught timeout recovery remains covered separately from same-backend reuse after a handled timeout.
- Offline sync: 153 visible integration tests pass across 14 suites, with a complete successful runner result; 246 additional events are hidden setup/teardown. Server package and focused-test analysis pass. An initial local command failed before connecting because a redundant global database-data-path environment variable produced incomplete configuration; removing that variable lets the existing tests use their isolated databases.
- Independent Orca review cleared the exact driver, Serverpod, and initial offline integration commits. Independent probes compare base/head lifecycle behavior and all 37 resolved driver runtime files. The later export assertion and report changes are coordinator-owned follow-ups.

The first full offline CI run exposed an outdated export assertion expecting six Git dependencies. It is updated to require PostgreSQL plus the six SDK packages; all existing immutable-ref, URL, path, and resolved-lock assertions remain. All 15 real preparation/generation tests and focused analysis pass after the correction. The original full CI failure is retained, and full CI is rerunning on the follow-up commit. The dependency check is not weakened.

Serverpod's broad CI runtime/build tests pass, including the CLI job after a retained temporary-directory-cleanup failure and rerun. Four analysis configurations flag Git dependencies in publishable packages. That is an explicit **draft release gate**: replace the five temporary pins with a real upstream hosted release and regenerate before merge/publication. The analyzer rule is not suppressed. The title capitalization check is fixed. Driver upstream CI has not reported checks. See the PRs for current hosted CI status; local validation and CI are separate evidence.

## Tradeoffs and remaining work

The optimizations retain TLS and transaction serialization. TCP_NODELAY can send more small packets; inline cleanup reduces exchanges and runtime work. Named statement disposal stays separate. A query already queued before an explicit COMMIT no longer receives the old spurious late-cleanup error after its data committed; new queries on a closed transaction are still rejected. The driver tests and independent base/head probes cover that distinction.

The development workspace override does not propagate to downstream applications consuming released offline-sync packages. Adoption there depends on Serverpod and the hosted driver release. No nonexistent release version is assumed.

These are short runs with one-row writes and 8 or 64 streams, not proof of capacity for thousands of actively writing devices or a long memory soak. Medium and Small still miss their offered rates in the heavy cases. Further work should measure remaining secure-I/O/runtime CPU and idle/background work under low quotas, while separately testing closer client and database placement. Pool admission/creation behavior is a separate opportunity; it was not changed here. Keep stream count, active write rate, and instance budget separate when setting capacity targets.

The final Cloud state is one **Small** podlet, the new driver deployed, original database/full schema/pool 100, logging and commit hints disabled, unchanged secrets/configuration, and clean streams/transactions. Owned local PostgreSQL test processes are stopped. No merge or package publication was performed.

## Evidence

Sanitized [results](postgres-wire-cloud/results.json), [raw round durations](postgres-wire-cloud/rounds.json), [correlated phase samples](postgres-wire-cloud/profiles.json), and [source/deployment provenance](postgres-wire-cloud/provenance.json) accompany this report. Raw logs, exact source hashes, private configuration snapshots, build archive, orchestration reports, and executable receipts remain in the local campaign directory `/tmp/driver-wire-rollout-20261026`; credentials and configuration contents are excluded from the committed artifacts.
