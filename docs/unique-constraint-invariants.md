# Preserving unique constraint invariants while merging

## Summary

Concurrent inserts or updates can make multiple CRDT rows claim the same unique
value. The current merge model resolves this without hiding rows: every row
remains visible, and the losing unique claims are materialized with
deterministic conflict-free visible values.

This is the `flag` policy. It is intentionally simple:

- all rows remain CRDT facts;
- all rows remain visible domain rows;
- one deterministic winner keeps the claimed unique value;
- each loser keeps its own row identity and receives a conflict-free visible
  unique value;
- no business conflict object is synced;
- no foreign key retargeting is needed for unique conflicts.

This policy is the only unique-conflict policy in scope for the current
implementation.

## Current Policy: Flag

For each unique index conflict group:

1. Compute each row's unique claim timestamp from the HLC of the unique-indexed
   field or fields. For an insert, use the insert HLC and any incoming field HLCs
   for the indexed fields.
2. Pick the winner deterministically by oldest unique-claim HLC, with row id as
   the stable tie-break.
3. Leave the winner's unique value unchanged.
4. Rewrite each loser's visible unique-indexed value to a deterministic
   conflict-free value:
   - nullable unique values may be released to `null`;
   - text values receive a stable `__conflict__<rowId>` suffix;
   - UUID values receive a deterministic synthetic UUID.
5. Keep all rows visible. Application code can decide whether and how to surface
   the changed visible value as a business conflict.

The rewritten value is a materialized data value, not a synced conflict class.
The core CRDT protocol does not need to expose unique conflict objects to users.

## Why Flag Is The Current Default

The `flag` policy avoids the hard second-order effects caused by hiding or
merging rows:

- no child row needs to be moved from one parent row id to another;
- `ON DELETE RESTRICT` children do not accidentally keep a unique loser alive;
- cascade chains are not triggered by unique conflict resolution;
- non-key field updates on both rows remain attached to their original rows;
- the algorithm stays local to the conflicting unique index and affected rows.

This keeps merge behavior associative, commutative, and idempotent without
requiring a combined unique/FK fixed-point projection.

## Deferred Policies

The following policies are plausible future schema-level options, but they are
not part of the current implementation because they require a substantially more
complex projection algorithm.

Both policies should be projections over the canonical `flag` result, not
separate unique-resolution algorithms. The `flag` layer computes conflict
components, winners, losers, and released loser values once from CRDT facts:

```text
unique facts -> conflict components -> winner + losers + released loser values
```

Future policies then interpret that canonical result:

```text
flag      = show all rows; losers show released unique values
overwrite = use flag winner; alias/hide losers in the visible projection
merge     = overwrite projection + deterministic field folding into winner
```

`merge` and `overwrite` must use the original unique claims and conflict
components from the `flag` projection. They must not infer conflicts from only
the already-released materialized values.

### Overwrite

`overwrite` would keep a deterministic winner visible and hide the losers.

To be safe, this cannot simply tombstone the loser. A hidden loser may already
be referenced by visible children, including children using `ON DELETE RESTRICT`
or deeper mixed cascade/restrict chains. A safe overwrite policy therefore needs
an internal row-alias projection:

```text
loserRowId -> winnerRowId
```

Foreign key projection would then consume the alias map and materialize child FK
values through the winner where legal. Without this aliasing step, overwrite can
produce visible orphans or order-dependent outcomes.

### Merge

`merge` would also pick a deterministic winner and alias loser rows to it, but
would additionally fold selected loser fields into the winner.

This needs explicit deterministic per-column policies, such as:

- `winnerWins`
- `latestFieldWinsAcrossMergedRows`
- `preferNonNullLatest`
- `ignore`

These policies must be schema-defined, deterministic on every replica, and
included in schema compatibility checks. Arbitrary app callbacks inside core
merge would not be safe unless they are deterministic, versioned, and available
identically on every replica.

## Why Merge And Overwrite Are Deferred

`merge` and `overwrite` combine unique projection with foreign key projection.
The resolver would need to compute, at minimum:

- unique conflict groups;
- winners and losers for each group;
- row aliases from loser ids to winner ids;
- hidden-row projection;
- field projections for merged rows;
- foreign key repairs over aliases;
- nested cascade/restrict/set-null/set-default effects;
- fixed-point recomputation when FK repairs touch unique-indexed values.

That interaction can grow quickly with graph depth, shared children, cycles, and
rows participating in multiple unique indexes. The implementation would need a
full recomputation oracle and incremental-closure equivalence tests before it is
safe enough for real data.

For now, the `flag` policy gives a safer and smaller invariant:

```text
unique projection changes values, not row identity or row visibility
```

Foreign key repair can then be developed independently as a projection over row
visibility and FK values, without also needing row aliasing and field folding.

## Invariants

- No visible duplicate remains for a unique index after projection.
- Unique conflict resolution is deterministic from merged CRDT facts.
- Merge replay does not create additional metadata churn.
- Splitting the same operations into different sync batches converges to the
  same visible result.
- Unique projection does not emit app-visible CRDT conflict objects.
- Current `flag` projection does not hide rows or retarget foreign keys.

## Test Cases

### Current Flag Policy

1. Given two replicas concurrently insert different rows with the same unique
   value, when they merge, then both rows remain visible, the deterministic
   winner keeps the original value, and the loser receives a deterministic
   conflict-free value.

2. Given an older insert conflicts with a newer update on another row, when they
   merge, then the row with the older unique-field claim keeps the unique value,
   regardless of the other row's insert time.

3. Given two rows concurrently update the same unique field to the same value,
   when they merge, then both rows remain visible and only the deterministic
   winner keeps the claimed value.

4. Given the same conflict arrives in one batch or several smaller batches, when
   all operations have merged, then the same row keeps the unique value and the
   same rows receive the same conflict-free values.

5. Given a conflicting unique value is a nullable unique column, when the loser
   can be made conflict-free by setting the materialized value to null, then the
   loser remains visible and the unique index remains valid.

6. Given a conflicting unique value is a UUID column that is not an FK column,
   when the loser is released, then the materialized UUID is deterministic from
   the table, column, original value, and loser row id.

### Deferred Merge And Overwrite Policies

7. Given overwrite is enabled for a unique index, when a loser has visible
   restrict children, then FK projection retargets those children through the
   row alias or blocks the projection deterministically; no visible orphan is
   produced.

8. Given merge is enabled for a unique index, when loser rows contain newer
   non-key field values, then field folding follows documented per-column
   policies and every replica computes the same winner row.

9. Given a row participates in multiple unique conflict groups, when merge or
   overwrite projection runs, then row aliases are deterministic and do not form
   cycles.

10. Given FK repair changes a unique-indexed visible value, when combined unique
    and FK projection runs, then the fixed-point result matches a full
    recomputation oracle.

These deferred tests should not be implemented until the row-alias and combined
projection model exists.

## What These Tests Prove

- Current implementation safety: the `flag` policy preserves uniqueness without
  row hiding or FK retargeting.
- Convergence: same CRDT facts produce the same visible unique values.
- Idempotence: repeated merges do not keep rewriting the same conflict.
- Scope control: future `merge` and `overwrite` behavior is documented but not
  treated as supported until the projection algorithm can handle second-order FK
  effects.
