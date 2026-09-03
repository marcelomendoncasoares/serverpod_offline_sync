# Merge projection performance

Status: **options 1 and 2 implemented, projection gate restored; 3–6 still open.**

Merging inserts is roughly two orders of magnitude slower than merging updates
or deletes, and the gap widens as a scope fills up. This document records the
measurements, the cause, and the options for fixing it.

Related documents:

- [Rebuildable FK and unique projection strategy](rebuildable-projection-strategy.md)
- [Foreign-key projection invariants](foreign-key-invariants.md)
- [Unique-constraint invariants](unique-constraint-invariants.md)

## Result

Measured with `benchmark/merge_only.dart`, 500 changes per batch, SQLite, 22
synced tables, one scope. The pre-work column is `d3c2a96`, the last commit
before the projection redesign, measured with the same instrumented benchmark:
it is the bar to get back to, not the redesign's own starting point.

Throughput, changes per second:

| Batch | Pre-work | Redesign | Option 1 | Option 2 | Gate |
| --- | --- | --- | --- | --- | --- |
| merge insert | 1,002 | 8 | 9 | 628 | **900** |
| merge update | 1,697 | 1,150 | 1,222 | 1,250 | **1,670** |
| merge delete | 2,431 | 1,907 | 1,960 | 1,935 | **2,389** |
| merge mixed | 1,855 | 16 | 20 | 805 | **1,579** |
| merge unique conflict | 564 | 8 | 18 | 306 | 309 |
| merge fk chain insert | 350 | 14 | 16 | 345 | 369 |
| merge fk chain delete | 584 | — | — | 598 | 494 |

Rows read per merged change, the quantity that drove the regression:

| Batch | Pre-work | Option 2 | Gate |
| --- | --- | --- | --- |
| merge insert | 0.0 | 7.0 | **0.0** |
| merge update | 4.6 | 9.2 | **4.6** |
| merge delete | 2.0 | 5.0 | **2.0** |
| merge mixed | 1.3 | 12.0 | **1.3** |
| merge unique conflict | 2.0 | 21.0 | 21.0 |
| merge fk chain insert | 13.6 | 15.7 | 15.7 |
| merge fk chain delete | 44.3 | 33.3 | 33.3 |

Option 1 cut queries per change by 64–81% but barely moved the clock, because
insert cost was dominated by how much each query read rather than how many ran.
Option 2 removed the repeated reads and is where the time went. The gate then
removed the passes that never had anything to do.

The remaining gap to pre-work is the unique-conflict batch, at 0.55x. That work
is real — releasing values stranded on hidden rows is the defect the redesign
exists to fix, and the pre-work engine was not doing it — but 21 rows per change
is more than it needs. Options 4 and 5 address that.

Scenario throughput varies by up to ~15% between runs on this machine; the fk
chain delete column is within that band.

## Measurements before the fix

`melos run benchmark` (`benchmark/run.dart`), SQLite, 22 synced tables, one
scope. Two row counts, same machine, at `277cbdb`:

| Batch | 250 rows | 500 rows | ms/change ratio | queries/change |
| --- | --- | --- | --- | --- |
| merge update | 0.83 ms | 0.87 ms | 1.05x | 2.3 – 2.5 |
| merge delete | 0.53 ms | 0.52 ms | 0.98x | 2.1 |
| merge fk chain delete | 1.79 ms | 1.83 ms | 1.02x | 2.5 – 3.0 |
| merge insert | 67.9 ms | 123.9 ms | **1.82x** | 26.1 |
| merge unique conflict | 65.7 ms | 124.3 ms | **1.89x** | 36.1 |
| merge fk chain insert | 46.4 ms | 74.6 ms | **1.61x** | 46.7 |

Throughput at 500 rows: 1,919 changes/s for deletes and 1,150 for updates,
against **8 changes/s** for inserts and unique conflicts, and 13 for FK chains.

Two independent problems are visible:

- **A constant factor.** Inserts cost 26–47 queries per change while updates and
  deletes cost ~2. That ratio does not move with row count.
- **A quadratic term.** Per-change time for inserts nearly doubles when the batch
  doubles, so total batch time grows with the square of the batch. Update and
  delete per-change time is flat. Queries per change stay flat too, so the
  growth is in how much each query reads, not how many run.

## Cause

Both come from one place: every merge insert runs a full projection pass.

`_applyMergeInsert` calls `CrdtForeignKeyProjector.project` inside the
savepoint of each insert, and the batch calls `project` once more at the end.
Merging N inserts therefore runs N+1 full passes.

Each pass calls `_loadProjectionState`, which loops over
`_context.syncTableByName.keys` — every synced table, not the affected ones —
and for each non-empty table issues a `CrdtDataRow` query, a
`readDomainColumnValues` query, and a `_loadFields` query, loading **every CRDT
row in the scope**.

So one insert costs `O(tables)` queries reading `O(rows in scope)` rows, and a
batch of N inserts costs `O(N x tables)` queries reading `O(N x rows)` rows.
That is the 26–47 queries per change and the doubling per-change time.

Updates and deletes avoid this because they do not use the pre-write planning
path: they apply their fact and let the single end-of-batch pass do the work.

The pre-write pass is not gratuitous. Immediate SQLite unique indexes reject a
physical insert that lands on a value a hidden row still occupies, so the
planner must produce constraint-safe values *before* the row is written. The
problem is the granularity, not the existence, of that step.

## Options

Roughly ordered by effort. They compose; 1 and 2 are additive, and 4 subsumes 3.

### 1. Prune the table loop to what the operation can affect — done (`361adc7`)

`_loadProjectionState` visits all 22 tables regardless of what changed. The
projector already answers this question for the caller with `needsProjection`
and `_foreignKeys.edgesByChildTable`; the same information can prune the load
loop to the operation's table plus its FK neighbours and the tables sharing a
unique index with it.

- Removes most of the constant factor: 26–47 queries per change should fall
  towards the ~2 that updates and deletes cost.
- Does not touch the quadratic term.
- Contained: one loop in `_loadProjectionState`, no change to planning
  semantics, and the existing tests plus the DST already cover the result.

### 2. Plan once per batch instead of once per insert — done (`d3bc5bc`)

Hoist the pre-write plan out of the per-insert savepoint. Collect every insert
in the merge set as `pendingInserts`, run one planning pass for the batch,
materialize the constraint-safe values, then perform the physical writes.

- Turns N+1 passes into 2 (one plan, one final materialization).
- The per-insert savepoint stays around the physical write and its
  ownership-collision rollback; only the planning moved out. A collision only
  drops that row, so the rest of the plan stays valid and no replan is needed.
- An update must not be folded into the batch plan. Operations are causally
  ordered, so an update newer than its insert is applied after it; treating its
  value as authored during planning makes the planned domain differ from the
  insert's own authored value for a reason projection did not cause.
- Biggest single win: this is where merge insert went from 9 to 556 changes/s.

### 0. Restore the projection gate — done

The pre-work merge path gated the whole pass:

```dart
final shouldProjectForeignKeys =
    _foreignKeyProjector.mergeOperationsMayAffectForeignKeys(operations);
...
if (shouldProjectForeignKeys) await _foreignKeyProjector.project(transaction);
```

The redesign kept the predicate, renamed to `mergeOperationsMayAffectProjection`,
but stopped calling it, so a batch on a table with no foreign key and no unique
index still loaded that table's whole CRDT row set — twice, once to plan and
once at the end.

- Restores pre-work cost for every table that has nothing to project.
- The pass is also what writes an update's value, so the skipped path has to
  write the authored values itself; `writeAuthoredValues` does that through the
  same batched domain writer.
- Sound for the same reason the predicate is: with no foreign key column and no
  unique column in the batch there is no candidate to compute and no claim to
  resolve, so the pass would have materialized exactly the authored value.

### 3. Memoize projection state per transaction

Weaker version of 2: keep `_loadProjectionState`'s result on the transaction and
invalidate it when a write touches a loaded row. Repeated passes in one merge
then reuse one load.

- Removes the repeated reads without restructuring the savepoint flow.
- Invalidations are easy to get wrong, and a stale cache produces exactly the
  divergence this engine exists to prevent. Needs the DST as a gate.
- Worth it only if 2 proves too invasive.

### 4. Load the affected closure instead of the whole scope

The strategy document already anticipates this: "A full recomputation is the
oracle for any incremental affected-closure algorithm." Only the oracle is
implemented. The closure of a merge set is the rows reachable through FK edges
from the touched rows, plus the rows claiming a unique tuple that the batch
claims.

- Removes the quadratic term: cost becomes proportional to the closure, not to
  scope size.
- The unique half needs an indexed lookup by claim value (option 5) to avoid
  loading a table to find its claimants.
- Correctness is checkable: the full pass is the oracle, so an equivalence test
  comparing closure output against full recomputation is straightforward, and
  the strategy's verification gates already ask for it.

### 5. Look unique claimants up by value

Conflict grouping currently sees every row because every row was loaded. With a
closure it needs the rows whose unique tuple matches a claim being made, which
is an indexed query against the domain table's own unique index rather than a
scan.

- Prerequisite for 4 on unique-heavy tables; the unique-conflict batch is the
  slowest measured case.
- Hidden rows hold released values, so the lookup must search released forms as
  well as the canonical claim, or the released value must be derivable from the
  claim (it is: the release is deterministic from row id).

### 6. Keep projection out of the insert path entirely

Write inserts with a deterministic parking value for every unique and FK column,
then let the single end-of-batch pass materialize final values.

- Restores the update/delete cost profile for inserts.
- Every inserted row is written twice, and the parking values are visible to
  anything reading inside the transaction.
- Only attractive if 1, 2 and 4 together still fall short.

## What is left

The gate met the pre-work bar on every batch that does not use a unique index.
Remaining work, in order of expected value:

1. Options 4 and 5 for the unique-heavy batches, which still cost ~10 queries
   and 21 rows per change against ~2 and ~2 for everything else.
2. Option 3 is now redundant: one pass per batch already removes the repeated
   reads it was meant to cache away.
3. Option 6 is unnecessary.

`safeIncomingData` still runs per insert, one target-presence query per foreign
key edge. That is part of the ~8 queries per change on fk chain inserts and is
the next obvious batching target.

## Verification

Any change here must keep the deterministic suites and the DST green, and
should be reported with the same benchmark at two row counts, because a fix
that improves the constant factor without touching the quadratic term looks
good at 250 rows and still fails at scale.
