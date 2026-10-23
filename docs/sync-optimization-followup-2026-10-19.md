# Sync optimization follow-up — 19 October 2026

> Historical evidence through 19 October 2026. No tests, benchmarks or
> deployments were rerun for this review split. Deployment states, source
> commits and configuration below describe those experiments. Private paths
> and deployment identities use stable aliases; `evidence://` references
> identify original artifacts that are not bundled in this repository.
> Build and setup references concern the companion code reviews linked in the
> [evidence index](../benchmark/results/README.md). Historical patch descriptions
> are not installation instructions.

This follows proposals 2, 3, 4 and 5 from the [previous report](sync-benchmark-results-2026-10-18.md). The PostgreSQL portal-close experiment (proposal 1) is deferred at the user’s request. Each attempt is changed, validated, measured, recorded and committed separately. One streaming protocol, database serialization, cancellation rollback and complete snapshot/checkpoint safety remain requirements.

## Attempt 23 — Medium attribution and observer controls

All latency values below are milliseconds from local write start until exact application on every peer, after warmup. Each user has two devices. The 64-stream cases offer eight one-row rounds/s; the eight-stream case offers 2.67. The original fixed client uses Stopwatch; rows named raw use a rebuilt client whose Linux intervals use CLOCK_MONOTONIC_RAW. Do not pool or directly credit speed savings across this clock change. “Rate met” is separate from exact convergence.

| Run | n | Min | Mean | Median | p95 | Max | Rate met |
|---|---:|---:|---:|---:|---:|---:|---|
| quota-base8 | 80 | 22.5 | 25.7 | 24.7 | 29.1 | 78.5 | Yes |
| quota-base64 | 640 | 22.6 | 28.4 | 25.9 | 36.5 | 376.0 | Yes |
| quota-delay64 | 640 | 128.4 | 135.8 | 133.8 | 147.9 | 246.8 | Yes |
| quota-delay-off64 | 640 | 128.1 | 136.9 | 133.6 | 154.4 | 238.3 | Yes |
| quota-profile64 | 640 | 128.8 | 138.8 | 136.0 | 156.3 | 232.1 | Yes |
| medium-base64 | 640 | 560.3 | 6102.5 | 6011.9 | 7709.2 | 11404.5 | No |
| medium-profile64 | 640 | 771.7 | 6501.4 | 6490.1 | 7692.6 | 12757.1 | No |
| quota-raw-base64 | 640 | 139.3 | 151.2 | 147.6 | 166.1 | 402.6 | Yes |
| medium-raw-profile64 | 640 | 781.4 | 6563.2 | 6686.6 | 7492.6 | 8802.2 | No |

The local server is constrained by a real systemd cgroup to 25,000 µs per 100,000 µs period. PostgreSQL and the client remain outside that quota. The delay cases add 3 ms to each arriving PostgreSQL response chunk without accumulating delays between concurrent chunks. Direct local, delayed local and Cloud remain distinct environments; the local hardware, TLS path and Dart patch differ.

**No CPU or logging speedup is credited.** Disabling local benchmark diagnostics changed the mean from 135.8 to 136.9 ms. The local quota and calibrated database delay do not reproduce the Cloud slowdown. The diagnostic JIT CPU profile spans socket handling, async dispatch and allocation; it does not justify an application hot-function rewrite. Its 172.3 ms average is not pooled with AOT results.

### Clock correction and Cloud timing

All 40 explicitly matched sampled rounds have valid additive partitions. Matching uses the benchmark’s authored row/round/writer and numbered frames; all server timestamps share one isolate monotonic clock. No wall-clock conversion, ordinal pairing or clamped residual is used. The sampled mean is 6482.0 ms; it is distinct from the full run above.

| Component | Sampled mean ms |
|---|---:|
| mergeQueue | 0.04 |
| mergeSourcePreparation | 0.05 |
| mergeConnectionAndBegin | 174.23 |
| mergeSql | 3661.89 |
| mergeNonSql | 24.34 |
| mergeCommitAndRelease | 209.37 |
| mergeOther | 0.41 |
| afterMergeBeforeCapture | 223.00 |
| captureConnectionAndBegin | 196.86 |
| captureSql | 1254.49 |
| captureNonSql | 8.11 |
| captureCommitAndRelease | 197.57 |
| captureOther | 217.05 |
| afterCaptureBeforeYield | 2.62 |
| transportAndClientResidual | 311.99 |

The local machine clock was being slewed relative to CLOCK_MONOTONIC_RAW: a ten-second probe differed by 9.1 percent, and read-only adjtimex reported tick 9427 µs. The earlier explicit-identity Cloud trace still had 34 negative residuals and is retained as rejected. The new native client uses raw monotonic intervals; no operating-system clock setting was changed. A recovered DNS failure in the earlier collector caused no missing sequences and is retained in the raw receipt.

SQL time includes database execution, transport, driver work and process scheduling. Connection time includes BEGIN; the residual includes both network directions and client work. These measurements do not isolate geographic latency or a precise CPU-throttling fraction. Cloud VM/GC and throttled-time counters remain unavailable.

The retained change fixes diagnostic correlation and nested cgroup discovery. A bounded-warmup test failure was reproduced on the unchanged baseline and repaired in the harness. Validation: three core diagnostics tests, 28 benchmark tests plus the elapsed-clock check and clean analysis of eight changed benchmark Dart files. The deployment archive preserves 19 protected configuration/secret files and matches 194 runtime files; password files and secret bytes are excluded.

Evidence: `evidence://sync-next-20261019T005150Z`; full distributions, source identities, CPU samples, individual correlated rounds and cleanup receipts are retained in the [optimization ledger](../benchmark/results/2026-10-16-sync-optimization.json). Every completed run converged exactly and drained to zero streams and idle transactions. Full CI was not run.

## Attempt 24 — Outbound preparation (rejected)

The candidate resolved current grants and database space identities together, eliminating the separate authoritative identity lookup before capture. Membership was refreshed on every pass; the complete repeatable-read capture and permission checks remained. It passed 48 focused checks and 12 real PostgreSQL integration checks.

The local delayed-database A/B/B/A comparison used the same raw-clock client, 64 streams, one row per round, eight offered rounds/s, 0.25 server cores and 640 rounds per run. All four runs met the rate and converged.

| Local run | Mean ms | Median ms | p95 ms | Max ms |
|---|---:|---:|---:|---:|
| quota-raw-base64 | 151.21 | 147.56 | 166.11 | 402.61 |
| quota-grants64 | 144.34 | 143.18 | 155.59 | 172.17 |
| quota-grants64-b | 146.91 | 143.19 | 170.28 | 348.94 |
| quota-raw-reversal64 | 151.95 | 149.78 | 167.36 | 238.12 |

Pooling the two baseline and two candidate populations separately gives **151.58 → 145.63 ms mean**, a **5.95 ms (3.93%)** local saving. Their pooled p95 values are 166.96 and 162.42 ms; percentiles are computed from all rounds, not averaged.

**No saving is retained.** Both candidate Cloud Medium runs failed, after only 125 and 164 successful measured rounds. Streams ended unexpectedly; the first run also logged a PostgreSQL connection-acquisition timeout. The baseline restored on a fresh pod then completed all 640 rounds: 7008.45 ms mean and 8988.00 ms p95, though it still missed the offered rate. All three runs drained to zero streams and idle transactions. The pool failure's precise cause remains unresolved; the evidence is sufficient to reject the candidate pending reliable Cloud validation, not to claim that its SQL itself timed out. Partial failed-run distributions remain in the ledger and are excluded from savings.

The candidate is preserved on `reference/resolved-outbound-grants`: core `1d22388`, companion `b515eff`. The active branches and deployed runtime were restored to the prior implementation. Only four runtime files differed in the deployment archive; all 19 protected configuration/secret files remained unchanged. The planned two-core candidate run was dropped after the reliability gate; its baseline is reused for the following memory experiment.

## Attempt 25 — Release sent payloads while awaiting ACK (retained)

An outstanding batch now keeps the maximum HLC for each space/origin instead of retaining every change and domain row. The vector is built only after the complete snapshot has been collected, includes exact echo-suppressed facts, and advances only after the matching committed ACK. Transaction boundaries, database locks and the streaming protocol are unchanged.

The VM probe consumes every frame, holds the peer ACK, forces GC and checks the live heap. It then acknowledges, authors a newer row, verifies delivery without resending committed rows and closes the session. Both variants have zero active transactions at every barrier and zero session objects after closure.

| Payload | Baseline held heap MiB | Candidate held heap MiB | Saving MiB | Retained row objects, before → after |
|---|---:|---:|---:|---|
| 1000 × 8 KiB | 52.08 | 43.85 | 8.23 | 1000 → 0 |
| 2000 × 8 KiB | 60.83 | 44.26 | 16.57 | 2000 → 0 |

This removes payload retention **after transmission**. Complete outbound capture, queued unsent frames and inbound batches can still consume memory proportional to backlog size. There is no peak-memory or large-backlog capacity claim. A future byte bound must preserve complete snapshot enumeration, for example with bounded spooling; acknowledging partial enumeration by maximum clock would be unsafe.

The separate 64-idle-stream diagnostic JIT run increased post-GC heap from 78.81 to 81.45 MiB and returned to 79.68 MiB after disconnect. All 64 session, space-state, subscription, wrapper and recorder objects disappeared. Cgroup charged memory was 921.75, 897.14 and 909.20 MiB at those barriers, respectively; it includes compiler/runtime memory and is not a per-stream allocation estimate or Cloud capacity prediction.

Each latency row below pools two complete 640-round runs of the fixed raw-clock client: 64 streams, 32 users, one row and eight offered rounds/s. Local uses the 0.25-core quota plus 3 ms response-chunk delay; Cloud uses two cores. All runs met the offered rate and exact convergence, then drained to zero streams and idle transactions.

| Environment/build | n | Min ms | Mean ms | Median ms | p95 ms | Max ms |
|---|---:|---:|---:|---:|---:|---:|
| localBase | 1280 | 139.28 | 151.58 | 148.77 | 166.96 | 402.61 |
| localCandidate | 1280 | 132.44 | 150.08 | 147.95 | 165.72 | 445.65 |
| cloudBase | 1280 | 370.95 | 474.20 | 467.92 | 570.59 | 734.29 |
| cloudCandidate | 1280 | 362.33 | 484.77 | 471.56 | 597.65 | 1349.88 |

**No latency saving is credited.** Cloud mean increased by 10.57 ms (2.23%) in this deployment pair, while local mean changed by -1.50 ms. The memory saving justifies retaining the small centralized change; the measured tail increase remains visible rather than being described as a speedup. Different Cloud pods and time windows limit causal latency attribution.

Validation: 50 focused checks including independent origin clocks, 12 PostgreSQL integration checks, clean analysis of the changed runtime and space-state test, and a clean analyzed heap probe. The companion contains `benchmark/tool/retained_batch_probe.dart` and `benchmark/tool/profile_retained_batch.py`; run the controller with an output directory, fresh label, row count and payload bytes. The deployment archive changed only two runtime files and preserved all 19 protected configuration/secret files.

## Attempt 26 — Prompt cross-process commit hints (retained, opt-in)

The server can now own a reconnecting PostgreSQL hint transport. Successful owned commits enqueue space/revision UUIDs after the original transaction finishes. A dedicated session publishes `pg_notify`; other processes wake their existing listeners. Hints carry no rows, grant no permissions and advance no checkpoints. Fresh membership reads, complete capture, database serialization and the durable 1.2-second recovery cycle remain. Rollbacks publish nothing, and publication failures cannot undo a committed write. See [setup and failure semantics](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/commit-hints.md).

Each environment uses A/B/B/A on the same two running processes and the same raw-clock native client. Both arms publish the same notifications; the control deliberately drops received hints before delivery to the context. It therefore measures the benefit of prompt delivery while also proving recovery from missed hints. It does not measure notification overhead versus having no transport.

Each run has one user and two continuous devices, alternating one-row authorship over 20 timed rounds at a requested 1700-ms period. The placement barrier proves different processes **before** measurement. Same-pod placements are retained and excluded before any timed rounds; selection never uses latency. Local uses two 0.25-core processes and local PostgreSQL. Cloud uses two two-core pods and the existing remote database.

Both client and selected server streams retain detailed diagnostics in both arms. These are **profiled mechanism comparisons**, separate from the earlier untraced single-pod headline results. There is no collector HTTP traffic during the timed exercise, no dropped diagnostic pages, and no subtraction of timestamps from different processes. Every eligible run met its schedule, verified the complete server and replica journals without repair syncs, and drained both processes to zero streams and idle transactions.

| Environment / hint delivery | n | Min ms | Mean ms | Median ms | p95 ms | Max ms |
|---|---:|---:|---:|---:|---:|---:|
| Local / deliberately dropped | 40 | 147.87 | 806.12 | 822.85 | 1313.86 | 1335.68 |
| Local / delivered | 40 | 25.59 | 27.99 | 27.36 | 31.40 | 35.31 |
| Cloud / deliberately dropped | 40 | 460.85 | 1058.76 | 1078.96 | 1579.65 | 1806.01 |
| Cloud / delivered | 40 | 375.48 | 457.24 | 450.23 | 535.20 | 601.85 |

The pooled local mean saving is **778.13 ms (96.53%)**; Cloud saves **601.52 ms (56.81%)**. Cloud p95 falls by **1044.45 ms (66.12%)**. Percentiles use the pooled 40 rounds per arm, not an average of run percentiles. These savings address cross-process polling wait and are not added to the earlier single-pod savings.

The cost is one additional session-capable PostgreSQL connection per configured process plus asynchronous notification statements. Pending hints coalesce by space, with 1024 queued spaces and 64 UUID pairs per notification. A direct endpoint or session pool is required for LISTEN; the benchmark selects the corresponding direct endpoint when the configured host is Neon's pooled hostname, without changing application database pooling. The public adapter requires an explicitly suitable endpoint. Connection state and queue-drop counters are observable. Durable polling remains necessary through disconnects, missed or reordered hints, and the gap between the database commit and notification publication.

Validation: four real PostgreSQL transport checks (bounded payloads, connection termination/reconnection, malformed messages and shutdown), three owned-transaction publication checks, ten recovery checks including revocation after a delayed hint, and fifteen benchmark checks including twelve PostgreSQL integration checks. Listener reconnection and revocation were exercised locally; the Cloud runs prove separate-pod delivery and missed-hint convergence. Changed runtime, new tests and benchmark code analyze cleanly; two existing informational nullable-cast lints remain in the older recovery test file. Full CI was not run.

The deployment archive matches 198 managed runtime files. Eighteen protected source files remain byte-identical; the server package pubspec has only the direct PostgreSQL dependency added. The existing secrets and server configuration are preserved, and password files and secret bytes are absent from the archive. The ledger retains all source/executable identities, placement exclusions, raw CPU ticks, RSS observations, transport counters and cleanup receipts. CPU/RSS intervals include warmup and collection and do not support a CPU or memory saving claim for this attempt.

## Outcome and remaining work

| Requested proposal | Outcome | Credited improvement |
|---|---|---|
| 1. Portal-close driver experiment | Deferred as requested | None |
| 2. Medium CPU/observer investigation | Corrected correlation and raw elapsed clock; no evidence-backed CPU rewrite | Diagnostic accuracy only |
| 3. Outbound preparation | Rejected after two Cloud failures; reference branches retained | No retained saving; local candidate saved 5.95 ms |
| 4. Retained memory | Retained compact per-origin ACK vectors | 8.23–16.57 MiB less held heap for the measured payloads; no latency gain |
| 5. Cross-process wakeups | Retained optional transport with durable fallback | Cloud cross-pod mean 1058.76 → 457.24 ms |

The deployment is restored to **one Small instance**, with actual CPU quota **0.1 cores**, zero open streams and zero idle transactions. Commit hints are disabled on this single pod, while the tested implementation remains deployed and available through initialization. Persistent and console session logging remain disabled. Local servers, their PostgreSQL database, probes and CPU scopes are stopped. Small was checked for readiness and cleanup only; no Small capacity or fresh-syncOnce result is claimed.

The Medium throughput problem remains unresolved. Next investigate the rejected preparation candidate's pool-acquisition failure under controlled load before revisiting that change; measure high-load notification overhead and multi-pod throughput separately from this two-device result; and measure peak backlog bytes before designing bounded spooling or backpressure that preserves complete enumeration. Fresh syncOnce, conflict-heavy traffic and reconnect bursts also need current-code measurements. Keep the portal-close experiment deferred until explicitly resumed, and keep one streaming protocol with no compatibility layer.
