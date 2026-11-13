# Sync performance handoff — 2026-10-19

> Historical evidence through 19 October 2026. No tests, benchmarks or
> deployments were rerun for this review split. Deployment states, source
> commits and configuration below describe those experiments. Private paths
> and deployment identities use stable aliases; `evidence://` references
> identify original artifacts that are not bundled in this repository.
> Build and setup references concern the companion code reviews linked in the
> [evidence index](../benchmark/results/README.md). Historical patch descriptions
> are not installation instructions.

Proposals 2, 3, 4 and 5 are complete as attempts 23–26. Proposal 1, the PostgreSQL portal-close driver experiment, remains deferred. The [follow-up report](sync-optimization-followup-2026-10-19.md) and [ledger](../benchmark/results/2026-10-16-sync-optimization.json) contain distributions, rejected attempts, costs and raw artifact pointers. Keep one streaming protocol and the change → correctness validation → measurement → record → commit process.

## Result at the end of the experiments

- Attempt 23 repaired explicit frame correlation and the client raw elapsed clock. The real 0.25-core local control did not reproduce Cloud Medium's slowdown; no CPU or logging speedup is credited. Medium still misses eight active rounds/s across 64 streams.
- Attempt 24's outbound preparation candidate saved 5.95 ms locally but failed both Cloud candidate runs. It is reverted. Preserve `reference/resolved-outbound-grants` at core `1d22388` and companion `b515eff`; investigate the pool-acquisition failure before reconsidering it.
- Attempt 25 keeps per-origin checkpoint maxima after sending instead of retaining whole payloads until ACK. Held heap fell by 8.23 and 16.57 MiB for 1000 and 2000 8-KiB rows. The Cloud mean increased by 10.57 ms in the observed pair, so this is a memory improvement without a credited latency gain. Complete capture and inbound buffering remain proportional to backlog bytes.
- Attempt 26 adds an optional owned PostgreSQL hint transport. Two separate Cloud pods at two cores each were verified before timing. Across 40 rounds per arm, mean fell from 1058.76 to 457.24 ms; median from 1078.96 to 450.23 ms; p95 from 1579.65 to 535.20 ms. The dropped-hint control still converged through durable polling. Both arms are profiled two-device mechanism comparisons, not large-scale capacity results. [Transport setup and safety](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/commit-hints.md) documents the dedicated connection and direct-endpoint requirement.

Every eligible attempt-26 run met its offered schedule, verified the full server/replica journal without repair syncs, and drained to zero streams and idle transactions. Local transport tests cover forced PostgreSQL listener termination/reconnection, malformed messages and shutdown. Transaction tests cover post-commit publication, rollback and failed publishing; recovery tests cover missed hints and revocation. Full CI was not run.

## Historical deployment and artifacts

Cloud is ready on **one Small pod**, actual **0.1 cores**, configured **256 MiB**, zero streams and zero idle transactions. Its executable is `1d54b3ecea288e448162b26757c2787dc608a6b811988d9dc47ea76e1b844f7d`. The latest build/upload identity is in `evidence://sync-26-commit-hints-deploy-20261019T022536Z/live-receipt.json`; that receipt describes the earlier two-pod measurement topology. The authoritative capacity receipt at that time is `evidence://sync-next-20261019T005150Z/final-small-26-verification.json`.

`BENCHMARK_COMMIT_HINTS=off` avoids the extra listener on this single pod; the implementation remains deployed and can be enabled for later multi-pod tests. Persistent and console session logging remain disabled by the benchmark override. Secrets and server configuration files are unchanged. The prepared server package pubspec has only the new direct PostgreSQL dependency added. Small received readiness and cleanup checks only.

The source workspaces remain `${CORE_CHECKOUT}` (`fix/sync-merge-admission`) and `${BENCHMARK_CHECKOUT}` (`fix/deployed-sync-benchmark`). Deployment remains `${PREPARED_WORKSPACE}/benchmark`. The experimental branches were unpublished at that time. All owned local servers, PostgreSQL, probes and CPU scopes are stopped; cleanup is recorded in `cross-local-cleanup.json`.

Evidence root: `evidence://sync-next-20261019T005150Z`. `cross-runs/` retains every placement attempt, raw events, full replica verification, server diagnostics and receipts. `attempt26-summary.json` contains the pooled tables. The cross-process native client SHA is `6565e4dc9f0a940fc46fcc11bcc523c4ecbcb7dcef0573363b101168c2c09a63`. The reusable companion controller is `benchmark/tool/cross_process_rounds.py`, with `benchmark/bin/cross_rounds.dart`; its secret comes from the environment. The retained-batch heap probe and its controller also live in `benchmark/tool/`.

## Continue from here

1. Investigate Medium's pool-acquisition/throughput behavior with fixed source, real quota, explicit frame IDs and the raw client clock. SQL timing includes driver/network/scheduling; current evidence does not establish database geography as the main cause.
2. Measure notification overhead and throughput with more active users on multiple pods. Keep a no-transport control distinct from the delivered-versus-dropped comparison. Preserve placement checks, failure recovery, exact journals and cleanup.
3. Measure peak memory versus backlog bytes before designing bounded capture spooling or backpressure; preserve complete snapshot enumeration and per-origin ACK checkpoints.
4. Remeasure fresh syncOnce and cover conflicts and reconnect bursts. Do not revive HTTP sync or add protocol compatibility handling. Keep the driver experiment deferred unless the user resumes it.

## Historical handoff through attempt 22

The material below is the earlier 2026-10-18 record. Its deployment identities, unresolved timing-correlation status and unimplemented cross-pod observations are historical; the later experiment results are above.

Attempts 17–22 are complete. Sampled profiling, longer insert controls, same-machine database-delay controls, shared projection rebuilds, batched authored updates and final Medium capacity are recorded below. The retained runtime changes are deployed, all local services are stopped, and Cloud is restored to one Small instance. The production capacity goal remains open: the final Medium server does not sustain eight active one-row rounds/s across 64 streams. Continue the change → measure → record → commit process; retain failed runs and attribution limits. The single streaming protocol is described in [streaming-sync-protocol.md](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/streaming-sync-protocol.md), and [the optimization ledger](../benchmark/results/2026-10-16-sync-optimization.json) retains every attempt.

The largest new improvement is the 50-row update: on the two-core instance its mean fell from 770.7 to 545.7 ms, median from 763.2 to 542.8 ms and p95 from 852.6 to 651.4 ms. Ten-row updates improved by 67.3 ms mean. Same-machine controls demonstrate 128.3 ms of additional latency from delayed database responses, but do not establish database geography as most of the Cloud delay. The earlier insert penalty did not reproduce in longer B/A/A/B controls. No insert speed saving is credited.

The [consolidated benchmark report](sync-benchmark-results-2026-10-18.md) collects the latest min/mean/median/p95/max tables, capacity limits and proposed next experiments. Proposed savings are kept separate from measured results.

### Historical source and deployment

| Attempt | Core commit | Benchmark commit |
| --- | --- | --- |
| 09: remove SDK pre-open ping | `86d19f0` | `8999fe0` |
| 10: defer capture during a complete finite upload | `5b4b1be` | `e48c6e0` |
| 11: announce finite readiness with the prepared upload | `de35239` | `aad1caf` |
| 12: remember locally announced recovery revisions | `3f120acbd5efdbcc3205097d510efe22fee3f6f6` | `0c0123f5f57c06cfddf10b9285b956628e1a9eef` |
| 13: reject joined source lookup; retain regression coverage | `001f23d` | `89d20b6` |
| 14: consolidate outbound metadata | `11e7eff` | `058a128` |
| 15: group PostgreSQL progress writes | `381a40e` | `2a3d10d` |
| 16: batch outbound update payloads | `3f871b26f5bde63f380acabee8ae04233963ce0f` | `f3b539915a722f5efd5dff20b970c93e22634fc2` |
| 17: selective profiling and read-only CTE plans | `f69a78f` | `daf805a` |
| 18: longer insert controls | `eb62e70` | `39e4fcb` |
| 19: same-machine and database-delay controls | `9432c9b` | `81a07ad` |
| 20: shared projection rebuild lifetime | `cbb69d5` | `d650951` |
| 21: batch authored domain updates | `d9beeb3` | `eb92811` |
| 22: final Medium measurements and bounded benchmark warmup | This handoff commit | This harness/handoff commit |

- Core: `${CORE_CHECKOUT}`, branch `fix/sync-merge-admission`.
- Companion: `${BENCHMARK_CHECKOUT}`, branch `fix/deployed-sync-benchmark`. Those experimental commits were local at that time.
- Project: `benchmark-deployment`; API: `https://benchmark-target-7ae5d9ccf154.invalid/`.
- Prepared workspace: `${PREPARED_WORKSPACE}`; deploy from `benchmark/`. All 19 protected config/secret files retain their hashes; all 193 runtime files match the final deployment manifest.
- **One Small instance, 256 MB, actual CPU quota 0.1 cores**, verified at `2026-10-18T20:04:35.781458+00:00`. Scale-down checks cover readiness, identity and cleanup; Small capacity was not benchmarked.
- Final upload: `uploadId-3615880cbcd5`; build: `buildId-759bb38a8c42`.
- Executable SHA-256: `ce2bdf2a4983441a2e4364127d123510a9282b0e648a9a3a706cc74186d009cf`. It matches the final measured executable.
- Small serving instance: `hostname-88e15a582969/1/1792353863322153`. Zero streams and idle transactions after scale-down.
- Session persistence and console logging remain disabled by the benchmark override. Pool limit 100 and merge admission 50 remain experiment settings, not Small capacity recommendations.

Attempts 17–21 used a verified two-core XXL instance for hosted comparisons; attempt 22 used Medium with an actual 0.25-core quota. These capacity settings are separate from the current Small deployment. Those historical deployment and capacity changes were authorized for that experiment; this report does not authorize a new deployment.

### Historical measurements after attempts 13–16

Milliseconds from local write start to exact application on every peer, after warmup, with two devices per user in personal spaces and conflict-free writes. All headline runs disable detailed tracing. The insert distributions each pool 1,024 rounds; each update distribution pools 96 rounds. Each before/after pair uses the same native client. These are one verified 2-core XXL instance results, not Small results.

| Workload | Version | Min | Mean | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 64 streams / 16 insert rounds/s | Before retained changes | 385.6 | 596.5 | 535.4 | 1148.3 | 2078.1 |
| 64 streams / 16 insert rounds/s | Final | 356.2 | 463.9 | 455.6 | 562.9 | 980.4 |
| 64 streams / 32 insert rounds/s | Before retained changes | 393.5 | 985.1 | 1015.2 | 1197.7 | 1429.9 |
| 64 streams / 32 insert rounds/s | Final | 366.0 | 747.7 | 676.0 | 1161.6 | 2124.6 |
| 8 streams / 10 edited rows, two fields each | Before payload batching | 534.6 | 650.7 | 639.2 | 777.4 | 1007.5 |
| 8 streams / 10 edited rows, two fields each | Final | 386.6 | 487.9 | 483.1 | 596.1 | 652.6 |
| 8 streams / 50 edited rows, two fields each | Before payload batching | 1332.6 | 1579.5 | 1574.6 | 1739.8 | 1796.8 |
| 8 streams / 50 edited rows, two fields each | Final | 655.3 | 752.4 | 740.1 | 860.5 | 1064.2 |

The insert predecessor is the exact restored attempt-12 executable after rejecting attempt 13. The update predecessor already includes attempts 14 and 15. Do not add percentage savings across these different workloads. Hosted variability and the four-hour pause before attempt 15 remain limitations. All reported runs passed exact server/peer convergence, had zero sampled database lock waits, and drained streams and idle transactions. One final 32-rounds/s repetition missed its offered-load gate: the slowest user completed at 97.9% of its scheduled rate. Exact convergence is not proof of sustained 32-rounds/s capacity. Offered-load adherence is retained for every run in the ledger.

The new update harness (`495ff3b` in the companion) uses one native binary in both arms, SHA-256 `4f9a0a6e7a91654a4642835d2e918c4277161872145c5215c61429ed9337f625`. Only the server implementation changed between the comparison arms; potential client-engine savings are excluded.

The final warmed database probe measured 7.928 ms median and 8.546 ms p95 for serial SELECT 1; PostgreSQL replay execution was 0.009 ms. This is an off-load measurement of network, driver and scheduling overhead together, not an isolated geographic latency measurement. That collector omitted queries beginning with WITH; attempt 17 subsequently fixed selection and retained the missing read-only CTE plans.

### Attempt 12 and its savings

Local commits already wake affected streams. Recovery polling was later detecting the same committed revision and waking them again, causing redundant full outbound captures. The transaction wrapper now records the exact revision it wrote and, after successful commit and delivery of the local hints, remembers that revision in the existing recovery cache. This adds 19 net runtime lines across three files. No protocol frame or SQL write was removed.

The first recovery baseline still wakes, external changes still compare unequal and wake, and membership polling is unchanged. Failed listener delivery does not advance the recovery cache. A scan racing a commit can conservatively wake again. The revision cache never authorizes checkpoint advancement. Same-space locking and consistent snapshot boundaries remain unchanged.

The client executable was deliberately unchanged throughout, including its own recovery behavior. These measurements isolate the server improvement; possible future client savings are not credited.

Milliseconds from **local write start to application by the other device**, on already established streams. One row per write, two devices per user. These are end-to-end delivery times, not just merge transaction times.

| Workload | Version | Samples | Min | Mean | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 8 streams / 4 rounds/s | Reverted control | 120 | 392 | 489 | 491 | 592 | 678 |
| 8 streams / 4 rounds/s | Optimized | 240 | 352 | 455 | 461 | 535 | 626 |
| 64 streams / 16 rounds/s | Reverted control | 640 | 419 | 682 | 640 | 1029 | 1882 |
| 64 streams / 16 rounds/s | Optimized | 1280 | 347 | 497 | 490 | 608 | 912 |
| 64 streams / 32 rounds/s | Reverted control | 640 | 473 | 1502 | 1492 | 1783 | 2096 |
| 64 streams / 32 rounds/s | Optimized | 640 | 453 | 978 | 991 | 1280 | 1448 |

The optimized main-load results pool two repeats each. The table uses the old executable redeployed after those repeats as the control; it was byte-identical to the initial baseline. This reversal gave **34 ms / 7.0%** lower mean at 8 streams and **185 ms / 27.1%** at 64 streams / 16 rounds/s. Mean process CPU seconds per run, including warmup and cleanup, fell from 9.63 to 7.82 and from 41.49 to 33.625 respectively: about **19% less CPU**. These are observed sequential comparisons, not exact additive causal savings.

Two initial controls per main load are also retained. Pooling all three control runs gives means 517 and 657 ms, for reductions of 12.0% and 24.3%. The initial 8-stream controls varied from 504 to 559 ms, so the later 489 ms reversal is the more conservative comparison. The final restored-deployment smoke averaged 514 ms across 32 samples; it checked convergence and cleanup and is not pooled with the longer performance comparisons.

Both versions sustained the 4 and 16 offered rounds/s workloads. At 32 offered rounds/s, the change reduced mean from **1502 to 978 ms**, but **both versions missed their offered schedule**. There was one high-rate run per version. Eventual convergence does not establish 32-rounds/s capacity.

All valid runs passed exact journal convergence without repair sync, had zero sampled database lock waits, and finished with zero open streams and idle transactions. The early `base-c8-a` run started before resizing finished, on 0.1 actual cores. It was terminated, retained with its failures, and excluded. The runner now checks actual CPU quota and zero open streams before starting. Two pre-deploy dry runs encountered read-only Flutter cache access; neither changed the hosted deployment.

### Attempt 12 work eliminated and its measured critical path

Complete short traces each contained 40 writes including warmup, across eight streams; none dropped diagnostic details.

| Profile | Outbound captures | Recovery wakeups | SQL statements | Transactions |
| --- | ---: | ---: | ---: | ---: |
| Initial control | 152 | 66 | 1512 | 192 |
| Optimized | 95 | 8 | 1225 | 135 |
| Reverted control | 153 | 68 | 1521 | 193 |

This removes about **38% of captures and 19% of SQL statements**. The eight remaining recovery wakeups are initial baselines. Captures still include useful writes, initial work and acknowledgement-driven progress.

In the optimized trace's 32 exercise rounds, mean end-to-end delivery was 473.327 ms. Correlating each server merge with the following other-device batch on the same user gives:

| Part | Mean ms | Interpretation |
| --- | ---: | --- |
| Server merge | 138.221 | Merge processing and database work |
| Merge completion to peer batch dispatched | 109.471 | Remaining capture, membership/read work and scheduling |
| Remaining end-to-end time | 225.635 | Transport and client work combined |
| Total | 473.327 | Local write start to peer application |

The server merge-start to peer-send interval is 247.692 ms. The same-server anchors avoid cross-machine clock subtraction; correlation assumes this harness's one outstanding write per user and two devices. The residual is **not pure network propagation**. Individual capture spans averaged 89.554 ms, but overlap other work and must not be added to this partition. Capture counts include warmup; the latency partition excludes warmup.

At that stage, the next target was the approximately 109 ms between merge completion and dispatching the downloaded batch, followed by the 138 ms merge work; subsequent attempts below measured those paths again. Established streams avoid connection startup; the same SDK startup patch was present in both control and optimized clients.

### Historical high-load profile after attempt 12

The user requested a profile of the instrumented version. The same optimized server and native client executables were rerun with the existing diagnostics enabled: 32 users, two devices each, eight exercise rounds per user, one row per round. All runs used one verified 2-core instance. The sequence was untraced 32 rounds/s, traced 32 rounds/s, untraced 32 rounds/s, then traced 16 rounds/s. No runtime or wire change was made.

| Run | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 32 rounds/s, untraced before | 487 | 1014 | 1056 | 1310 | 1417 |
| 32 rounds/s, traced | 540 | 1582 | 1651 | 1999 | 2079 |
| 32 rounds/s, untraced after | 533 | 1091 | 1099 | 1298 | 1409 |
| 16 rounds/s, traced | 440 | 582 | 581 | 705 | 783 |

Each run has 256 exercise samples. Both traced runs retained all 64 server traces and 64 client traces with zero dropped details or unfinished spans. All four runs passed exact convergence and cleanup, with no sampled lock waits. The 32-rounds/s workloads missed their offered schedules; the 16-rounds/s run sustained its schedule.

**Tracing adds substantial overhead near saturation.** The 1999 ms traced p95 cannot be presented as a decomposition of the earlier untraced 1280 ms p95. The controls reproduced a roughly 1300 ms untraced tail. The existing profiler emits SQL fingerprints, detailed merge logs and collected timelines. Attempt 17 later introduced selective sampling; do not subtract a uniform percentage from this older trace.

The following values are paired round means, plus the actual individual round at the traced high-load p95. Percentiles of independent phases were not added together.

| Part | Mean at 16 rounds/s | Mean at 32 rounds/s | High-load p95 round |
| --- | ---: | ---: | ---: |
| Merge admission and source preparation | 0.02 | 0.02 | 0.01 |
| Connection acquisition plus BEGIN | 6.8 | 30.5 | 16.6 |
| SQL calls inside merge transaction | 205.7 | 833.5 | 1056.4 |
| Other merge work, including non-SQL transaction body | 5.8 | 7.0 | 11.1 |
| COMMIT and connection release | 7.6 | 35.4 | 48.5 |
| Merge completion to peer batch dispatched | 146.5 | 518.3 | 722.3 |
| Transport and client work combined | 209.8 | 157.3 | 143.7 |
| **End-to-end total** | **582.0** | **1582.0** | **1998.6** |

The p95 round used 12 SQL statements in the merge transaction. Its 722 ms post-merge interval comprises 105 ms before capture, 618 ms in capture, and under 0.01 ms between capture completion and batch dispatch. The capture transaction contains another five SQL statements, taking 457 ms in aggregate; other capture time includes transaction and membership/read work. Across all exercise rounds, these merge SQL calls average about 69 ms per statement at 32 rounds/s versus 17 ms at 16 rounds/s; the five capture SQL calls average 74 versus 21 ms. The expanding cost is spread across calls rather than one uniquely expensive statement.

The slowest 13 of 256 high-load rounds averaged 2036 ms: 1164 ms merge, 728 ms post-merge dispatch and 144 ms transport/client residual. The peer's actual local merge averaged 3.2 ms in that tail. Server process samples inside the exercise-merge window averaged 0.997 CPU cores; event-loop lag averaged 2.87 ms and peaked at 31.47 ms. The low-rate profile used 0.825 cores, with 0.76 ms mean and 8.64 ms maximum lag. One-core pressure is consistent with CPU/driver scheduling limits, but the measurements do not identify a particular isolate or give GC pause times.

Database samples retained spare idle sessions and no lock waiters. The observed SQL durations include network, driver processing, scheduling and PostgreSQL execution; they are not database execution times alone. After the runs, warmed SELECT 1 had a 7.4365 ms median, with a retained 56.292 ms outlier. Eight hot query replays had PostgreSQL execution times of 0.026–0.901 ms and planning times of 0.054–1.413 ms. Two plans scanned approximately 5.4–5.6k node/tombstone rows, but still executed below one millisecond in this replay. Their growth should be watched; these off-load plans do not prove under-load execution cost. Rows have changed by replay time, and existence guards can short-circuit branches that ran before an insert. `pg_stat_statements` is available, but this follow-up retained only its cumulative snapshot, not a per-run delta.

The current conclusion is that many sequential database calls and outbound capture amplify latency under load. The exact split between database network, driver and server scheduling remains unresolved. Reducing those calls while retaining a consistent snapshot is the next implementation target; improving sampled diagnostics is needed to measure the untraced tail more precisely.

Evidence: `evidence://sync-tail-profile-20261018T101736Z`. `case-report.json` holds the comparisons; each `*-decomposition.json` retains all paired rounds, exact p95 round and tail cohort; `*-capture-breakdown.json` subdivides the outbound capture path; `database-diagnostics-after.json` retains query plans and the round-trip probe. The ledger stores summaries, commands and hashes. The analysis script is `evidence://sync-tail-decompose.py`, and the native-run wrapper is `evidence://sync-tail-run.py`.

Returned to Small at `2026-10-18T10:24:58.481179+00:00`, same optimized executable, zero streams and idle transactions. No benchmark process remains active. No runtime code changed in this follow-up; the prior 79-test validation remains the implementation evidence.

### Attempt 13: Join source metadata reads

The candidate combined established author identities and space-local progress into one joined query, reducing merge SQL from 12 to 11 calls. It preserved deterministic creation and transaction-local cursor reads. It was not retained because repeated hosted measurements did not demonstrate a performance benefit; the implementation is archived on reference/merge-source-lookup and reference/merge-source-lookup-benchmark.

| 64 streams, offered rounds/s | Before mean ms | After mean ms | After median ms | After p95 ms | Mean saving |
| --- | ---: | ---: | ---: | ---: | ---: |
| 16 | 493.7 | 618.9 | 597.6 | 868.4 | -125.2 ms (-25.4%) |
| 32 | 1019.1 | 1292.0 | 1276.9 | 1785.9 | -272.9 ms (-26.8%) |

Decision: The joined lookup removed one established-merge SQL call but did not demonstrate a latency or CPU benefit. It was slower than both surrounding baseline deployments at the high offered rate. The exact cause is unresolved; the replayed SQL plan was cheap. Preserve the candidate for reference and continue from the baseline.

Each before/after distribution pools two 512-round runs. Same native client, one verified 2-core instance, one row per round and two devices per user. Headline runs disable detailed tracing. All runs passed exact convergence and ended with zero streams and idle transactions. Hosted variation remains; these are observed differences.

80 focused tests passed: 16 merged-insert cases and 64 PostgreSQL concurrency, cancellation and SQLite clock cases. The new mixed-author regression verifies newer progress committed through an independent session, older unseen facts, an author known only in another space, and a fresh author. Its later assertion also passed independently. Analyzer: no issues. An initial parallel invocation collided on port 8080; affected suites passed with test concurrency 1. Full CI was not run.

Evidence: `evidence://sync-roundtrips-20261018T115308Z`; `source-comparison.json` retains min/mean/median/p95/max, commands, raw latencies, executable/source hashes, trace counts and per-attempt savings. The predecessor is `base`. Reversal restored the exact original executable: mean 596.5 ms at 16 rounds/s and 985.1 ms at 32 rounds/s. The active code remains on the baseline lookup. The new per-author progress coverage is retained.

### Attempt 14: Consolidate outbound metadata capture

Capture row and tombstone metadata together, then fetch changed fields and authored attempted values in one included collection. The entire metadata/payload/ownership pass remains in one repeatable-read snapshot. In the short trace, 76 nonempty captures dropped from 5 SQL calls each to 3, and 19 empty captures from 3 calls to 1; established merge work stayed at 12. Total traced server SQL fell from 1225 to 1031 calls. The same native client and streaming protocol were used for both arms.

| 64 streams, offered rounds/s | Before mean ms | After mean ms | After median ms | After p95 ms | Mean saving |
| --- | ---: | ---: | ---: | ---: | ---: |
| 16 | 596.5 | 466.0 | 462.7 | 558.2 | 130.5 ms (21.9%) |
| 32 | 985.1 | 661.5 | 636.1 | 903.4 | 323.6 ms (32.9%) |

Decision: Retained. Both 64-stream repeats improved at both offered rates, with exact convergence and no sampled database lock waits. Hosted variation limits causal attribution; the deterministic result is two fewer metadata reads per capture.

Each before/after distribution pools two 512-round runs. Same native client, one verified 2-core instance, one row per round and two devices per user. Headline runs disable detailed tracing. All runs passed exact convergence and ended with zero streams and idle transactions. Hosted variation remains; these are observed differences.

59 focused tests passed: 35 outbound/snapshot/payload/projection/clock checks, 19 DST snapshot/shared-space/authorization checks, and five new real-PostgreSQL capture checks. An independent writer committed between metadata and payload reads without leaking into the pinned snapshot; a later pass delivered both later facts. Checkpointed attempted FK values remain attached to unseen inserts. The later PostgreSQL assertion passed independently. An initial embedded-PostgreSQL fixture used a one-connection pool and timed out during migration; setting its pool to eight resolved it. Analyzer: no issues. Full CI was not run.

Evidence: `evidence://sync-roundtrips-20261018T115308Z`; `capture-comparison.json` retains min/mean/median/p95/max, commands, raw latencies, executable/source hashes, trace counts and per-attempt savings. The predecessor is `reversal`.

### Attempt 15: Persist merge progress and clocks together

On PostgreSQL, persist received cursors, the applying user clock and the space revision in one data-modifying CTE statement inside the existing transaction. The three CTE updates write distinct locked metadata rows and do not depend on sibling execution order. The existing clock-then-space lock order, SQLite writes, rollback and postcommit notification boundaries remain intact. Established merge SQL dropped from 12 to 10 statements in every exercise merge. The writeReceivedCursors trace phase now contains all three metadata writes; persistClockAndCleanup no longer performs SQL for those merges.

| 64 streams, offered rounds/s | Before mean ms | After mean ms | After median ms | After p95 ms | Mean saving |
| --- | ---: | ---: | ---: | ---: | ---: |
| 16 | 466.0 | 442.7 | 439.2 | 534.4 | 23.2 ms (5.0%) |
| 32 | 661.5 | 499.1 | 485.0 | 661.6 | 162.3 ms (24.5%) |

Decision: Retained. Both repeats improved at both offered rates and the short trace confirms two fewer SQL round trips per merge. There was a roughly four-hour pause between the capture baseline and this candidate, so the hosted latency savings remain observations rather than isolated causal estimates.

Each before/after distribution pools two 512-round runs. Same native client, one verified 2-core instance, one row per round and two devices per user. Headline runs disable detailed tracing. All runs passed exact convergence and ended with zero streams and idle transactions. Hosted variation remains; these are observed differences.

113 focused tests passed: 19 real-PostgreSQL merged-insert cases and 94 concurrency, cancellation, atomicity, caller-owned transaction, SQLite clock, recovery and shared-space cases. A new PostgreSQL trigger injects failure after the domain write when the revision is stored; domain data, CRDT metadata, received progress, clock and revision all roll back. Removing the trigger and retrying commits all of them. That later retry assertion also passed independently. Analyzer: no issues. Full CI was not run.

Evidence: `evidence://sync-roundtrips-20261018T115308Z`; `progress-comparison.json` retains min/mean/median/p95/max, commands, raw latencies, executable/source hashes, trace counts and per-attempt savings. The predecessor is `capture`.

### Attempt 16: Batch outbound update payloads

Read pending update payloads by table and owning space in batches of at most 100 row ids; union only the required columns with any insert payload columns. Attempted FK overrides, domain ownership validation and the full repeatable-read capture remain intact. No endpoint or protocol change. The server is the only changed executable in each comparison.

| Edited rows/round, 8 streams | Before mean ms | After mean ms | After median ms | After p95 ms | Mean saving |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10 | 650.7 | 487.9 | 483.1 | 596.1 | 162.8 ms (25.0%) |
| 50 | 1579.5 | 752.4 | 740.1 | 860.5 | 827.1 ms (52.4%) |

The ten-row short profiles show 22 SQL statements per nonempty update capture before and 3 after. Total traced server SQL fell from 884 to 506 calls; established update merges retain 19 statements. Capture timing and full statement-count distributions are in `update-capture-mechanism.json`; the profile is explanatory and separate from the untraced headline distributions.

Two fields change per row. Each distribution pools two 48-round runs, using one unchanged update-capable native client. The 10-row runs offer 2.67 rounds/s; 50-row runs offer 1.33 rounds/s. All verify exact final data on the server and both devices without repair sync. The existing one-row insert client is separately repeated at both 64-stream load levels, including a fresh byte-identical predecessor reversal and a byte-identical candidate restoration after the first comparison appeared slower. All four before/after distributions are retained. The restored candidate still has high-load insert stalls; an insert penalty is not ruled out and no insert-speed saving is credited to this step. Retention is based on the large repeated update savings and bounded payload reads.

| One-row inserts, 64 streams | Initial predecessor mean / p95 ms | Initial candidate mean / p95 ms | Fresh predecessor mean / p95 ms | Restored candidate mean / p95 ms |
| --- | ---: | ---: | ---: | ---: |
| 16 rounds/s | 442.7 / 534.4 | 465.3 / 573.2 | 489.6 / 633.7 | 463.9 / 562.9 |
| 32 rounds/s | 499.1 / 661.6 | 599.7 / 759.6 | 625.7 / 893.8 | 747.7 / 1161.6 |

One final 32-rounds/s repetition missed its offered-load gate: the slowest user completed at 97.9% of its scheduled rate. Exact convergence is not proof of sustained 32-rounds/s capacity.

74 focused checks passed, including real-PostgreSQL concurrent snapshots, DST interleavings, projected references, structured/binary values, missing domain rows and cross-space ownership. The new mixed insert/update case spans over 100 row ids per space and two tables; its bounded-read assertion fails on the predecessor with 636 calls, passes with fewer than 25, and also passes independently. After the final decoder adjustment, all 33 payload/projection/PostgreSQL cases passed again. Nine harness checks and an exact-convergence hosted smoke passed. Analyzer: no issues. Full CI was not run.

Evidence: `evidence://sync-roundtrips-20261018T115308Z`; `updates-comparison.json` holds min/mean/median/p95/max, raw samples, before/after insert checks, source/client/executable hashes and profiles. The update harness is committed as `495ff3b` in the companion. Use `rounds --write-mode update --rows 10` (or `50`), with two devices per user; other flags are recorded per run.

### Attempt 17: Selective complete profiling

The benchmark can select up to 16 authenticated user ids for tracing before streams open. Both devices are observed without changing the pinned native client. Selected streams emit complete timelines and transaction summaries through the bounded authenticated collector, with per-phase SQL count/time/rows; they omit SQL fingerprinting, payload re-encoding and stdout logging. Other users are untraced. Sampling changes are rejected while streams remain open.

| 64 streams, 32 rounds/s | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Untraced control A | 354.4 | 479.0 | 473.7 | 574.0 | 732.0 |
| Two of 32 users traced | 372.3 | 505.2 | 495.4 | 616.4 | 994.0 |
| Untraced control B | 354.0 | 478.5 | 473.2 | 576.6 | 731.8 |

Each arm contains 2,560 exercise rounds. Sampling added 26.4 ms (5.5%) versus the pooled controls, so headline comparisons stay untraced. All runs met offered load, converged exactly, and ended with zero streams and idle transactions; no sampled lock wait was observed. All 160 selected rounds were paired without event gaps or unfinished spans. Their average was 501.1 ms: 159.7 ms merge SQL, 59.6 ms capture SQL, 231.4 ms combined transport/client residual and 50.4 ms other server time. Mean admission queue wait was 0.03 ms. This sample describes selected users, not the population's exact p95 round.

The slowest sampled 5% averaged 677.7 ms: 235.7 ms merge SQL, 87.8 ms capture SQL, 273.7 ms transport/client residual. Every exercise insert used 10 merge SQL calls and 3 capture calls. Event-loop lag averaged 0.45 ms and peaked at 9.98 ms. The former greater-than-one-second p95 did not reproduce in this run.

Plan collection now admits read-only WITH statements and excludes data-modifying CTEs before the existing read-only transaction and timeout guards. Two previously omitted outbound metadata CTE plans executed in 0.94 and 1.04 ms, each scanning 5,568 tombstones; unloaded replay can short-circuit paths and is not an under-load execution profile. Warmed serial SELECT 1 had a 6.29 ms median, including driver, network and scheduling.

Validation: 27 focused tests passed, including actual PostgreSQL sampling isolation/convergence and read-only CTE selection; the later sampling assertion also passed independently. Analyzer: no issues. Full CI was not run. All 19 protected configuration files and 193 runtime files were verified. No package runtime or protocol changed in this attempt.

Evidence: `evidence://sync-sampled-20261018T173847Z`; `sampling-comparison.json`, `overhead-on-decomposition.json`, `sampled-database-plans.json`, and `query-plan-summary.json` retain raw comparisons, full paired rounds and replay plans. Helpers: `evidence://sync-sample-run.py` and `evidence://sync-sample-profile.py`. The subsequent insert controls and same-machine comparison are complete in attempts 18 and 19; final capacity and Small restoration are in attempt 22.

### Attempt 18: Longer insert controls

The original native insert client was held fixed. At 32 offered rounds/s, the planned order was candidate B, predecessor A, A again, then a byte-identical B restoration. A is attempt 15; B is attempt 16. Both include attempt 17 instrumentation, disabled for the headline runs. Only engine.dart differs. Each run has 32 users, two devices each and 120 rounds per user: 3,840 exact exercise rounds.

| Version / offered rate / repeat | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| insert-b1-r16 | 317.4 | 420.1 | 414.5 | 514.6 | 699.2 |
| insert-a1-r16 | 335.1 | 462.0 | 453.3 | 560.6 | 1129.8 |
| insert-b1-r32 | 336.0 | 484.4 | 478.8 | 591.7 | 858.6 |
| insert-a1-r32 | 390.1 | 645.4 | 598.2 | 1030.0 | 1968.3 |
| insert-a2-r32 | 385.6 | 635.8 | 602.2 | 926.4 | 1349.0 |
| insert-b2-r32 | 375.8 | 589.7 | 567.6 | 815.5 | 1108.9 |

At 32 rounds/s the pooled predecessor mean/p95 were 640.6/979.9 ms, versus 537.0/735.2 ms for the candidate. Both candidate repeats were faster than both predecessor repeats. All six controls met offered load, converged exactly, had no sampled lock waits and drained to zero streams and idle transactions.

The earlier insert penalty is not reproduced. Keep the demonstrated update payload batching; do not introduce a speculative insert fast path or credit an insert speed improvement to this change. Deployment instances and time differ even with a fixed two-core quota, so this is stronger regression evidence, not an isolated causal speed estimate.

The separate predecessor profile paired 160 selected rounds completely. Its slowest sampled 5% averaged 974.9 ms: 466.8 ms merge SQL, 164.3 ms capture SQL, 193.1 ms transport/client residual, and about 150.7 ms of other server work including transaction begin/commit and delivery scheduling. Queue wait averaged 0.04 ms in that cohort. Every selected insert still used 10 merge SQL calls and 3 capture calls. Event-loop lag averaged 0.78 ms and peaked at 15.77 ms. The added tail was predominantly in database-call elapsed time; this includes network and driver waiting and is not PostgreSQL execution time alone.

Evidence: `evidence://sync-sampled-20261018T173847Z/long-insert-comparison.json`, `insert-comparison-plan.json`, `insert-a-profile-decomposition.json` and all six commands, native/client hashes, raw events and cleanup receipts. The restored B executable SHA-256 matches its first run exactly.

### Attempt 19: Same-machine baseline and database latency control

The unchanged native client and the same application sources run locally with PostgreSQL. The server is a Dart 3.12.2 AOT build, pinned to two physical CPU cores; PostgreSQL and the client use separate cores. Cloud uses Dart 3.13.5, different hardware and TLS. This removes both network paths, so the initial Cloud/local difference is not a pure database-placement effect.

| 64 streams, 32 offered rounds/s | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cloud, 2-core XXL | 336.0 | 484.4 | 478.8 | 591.7 | 858.6 |
| Same machine, direct database | 23.4 | 28.1 | 27.5 | 32.4 | 215.1 |
| Same machine, zero-delay proxy controls | 27.1 | 32.0 | 30.5 | 38.7 | 195.7 |
| Same machine, matched database query latency | 142.7 | 160.4 | 157.9 | 174.8 | 362.8 |

The Cloud and direct-local runs each contain 3,840 exercise rounds. The delay experiment uses 1,280 per arm in zero/delayed/zero order; the zero-delay table row pools both controls. All headline runs are untraced, meet offered load, converge exactly and drain to zero streams and idle transactions.

With the same local server/client executables and PostgreSQL cluster, matching the warmed query duration increased average sync latency by **128.3 ms**. Warmed SELECT 1 medians were 0.63 and 0.79 ms in the surrounding zero-delay controls, and 6.88 ms in the matched arm; the Cloud probe was 6.29 ms. The proxy schedules each response chunk from its arrival time, adding 3 ms in one direction. PostgreSQL execution of SELECT 1 remained about 0.003 ms. The driver also waits for portal cleanup inside these transactions, so the query time includes more than one exchange and must not be labeled pure network RTT.

This establishes a substantial cost from repeated database responses. It does not establish database geography as most of the hosted end-to-end delay. The sampled Cloud path contains 231.4 ms of transport/client residual; local profiling reduces that residual to about 11 ms. Hosted CPU cost is also higher: the retained exercise-window samples use about 0.79 cores on Cloud versus 0.23–0.26 locally. Hardware, runtime, managed-database load and scheduling are not isolated by the geography comparison.

A separate startup failure appeared on the freshly initialized local database. After registry creation, every new session repeated the projection rebuild for all spaces; two sampled runs timed out during startup with no exercise rounds. Restarting the unchanged server against the populated registry removed that path, and the sampled 64-stream run passed. Attempt 20 fixes this lifetime bug and includes a real-PostgreSQL regression that fails on the predecessor. It is not attributed to sampling overhead or to the hosted steady-state timings.

The initial serial-chunk-delay proxy runs are retained as exploratory evidence. Their timing is not used in the final comparison because separate reads of one response could accumulate delays. The corrected proxy still shows doubled query sensitivity, consistent with the driver's portal-cleanup exchange. All local services were stopped before the longer hosted predecessor comparisons resumed.

Evidence: `evidence://sync-sampled-20261018T173847Z/placement-comparison.json`, paired `*-decomposition.json` files, `local/delay-plan.json`, `local/driver-exchange-evidence.json`, all startup failures and all proxy versions. No package runtime change or speed saving is credited to this measurement.

### Attempt 20: Rebuild projections once per shared database context

After a schema registry change, the old context kept registryChanged true for its lifetime and each ephemeral recorder rebuilt every space again. This caused two local 64-stream runs to time out during startup with zero exercise rounds. The shared context now owns one rebuild future. Concurrent and later sessions await that rebuild; a failure is surfaced and the next initialization can retry. The projection algorithm and merge transaction boundaries are unchanged.

The real-PostgreSQL regression fails on the predecessor in three places: concurrent sessions read four projection rows instead of two, a later session reads two instead of zero, and a session after a successful retry reads three instead of zero. All five candidate assertions pass, including data integrity and retry. The later retry assertion also passes independently. The combined schema, admission, cancellation and clock suite passed 96 checks, including the five new schema assertions. Analyzer: no issues. Full CI was not run.

The native candidate contains only this recorder change over the local baseline. On the populated disposable PostgreSQL database, removing one unused registry column forces reconciliation. Two sampled 64-stream runs then pass on the same process without a restart, 1,280 exercise rounds each. Both meet offered load, converge exactly, and drain streams and idle transactions.

| Same-process native run | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| local-schema-once-first | 22.8 | 26.9 | 25.5 | 29.8 | 261.8 |
| local-schema-once-second | 22.9 | 26.5 | 25.7 | 30.8 | 84.4 |

Decision: retain as a startup correctness and bounded-work fix. These are not matched steady-state speed measurements against the failed predecessor; no hosted latency saving is credited. The already-initialized Cloud registry was not exercising this rebuild path during the insert controls. A long-lived migration/rebuild still has real one-time work to perform.

Evidence: `evidence://sync-sampled-20261018T173847Z/schema-lifetime-comparison.json`, `local/schema-once-native/manifest.json`, retained failed startup runs, `evidence://sync-schema-lifetime-base.log`, `evidence://sync-schema-lifetime-final.log`, and `evidence://sync-final-candidate-guards.log`. Local server and PostgreSQL were stopped after both successful runs.

### Attempt 21: Batch distinct authored domain updates

Unconstrained PostgreSQL merge edits now group by table and exact column set, up to 100 rows per statement. Each row keeps its own typed values through CASE expressions; sparse fields remain untouched. Existing ownership checks, clock-then-space locking, atomic rollback, foreign-key projection and unique-value parking remain intact. No endpoint or protocol change.

The fixed update client writes two fields per row, with four users and two devices each. Each untraced distribution pools two 80-round repetitions. The 10-row workload offers 2.67 rounds/s and the 50-row workload 1.33 rounds/s. All pass exact server/peer convergence, meet offered load, have no sampled lock waits and drain streams and idle transactions.

| Rows per round, 8 streams | Version | Min ms | Mean ms | Median ms | p95 ms | Max ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 10 | before | 382.6 | 525.5 | 489.3 | 585.6 | 2340.7 |
| 10 | after | 351.0 | 458.2 | 455.3 | 531.8 | 819.4 |
| 50 | before | 628.7 | 770.7 | 763.2 | 852.6 | 1171.6 |
| 50 | after | 438.2 | 545.7 | 542.8 | 651.4 | 963.3 |

Mean savings are 67.3 ms (12.8%) for 10 rows and 225.1 ms (29.2%) for 50. Different Cloud instances and time remain confounders; the 2.34-second baseline outlier is retained. The separate local comparison holds the host, PostgreSQL cluster, native client, runtime and calibrated 3 ms response delay fixed: 10-row means fall from 179.5 to 137.2 ms, and 50-row means from 360.7 to 184.3 ms. Those local arms contain 48 rounds each and are not pooled with Cloud.

All eight selected profile rounds per shape confirm merge SQL falling from **19 to 10** and **59 to 10**. Capture remains three statements. The full paired phase breakdown is retained. The original 64-stream one-row insert client also passes 2,560 rounds at 32 offered rounds/s: mean 596.7 ms, median 564.2 ms, p95 848.5 ms. That is a regression check, not an insert speed claim.

Validation: 55 focused merge checks pass, including seven new PostgreSQL checks for distinct/sparse/null values across more than 100 rows, multiple tables, an unrelated space, structured/binary/UUID values, and a trigger failure after an earlier chunk writes. The failed merge rolls back domain values, CRDT metadata, clock and revision; retry commits every row. The later retry assertion also passes alone. The combined schema/admission/cancellation/clock suite passes 96 checks. Analyzer: no issues. Full CI was not run.

Decision: retain. Evidence is in `evidence://sync-sampled-20261018T173847Z/domain-write-comparison.json`, `local-domain-comparison.json`, the four paired profile files and `domain-write-plan.json`. The native candidate build manifest verifies that only the two domain-write runtime files differ from the local baseline. All 19 protected deployment config/secret files retain their hashes.

### Attempt 22: Final Medium capacity

The exact attempt 21 server executable runs on one Medium instance: **0.25 actual CPU cores and 512 MB configured memory**. Session persistence and console logging remain off. The original eight-stream run passed, but the original 64-stream harness opened all streams together during warmup and failed after a 45-second sentinel timeout, before any exercise rounds. It reached 46 streams and reported 30 unexpected ends. Every stream and unfinished transaction drained. That failed case remains in the evidence; it is not represented by a zero latency.

The benchmark warmup now uses the existing setup-concurrency bound per user group. Four workers warm one user each at a time. Every device still authors a sentinel and the parent verifies the full stream count before starting measurement. Startup already used the long startup deadline; per-round timeouts remain unchanged. Nine existing harness checks and fatal-info analysis pass. The rebuilt client includes the current package sources; the original fixed-client optimization comparisons are unchanged. Different pod instances and clients prevent treating the initial/staged difference as a server speed saving.

The eight-stream workload offers 2.67 one-row rounds/s. The 64- and 128-stream workloads offer the same eight total rounds/s. The ten-row update workload uses eight streams and two rounds/s. Load adherence is separate from convergence.

| Active workload | Min ms | Mean ms | Median ms | p95 ms | Max ms | Offered load met | Mean CPU cores |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| medium8 | 508.5 | 712.2 | 668.7 | 960.3 | 1449.1 | yes | 0.252 |
| medium-staged8 | 431.9 | 627.4 | 584.6 | 957.9 | 1266.0 | yes | 0.247 |
| medium-staged64 | 702.1 | 6260.9 | 6207.6 | 7500.2 | 12739.2 | no | 0.307 |
| medium-staged-update10 | 523.0 | 679.7 | 660.5 | 842.2 | 1205.9 | yes | 0.228 |

Higher active stream counts are stopped when the 64-stream convergence or offered-load gate fails; skipped and failed cases are explicit in the ledger. The 64-stream untraced mean is 6.26 seconds and p95 7.50 seconds; exact convergence passed, but the offered load was missed, so 128 active streams were skipped.

A separate two-user sampled profile has 40 complete rounds and no detail loss. Its independent server counters average 4,044 ms across 10 merge SQL calls, 1,176 ms across three capture calls, and 0.04 ms admission wait; connection acquisition plus BEGIN averages 189/204 ms and commit/release 208/192 ms for merge/capture. Event-loop lag averages 7.72 ms and peaks at 490 ms. These are elapsed driver calls, not PostgreSQL execution times.

The attempted end-to-end partition was rejected because 22 of 40 inferred server paths exceed the client duration. The cause is unresolved; no negative residual is clamped or omitted, and these server counters are not an exact partition of the untraced p95. The failed analysis, raw events and server-only summary are retained. Sampling adds overhead.

Idle connections open at an aggregate scheduled rate of two per second, with a target sixty seconds after the last scheduled opening. This measures maintaining established connections separately from opening bursts. The 512-stream step requires a passing 256-stream run, at least twenty seconds of observed quiet, peak RSS below 350 MiB and mean quiet CPU below 0.2 cores.

| Idle streams | Result | Observed quiet seconds | Quiet CPU cores | Peak RSS MiB | Inbound/outbound change delta |
| --- | --- | ---: | ---: | ---: | ---: |
| 64 | passed | 58.7 | 0.010 | 149.7 | 0/0 |
| 256 | passed | 59.0 | 0.026 | 294.1 | 0/0 |
| 512 | passed | 58.5 | 0.055 | 551.1 | 0/0 |

The raw scale summaries label these all-idle runs as an offered-load shortfall: tiny initial offline residency contributes less than one nominal operation while actual operations are zero. No writes were requested. The ledger retains that raw label and the fractional counts; it does not treat these cases as active throughput measurements.

The 512-stream process RSS reaches the configured memory size; RSS is not cgroup-charged memory, and the actual memory hard limit was not inspected. Treat this as a boundary measurement with no demonstrated memory headroom. The 256- and 512-stream cases reuse one pod, and peak RSS includes setup and verification; these are not per-connection allocation estimates.

Change counters exclude transport keepalives and do not prove zero WebSocket bytes. CPU includes benchmark telemetry. Some sampled CPU estimates exceed the nominal quota; they are approximate accounting observations, not proof of a measured throttling fraction. The quota is visible, but throttled-time counters and VM-service GC/isolate data are unavailable. These bounded runs do not establish thousands of active devices, sustained production load or multi-pod capacity.

The deployment is back on **one Small instance, 0.1 cores and 256 MB configured memory**, verified at `2026-10-18T20:04:35.781458+00:00`, with the same executable and zero streams or idle transactions. Small readiness and cleanup were checked; Small performance was not benchmarked.

Evidence: `evidence://sync-sampled-20261018T173847Z/medium-capacity-comparison.json`, `capacity-plan.json`, all per-case commands and raw events, the staged client's build-info source hashes, and `final-small-idle-extended-verification.json`. No server runtime change or speed saving is credited to this measurement.

### Correctness and validation

One streaming endpoint and one current wire protocol remain. No compatibility handler, fallback protocol or compatibility test was added. The HTTP sync experiment is archived only on `reference/http-sync-once-core` and `reference/http-sync-once-benchmark`.

Same-space database locks remain the serialization boundary across processes. Admission serializes users/spaces before opening transactions; unrelated users and spaces do not share that serialization queue, but share global capacity and database/process resources. No transaction waits for peer acknowledgements. Cancellation still uses `transaction.cancel()`.

Recovery retains one timer and two set queries per database context, scheduled 1.2 seconds after the previous scan completes. Local commits send immediate hints. Other processes and caller-owned transactions still rely on polling; cross-pod push is not implemented. Remembering a local revision is a constant-time lookup and does not scan subscriptions or retain new untracked spaces.

**Attempt 12 validation: 79 focused tests passed**, covering recovery, wakeups, duplex lifecycle, snapshots, cancellation, clocks and membership. The new regression failed on base with two redundant captures and passed on the change with zero. Another regression covers a local commit and an external write racing a held recovery read; the external write is delivered without needing a later write. Independent database contexts exercise external recovery locally; multiple hosted podlets were not tested.

Current validation passed 55 focused merge checks and 96 schema/admission/cancellation/clock checks, including the seven new domain batching and five new schema lifetime assertions. The later retry assertions also passed independently; the schema regression fails on the predecessor. The sampled instrumentation passed 27 focused checks and the bounded warmup passed nine existing harness checks. Fatal-info analysis is clean for the current changes. Full CI was not run.

Final source verification matched 50 application files to the companion checkout, including 42 package files also matching the core checkout. The other 143 managed files are deployment-only SDK, bootstrap and migration files and match the deployment manifest. All 193 files and 19 protected config files were verified before the final documentation commit. The client-only warmup change is outside the server deployment manifest. The final two-core insert regression check met offered load; Medium's 64-stream load miss and startup burst failure remain explicit. All measured cases drained before scale-down.

### Earlier results and remaining limits

Fresh syncOnce was not remeasured in attempts 12–22. Historical attempt-11 results were mean 1176 ms, median 1093 ms, p95 1722 ms across 192 individual finite calls. Its 91.397 ms / 7.214% saving used A/B/B/A ordering and an unchanged server executable. The finite-ready change eliminated a second capture in its short trace. Attempt 10's observed 80 ms saving was not fully attributed because its SQL work barely changed. The ledger retains each attempt separately.

Prior transport probes measured established WebSocket ping round trips at 229 ms mean / 228 ms median; fresh default-connector WebSocket setup was 366 / 330 ms, and database-free fresh HTTP was 416 / 338 ms. HTTP was only a diagnostic reference. These include dispatch and processing, not pure propagation; only 16 fresh connections per transport were sampled. Warm SELECT 1 medians were approximately 7–9 ms with a 60.829 ms outlier retained. No database relocation experiment has isolated geographic latency. These are historical probes, not fresh measurements from attempt 12.

Complete outbound snapshots and inbound batches remain buffered. One unacknowledged batch is not a byte or memory bound. Large simultaneous uploads/downloads, conflict-heavy workloads, thousands of idle streams, cross-pod delivery and Small performance are not established. Attempt 22 measures bounded final Medium active/idle workloads; it does not establish general production capacity. The historical 64-idle-stream run used about 0.021 cores and sent zero sync batches; it is not a thousand-stream claim.

High-load full tracing previously overflowed the diagnostics buffer. Selective tracing in attempt 17 retained complete samples at 5.5% mean overhead in its controlled comparison. The Medium profile retained all details but failed the end-to-end duration consistency guard; report its independent server counters only, and resolve the inconsistency before claiming a complete Medium critical-path partition. VM-service GC pauses and isolate counts remain unavailable in Cloud AOT. The original attempt-09 7–15-second continuous anomaly did not reproduce in sequential traced control/changed repeats; its cause remains unknown.

The historical SDK startup patch was experimental and separate from the released dependency. Its source hashes and measurements remain in the ledger; the companion harness review uses SDK Git dependencies in its root manifest. The old patch and application helpers are superseded by SDK implementation and regression coverage. Authentication refresh, opening deadlines, disconnect cleanup and concurrent-method behavior remain requirements.

### Reproduction and evidence

- Current evidence: `evidence://sync-sampled-20261018T173847Z`. Each case retains its exact command, raw events, summary, executable identity and cleanup. Its `final-source-verification.json` verifies all 193 runtime files and 19 protected files. `local/shutdown.json` confirms local PostgreSQL and server shutdown.
- Final measurement deployment: `evidence://sync-21-domain-batching-deploy-20261018T190307Z`; upload/build and executable hashes above. `final-small-idle-extended-verification.json` is the final live capacity receipt; earlier Small receipts are historical intermediate restorations.
- `evidence://sync-sample-run.py LABEL` runs guarded native rounds. Its default original insert client and `--write-mode update` client were held fixed within optimization comparisons. Selective server tracing uses `--sample-users 0,16`; headlines use no detailed tracing. Run one workload at a time with a fresh label, the expected executable, actual CPU quota and zero existing streams.
- `evidence://sync-sample-profile.py LABEL` validates complete paired timelines; never suppress its nonnegative residual guard to publish a partition. The Medium failure is retained alongside `medium-staged64-profile-server-only.json`. `evidence://sync-capacity-analysis.py` restricts quiet capacity to the exercise phase with all expected streams, no active changes and constant change counters.
- Final active Medium measurements use `evidence://sync-capacity-client-20261018/native/bundle/bin/rounds`, SHA-256 `969a3ab35b2ea784382a8e9376ada881e2967c58955ee6f2c8d05cfca84725c4`, four workers and setup concurrency one. This rebuilt client includes current package sources and is not pooled into the older fixed-client controls. Idle runs use `evidence://sync-idle-client-20261018/native/bundle/bin/scale`, SHA-256 `660ea2c237aee74a45c87583373dffa78fba5c017a9a67b1a3d5c889517bd76b`; their build-info source hashes are retained.
- `evidence://sync-capacity-change.py` verifies live size, quota, executable identity and cleanup. `evidence://sync-final-idle-extended.py` restores Small in its finalizer. The final idle runs and escalation gates are in `capacity-plan.json` and `medium-capacity-comparison.json`.
- The final unloaded query probe measured 7.65 ms median, with PostgreSQL SELECT 1 execution of 0.011 ms. `final-xxl-database-plans.json` contains no new hot-query plans because selective tracing deliberately omitted fingerprints on that new pod. The eight attempt-17 read plans, including two WITH plans, remain in `sampled-database-plans.json`. The cumulative pg_stat_statements snapshot is not a per-run delta.
- Prior attempts 13–16: `evidence://sync-roundtrips-20261018T115308Z`; rejected source lookup variants remain on their reference branches. Do not overwrite earlier raw evidence or combine different native clients, workloads or instance sizes into one distribution.
- When rebuilding a native client, keep the isolated SDK copy outside the compiler output directory: `dart build cli` deletes that directory. Restore workspace package resolution afterward; do not modify the global pub cache.

- Attempt-12 evidence: `evidence://sync-incremental-20261018T031007Z`. Each run receipt records its exact command, immutable run ID, `summary.json` and `events.jsonl` paths; the ledger retains their hashes and raw exercise latencies.
- Insert native client: `evidence://sync-ready-client/bundle/bin/rounds`; SHA-256 `d2447d4d25462847e4735329ebb590acaf7f33fec4af726b11598296fc24ffa4`.
- Optimized measurement deployment: `evidence://sync-12-local-recovery-final-deploy-20261018T031736Z`.
- Reversal deployment: `evidence://sync-12-reversal-base-20261018T032728Z`.
- Restored optimized deployment: `evidence://sync-12-reversal-head-20261018T033357Z`. Original manifests, archive/secret-exclusion validations and live receipts are retained. Manifests identify the then-uncommitted source hashes; the ledger associates them with the implementation commits above without rewriting the original receipts.
- Earlier evidence: `evidence://sync-resume-20261017T234757Z` and `evidence://sync-optimization-20261016T140937Z`.

`evidence://sync-incremental-run.py LABEL continuous USERS 1 ROUNDS PERIOD_MS 2 --no-sync-diagnostics` reads the secret internally from the prepared configuration. Use 4 users, 30 rounds, 1000 ms for eight streams; 32 users, 20 rounds, 2000 ms for 64 streams at 16 offered rounds/s. The high-rate check changes the last period to 1000 ms. Workers are `min(users, 8)`; samples are every two seconds and timeout is 45 seconds. The guard requires two actual CPU cores and zero open streams. Run only one hosted workload at a time with fresh labels. Short profiles use four users and eight rounds, with diagnostics enabled.

`evidence://sync-incremental-report.py` computes min, mean, even-sample median and nearest-rank p95. It replaces `case-report.json` with the requested cases, so pass all intended labels. `evidence://sync-incremental-profile-rounds.py` retains complete short-trace counts and same-server latency correlations. The final smoke report is separate from the headline comparisons. `evidence://sync-incremental-scale-down.py` wrote the attempt-12 Small verification.

Attempt 12 intentionally held its experimental client binary fixed. For new builds, use the [companion harness source](https://github.com/marcelomendoncasoares/serverpod_offline_sync/tree/67a993179a21d69dc63e2a04799add78c756ebf8), resolve its root SDK Git dependencies, then use its `benchmark/tool/build_native.dart`. Historical patch receipts identify measured sources; the patch helpers have been superseded by the reviewed SDK source dependencies and are not distributed.

### Next work

1. Resolve the Medium timing/correlation inconsistency with monotonic anchors and explicit frame-to-round identity before publishing an exact cross-stream critical-path partition. Preserve all 40 samples, including the 22 invalid residuals; do not clamp or selectively exclude them. Separate process/diagnostic overhead from useful sync work and obtain CPU throttling evidence if the platform exposes it.
2. Investigate the PostgreSQL driver's awaited portal-close exchange. Unnamed parse/bind/execute are already pipelined; do not assume a separate prepare round trip. Any driver change needs transaction-error, rollback, cancellation and connection-reuse tests plus the same fixed-client delayed-local and Cloud comparisons. Preserve serialization and complete repeatable-read captures.
3. Measure a database close to the same Cloud host when management access is available. The same-machine delay control establishes sensitivity, but different hardware, Dart runtime, TLS and client transport prevent attributing the entire Cloud/local gap to database geography. Keep the sampled 231 ms transport/client residual separate.
4. Recheck fresh syncOnce on the current single streaming protocol, then evaluate larger payloads, conflict-heavy traffic and multiple podlets. Bounded Medium idle capacity is not active-write or reconnect-storm capacity; the 64-stream active offered-load miss remains a limit. Current results do not establish thousands of production devices.
5. Consider shared capture/journal work only with an authorization and checkpoint proof. Retain older unseen facts, clock-then-space lock order, cancellation rollback and postcommit wakeups. No transaction may wait for peers, and no HTTP alternative or legacy protocol path should be added.
