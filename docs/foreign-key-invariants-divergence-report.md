# Foreign key invariant implementation review

Reviewed against `docs/foreign-key-invariants.md` on branch `foreign-key-handling` at `6834d7e`.
Updated on the current branch after applying the local/merge semantic
clarification and the FK projection fixes.

## Summary for distribution

The branch now aligns with the clarified spec on the major FK invariant points:

1. **Local and merge FK semantics are intentionally different and implemented.** Local `RESTRICT` / `NO ACTION`, `SET NULL`, `SET DEFAULT`, and `CASCADE` are material user actions. Merge-time FK repairs remain projection-only and do not advance ordinary `CrdtDataField` HLCs.
2. **Missing-parent merge cases are handled before physical FK writes.** Incoming FK attempts are recorded in `CrdtDataForeignKey.attemptedValue`, while the constrained domain column receives a safe visible value before the write.
3. **FK attempted-value storage is explicit.** `attemptedValue` is durable FK field-value storage; `visibleValue`, `hasOverride`, and `overrideReason` are projection metadata.
4. **Projection recomputation is clarified.** FK-affecting work may use full fixed-point recomputation as a valid strategy/oracle, while unrelated non-FK updates skip FK projection.
5. **The targeted spec coverage has been expanded.** The suite now covers local cascade user tombstones, multiple restrict children, invalid non-null `SET NULL`, missing-parent repairs, unique FK repair, replay metadata churn, batching convergence, and a permitted FK cycle.
6. **The main easy performance cleanups are implemented.** CRDT field upsert logic is shared, projection rows are upserted in batches, parent/child projection lookups are indexed, loaded CRDT rows are reused for visibility writes, FK materialization writes are batched, FK edges are precomputed by parent/child table, list updates project once, and sync avoids FK projection N+1 lookups.

The detailed items below retain the original review structure but now record the updated status.

## Correctness work item status

### FK-1: Local cascade should be material; merge projection should stay non-authoring

**Spec reference:** Core Policy and Local Action Semantics: local `ON DELETE` actions are authored CRDT facts. `RESTRICT` / `NO ACTION` reject the local delete, `SET NULL` / `SET DEFAULT` update child FK fields and ordinary field HLCs, and `CASCADE` records user-delete tombstones for visible cascade descendants. Merge-time FK repairs remain deterministic projection and must not create ordinary user field updates.

**Current code after fix:**

- `CrdtMutationRecorder.insteadOfDelete` calls `_softDeleteRowsByTable`, then `_projectForeignKeys` (`packages/serverpod_offline_sync_client/lib/src/database/recorder.dart:620-634`).
- `_softDeleteRowsByTable` calls `_applyForeignKeyDeleteActions` before marking the parent deleted, releases unique conflicts, records the parent tombstone, and recursively soft-deletes cascade descendants with the same user-delete reason.
- `_applyForeignKeyDeleteActions` throws for `RESTRICT` / `NO ACTION`, mutates child FK columns for `SET NULL` / `SET DEFAULT`, records ordinary CRDT field updates through `recordFieldsUpdatedByTable`, and returns `CASCADE` descendants for recursive user tombstones. Under the revised spec, all of that local behavior is intended.
- CRUD tests assert local cascade user-delete tombstones while preserving local restrict/set-null/set-default material-action expectations (`test/serverpod_offline_sync_test_server/test/integration/crud/delete_test.dart`).

**Status after fix:**

Resolved. The reviewed branch already treated local `SET NULL`, `SET DEFAULT`, `RESTRICT`, and `NO ACTION` as material database-style actions. Local `CASCADE` now also authors synced `CrdtDataDeletedReason.userDelete` tombstones for visible cascade descendants instead of relying on projection-only `foreignKeyCascade` visibility.

The inverse risk also matters: when projection runs after a remote merge, its `SET NULL` / `SET DEFAULT` materialization must not call `recordFieldsUpdatedByTable` or otherwise mint new user field HLCs. Those repairs are merge-time projections, not local authored actions.

**Scenarios verified:**

- Local delete of `City` with visible `Organization` and `Person` descendants under `ON DELETE CASCADE` should leave descendant domain rows present but attach `CrdtDataDeletedReason.userDelete` tombstones to every cascade descendant and set their visibility to `userDelete`.
- Local delete of `Person` referenced by `Town.mayorId ON DELETE SET NULL` should continue to leave `Town` visible with `mayorId == null` and a newer ordinary `Town.mayorId` `CrdtDataField` HLC.
- Local delete of `Town` referenced by `Company.townId ON DELETE SET DEFAULT` should continue to materialize the default as an ordinary child FK field update.
- Local delete of a `RESTRICT` / `NO ACTION` parent should continue to fail while visible children exist and should not record a parent tombstone for the failed operation.
- Remote/merge-time `SET NULL` and `SET DEFAULT` repairs should still update only the materialized domain FK value and `CrdtDataForeignKey` projection metadata, without bumping ordinary child `CrdtDataField` HLCs.

**Implemented direction:**

Keep local `RESTRICT`, `SET NULL`, and `SET DEFAULT` as material actions. Add recursive local cascade handling that records user-delete tombstones for visible cascade descendants. Keep merge-time projection pure: do not record ordinary field updates from `_materializeForeignKeyValues`, and keep derived cascade visibility as `foreignKeyCascade` only for rows hidden by merged facts rather than the current local transaction.

**Stash `e77b65745ee6277d7e695417547ac47ec60acd5f` evaluation:** not sufficient as-is. Directionally, the stash moves local cascade toward authored tombstones by adding `_cascadeUserDeleteFacts` and updating the cascade CRUD expectations, but it regresses two clarified requirements:

- It removes the existing local `SET NULL` / `SET DEFAULT` material actions from the soft-delete path instead of preserving them.
- It adds `recordFieldsUpdatedByTable` calls inside `_materializeForeignKeyValues`, which turns remote/merge-time `SET NULL` and `SET DEFAULT` projection repairs into ordinary user field updates and makes repair HLCs depend on merge timing.

It also removes `_foreignKeysByReferencedTable`, which removes the existing composite-FK initialization guard and leaves composite FKs silently ignored by `_foreignKeyEdges`.

### FK-2: Missing-parent merge operations can fail before projection can repair them

**Spec reference:** Merge-Time Action Semantics and Invariants: for attempted FK values that point to a hidden or missing parent, projection must produce no visible orphan; merge-time `SET NULL` / `SET DEFAULT` repairs are pure functions of merged facts.

**Current code after fix:**

- Merge insert/update paths call `_safeIncomingForeignKeyData` before writing FK columns to constrained domain tables.
- The original incoming FK value is recorded as an attempted value for `CrdtDataForeignKey.attemptedValue`.
- Repairable missing-parent `SET NULL` / `SET DEFAULT` writes use a safe visible value before the physical write. Nullable unrepairable `RESTRICT` / `NO ACTION` / `CASCADE` missing-parent writes use `null` as the physical value and projection hides the row so no visible orphan remains.
- Local user updates are still blocked by `_assertVisibleForeignKeyTargets`, which throws when the updated FK points at a missing or hidden parent.

**Status after fix:**

Resolved. The projection model now accepts the merged attempted FK fact without forcing that unsafe value into the constrained domain column first. Repairable actions materialize a safe visible value; unrepairable missing-parent attempts are hidden deterministically.

**Scenarios verified:**

- Remote `Town` insert/update with `mayorId` pointing at a parent row that is absent locally should converge to a visible town with a materialized `null` mayor and the attempted id preserved.
- Remote `Company` insert/update with `townId` pointing at an absent attempted town and a visible default town should converge to the visible default, not throw during the write.
- Remote child insert/update under `RESTRICT` / `NO ACTION` / `CASCADE` with a missing parent must follow an explicit deterministic policy that satisfies “no visible row references a hidden or missing parent.” The current spec implies no visible orphan, but the implementation needs a concrete policy for the “parent fact is absent” case.

**Implemented direction:**

Do not write an unsafe attempted FK into the physical FK column before projection. Options include computing the visible FK value before the domain write for FK columns, staging attempted values outside the constrained domain column, deferring constraints where supported, or making the attempted value durable in CRDT metadata and writing only the projected visible value to the domain table.

### FK-3: FK attempted-value storage must be explicit

**Spec reference:** Projection Metadata: `CrdtDataForeignKey.attemptedValue` is the durable FK field-value payload for FK columns because `CrdtDataField` stores only HLC metadata. `visibleValue`, `hasOverride`, and `overrideReason` are projection metadata and must not be used as business conflict authority.

**Current code:**

- `_attemptedForeignKeyValue` returns `projection.attemptedValue` whenever an override is active, otherwise it reads the current domain column (`packages/serverpod_offline_sync_client/lib/src/database/merge_utils/foreign_key_projector.dart:730-746`).
- `_childrenReferencingParent` and closure/blocking decisions use `_attemptedForeignKeyValue` (`foreign_key_projector.dart:798-811`).
- Sync also relies on projection metadata to reconstruct attempted values: `_applyProjectedForeignKeyAttempts` replaces row insert payload columns with `projection.attemptedValue`, and streamed update fields include `foreignKey` projection rows to return attempted values when an override is active.

**Status after spec clarification:**

Once `SET NULL` or `SET DEFAULT` is materialized, the physical domain column no longer contains the attempted FK. `CrdtDataField` only stores HLC metadata, not the attempted value. Therefore `CrdtDataForeignKey.attemptedValue` is explicitly the durable attempted FK value. This removes the earlier spec/code contradiction.

The remaining correctness requirement is that merge projection only updates the materialized domain value plus projection fields. It must not advance the ordinary `CrdtDataField` HLC for a repaired FK. The test suite now includes a set-null merge repair regression that snapshots the child FK field HLC and verifies projection does not advance it.

**Documented direction:**

Keep this storage model documented in the spec and model comment. Treat `CrdtDataForeignKey.attemptedValue` as FK field-value storage and keep `visibleValue`, `hasOverride`, and `overrideReason` as recomputable projection metadata.

### FK-4: `visibleValue` is populated when `hasOverride == false`

**Spec reference:** Projection Metadata: `visibleValue` is meaningful only with `hasOverride`; when `hasOverride` is false, it means “same as attempted.”

**Current code after fix:**

- `_recordForeignKeyAttemptsForRows` and `_materializeForeignKeyValues` write `visibleValue == null` when `hasOverride == false`.
- Tests now assert inactive projections have `visibleValue == null`.

**Status after fix:**

Resolved. Inactive projections no longer duplicate the attempted value in `visibleValue`; `visibleValue == null` is interpreted with `hasOverride`.

**Implemented direction:**

Store `visibleValue == null` whenever `hasOverride == false`; tests assert that inactive projections leave `visibleValue` empty.

### FK-5: FK-affecting projection uses full fixed-point recomputation

**Spec reference:** Merge Pipeline steps 2-4 and invariant/test 15: FK-affecting work must compute the same fixed point as the affected FK closure. A full graph recomputation is valid for FK-affecting work; unrelated non-FK updates must skip FK projection.

**Current code after fix:**

- `_projectForeignKeys` still computes a full fixed point for FK-affecting operations, which is now an allowed implementation strategy and oracle.
- `_tableColumnsMayAffectForeignKeys` and `_mergeOperationsMayAffectForeignKeys` skip projection for updates that touch no child FK column or parent reference column.
- `Database.update(List<T>)` performs row writes in one transaction and calls `afterUpdate` once, so list updates trigger at most one projection pass.
- Projection state now indexes parent and child lookups and batches projection/domain writes, reducing the cost of full fixed-point recomputation.

**Status after spec clarification and fix:**

Resolved against the clarified spec. The implementation uses full fixed-point recomputation only when an operation can affect FK state, and skips FK projection for unrelated non-FK updates. A narrower affected-closure loader remains a possible optimization, not a correctness requirement.

**Implemented direction:**

Gate projection by FK-affecting tables/columns; keep full recomputation as the fixed-point oracle for FK-affecting work; reduce full recomputation cost with indexed state and batched writes.

### FK-6: Composite foreign keys must be explicitly unsupported

**Spec reference:** Core Policy: supported foreign keys are single-column child references to single-column parent references. Schemas with composite foreign keys must fail recorder initialization instead of silently bypassing projection.

**Current code:**

- `_foreignKeysByReferencedTable` throws during recorder initialization if any target table definition contains a composite FK (`packages/serverpod_offline_sync_client/lib/src/database/recorder.dart:95-106`).
- `_foreignKeyEdges` silently includes only FKs whose `columns.length == 1` and `referenceColumns.length == 1` (`recorder.dart:119-135`).

**Status after spec clarification:**

A schema with a composite FK fails during recorder initialization through `_foreignKeysByReferencedTable`. This is now documented as an explicit limitation rather than a spec divergence. Later refactors must keep that guard so composite FKs are not silently ignored by `_foreignKeyEdges`.

**Documented direction:**

Keep the initialization validation and add/keep a schema test that proves composite FKs fail fast if such a model is introduced.

### FK-7: Unique/FK stage order is only partially implemented and not proven by tests

**Spec reference:** Merge Pipeline step 6 and test 13: if FK repairs can change unique columns, recompute unique projection after FK projection or define/prove the opposite order.

**Current code after fix:**

- Unique conflict resolution runs before FK projection for incoming inserts/updates (`merge.dart:273-345`).
- `_materializeForeignKeyValues` runs `_resolveUniqueConflictsAfterForeignKeyProjection` only for rows whose visible FK value changed (`foreign_key_projector.dart:588-679`).
- The test schema now includes a unique nullable `SET NULL` FK via `UniqueSetNullChild.parentId`.

**Status after fix:**

Resolved for the covered nullable unique `SET NULL` case. The code keeps the pre-FK unique pass and the post-FK unique pass for rows whose FK projection changed; the integration suite now proves the repaired unique FK becomes visible as `null` with the attempted value preserved.

**Implemented direction:**

Added a test model with a unique nullable `SET NULL` FK and covered the post-FK unique pass for that repair path. Batching convergence is covered separately for the repaired `SET NULL` graph.

## Spec coverage status in tests

The integration suite now covers the high-risk cases from the review:

- **Test 2:** multiple visible restrict children where any one child keeps the parent visible.
- **Local cascade:** local cascade deletes assert synced user-delete tombstones on cascade descendants.
- **Test 3:** restrict child detachment after a blocked parent delete restores the preserved delete projection.
- **Test 4/6/7 merge projection discipline:** remote `SET NULL` repairs assert that ordinary child `CrdtDataField` HLCs are not advanced by projection.
- **Invalid `SET NULL`:** a non-nullable `ON DELETE SET NULL` relation proves deterministic blocking.
- **Missing-parent repair:** remote insert/update references to absent parents cover repairable `SET NULL` / `SET DEFAULT` and unrepairable `RESTRICT` behavior before domain writes.
- **Replay metadata churn:** cascade replay snapshots both `CrdtDataRow.visibility` and `CrdtDataForeignKey` projection rows.
- **Test 12:** an existing permitted data cycle across `Person`, `Company`, and `Town` proves fixed-point evaluation terminates.
- **Test 13:** a unique-indexed nullable `SET NULL` FK repair is covered.
- **Batching convergence:** one-batch and split-batch merges converge for a repaired `SET NULL` graph.

Remaining optional coverage candidates:

- A dedicated fourth-degree chain comparing a hand-minimized affected closure to full recomputation. The current spec allows full recomputation as the implementation strategy.
- A synthetic composite-FK schema test. Composite FKs are explicitly unsupported and the initialization guard is retained, but the test server does not include a composite FK model.

## Duplication and easy performance cleanup items

### PERF-1: Extract duplicated CRDT field upsert logic

Resolved. `_recordUpdatedFields` and `recordFieldsUpdatedByTable` now share `_upsertCrdtFieldsForRows(tableName, crdtRows, schemaColumns, skippedFields?)`. This also keeps merge-time FK projection away from ordinary field-HLC authoring.

### PERF-2: Batch projection upserts instead of querying one row at a time

Resolved. `_ForeignKeyProjectionRow` now carries the projection row id and override reason, and `_upsertForeignKeyProjections` batches inserts/updates using either loaded projection state or one bulk lookup for missing field ids.

### PERF-3: Index parent and child lookups inside projection state

Resolved. `_ForeignKeyProjectionState` now builds `(parentTable, parentColumn, value) -> row` and `(childTable, childColumn, attemptedValue) -> children` maps once, and hot closure/blocking/materialization paths use those indexes.

### PERF-4: Avoid re-querying CRDT rows already present in projection state

Resolved. `_ProjectedForeignKeyRow` now carries the loaded `CrdtDataRow` and current visibility, so `_setProjectedRowVisibility` can update without re-querying rows.

### PERF-5: Batch domain FK materialization writes

Resolved for equal update sets. `_materializeForeignKeyValues` collects domain FK changes, groups rows by table and identical update map, writes each group once, then runs the post-FK unique pass.

### PERF-6: Precompute foreign-key edges by parent and child table

Resolved. The recorder now precomputes `_foreignKeyEdgesByParentTable` and `_foreignKeyEdgesByChildTable`, and projector paths use them for child-table and parent-table loops.

### PERF-7: Avoid full projection per row in `Database.update(List<T>)`

Resolved at the recorder/projection layer. `CrdtDatabase.update(List<T>)` still applies the tombstone-aware row update predicate per row, but it records CRDT updates once for the full list and therefore runs FK projection at most once.

### PERF-8: Avoid N+1 sync projection lookups

Resolved for FK projection lookups. `_streamUpdates` includes `foreignKey` with each `CrdtDataField`, and `_streamInserts` preloads active projected FK attempt fields for all streamed CRDT rows.

## Validation notes

- Ran `dart analyze packages/serverpod_offline_sync_client test/serverpod_offline_sync_test_server --fatal-infos --fatal-warnings`; no issues found.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/merge/foreign_key_invariant_test.dart --reporter=expanded --concurrency=1`; it passed all 36 tests.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/crud/delete_test.dart --reporter=expanded --concurrency=1`; it passed all 20 tests.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/crud --reporter=expanded --concurrency=1`; it passed all 58 tests.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/merge --reporter=expanded --concurrency=1`; it passed all 71 tests.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/database --reporter=expanded --concurrency=1`; it passed all 3 tests.
- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/sync/sync_roundtrip_test.dart --reporter=expanded --concurrency=1`; it passed all 6 tests, including projected FK attempted-value insert/update payload roundtrips.
- Attempted `dart test test/serverpod_offline_sync_test_server/test/integration/sync --reporter=expanded --concurrency=1`; `sync_roundtrip_test.dart`, `sync_merge_helpers_test.dart`, and `sync_hash_test.dart` passed, but `sync_flow_test.dart` and `sync_unique_conflict_test.dart` failed during load with `Database is not available in this session` from the `withServerpod` test harness before test bodies executed.
