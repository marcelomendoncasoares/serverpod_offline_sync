# Preserving foreign key invariants while merging

## Summary

After merging remote CRDT operations, the visible database must not contain
foreign key violations. The merge result must be associative, commutative, and
idempotent: the same merged CRDT facts must produce the same visible rows and
visible FK values regardless of arrival order, batching, or replay.

The safe merge model is projection-based. Local ORM operations are still
authored user actions: when a local delete is intercepted for soft delete, the
database-style `ON DELETE` side effects are materialized as CRDT facts in the
same local transaction. FK repairs created only because independently authored
facts were merged are deterministic materialized projections over those facts,
not new user field updates emitted opportunistically during merge.

## Core Policy

- Keep every row as a CRDT fact. Visibility is derived from row tombstones and
  schema-driven FK projection.
- Supported foreign keys are single-column child references to single-column
  parent references. Schemas with composite foreign keys must fail recorder
  initialization instead of silently bypassing projection.
- Merge input is causally complete: the sync protocol delivers each batch as a
  full causal snapshot of the sender, so every merged FK attempt's parent facts
  precede or accompany the child fact. Input that violates this precondition
  (for example, a non-nullable FK attempt whose parent fact is absent and whose
  default target is missing) is outside the merge contract and fails the merge
  transaction atomically against the database foreign key constraints.
- Local `ON DELETE` actions are authored CRDT facts. `RESTRICT` and `NO ACTION`
  reject the local delete while visible children exist; `SET NULL` and
  `SET DEFAULT` update child FK fields and their ordinary `CrdtDataField` HLCs;
  `CASCADE` records user-delete tombstones for the visible cascade descendants.
- Keep the user/attempted FK value as the CRDT field value for authored
  operations.
- During merge projection, materialize a separate visible FK value only when FK
  repair requires it. `CrdtDataForeignKey.attemptedValue` is the durable FK
  field-value payload for FK columns because `CrdtDataField` stores only HLC
  metadata. `visibleValue`, `hasOverride`, and `overrideReason` are projection
  metadata, not business conflict classes.
- Do not create ordinary user field updates for `SET NULL` or `SET DEFAULT`
  repairs during merge. Doing so makes repair HLCs depend on merge timing. This
  does not apply to locally initiated `SET NULL` or `SET DEFAULT` actions,
  which are authored user field updates.
- For FK-affecting operations, recompute FK projection to the same fixed point
  as the affected FK closure. A full graph recomputation is a valid
  implementation strategy and oracle as long as it produces the same projection.
  Operations that touch no child FK column, parent reference column, insert, or
  tombstone must not trigger FK projection.

## Local Action Semantics

Local deletes preserve database action semantics even though the physical row is
soft-deleted instead of removed:

- `ON DELETE RESTRICT` and `NO ACTION`: the delete fails if any visible child
  still references the parent. No parent tombstone is recorded for the failed
  operation.
- `ON DELETE SET NULL`: visible child FK columns are updated to `null` when the
  FK is nullable, and those child FK fields receive ordinary CRDT field updates.
- `ON DELETE SET DEFAULT`: visible child FK columns are updated to the column
  default when the default is legal, and those child FK fields receive ordinary
  CRDT field updates.
- `ON DELETE CASCADE`: visible cascade descendants receive synced
  user-delete tombstones. Local cascade descendants are not hidden only as
  `foreignKeyCascade` projection rows.

These local side effects are the facts that other replicas merge.

## Merge-Time Action Semantics

For each child FK whose attempted value points to a hidden or missing parent:

- `ON DELETE SET NULL`: the visible FK value is `null` when the FK is nullable.
  If the FK is non-nullable, this action cannot repair the row and must fall
  through to the deterministic blocking policy.
- `ON DELETE SET DEFAULT`: the visible FK value is the column default only if
  that default points to a visible parent or is a legal nullable default. If the
  default target is hidden or missing, this action cannot repair the row and
  must fall through to the deterministic blocking policy.
- `ON DELETE RESTRICT` and `NO ACTION`: the parent delete loses while a visible
  child still references the parent. The parent remains visible in the derived
  projection.
- `ON DELETE CASCADE`: the child can be hidden only if the whole cascade closure
  is valid. If any descendant blocks the cascade through `RESTRICT`, `NO ACTION`,
  invalid `SET NULL`, or invalid `SET DEFAULT`, the ancestor delete loses and
  the cascade is not partially applied.

This makes mixed chains atomic for visibility. For example, if deleting `A`
would cascade-delete `B`, but `B` has a visible `RESTRICT` child `C`, then `A`,
`B`, and `C` remain visible. The result must not depend on whether cascade or
restrict edges are evaluated first internally.

## Projection Metadata

`CrdtDataForeignKey` should represent the FK field payload and materialized FK
projection for one `CrdtDataField`:

- `attemptedValue`: the current user-attempted FK value carried by the CRDT
  field. It may be null for nullable FKs. This is durable FK field-value storage
  and is part of the CRDT facts for FK columns.
- `visibleValue`: the value currently materialized into the domain row when an
  override is active.
- `hasOverride`: whether the projection overrides `attemptedValue` and
  materializes `visibleValue` instead.

`visibleValue == null` is meaningful only with `hasOverride`. When
`hasOverride` is false it means "same as attempted"; when `hasOverride` is true
it means "materialize null".

The resolver may use `visibleValue`, `hasOverride`, and `overrideReason` for
efficient materialization and write deduplication. It must not use those
projection fields as the authority for FK conflict decisions; the authority is
the deterministic resolver over merged CRDT row, field, tombstone, and FK
attempt facts.

## Merge Pipeline

1. Merge CRDT row, field, and tombstone facts by their existing HLC/CLFlag
   rules.
2. Identify whether inserts, updates, deletes, FK columns, parent reference
   columns, or existing FK projection records can affect FK state. Skip FK
   projection when the merge touches none of them.
3. For FK-affecting work, expand to the FK closure in both directions: parents
   needed by children and children affected by parent visibility. A full graph
   recomputation may be used instead of the minimal closure.
4. Compute effective row visibility and visible FK values to a fixed point.
5. Apply only the materialized differences:
   - update domain FK columns when projection differs from attempted value;
   - update `CrdtDataForeignKey` projection metadata;
   - update system tombstones only for deterministic derived visibility where
     that is part of the chosen storage model.
6. Re-run unique conflict projection after FK projection if FK repairs can
   change unique columns, or define the opposite stage order and prove it with
   the full recomputation oracle.

## Invariants

- No visible row references a hidden or missing parent.
- No cascade delete is partially applied across a blocked nested relation.
- Merge-time `SET NULL` and `SET DEFAULT` repairs are pure functions of merged
  facts. Local `SET NULL` and `SET DEFAULT` actions are authored field facts.
- Local cascade deletes produce synced user-delete tombstones for cascade
  descendants; merge-time cascade projection may derive `foreignKeyCascade`
  visibility for descendants without authored tombstones.
- Replaying the same merge batch produces no metadata churn.
- Splitting a merge into smaller batches converges to the same final projection
  as merging the same operations in one batch.
- FK-affecting recomputation over the affected closure matches full global
  recomputation; unrelated non-FK updates do not trigger FK projection.

## Test Cases

### Local CRUD Actions

- Given a visible `RESTRICT` or `NO ACTION` child, when the parent is deleted
  locally, then the delete fails and no parent tombstone is recorded.
- Given a nullable `SET NULL` child, when the parent is deleted locally, then the
  child FK is set to `null` as an authored field update.
- Given a valid `SET DEFAULT` child, when the parent is deleted locally, then
  the child FK is set to the default as an authored field update.
- Given a valid cascade chain, when the root is deleted locally, then every
  visible cascade descendant receives a user-delete tombstone.

### Restrict and No Action

1. Given a parent and a visible child with `ON DELETE RESTRICT`, when one replica
   deletes the parent and another concurrently updates the child, then the parent
   remains visible after convergence and no visible orphan appears.

2. Given a parent with multiple visible restrict children, when the parent is
   deleted concurrently with updates to different children, then any visible
   child is enough to keep the parent visible on every replica.

3. Given a parent kept visible because of restrict, when all restrict children
   are later deleted or detached, then the parent visibility follows the same
   deterministic recomputation rule on every replica.

### Set Null and Set Default

4. Given a nullable FK with `ON DELETE SET NULL`, when the parent is deleted on
   another replica, then the child remains visible with a materialized null FK
   and the user/attempted FK value remains unchanged as a CRDT fact.

5. Given a child whose FK was materialized to null by `SET NULL`, when the user
   later changes the FK to a visible parent, then the projection override becomes
   inactive and the domain row materializes the new user value.

6. Given `ON DELETE SET DEFAULT` and a visible default target, when the attempted
   parent is deleted, then the child remains visible with the default FK
   materialized.

7. Given `ON DELETE SET DEFAULT` and a hidden or missing default target, when the
   attempted parent is deleted, then the action cannot repair the child and the
   deterministic blocking policy keeps the necessary parent visible.

### Cascade

8. Given a parent delete fact merged from another replica with children under
   `ON DELETE CASCADE`, then all cascade descendants in the valid cascade
   closure become hidden and no visible descendant references a hidden ancestor.

9. Given a child already hidden by a cascade projection, when the same delete
   facts are merged again, then no additional metadata churn occurs.

### Mixed Nested Relations

10. Given `A -> B` is cascade and `B <- C` is restrict, when `A` is deleted
    concurrently with an update to `C`, then the cascade is blocked and `A`,
    `B`, and `C` remain visible.

11. Given a fourth-degree chain with alternating cascade, restrict, set-null,
    and set-default edges, when a merge touches both a root and a leaf, then the
    affected-closure result and a full fixed-point recomputation produce the
    same visible graph and FK projection.

12. Given an FK cycle that the engine permits, when concurrent deletes and
    updates happen around the cycle, then fixed-point evaluation terminates and
    every replica computes the same projection.

### Cross-Cutting

13. Given an FK repair changes a unique-indexed column, when unique projection
    and FK projection are recomputed, then the documented stage order prevents
    visible unique and FK violations.

14. Given the same remote operations arrive in one batch or several smaller
    batches, when all operations have merged, then visible rows, visible FK
    values, FK projection metadata, unique projection, and tombstones are the
    same.

15. Given a merge touches only a non-indexed, non-FK field that is not a parent
    reference column, then FK projection is skipped and the visible FK graph is
    unchanged.

## What These Tests Prove

- Integrity: no surviving visible FK violation.
- Convergence: same merged facts produce the same projection on every replica.
- ACI merge behavior: batching, replay, and merge order do not change the final
  visible result.
- Nested safety: cascade cannot bypass restrict/no-action descendants.
- Local action fidelity: local deletes preserve database-style FK side effects
  as authored CRDT facts.
- Projection discipline: merge-time `SET NULL` and `SET DEFAULT` repairs do not
  become ordinary user CRDT writes.
