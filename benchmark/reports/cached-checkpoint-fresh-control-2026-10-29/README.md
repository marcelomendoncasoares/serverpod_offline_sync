# Native TLS capacity measurements

This is the cached/HLC implementation's fresh-database control for the durable revision-checkpoint comparison. It uses the same cached server executable as the [391-case baseline](../native-tls-capacity-baseline-combined-2026-10-29/README.md), but separate databases. It is not a measurement of the checkpoint candidate.

The 16-case plan produced 12 measurements and four explicit skips. All 12 measured cases converged, had complete diagnostics, and drained cleanly. Five kept up with the offered two-second cadence and seven fell behind. There were 512 measured exercise rounds; `rounds.jsonl` additionally retains warmup rounds.

The stopping rule skipped Medium linked Town at 1,000 rows and Small Person, linked Town and City at 1,000 rows after their respective 200-row controls fell behind. Those skipped cases are unmeasured, not measured failures. The [replay matrix](replay.json) contains the 12 executed cases; [skipped-cases.json](skipped-cases.json) retains the remaining four and their blocking observations.

Use [planned-matrix.json](planned-matrix.json) to rerun the full 16-case comparison on a new implementation. Its stopping decisions depend on that new run: a case skipped on this baseline may be attempted if the new implementation passes its lighter predecessor.

## Redundant uploads in the cached implementation

With one user and two devices, each 1,000-row exercise round produced an upload of the authored rows followed by another upload on the other stream carrying the same round/writer marker. These observations reproduce the received-cache overflow pattern and provide a direct control for the checkpoint replacement.

| Profile | Authored rows | Rows received by server | Additional peer-upload rows | Merge transactions per round | Merge SQL statements per round |
|---|---:|---:|---:|---:|---:|
| Medium Person, eight 1,000-row rounds | 8,000 | 14,264 | 6,264 | 2 | 23 |
| Medium City, eight 1,000-row rounds | 8,000 | 14,216 | 6,216 | 2 | 16 |

The Person trace contains eight 1,000-row and eight 783-row uploads; City contains eight 1,000-row and eight 777-row uploads. Counts exclude warmup and cover both devices of the single active user. Exact final data still converged, but both workloads missed their offered rate. Per-round markers, counts and transaction measurements are preserved in each case's interpretation in [results.json](results.json).

## Sampled cost as concurrency increased

The Medium one-row controls each sampled eight uploads from one user. User/space merge queue time stayed below 0.1 ms while SQL wall time, transaction begin and commit grew with concurrency. This differs from the accumulated XXL Person case, where a single dependency-planning statement dominated.

| Participating devices | Offered rounds/s | Mean sampled merge SQL wall (ms) | Connection and begin (ms) | Commit and release (ms) | Statements per sampled merge |
|---|---:|---:|---:|---:|---:|
| 8 | 2 | 41.13 | 3.87 | 4.87 | 10 |
| 32 | 8 | 245.07 | 17.39 | 26.78 | 10 |
| 64 | 16 | 1,560.11 | 218.26 | 173.38 | 10 |

These sampled merge costs do not decompose every end-to-end round or isolate database execution from driver, network and scheduling waits. CPU accounting has unresolved discrepancies; see the [accounting observations](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md) before inferring effective CPU limits, headroom or throttling.

Each case records exact Person, Town and City table counts before execution. Post-run counts are marked as non-exact and are not used to establish matching starting datasets. Both comparison arms start with fresh databases, but different pruning decisions can change later accumulated datasets. Check the exact starting counts when assessing matched latency changes. The control restored its own starting configuration; final restoration of the original executable and configuration on Small remains a separate campaign obligation.

## Complete measurements

Status: measured. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.

Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.

Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. Failed runs retain their completed observations, which must not be interpreted as successful-run latency.

| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| medium-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 305.2 | 324.1 | 337.9 | 425.4 | 486.4 | True / True |
| medium-full-person-r1-c32-a32-spread-t2 | 32 / 32 | 1 | 128 | 439.6 | 817.4 | 809.9 | 1009.9 | 1062.9 | True / True |
| medium-full-person-r1-c64-a64-spread-t2 | 64 / 64 | 1 | 256 | 478.4 | 3688.8 | 3616.2 | 4989.7 | 5485.1 | True / False |
| medium-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1035.3 | 1188.2 | 1167.6 | 1278.0 | 1278.0 | True / True |
| medium-full-person-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 5016.5 | 6240.4 | 6211.0 | 7131.0 | 7131.0 | True / False |
| medium-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 1437.9 | 2789.6 | 2572.3 | 3871.2 | 3871.2 | True / False |
| medium-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 830.4 | 926.1 | 963.8 | 1283.9 | 1283.9 | True / True |
| medium-city-city-r1000-c2-a2-spread-t2 | 2 / 2 | 1000 | 8 | 3660.5 | 4147.9 | 4245.9 | 5272.7 | 5272.7 | True / False |
| small-full-person-r1-c8-a8-spread-t2 | 8 / 8 | 1 | 32 | 604.2 | 807.4 | 793.2 | 1011.1 | 1012.9 | True / True |
| small-full-person-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 2373.6 | 2617.9 | 2596.4 | 2845.1 | 2845.1 | True / False |
| small-full-town-linked-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 3453.2 | 7148.2 | 6925.3 | 9572.9 | 9572.9 | True / False |
| small-city-city-r200-c2-a2-spread-t2 | 2 / 2 | 200 | 8 | 2191.2 | 2368.9 | 2385.4 | 2590.4 | 2590.4 | True / False |

The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.

## Idle connections and resumed delivery

Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.

| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |
|---|---:|---:|---|---:|---|---:|---|

Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.

## Skipped heavier cases

These cases were not measured because an equal or lighter comparable load did not pass. They do not establish a measured capacity limit. See `skipped-cases.json` for parameters and blocking verdicts.

| Skipped case | Blocking measurement |
|---|---|
| medium-full-town-linked-r1000-c2-a2-spread-t2 | medium-full-town-linked-r200-c2-a2-spread-t2 |
| small-full-person-r1000-c2-a2-spread-t2 | small-full-person-r200-c2-a2-spread-t2 |
| small-full-town-linked-r1000-c2-a2-spread-t2 | small-full-town-linked-r200-c2-a2-spread-t2 |
| small-city-city-r1000-c2-a2-spread-t2 | small-city-city-r200-c2-a2-spread-t2 |
