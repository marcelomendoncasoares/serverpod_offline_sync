# Merge projection performance

Status: **problem statement and options — nothing here is implemented.**

Merging inserts is roughly two orders of magnitude slower than merging updates
or deletes, and the gap widens as a scope fills up. This document records the
measurements, the cause, and the options for fixing it.

Related documents:

- [Rebuildable FK and unique projection strategy](rebuildable-projection-strategy.md)
- [Foreign-key projection invariants](foreign-key-invariants.md)
- [Unique-constraint invariants](unique-constraint-invariants.md)

## Measurements

`melos run benchmark` (`benchmark/run.dart`), SQLite, 22 synced tables, one
scope. Two row counts, same machine, after the review fixes in `277cbdb`:

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

### 1. Prune the table loop to what the operation can affect

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

### 2. Plan once per batch instead of once per insert

Hoist the pre-write plan out of the per-insert savepoint. Collect every insert
in the merge set as `pendingInserts`, run one planning pass for the batch,
materialize the constraint-safe values, then perform the physical writes.

- Turns N+1 passes into 2 (one plan, one final materialization).
- The per-insert savepoint exists to roll back a foreign-scope row collision
  without leaving CRDT metadata behind. That savepoint has to stay around the
  physical write; only the planning moves out. A collision then invalidates the
  batch plan for that row, so the recovery path needs a replan or a per-row
  fallback.
- Biggest single win available, and the one with real design work in it.

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

## Suggested order

1. Option 1, and re-measure. Cheap, and it should show whether the constant
   factor alone accounts for the shortfall against the target.
2. Option 2, and re-measure. This is where the N multiplier goes.
3. Option 4 with 5, if the quadratic term still dominates at realistic scope
   sizes.

Target: hundreds of changes per second for insert batches, against 8–19/s now.
Updates and deletes already run at 1,150–1,919/s on the same schema, so that
figure is what the engine achieves when projection is not re-run per operation.

## Verification

Any change here must keep the deterministic suites and the DST green, and
should be reported with the same benchmark at two row counts, because a fix
that improves the constant factor without touching the quadratic term looks
good at 250 rows and still fails at scale.
