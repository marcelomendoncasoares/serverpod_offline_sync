# Merge projection performance

Status: **options 1, 2, 4 and 5 implemented, projection gate restored, attempted
values looked up by value; 3 and 6 rejected.**

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

| Batch | Pre-work | Redesign | Option 1 | Option 2 | Gate | Option 4 | Option 5 | By value |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| merge insert | 1,002 | 8 | 9 | 628 | 900 | 961 | 925 | **893** |
| merge update | 1,697 | 1,150 | 1,222 | 1,250 | 1,670 | 1,730 | 1,666 | **1,476** |
| merge delete | 2,431 | 1,907 | 1,960 | 1,935 | 2,389 | 2,480 | 2,531 | **2,194** |
| merge mixed | 1,855 | 16 | 20 | 805 | 1,579 | 1,588 | 1,663 | **1,434** |
| merge unique conflict | 564 | 8 | 18 | 306 | 309 | 280 | 307 | **302** |
| merge fk chain insert | 350 | 14 | 16 | 345 | 369 | 400 | 434 | **369** |
| merge fk chain delete | 584 | — | — | 598 | 494 | 519 | 542 | **693** |

The redesign and option 1 columns are from the original runs; everything else
was measured back to back in one session. Nothing hinges on the difference: the
columns that matter differ by two orders of magnitude.

Rows read per merged change, the quantity that drove the regression:

| Batch | Pre-work | Option 2 | Gate | Option 4 | Option 5 | By value |
| --- | --- | --- | --- | --- | --- | --- |
| merge insert | 0.0 | 7.0 | **0.0** | **0.0** | **0.0** | **0.0** |
| merge update | 4.6 | 9.2 | **4.6** | **4.6** | **4.6** | **4.5** |
| merge delete | 2.0 | 5.0 | **2.0** | **2.0** | **2.0** | **2.0** |
| merge mixed | 1.3 | 12.0 | **1.3** | **1.3** | **1.3** | **1.3** |
| merge unique conflict | 2.0 | 21.0 | 21.0 | 24.0 | 31.5 | **16.0** |
| merge fk chain insert | 13.6 | 15.7 | 15.7 | **8.1** | **8.1** | **8.1** |
| merge fk chain delete | 44.3 | 33.3 | 33.3 | 43.3 | 43.3 | **18.5** |

Read the unique row counts with care from option 4 on. The counter counts every
row a query hands back, and the closure walk replaced whole-table loads of
materialized models with id lookups and `(tblId, uuidRowId)` tuples. More rows
cross the boundary and each one costs a fraction of what it used to, which is
why the count rises while the clock does not.

Option 1 cut queries per change by 64–81% but barely moved the clock, because
insert cost was dominated by how much each query read rather than how many ran.
Option 2 removed the repeated reads and is where the time went. The gate then
removed the passes that never had anything to do, and option 4 halved what an
fk chain insert reads.

Looking attempted values up by value is what finally bounded the closure. Until
then a pass loaded every row of its tables holding an attempted value, because
any of them might be owed a claim; the unique-conflict scenario manufactures one
such row per merged change, so its closure grew with everything the scope had
ever parked. Asking for the rows owed *the values in this batch* leaves that
history out: 31.5 rows per change to 16.0, and 43.3 to 18.5 on fk chain delete.

It does not move the unique batch's clock, because that batch is no longer
paying for its closure. At ~10 queries per change against ~2 elsewhere, its cost
is per-change metadata work — `recordInsertAttempts`, `recordAttemptsForRows`
and `safeIncomingData` each running per row — roughly 5,000 queries for a batch
of 500. The closure loads are a handful of queries against that. What the value
filter removes is the growth term: closure size no longer tracks how many
projections the scope holds.

The remaining gap to pre-work is the unique-conflict batch, at 0.55x. That work
is real — releasing values stranded on hidden rows is the defect the redesign
exists to fix, and the pre-work engine was not doing it — but 21 rows per change
is more than it needs. Options 4 and 5 address that.

Scenario throughput varies by up to ~15% between runs on this machine, and the
by-value column was measured under load, so read its drops as noise and its row
counts as the signal. The one clock change it makes on its own is fk chain
delete, which reads less than half of what it did.

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

### 4. Load the affected closure instead of the whole scope — done

Cost is now proportional to the rows a pass can reach rather than to the tables
it can reach. Callers pass the rows they touched as `seedRows`; the loader walks
outward from them and loads nothing else.

The closure is the seeds plus their foreign key component, in both directions:

- **Down**, to children of a loaded row, because hiding or restoring a parent
  decides the child's fate — that is cascade, restrict and repair.
- **Up**, to parents of a loaded row, transitively. This one is not optional: a
  parent that is not loaded reads as a *missing* parent, and the pass would hide
  or rewrite a row that a full pass leaves alone.
- Plus three sets no edge query can reach: rows holding an attempted value (a
  late parent restores them, and their domain column no longer names it), the
  values a pending insert or an authored overlay is about to write (they are
  applied after loading), and the target of a set-default edge (named by the
  schema, not by any row).

Tables with a unique index still load whole: a claim can be held by any row of
the table and there is no way to find it by value yet. That is option 5.

A pass with no `seedRows` — a rebuild — still loads everything, which keeps the
full recomputation available as the oracle the strategy document asks for.

### 5. Look unique claimants up by value — done

Unique-indexed tables no longer load whole. The closure walk asks the table for
the rows holding the values it claims, one indexed query per unique index, and
matches a composite index column by column, so the result is a superset of the
exact tuples.

The released form does not need searching for. A row that does not hold its
authored value holds an attempted value instead, and those rows are already in
the closure, so a hidden row's released claim is reachable without inverting the
release function.

### 5b. Ask for the rows owed a value, rather than all of them — done

The walk needs rows nothing points at: a child repaired away from its parent no
longer names it in the domain column, and a row that lost a unique claim was
parked on a value derived from its own id. Both keep what they are owed in a
sparse attempted value, so the walk asks for that.

- **The predicate is built by the write path's own encoders.** The authored
  value goes through the protocol's dynamic-field encoding and then the
  structured-column encoder, which is what makes it dialect correct without a
  hand-written one: `jsonb('…')` against SQLite's binary JSONB, a jsonb literal
  on Postgres. `ColumnStructured` exposes no comparison operators, so this has
  to be raw SQL, but nothing about the encoding is reimplemented.
- **It runs inside the walk, not before it.** The values a pass contests are
  discovered wave by wave, so the lookup sits beside the domain lookups that
  already use those same sets — parent references for foreign keys, claim tuples
  for unique indexes.
- **It is deliberately not narrowed to the seeds' descendants.** An earlier
  version scanned only tables a seed could reach downward, on the argument that
  nothing else can change. The DST disagreed: a pass repairs whatever its
  closure can see, and a stale override on a table reached only upward stayed
  stale, tripping `projectionPurity` on three seeds. Repair opportunity is not
  bounded by the seed's descendants.
- **An index on the column is not available.** Declaring one on the model
  produces a definition entry but no `CREATE INDEX`: the generator drops indexes
  on jsonb columns. The lookup is a scan of the attempted-value table alone,
  which measures ~1 ms against 3,000 rows with 500 values in the predicate, so
  it is not currently worth pursuing.

### 6. Keep projection out of the insert path entirely

Write inserts with a deterministic parking value for every unique and FK column,
then let the single end-of-batch pass materialize final values.

- Restores the update/delete cost profile for inserts.
- Every inserted row is written twice, and the parking values are visible to
  anything reading inside the transaction.
- Only attractive if 1, 2 and 4 together still fall short.

## What is left

Every batch is back at or above its pre-work throughput except the unique
conflict one, which sits at 0.54x while doing work the pre-work engine did not
do at all.

The cost that remains is the size of the *active projection set*: every pass
loads every row of its tables that holds an attempted value, because any of
them may be owed a claim back. That is proportional to how many projections a
scope currently holds, not to how large the scope is, which is the right shape —
but the benchmark manufactures one projection per change, so it measures the
worst case.

Two ways to make even that case cheap, neither implemented:

1. **Per-change metadata work in the unique path.** `recordInsertAttempts`,
   `recordAttemptsForRows` and `safeIncomingData` each run per row. That is the
   ~10 queries per change the unique batch pays, and the only thing between it
   and the ~2 that everything else costs.
2. **Skip the lookup when no claim can be freed.** A claim only comes back when a
   claimant is hidden, deleted, or changes its value; a batch that only inserts
   new rows cannot free one. The winner is the maximum over claimants under a
   total order, and a row that already lost cannot win by a new row arriving, so
   the parked losers can stay unloaded. The foreign key half does not have this
   property — a late parent restores children by attempted value — so the two
   needs would have to be separated first.

Option 3 is redundant: one pass per batch already removes the repeated reads it
was meant to cache away. Option 6 is unnecessary.

`safeIncomingData` still runs per insert, one target-presence query per foreign
key edge. That is part of the ~8 queries per change on fk chain inserts and is
the next obvious batching target.

## Verification

Any change here must keep the deterministic suites and the DST green, and
should be reported with the same benchmark at two row counts, because a fix
that improves the constant factor without touching the quadratic term looks
good at 250 rows and still fails at scale.
