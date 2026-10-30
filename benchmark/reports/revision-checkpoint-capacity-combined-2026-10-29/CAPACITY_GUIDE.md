# Native TLS capacity with durable revision checkpoints

The completed campaign contains **345 measured cases: 324 discovery cases and 21 qualification cases**, covering Small, Medium, Large, XL and XXL. Every tier/schema pair has a qualifying five-minute, one-row operating point. The independent audit recalculated statistics from **138,897 raw round events**, including **111,423 completed exercise rounds**; the latter includes completed rounds from unsuccessful trials. All 75 planned tier/schema/row cells are accounted for by measurements or justified skips. Larger loads were skipped after an unsuccessful comparable lower load.

The results use the durable replica revision checkpoint implementation, including removal of the echo cache, with **native PostgreSQL TLS enabled and pipelining disabled**. Server source is `be5a9076ef7d165dd728f0ff99bff0096293ec2a`, client source is `87451ccf2733f8792d90988f8e23aebfbe1bcb17`, and all runs use the same verified server and client binaries. See the [build provenance](../revision-checkpoint-capacity-2026-10-29/ARTIFACT_PROVENANCE.json), [manifest](manifest.json), and [source reports and hashes](sources.json).

The runtime reference is preserved on `perf/checkpoint-capacity-runtime-20261029`; the runner and reports are on `perf/checkpoint-capacity-validation`. The measured client snapshot differs from the runtime reference only in an integration test file: all tracked runtime code and dependency manifests are identical. [Runtime reference details](RUNTIME_REFERENCE.json) retain both original source identities. Use the runtime reference when preparing server/client builds, and the runner branch for the measurement tooling.

## Qualified operating points

Cells show participating devices and p95 milliseconds for **one row per round**, two devices per user, and one offered round per user every two seconds. These are the largest qualifying sustained points selected by the tested brackets. They are starting points for application validation, not exact hardware maxima. The idle column is a separate idle/resume workload and cannot be combined with an active-device column as though that joint load had been tested.

| Tier | Person: devices / p95 ms | Linked Town: devices / p95 ms | Isolated City: devices / p95 ms | Strict idle/resume trial |
|---|---:|---:|---:|---:|
| Small | 8 / 1990 | 4 / 960 | 8 / 883 | 256 |
| Medium | 4 / 443 | 32 / 1736 | 32 / 652 | 1024 |
| Large | 64 / 682 | 16 / 413 | 64 / 497 | 128 |
| XL | 64 / 450 | 64 / 464 | 128 / 420 | 512 |
| XXL | 64 / 466 | 128 / 535 | 128 / 422 | 1024 |

The [qualified-round table](QUALIFIED_ROUNDS.md) includes min, median, mean, p95, max, sample counts and actual overlap. The [full volume matrix](SIZING.md#active-devices) covers 1, 10, 50, 200 and 1,000 rows, with conditional 5,000-row extensions. Those volume brackets are eight-round screens; the five-minute qualification applies to one-row rounds. [Every measured case](README.md) retains its statistics and verdict.

Several lower selections reflect reliability failures, so these counts are not a monotonic CPU ranking:

- **Medium Person:** its eight-device sustained run ended unexpectedly before verification. Four devices subsequently qualified. The short 32-device screen is retained, but is not a sustained qualification.
- **Large linked Town:** the 32-device setup attempt lost its control HTTP connection. Sixteen qualified for five minutes; this does not prove a processing ceiling at 16.
- **Large idle:** a 256-device idle trial lost a stream, so 128 is the strict idle/resume selection. A separate **256 connected / 8 active** mixed trial did pass, at 442 ms p95 over 120 rounds.
- **XL Person:** 128 passed its short screen but failed warmup in the sustained attempt. The 64-device sustained trial qualified.
- **XXL idle:** 2,048 devices were observed through idle and resumed delivery, and **all 1,024 users passed exact verification**. One unexpected stream end during close failed the lifecycle gate. Consequently 1,024 remains the strict idle/resume selection. The 2,048-device probe timings and failed verdict remain available.

Small's 512-device and Medium's 2,048-device refinements failed during warmup with sampling failures and many stream ends; Medium also changed server instance. Their peak sampled memory was 235.8 MiB of 256 MiB and 475.7 MiB of 512 MiB, respectively. Those observations are consistent with little memory headroom, but do not prove an out-of-memory kill or the maximum memory reached. Other setup, stream and close failures do not establish hardware ceilings.

## Mapping an application to the measurements

1. **Match schema behavior.** Isolated City has one persisted name field and no larger registry. Person writes two text fields with nullable relations unpopulated in the full registry. Linked Town writes its name and populated City/Person references, with parents seeded first. Field count alone is not a proxy for relationship validation or projection work.
2. **Choose the usual and high-percentile row volume.** Use the matching row count in the volume matrix. For intermediate or larger batches, validate that workload rather than interpolate a hard limit. At 1,000 rows, only isolated City kept the offered cadence: four participating devices on Large and XL, eight on XXL. None of these 1,000-row points met a one-second p95. Person and linked Town did not qualify at 1,000 rows even at the smallest two-device point. The conditional 5,000-row trials did not keep up.
3. **Count connected and active devices separately.** Registered accounts that are offline do not represent live streams. Connected idle devices consume a different budget from users regularly writing. With this two-device, two-second workload, 64 participating devices offer 16 rounds/s and 128 offer 32 rounds/s. Actual overlapping work is reported separately; the tests do not mean that every participating device writes at precisely the same instant.
4. **Select a candidate tier with headroom, then test the joint workload.** Match both the active and idle requirements, check the latency target separately from throughput, and validate the actual connected population plus active rate together. Test reconnect bursts, longer idle periods, and representative retained data. These measurements do not establish multi-instance scaling or a thousands-of-active-devices guarantee.

Examples supported by the observations:

- **A few devices, small simple changes:** Small sustained eight isolated-City devices at 883 ms p95, while eight Person devices had 1,990 ms p95. The schema path materially changes the starting point.
- **A regular stream of independent Person updates:** Large sustained 64 participating devices at 682 ms p95. XL and XXL also qualified 64, at 450 and 466 ms. This supports Large as an application-validation starting point for that load, subject to its connected population; the trials do not establish a causal XL-versus-XXL speed difference.
- **Populated relationships with a one-second latency target:** Medium sustained 32 linked-Town devices but had 1,736 ms p95. XL sustained 64 at 464 ms p95. Throughput success alone is insufficient for a subsecond objective.
- **Many open streams with little active work:** Large's measured 256-connected/8-active control passed at 442 ms p95. Small's corresponding control converged but fell behind, at 2,593 ms p95. These were 120-round mixed controls, not five-minute qualifications.
- **About 1,000 mostly idle connections:** Medium and XXL both completed 1,024-device idle/resume trials, with probe p95 of 1,903 and 441 ms. Probes covered every idle user with at most eight users being probed concurrently. A 1,024-connected population with continuous application writes still requires a joint workload test.

## The sustained Person bottleneck

XXL's 128-device Person trial completed all 9,600 exercise rounds and exact verification, but delivered **25.43 rounds/s against 32 offered**, with 2,499 ms median and 2,814 ms p95. Reducing the participating population to 64 qualified at 15.98 rounds/s against 16 offered, with 386 ms median and 466 ms p95.

The sampled user0 uploads show where to investigate next:

| XXL Person workload | Sampled transactions | SQL statements/round | Mean merge SQL wall ms | Mean conflict/reference-planning SQL ms |
|---|---:|---:|---:|---:|
| 128 participating devices | 150 | 10 | 1,933.2 | 1,781.7 |
| 64 participating devices | 150 | 10 | 95.4 | 53.3 |

One SQL statement in `planConflictsAndReferences` accounts for about **92% of sampled merge SQL wall time** at 128 devices. Its in-memory phase overhead was small relative to the SQL call. SQL wall time includes database execution, driver handling, network and scheduling; it is not a PostgreSQL execution plan. These sequential trials also have different retained data sizes. Capture database-side timing and an execution plan for that statement under load before choosing an optimization. The [phase profile](XXL_PERSON_PHASE_PROFILE.json) records the source trace hashes and exact aggregation scope.

The [300 extracted transaction samples](XXL_PERSON_PHASE_SAMPLES.jsonl) allow those phase means to be recalculated without the private collector files.

## Method and limits

The benchmark measured incremental rounds on **established continuous streams**. Startup, initial synchronization, verification and close were separate measured phases and part of the success gate. These results are not syncOnce startup timings. Latency runs from the local write through application on all peers, including the benchmark machine's network path.

Each user had a separate personal space shared by its two devices. Same-space merges still serialize; a shared hot space with many writers needs its own test. The server used a database pool limit of 100, global merge admission limit of 50, disabled persistent/console session logging, and disabled cross-process commit hints. There was one Cloud instance at a time. PostgreSQL placement was unchanged and remote; separate full-registry and City-only campaign databases were retained across sequential cases. Exact starting domain counts are recorded per run, while ending table counts are estimates. This is not an isolated comparison of CPU tiers, database locations, or database sizes.

Visible CPU quotas were 0.1/0.25/0.5/1/2 cores and memory limits 256/512/1,024/2,048/4,096 MiB. **CPU accounting has unresolved discrepancies:** do not infer actual enforced CPU capacity, headroom or throttling from those counters. See the [resource-accounting evidence](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md). Connection counts limited by setup or transport failures remain distinguished from throughput failures.

The full results preserve failed and partially observed trials. A passing finite run does not prove long-term reliability. Larger comparable loads were pruned after failures; they are recorded as unmeasured, not as observed failures. The prior 391-case cached-checkpoint campaign remains a separate baseline; [the controlled checkpoint comparison](../revision-checkpoint-first-comparison-2026-10-29/COMPARISON_NOTES.md) is the appropriate source for matched before/after claims.

## Replay, audit and restoration

The public [capacity runner](../../tool/capacity/README.md) automatically visits all five tiers, brackets active users and row volume, skips heavier comparable failures, and performs the sustained qualification and idle refinements. Replay files retain measured cases and configuration identities. Supply local credentials/configuration as documented; no secrets are included in these reports. The combiner CLI regression discovered at publication was fixed and checked through its actual command entry point; six combiner and 36 capacity-runner tests pass.

The [measurement audit](MEASUREMENT_AUDIT.json) verifies runtime/configuration identities, raw latency statistics, coverage, skip justifications, qualification decisions and unchanged combined observations. [Failure notes](FAILURE_NOTES.json) supplement the per-case interpretations with the remaining setup/exercise/close distinctions. The original Cloud executable and configuration were restored on **one Small instance**, with all 11 protected files unchanged, no open streams and no idle-in-transaction connections; [the independent restoration check](RESTORATION.json) records the verification time. Historical source-manifest restoration flags are snapshots, not a statement of the current deployment.
