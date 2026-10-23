# Offline sync optimization executive summary

> Historical evidence through 19 October 2026. No tests, benchmarks or
> deployments were rerun for this review split. Deployment states, source
> commits and configuration below describe those experiments. Private paths
> and deployment identities use stable aliases; `evidence://` references
> identify original artifacts that are not bundled in this repository.
> Build and setup references concern the companion code reviews linked in the
> [evidence index](../benchmark/results/README.md). Historical patch descriptions
> are not installation instructions.

Date: 19 October 2026. Scope: `fix/sync-merge-admission` through `3a5619b`, with companion benchmark and SDK changes identified separately.

The branch's central premise is **reduce the work and waiting required for each sync while preserving transaction serialization**. The largest gains came from batching database operations, eliminating duplicate processing, and delivering changes immediately after commits.

The figures below are individual before/after comparisons; **their percentages cannot be added together**. Latency figures are averages unless stated otherwise. Established-stream latency measures local write start to exact application on peers, including local persistence, transport, server processing and peer application. Early verification and cancellation probes measure different operations, as labeled. Sequential Cloud comparisons remain subject to hosting and network variation; fixed SQL-count reductions establish the mechanism more directly.

| Change | Core premise | Measured improvement |
|---|---|---|
| **Queue merges before acquiring connections** | Contending merges should wait outside the database pool. Independent users can proceed concurrently, subject to capacity. | Original single-process probe: **8 database lock waiters → 0**. Prevented the original pool contention pattern; database locks remain necessary across processes. |
| **Centralized cancellation and rollback** | A disconnected stream must release unfinished transaction work promptly. | Median cancellation **35.6 → 13.0 ms**, **63% shorter**. Healthy sync latency stayed essentially unchanged: **2.166 → 2.164 s**. |
| **Batch fresh inserts and simplify ownership checks** | Avoid per-row savepoints and write related rows and trackers together, respecting dependencies. | Fixed 50-row probes progressed from **360 → 160 → 50 SQL statements** across the optimization series—**86% fewer**. The initial ownership change alone reduced observed Cloud verification mean **25.9 → 12.4 s**. |
| **Reuse projection reads and skip unchanged work** | Reuse information within a transaction and rebuild only what the merge can affect. | Projection phase **21 → 8 statements**. Additional targeted probes reduced mixed-workload statements **57 → 43**, and independent-insert workloads **54 → 32**. These overlap the insert optimization series above. |
| **Batch outbound payload reads** | Fetch changed rows by table and space instead of querying each row separately. | Ten-row updates: **651 → 488 ms**, **25% lower**. Fifty-row updates: **1,579 → 752 ms**, **52% lower**; p95 **1,740 → 861 ms**. Insert payload reads were also batched. |
| **Suppress exact echoes** | Do not send a device the same facts it just supplied. | Controlled profile: merge SQL **2,128 → 1,072**, **50% fewer**; process CPU time **32% lower**. No reliable standalone latency improvement. |
| **Wake streams immediately after local commits** | A committed change should trigger delivery immediately instead of waiting for polling. | Eight-stream mean **1,675 → 522–572 ms**, **66–69% lower**. This was one of the largest direct latency improvements. |
| **Share recovery polling and avoid rediscovering local commits** | Keep durable recovery, but share its database work and avoid repeating captures already triggered locally. | Shared recovery uses **two queries per scan**, rather than separate recovery work per stream. Subsequent duplicate-capture removal reduced 64-stream/16-rounds-per-second mean **682 → 497 ms**, **27% lower**, with **19% less CPU**. |
| **Replace lockstep streaming with duplex batches and explicit completion** | Let upload and download progress independently; acknowledge durable batches and finish without redundant control waits or captures. | Boundary pipelining gave approximately **3% improvement against the pre-duplex baseline**. Later readiness/upload coordination reduced fresh `syncOnce` mean **1,267 → 1,176 ms**, **7% lower**, with one capture in all 32 profiled calls. The initial rewrite itself regressed before these refinements. |
| **Consolidate outbound metadata capture** | Read related metadata together inside the same consistent snapshot. | **Two fewer SQL calls per capture**. At 64 streams, observed mean improved **22–33%**, depending on load; the 32-rounds/s comparison was **985 → 661 ms**. |
| **Persist merge progress and clocks together** | Update related transactional bookkeeping in one database exchange. | **Two fewer SQL calls per merge**. Observed mean improved **5–25%**; at 32 rounds/s, **661 → 499 ms**. The roughly four-hour gap between predecessor and candidate limits causal attribution. |
| **Batch authored domain updates** | Apply distinct row edits in bounded batches instead of issuing one statement per row. | Ten-row updates: **526 → 458 ms**, **13% lower**. Fifty-row updates: **771 → 546 ms**, **29% lower**; p95 **853 → 651 ms**. Fifty-row merge SQL **59 → 10 statements**. |
| **Share schema projection rebuilds across sessions** | Initialization work belongs to the shared database context, not every new session. | Eliminated repeated full rebuilds and the reproduced startup failures. Two consecutive 64-stream runs then passed without restarting the server. **No steady-state latency percentage claimed.** |
| **Release transmitted payloads while awaiting ACK** | An outstanding acknowledgement needs compact progress information, not every transmitted row object. | Saved **8.23 MiB** for 1,000 × 8 KiB rows and **16.57 MiB** for 2,000 rows in the held-ACK heap probe. **No latency gain**; observed Cloud mean increased approximately 2.2%. This does not bound peak capture or inbound memory. |
| **Optional cross-process commit notifications** | Devices on different pods should receive prompt wakeups, with durable polling recovering missed notifications. | Two-device Cloud comparison: mean **1,059 → 457 ms**, **57% lower**; p95 **1,580 → 535 ms**, **66% lower**. Requires one additional PostgreSQL session per configured process. Both arms published notifications; the control dropped received hints. This establishes delivery benefit, not notification overhead or multi-pod capacity. |

The benchmark also used a **companion Serverpod client SDK change** that removes a redundant startup ping exchange: fresh `syncOnce` mean **1,574 → 1,319 ms**, saving **255 ms / 16%**. That historical benefit required the SDK startup change; the offline-sync package alone does not supply it. Companion transport fixes also improved cancellation propagation and cleanup.

Instrumentation and benchmark controls were substantial deliverables: queue/transaction/SQL/frame timing, exact convergence checks, CPU quota verification, corrected elapsed clocks, memory probes, and database-delay controls. These improve confidence rather than runtime speed. Selective tracing measured approximately **5.5% overhead**, so headline performance comparisons kept it disabled. The cross-process comparison explicitly used profiling in both arms.

The resulting performance is substantially better, with important limits:

- The latest full **64-stream, 32-rounds/s, two-core** check recorded **597 ms mean / 849 ms p95**. This predates the final memory and cross-process changes.
- Fifty-row updates reached **546 ms mean / 651 ms p95** across eight streams.
- **Medium remains unresolved:** the corrected 64-stream measurement averaged approximately **6.56 s** and could not sustain eight rounds/s.
- Fresh `syncOnce` has not been remeasured on the final head, and thousands of active devices remain unvalidated.
- Controlled database response delay added **128 ms** to average sync time. Database round-trips matter considerably, but the evidence does **not** establish database geography as most of the remaining Cloud delay.

Three experiments contribute **no retained savings**: HTTP `syncOnce` was removed to preserve one streaming protocol; joined source lookup was slower; consolidated outbound preparation was reverted after Cloud failures. The PostgreSQL portal-close experiment remains deferred.

The gains preserve database locking, atomic merges, authorization checks, and snapshot/checkpoint correctness. Correctness fixes include preserving empty insert payloads, transaction cancellation cleanup, retryable schema initialization, and durable completion boundaries. They are not assigned invented latency savings.

## Recommended next work

**Prioritize the database access path for further small-round latency reductions. Keep offline-sync work focused on demonstrated capacity and lifecycle limits.** There is no measured basis for another broad streaming-protocol rewrite now.

The corrected Medium sample spends **4,916 ms of 6,482 ms (about 76%) inside merge and capture SQL calls**. Connection acquisition/BEGIN and commit/release add approximately **778 ms**. Admission queueing averages **0.04 ms**, and recorded non-SQL work inside the transaction bodies totals approximately **32 ms**. SQL spans include database execution, network, driver processing and process scheduling; they do not establish that PostgreSQL execution or geography accounts for 76%. Synchronous driver work can also be charged to these spans.

The older two-core sample gives a different picture: approximately **219 ms SQL**, **231 ms combined transport/client residual** and **50 ms other server time** within a 501-ms sampled mean. Neither sample is the population's p95. Database improvements cannot be assumed to eliminate client/server transport or peer application time.

| Priority | Experiment | Why it is relevant | Measurement required |
|---|---|---|---|
| 1 | **Evaluate the deferred PostgreSQL portal-close experiment only if separately resumed.** | The pinned `postgres` 3.5.20 implementation awaits portal cleanup after a transactional query result. Parse, bind and execute already travel together; the concrete opportunity is the additional cleanup exchange. Serverpod's adapter delegates to this driver. | Compare driver wire exchanges and complete sync rounds with unchanged application logic. Exercise errors, rollback, cancellation, partially consumed results and subsequent connection reuse before judging performance. No saving is predicted yet. |
| 2 | **Compare a nearby database with the current database.** | The calibrated delay control proves sensitivity to repeated database responses, but moving both server and database to the local machine also changes client transport, runtime and hardware. | Keep the Cloud server, benchmark client, workload and dataset fixed; match database version and capacity as closely as possible. Record residual differences. Measure current/nearby database with both baseline and candidate driver so placement and fewer exchanges remain separately attributable. |
| 3 | **Resolve Medium's database/pool slowdown.** | The real local 0.25-core quota plus calibrated delay did not reproduce Cloud's multi-second rounds. The rejected preparation candidate also exposed a connection-acquisition timeout. | Correlate pool acquisition and release, database activity, wire progress, SQL spans and event-loop delay under fixed offered load. Compare direct and pooled database routes only as separate controlled experiments. Do not infer that a larger pool fixes the cause. |
| 4 | **Bound offline-sync backlog memory and apply backpressure.** | Consumed payloads are released, but complete captures, queued unsent frames and inbound batches still scale with backlog bytes. | Measure peak heap/RSS and throughput across backlog size and slow receivers; investigate bounded spooling or buffering while preserving complete enumeration and durable per-origin acknowledgements. Do not keep database transactions open while waiting for peers. |
| 5 | **Measure offline-sync fan-out and multi-pod throughput.** | The two-pod result covers two devices. Many devices can repeat capture and serialization work, and notifications add database traffic. | Vary users, devices per space and pods. Include a transport-disabled control, measure listener/notification cost, and only consider sharing immutable captures where authorization, cursors and snapshot identity permit it. No fan-out saving is established yet. |
| 6 | **Refresh fresh-sync and lifecycle coverage.** | Current-head `syncOnce`, reconnect bursts, conflicts, large backlogs and aged change tables are not covered by the headline results. | Rerun these shapes on the same streaming endpoint; collect hot-query plans as data grows. Optimize only paths that those measurements show to dominate. |

The previous preparation consolidation saved only **5.95 ms / 3.93% locally** and failed both Cloud candidate runs. Its failure should be explained before reconsidering it. This does not prove all remaining offline-sync changes are small; it gives little support for prioritizing that particular rewrite over the measured database exchanges.

PostgreSQL's [extended-query protocol and pipelining documentation](https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY) describes a Parse/Bind/Describe/Execute/Close/Sync sequence and how pipelining reduces round-trips. That makes combining cleanup with a completed execution a reasonable experiment, not a proven-safe driver patch. Error recovery and result-stream lifetimes must remain correct.

The driver inspection was repeated on 19 October. `postgres-3.5.20/lib/src/v3/connection.dart` still matches the recorded SHA-256 `9ee2a66eaf12a3a2d9777dedd9768759705b528a2a8af94105407c6274419609`. Its `_PreparedStatement.run` awaits `_closePendingPortals`; the Serverpod 4.1.0-beta.3 PostgreSQL adapter's `_query` calls the resolved driver's `execute`. This recommendation concerns that inspected implementation, not an assertion about every driver version.

This report adds recommendations only. It does not resume the deferred driver experiment, relocate the database, deploy code or claim new benchmark results.

## Evidence

- [Optimization ledger, attempts 1–26](../benchmark/results/2026-10-16-sync-optimization.json).
- [Consolidated benchmark report through attempt 22](sync-benchmark-results-2026-10-18.md).
- [Attempts 23–26, corrected Medium attribution, memory and cross-process results](sync-optimization-followup-2026-10-19.md).
- [Performance handoff and reproduction details](sync-performance-handoff.md).
- [Streaming protocol design](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/streaming-sync-protocol.md) and [commit notification setup](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/commit-hints.md).
- Initial admission and cancellation artifacts: `evidence://sync-admission-evidence/results.json`, `evidence://sync-transaction-cancel-evidence/results.json`, and the subsequent adoption receipt `evidence://sync-transaction-cancel-evidence/adoption/validation.json`.
- Initial SQL/Cloud comparisons: `evidence://sync-upsert-final-deploy-ifydpb30/comparison.json` and the `comparison.json` files under `evidence://sync-stage1-deploy-wx6flid7`, `evidence://sync-stage2-deploy-er36zasl`, `evidence://sync-stage4-deploy-qex4346g`, `evidence://sync-stage6-deploy-2h1huso9`, and `evidence://sync-stage7-deploy-uh4ms01j`.
- Database exchange evidence: `evidence://sync-sampled-20261018T173847Z/local/driver-exchange-evidence.json`.

Temporary artifacts are local evidence locations; the checked-in reports and ledger retain the later measurements and their qualifications. No performance tests were rerun to create this summary.
