# Native TLS and PostgreSQL pipelining benchmark — 2026-10-28

This experiment tests two revisions of the requested `cloud-test` PostgreSQL
driver with native TLS and `postgresPipelineDepth = 8`, including an Offline Sync change that
submits independent merge reads concurrently. It continues
[the native TLS comparison](sync-native-tls-benchmark-2026-10-28.md).

The final source uses `9c4cbc007327444944bef83f20d0e9e48e8ec84e`, obtained by
rerunning `dart pub upgrade postgres postgres_tls serverpod_database` after the
branch update. Variants ending in `-v2` use that revision. Other `pipeline*`
variants use `3a05c58697454816f386017f9c9ad89191a08929`; `matched-native` is the
previous native TLS control. These populations are kept separate.

## Findings

The updated driver pipelines queries correctly in the exercised cases, and the
Offline Sync change exposes two independent query chains without removing the
locks that serialize merges in the same space.

On two cores with 64 streams, depth eight reduced the observed average from
332.0 to 307.9 ms (7.3%) and p95 from 358.8 to 332.2 ms (7.4%) versus depth one
with the same concurrent merge code. In the ten traced rounds, merge SQL wall
time fell from 43.4 to 29.1 ms; total server path fell from 96.1 to 67.4 ms.
This is one comparison pair, not a proven universal speedup. The overall mean
and the sampled timing split describe different populations.

Medium does not establish a reliable improvement. The same updated depth-eight
process averaged 3107.2 ms in one 64-stream run and 941.8 ms in the repeat.
The first missed the offered rate; the repeat kept pace. At eight streams it
averaged 388.3 ms, compared with 394.1 ms for the earlier native TLS control,
while p95 was higher (588.7 versus 492.2 ms). Keep the concurrency change as an
experiment; these results do not justify claiming that pipelining resolves
Medium's capacity or tail-latency problem.

All 15 runs converged with zero retries and no streams or idle transactions
left after cleanup. Three runs missed the offered rate, as listed below.
This is correctness evidence and limited performance evidence, not production
approval of the experimental driver's cancellation semantics.

## Controls and scope

All runs use established continuous streams, one Person insert per round,
two devices per user, alternating writers, ten exercise rounds per user,
and the full schema. The measured latency is from the local write starting
to every peer applying the exact expected row. Startup is outside that metric.
Eight streams means four users and 40 rounds; 64 means 32 users and 320 rounds.
The target rate is two rounds/s at eight streams and eight rounds/s at 64.

The server uses Dart 3.13.7 and native TLS in every comparison. The same immutable
Dart 3.12.2 client is used throughout. The remote database, pool limit of 100,
one instance, disabled persistent/console session logging, and disabled commit
hints are unchanged. Medium's measured CPU quota is 0.25 cores; XXL's is two
cores. Server diagnostics sample only user zero, ten rounds per run.

The previous native-driver control includes its earlier single-exchange and
synchronous built-in codec optimizations. The new driver's depth-one control
isolates effects of its changed scheduling from useful query pipelining.
The first revision has a two-by-two depth/scheduling comparison. The upgraded
revision compares depth one and eight with concurrent reads on both Medium and
XXL. Diagnostic code is identical across variants. These are serial Cloud runs,
not a randomized capacity study; repeats and the full range remain visible.

## Incremental round latency

Milliseconds; the median averages the middle pair and p95 uses nearest rank.
The repeat is a separate fresh run, not a pooled or selected subset.

| Variant | CPU quota | Streams | n | Min | Median | Average | p95 | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| matched-native | 0.25 | 8 | 40 | 328.2 | 369.6 | 394.1 | 492.2 | 802.3 |
| matched-native | 0.25 | 64 | 320 | 350.4 | 980.8 | 973.2 | 1211.5 | 1469.9 |
| pipeline1-sequential | 0.25 | 64 | 320 | 363.4 | 895.9 | 979.9 | 1497.9 | 1746.8 |
| pipeline8-sequential | 0.25 | 64 | 320 | 379.6 | 2701.9 | 2960.9 | 4913.8 | 8910.3 |
| pipeline1-concurrent | 0.25 | 64 | 320 | 461.7 | 1240.4 | 1325.8 | 1997.4 | 2129.6 |
| pipeline8-concurrent | 0.25 | 8 | 40 | 285.3 | 312.3 | 330.4 | 388.8 | 470.5 |
| pipeline8-concurrent | 0.25 | 64 | 320 | 312.5 | 880.6 | 892.1 | 1180.6 | 1491.6 |
| pipeline8-concurrent repeat | 0.25 | 64 | 320 | 323.0 | 1000.8 | 1130.4 | 2037.5 | 2314.4 |
| pipeline8-concurrent | 2 | 64 | 320 | 292.5 | 312.9 | 317.8 | 355.2 | 544.2 |
| pipeline1-concurrent-v2 | 0.25 | 64 | 320 | 481.7 | 2467.6 | 2625.9 | 4164.5 | 4520.7 |
| pipeline8-concurrent-v2 | 0.25 | 8 | 40 | 306.2 | 367.2 | 388.3 | 588.7 | 685.0 |
| pipeline8-concurrent-v2 | 0.25 | 64 | 320 | 435.5 | 3111.2 | 3107.2 | 4948.0 | 9205.2 |
| pipeline8-concurrent-v2 repeat | 0.25 | 64 | 320 | 335.0 | 953.1 | 941.8 | 1191.3 | 1432.1 |
| pipeline8-concurrent-v2 | 2 | 64 | 320 | 285.1 | 307.1 | 307.9 | 332.2 | 430.2 |
| pipeline1-concurrent-v2 | 2 | 64 | 320 | 307.6 | 331.6 | 332.0 | 358.8 | 449.0 |

## Sampled server path

These averages describe the ten traced rounds, not the full latency population.
SQL wall time is the union of query intervals, including driver/network/scheduling
waits. It is not PostgreSQL execution time. Summing durations of concurrent calls
would double-count their overlap. BEGIN/COMMIT are counted separately.

| Run | Sampled round | Server path | Merge SQL wall | Download SQL wall | BEGIN / connection | Commit / release | Other server | Client / transport residual | Merge / download statements | Peak concurrent merge calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| matched-native-medium-8 | 440.4 | 191.2 | 84.2 | 33.9 | 11.3 | 9.3 | 52.5 | 249.2 | 10 / 3 | 1 |
| matched-native-medium-64 | 929.1 | 643.8 | 332.1 | 112.1 | 46.2 | 77.2 | 76.2 | 285.3 | 10 / 3 | 1 |
| pipeline1-sequential-medium-64 | 934.7 | 640.7 | 296.1 | 133.9 | 52.3 | 45.9 | 112.5 | 294.0 | 10 / 3 | 1 |
| pipeline8-sequential-medium-64 | 2731.6 | 2416.8 | 1184.6 | 398.7 | 279.0 | 234.4 | 320.1 | 314.8 | 10 / 3 | 1 |
| pipeline1-concurrent-medium-64 | 1253.7 | 964.5 | 494.2 | 177.9 | 55.2 | 98.9 | 138.3 | 289.2 | 10 / 3 | 2 |
| pipeline8-concurrent-medium-8 | 343.6 | 101.7 | 32.9 | 28.0 | 12.1 | 7.3 | 21.4 | 241.9 | 10 / 3 | 2 |
| pipeline8-concurrent-medium-64 | 855.6 | 597.6 | 272.7 | 127.9 | 33.8 | 77.2 | 86.0 | 258.0 | 10 / 3 | 2 |
| pipeline8-concurrent-medium-64-repeat | 1132.6 | 813.5 | 363.3 | 159.7 | 86.8 | 99.6 | 104.0 | 319.1 | 10 / 3 | 2 |
| pipeline8-concurrent-xxlarge-64 | 316.0 | 75.7 | 31.7 | 16.2 | 6.4 | 7.3 | 14.2 | 240.3 | 10 / 3 | 2 |
| pipeline1-concurrent-v2-medium-64 | 2524.6 | 2189.1 | 1145.1 | 357.8 | 182.5 | 213.3 | 290.3 | 335.5 | 10 / 3 | 2 |
| pipeline8-concurrent-v2-medium-8 | 432.7 | 160.3 | 48.7 | 36.8 | 16.2 | 19.1 | 39.6 | 272.4 | 10 / 3 | 2 |
| pipeline8-concurrent-v2-medium-64 | 3076.5 | 2735.9 | 1263.3 | 470.4 | 325.3 | 327.2 | 349.7 | 340.6 | 10 / 3 | 2 |
| pipeline8-concurrent-v2-medium-64-repeat | 882.0 | 599.0 | 263.9 | 110.7 | 52.5 | 96.1 | 75.8 | 283.0 | 10 / 3 | 2 |
| pipeline8-concurrent-v2-xxlarge-64 | 321.7 | 67.4 | 29.1 | 13.1 | 6.4 | 7.0 | 11.7 | 254.3 | 10 / 3 | 2 |
| pipeline1-concurrent-v2-xxlarge-64 | 337.3 | 96.1 | 43.4 | 14.8 | 8.2 | 8.3 | 21.3 | 241.2 | 10 / 3 | 2 |

The observed concurrency is the number of application SQL calls outstanding.
A depth-one driver can queue two application calls while sending only one.
The native local wire test separately verifies eight sends before the first
reply at depth eight, and alternating sends/replies at depth one.

## CPU, memory and cleanup

CPU is estimated from remote process counters over the sampled exercise window,
in cores. Sampling and accounting limits mean values near or slightly above the
quota should be treated as approximate. RSS is the median during that window.
Every run uses the same sampling method.

| Run | Exercise CPU | Median RSS MiB | Kept pace | Retries | Clean after run |
| --- | ---: | ---: | --- | ---: | --- |
| matched-native-medium-8 | 0.070 | 90.2 | True | 0 | True |
| matched-native-medium-64 | 0.251 | 110.7 | True | 0 | True |
| pipeline1-sequential-medium-64 | 0.259 | 109.8 | True | 0 | True |
| pipeline8-sequential-medium-64 | 0.269 | 103.2 | False | 0 | True |
| pipeline1-concurrent-medium-64 | 0.240 | 103.9 | True | 0 | True |
| pipeline8-concurrent-medium-8 | 0.064 | 81.0 | True | 0 | True |
| pipeline8-concurrent-medium-64 | 0.237 | 110.4 | True | 0 | True |
| pipeline8-concurrent-medium-64-repeat | 0.240 | 142.8 | True | 0 | True |
| pipeline8-concurrent-xxlarge-64 | 0.183 | 109.2 | True | 0 | True |
| pipeline1-concurrent-v2-medium-64 | 0.267 | 104.1 | False | 0 | True |
| pipeline8-concurrent-v2-medium-8 | 0.073 | 104.5 | True | 0 | True |
| pipeline8-concurrent-v2-medium-64 | 0.257 | 126.8 | False | 0 | True |
| pipeline8-concurrent-v2-medium-64-repeat | 0.228 | 162.1 | True | 0 | True |
| pipeline8-concurrent-v2-xxlarge-64 | 0.097 | 110.3 | True | 0 | True |
| pipeline1-concurrent-v2-xxlarge-64 | 0.180 | 110.3 | True | 0 | True |

## Medium variation and database latency

The two updated depth-eight Medium runs used the same executable and process,
but averaged 3107.2 ms and 941.8 ms. In the slow run, the per-round cohort average
grew from 976.0 ms at round zero to 4823.0 ms at round eight. This was not simply
a slow initial sync; every measured stream had already completed bidirectional
warmup. The repeat's cohort averages stayed between 666.1 and 1087.4 ms.

Database session samples grew from 34 to 41 during the slow run, then stayed at
41 for the repeat. These are database-wide session counts, not a precise count
of connections owned by this server's pool. Up to 25 sessions were sampled idle
in transaction while the slow workload was active; the repeat sampled seven.
There were no lock waits in these snapshots, and no idle transactions remained
after either run. Connection growth, scheduling and warm process state are
possible contributors; these observations do not isolate the cause. CPU quota
was 0.25 cores, and throttle counters were unavailable in this cgroup view.

A quiet probe, taken between workloads on the updated two-core instance, measured
16 SELECT 1 calls on one warmed TLS connection: median
3.024 ms, p95 3.372 ms.
PostgreSQL's EXPLAIN ANALYZE execution time was 0.004 ms. This confirms a
low-millisecond unloaded driver/database exchange floor at that time; it does
not isolate physical network time from driver scheduling. The large loaded
Medium SQL-call delays cannot be treated as the database's basic network RTT.

## Implementation and safety

The existing clock and space locks are acquired before starting both read
chains. One chain finds source nodes and their space participation; the other
loads conflict metadata and checks the projection proof. Neither needs the
other chain's result. Both must finish before domain writes or transaction
completion.
Source-node creation remains ordered within its lookup chain; conflict reads
do not depend on those newly created nodes.
`Future.wait` uses its default non-eager error behavior, so a failed read cannot
leave the other chain running past rollback. SQLite keeps sequential scheduling.
Writes, dependent lookups, projection application, progress persistence, lock
order and commit boundaries are unchanged. No extra connections are allocated
by the merge change. PostgreSQL executes statements on each backend in order;
pipelining lets requests travel without waiting for every prior reply.

The hot path still has dependent operations and exposes at most two concurrent
calls in the changed phase. Depth eight is a ceiling, not eight useful parallel
operations for this workload. These runs cover incremental continuous sync;
startup, syncOnce and heavier/conflicting workloads have separate behavior.

The refreshed driver changed cancellation semantics. Revision `3a05c586` skipped
soft cancellation when another statement was already in flight. Revision
`9c4cbc0` attempts it for the current query, holds new unsent statements until
cancellation completes, and rechecks the target after opening the side channel.
The native test now requires the slow query to time out and the following query
to succeed, matching the new upstream contract. It passed in JIT and AOT.

A race remains possible with an already-sent following statement if the original
query finishes just as cancellation arrives; the upstream source explicitly
acknowledges this. The tests do not prove every cancellation/network interleaving.
No upstream runtime patch was applied in this experiment.

## Validation and reproducibility

On the upgraded `9c4cbc0` source:

- 23 native TLS/driver checks passed in JIT and again in standalone AOT; both
  runners exited successfully. They cover wire depth, response association,
  middle-statement failure, transaction rollback, connection reuse and timeout.
- 63 existing PostgreSQL contracts passed at depth eight, including admission,
  cancellation cleanup, insert/domain batching and multi-space lock ordering.
- 32 diagnostics/export checks passed, including actual PostgreSQL/SQLite sync,
  convergence, overlapping SQL, cancellation cleanup and deployment export.
- Touched Dart sources analyzed without issues. All 37 vendored runtime files
  and the license exactly match upstream. The export verifier checks 233
  production Dart files plus pinned dependencies.

The old timeout-success expectation failed on the updated driver as expected;
it was changed to the new explicit timeout contract, retaining the following
query success assertion. One AOT invocation from the evidence directory failed
because the test proxy path is relative to `benchmark/`; rerunning from the
required directory passed all 23 checks. Neither failed setup is treated as a
successful run.

The first `3a05c586` campaign separately passed 23 native checks in JIT/AOT,
63 PostgreSQL contracts, 43 additional sync/metadata/projection checks, and the
export/diagnostics checks. A fixed-port fixture collision was resolved by running
its seven checks alone, without changing assertions.

Upstream force-pushed `cloud-test` during the initial campaign. A clean Cloud
build could not fetch `3a05c586`, so the initial controls froze the exact runtime
files rather than silently upgrading mid-comparison. At the user's request,
`dart pub upgrade` was then rerun against the moving refs, resolving `9c4cbc0`.
The refreshed snapshot was frozen in the same way. The TLS connector stayed at
`22067026c50da3447931ba71ad13fc95f230d5e8` and Serverpod's database adapter at
`242ee66cc4b3176ac5c1bc3ed2b3c40cbd996d29`; other SDK overrides and the dependency
lockfile are unchanged. The initial source is retained at `d92ce779`.

The branch is `perf-postgres-pipeline`, based on `perf-postgres-native-tls`
commit `e8fd7dfc`. See [the build and test instructions](../benchmark/NATIVE_TLS.md)
for exact dependency commits and commands. Safe aggregate data, executable/client
hashes and timing splits are in
[`pipeline-results.json`](../benchmark/native_tls/pipeline-results.json).
Private raw receipts, sampled traces, run outputs and deployment archives remain
under `/tmp/sync-postgres-pipeline-20261028`; deployment archives contain private
configuration and are excluded from Git.

## Deployment cleanup

The original prepared deployment at `/tmp/offline-sync-cloud-ready-v2` was
restored on one Small instance. Runtime reports its original executable SHA-256
`e61d7523bf14fb3771ecaab9de26b98df2ad525b8bc7e9c2987cad615fae5ffc` and
a 0.1-core quota. Final checks found zero open streams and zero idle transactions.
All six protected configuration files, including the private credentials, match
their original hashes. The original `dst-hunt` worktree was not changed.
