# Foreign key invariant implementation review

Reviewed against `docs/foreign-key-invariants.md` on branch `foreign-key-handling` at `6834d7e`.

## Summary for distribution

The current branch implements a useful remote-merge FK projection and the new `foreign_key_invariant_test.dart` passes, but it is not fully aligned with the spec yet. The largest gaps are:

1. **Local and merge FK semantics are now intentionally different.** Local `RESTRICT` / `NO ACTION`, `SET NULL`, and `SET DEFAULT` behavior is meant to be material user action behavior, not projection-only behavior. The remaining local-delete gap is `CASCADE`: on the reviewed branch, a locally initiated cascade is still hidden as FK projection instead of recording synced user-delete tombstones for cascade descendants.
2. **Missing-parent cases are not safe.** The merge path writes incoming FK attempted values into the physical domain row before projection. If the parent row is missing, database FK constraints can reject a repairable `SET NULL` / `SET DEFAULT` operation before projection runs; if constraints are disabled, `RESTRICT`, `NO ACTION`, and `CASCADE` can leave a visible orphan.
3. **`CrdtDataForeignKey` is currently authoritative for attempted values under an override.** The spec says FK decisions must be derived from merged CRDT row/field/tombstone facts and must not use projection metadata as authority. The implementation needs `CrdtDataForeignKey.attemptedValue` to reconstruct the attempted FK once the domain column has been materialized to `null` or the default.
4. **The projection is full-global, not affected-closure incremental.** This is correct as a full recomputation strategy for many cases, but it diverges from the pipeline and test case 15 that require only the affected FK closure to be reconsidered. It also creates substantial easy performance wins.
5. **Several spec tests are not covered.** Missing coverage includes local cascade user tombstones, multiple restrict children, invalid non-null `SET NULL`, remote missing-parent repairs, composite or cyclic FKs, fourth-degree alternating chains compared with a full oracle, unique-indexed FK repairs, and metadata churn checks for projection rows.
6. **There are straightforward cleanup/performance items.** The biggest are duplicated CRDT-field upsert code, N+1 projection upserts, O(edges × rows²) parent/child scans, re-querying rows that are already loaded in projection state, per-row global projection during `Database.update(List<T>)`, and N+1 projection lookups while streaming sync changes.

The detailed items below are written as independent work packets for follow-up agents.

## Spec divergence / correctness work items

### FK-1: Local cascade should be material; merge projection should stay non-authoring

**Spec reference:** Core Policy and Local Action Semantics: local `ON DELETE` actions are authored CRDT facts. `RESTRICT` / `NO ACTION` reject the local delete, `SET NULL` / `SET DEFAULT` update child FK fields and ordinary field HLCs, and `CASCADE` records user-delete tombstones for visible cascade descendants. Merge-time FK repairs remain deterministic projection and must not create ordinary user field updates.

**Current code:**

- `CrdtMutationRecorder.insteadOfDelete` calls `_softDeleteRowsByTable`, then `_projectForeignKeys` (`packages/serverpod_offline_sync_client/lib/src/database/recorder.dart:620-634`).
- `_softDeleteRowsByTable` calls `_applyForeignKeyDeleteActions` before marking the parent deleted (`recorder.dart:667-674`).
- `_applyForeignKeyDeleteActions` throws for `RESTRICT` / `NO ACTION`, mutates child FK columns for `SET NULL` / `SET DEFAULT`, and records ordinary CRDT field updates through `recordFieldsUpdatedByTable` (`recorder.dart:919-961`). Under the revised spec, that local behavior is intended.
- `_applyForeignKeyDeleteActions` does nothing for `CASCADE`; the later `_projectForeignKeys` pass derives hidden descendants with `CrdtDataRowVisibility.foreignKeyCascade` instead of writing synced `CrdtDataDeletedReason.userDelete` tombstones.
- CRUD tests now need to assert local cascade user-delete tombstones while keeping the existing local restrict/set-null/set-default material-action expectations (`test/serverpod_offline_sync_test_server/test/integration/crud/delete_test.dart:433-585`).

**Why this diverges:**

The reviewed branch treats local `SET NULL`, `SET DEFAULT`, `RESTRICT`, and `NO ACTION` as material database-style actions, which is now the intended policy. But local `CASCADE` remains projection-only. A user-initiated cascade should author child delete facts the same way a database cascade is a real side effect of the user delete. If cascade descendants are only marked `foreignKeyCascade`, the local transaction does not record those descendant deletes as synced user tombstones, and other replicas must rediscover them by projection rather than merging the user's authored cascade facts.

The inverse risk also matters: when projection runs after a remote merge, its `SET NULL` / `SET DEFAULT` materialization must not call `recordFieldsUpdatedByTable` or otherwise mint new user field HLCs. Those repairs are merge-time projections, not local authored actions.

**Scenarios to verify after fixing:**

- Local delete of `City` with visible `Organization` and `Person` descendants under `ON DELETE CASCADE` should leave descendant domain rows present but attach `CrdtDataDeletedReason.userDelete` tombstones to every cascade descendant and set their visibility to `userDelete`.
- Local delete of `Person` referenced by `Town.mayorId ON DELETE SET NULL` should continue to leave `Town` visible with `mayorId == null` and a newer ordinary `Town.mayorId` `CrdtDataField` HLC.
- Local delete of `Town` referenced by `Company.townId ON DELETE SET DEFAULT` should continue to materialize the default as an ordinary child FK field update.
- Local delete of a `RESTRICT` / `NO ACTION` parent should continue to fail while visible children exist and should not record a parent tombstone for the failed operation.
- Remote/merge-time `SET NULL` and `SET DEFAULT` repairs should still update only the materialized domain FK value and `CrdtDataForeignKey` projection metadata, without bumping ordinary child `CrdtDataField` HLCs.

**Suggested direction:**

Keep local `RESTRICT`, `SET NULL`, and `SET DEFAULT` as material actions. Add recursive local cascade handling that records user-delete tombstones for visible cascade descendants. Keep merge-time projection pure: do not record ordinary field updates from `_materializeForeignKeyValues`, and keep derived cascade visibility as `foreignKeyCascade` only for rows hidden by merged facts rather than the current local transaction.

**Stash `e77b65745ee6277d7e695417547ac47ec60acd5f` evaluation:** directionally, the stash moves local cascade toward authored tombstones by adding `_cascadeUserDeleteFacts` and updating the cascade CRUD expectations. It is not sufficient as-is because it also adds `recordFieldsUpdatedByTable` calls inside `_materializeForeignKeyValues`, which would turn remote/merge-time `SET NULL` and `SET DEFAULT` projection repairs into ordinary user field updates. That reintroduces the projection-policy violation for merges. The cascade portion should be separated from that projection-field-HLC change. If the stash is applied, FK-6 also still needs attention because removing `_foreignKeysByReferencedTable` removes the old composite-FK initialization guard and leaves composite FKs silently ignored.

### FK-2: Missing-parent merge operations can fail before projection can repair them

**Spec reference:** Merge-Time Action Semantics and Invariants: for attempted FK values that point to a hidden or missing parent, projection must produce no visible orphan; merge-time `SET NULL` / `SET DEFAULT` repairs are pure functions of merged facts.

**Current code:**

- `mergeChanges` applies each incoming operation directly to the domain row before the final `_projectForeignKeys` call (`packages/serverpod_offline_sync_client/lib/src/database/merge.dart:47-77`).
- `_applyMergeInsertForMissingRow` upserts CRDT row metadata, then writes the incoming domain row with the attempted FK value through `_db.updateRow` / `_db.insertRow` (`merge.dart:523-553`).
- `_applyMergeUpdate` writes incoming FK values through `_updateDomainRows` before projection (`merge.dart:329-345`).
- Local user updates are additionally blocked by `_assertVisibleForeignKeyTargets`, which throws when the updated FK points at a missing or hidden parent (`recorder.dart:349-385`).

**Why this diverges:**

The projection model needs to accept merged CRDT facts first, then materialize a safe visible value. With physical FK constraints enabled, a remote child insert/update that attempts to reference a missing parent can be rejected by the database before the `SET NULL` or `SET DEFAULT` projection runs. With constraints disabled, the later projection only repairs `SET NULL` and valid `SET DEFAULT`; `RESTRICT`, `NO ACTION`, and `CASCADE` missing-parent cases are left as visible orphans because there is no parent row to restore.

**Scenarios to add:**

- Remote `Town` insert/update with `mayorId` pointing at a parent row that is absent locally should converge to a visible town with a materialized `null` mayor and the attempted id preserved.
- Remote `Company` insert/update with `townId` pointing at an absent attempted town and a visible default town should converge to the visible default, not throw during the write.
- Remote child insert/update under `RESTRICT` / `NO ACTION` / `CASCADE` with a missing parent must follow an explicit deterministic policy that satisfies “no visible row references a hidden or missing parent.” The current spec implies no visible orphan, but the implementation needs a concrete policy for the “parent fact is absent” case.

**Suggested direction:**

Do not write an unsafe attempted FK into the physical FK column before projection. Options include computing the visible FK value before the domain write for FK columns, staging attempted values outside the constrained domain column, deferring constraints where supported, or making the attempted value durable in CRDT metadata and writing only the projected visible value to the domain table.

### FK-3: Projection metadata is used as FK decision authority

**Spec reference:** Projection Metadata: `CrdtDataForeignKey` may be used for efficient materialization and write deduplication, but must not be the authority for FK conflict decisions; authority is the deterministic resolver over merged CRDT facts.

**Current code:**

- `_attemptedForeignKeyValue` returns `projection.attemptedValue` whenever an override is active, otherwise it reads the current domain column (`packages/serverpod_offline_sync_client/lib/src/database/merge_utils/foreign_key_projector.dart:730-746`).
- `_childrenReferencingParent` and closure/blocking decisions use `_attemptedForeignKeyValue` (`foreign_key_projector.dart:798-811`).
- Sync also relies on projection metadata to reconstruct attempted values: `_applyProjectedForeignKeyAttempts` replaces row insert payload columns with `projection.attemptedValue`, and `_fetchProjectedForeignKeyAttempt` returns attempted values for field updates (`packages/serverpod_offline_sync_client/lib/src/crdt/sync.dart:581-609`).

**Why this diverges:**

Once `SET NULL` or `SET DEFAULT` is materialized, the physical domain column no longer contains the attempted FK. `CrdtDataField` only stores HLC metadata, not the attempted value. Therefore the resolver needs `CrdtDataForeignKey.attemptedValue` to know which parent the child attempted to reference. That makes projection metadata part of the authoritative state, contrary to the spec. If two replicas have the same row/field/tombstone facts but one has stale or missing projection rows, they can compute different FK closures and sync payloads.

**Suggested direction:**

Choose one storage model and make it explicit. To match the current spec, keep attempted FK values in CRDT facts independently of the materialized visible domain column, then recompute `CrdtDataForeignKey` from those facts. If the intended design is to promote `CrdtDataForeignKey.attemptedValue` to durable CRDT fact storage, update the spec because that is not projection-only metadata anymore.

### FK-4: `visibleValue` is populated when `hasOverride == false`

**Spec reference:** Projection Metadata: `visibleValue` is meaningful only with `hasOverride`; when `hasOverride` is false, it means “same as attempted.”

**Current code:**

- `_recordForeignKeyAttemptsForRows` writes `visibleValue: attemptedValue` with `hasOverride: false` (`foreign_key_projector.dart:87-94`).
- `_materializeForeignKeyValues` writes `visibleValue: desiredVisibleValue` even when `hasOverride` is false (`foreign_key_projector.dart:665-670`).
- Tests currently expect inactive projections to carry the attempted UUID in `visibleValue`.

**Why this diverges:**

The stored metadata encodes duplicate state in inactive projections and makes `visibleValue == null` ambiguous without checking `hasOverride`. It also differs from the spec language agents will use when reasoning about churn and deduplication.

**Suggested direction:**

Store `visibleValue == null` whenever `hasOverride == false`, or update the spec to say inactive rows redundantly store the visible value. If changing code, update the tests that currently assert inactive `visibleValue == attemptedValue`.

### FK-5: Affected FK closure is not implemented

**Spec reference:** Merge Pipeline steps 2-4 and invariant/test 15: identify touched rows, expand to the FK closure in both directions, and ensure unrelated rows are not reconsidered when a non-indexed, non-FK field changes.

**Current code:**

- `_projectForeignKeys` takes only a transaction, with no touched row/field information (`foreign_key_projector.dart:235-262`).
- `_loadForeignKeyProjectionState` loops over every sync table and loads every CRDT row for the current user every time projection runs (`foreign_key_projector.dart:264-339`).
- `afterInsert`, `afterUpdate`, `insteadOfDelete`, and `mergeChanges` all call `_projectForeignKeys`; `Database.update(List<T>)` calls `updateRow` for each row, so a multi-row update can trigger a full global projection once per row (`packages/serverpod_offline_sync_client/lib/src/database/database.dart:289-304`).

**Why this diverges:**

Full recomputation is a valid oracle, but it is not the incremental closure algorithm described by the spec and it fails the “unrelated rows are not reconsidered” requirement. It also makes every unrelated field update scale with the entire synchronized database.

**Suggested direction:**

Thread a touched set into `_projectForeignKeys` from inserts, updates, deletes, incoming FK projection records, and rows whose visibility changed. Expand the set by both parent and child edges until stable. Keep an optional full recomputation path only for tests/oracle comparison.

### FK-6: Composite foreign keys are unsupported or ignored

**Spec reference:** Action Semantics: “For each child FK…” has no single-column-only exception.

**Current code:**

- `_foreignKeysByReferencedTable` throws during recorder initialization if any target table definition contains a composite FK (`packages/serverpod_offline_sync_client/lib/src/database/recorder.dart:95-106`).
- `_foreignKeyEdges` silently includes only FKs whose `columns.length == 1` and `referenceColumns.length == 1` (`recorder.dart:119-135`).

**Why this diverges:**

A schema with a composite FK either fails immediately or is omitted from projection, so the implementation cannot guarantee the no-visible-orphan invariant for those relations.

**Suggested direction:**

Either implement composite FK comparison/indexing in the projector or explicitly add a documented “single-column FK only” constraint to the spec and initialization validation.

### FK-7: Unique/FK stage order is only partially implemented and not proven by tests

**Spec reference:** Merge Pipeline step 6 and test 13: if FK repairs can change unique columns, recompute unique projection after FK projection or define/prove the opposite order.

**Current code:**

- Unique conflict resolution runs before FK projection for incoming inserts/updates (`merge.dart:273-345`).
- `_materializeForeignKeyValues` runs `_resolveUniqueConflictsAfterForeignKeyProjection` only for rows whose visible FK value changed (`foreign_key_projector.dart:588-679`).
- The test schema does not cover an FK repair on a unique-indexed `SET NULL` or `SET DEFAULT` FK; `Address.inhabitantId` is unique but uses `RESTRICT`, and the tested `SET NULL` / `SET DEFAULT` columns are not unique.

**Why this is incomplete:**

The code has a post-FK unique pass, but there is no oracle or targeted test proving that FK projection and unique projection converge when the repaired FK column is unique-indexed. There is also no documented proof that the pre-then-post order is ACI under batching and replay.

**Suggested direction:**

Add a test model with a unique nullable `SET NULL` FK and/or unique `SET DEFAULT` FK, then compare one-batch vs split-batch behavior and, ideally, full recomputation vs incremental projection. Document the chosen stage order once proven.

## Spec coverage gaps in tests

The new integration test file covers many important remote-merge paths, but the following spec cases are still absent or only partially covered:

- **Test 2:** multiple visible restrict children where any one child keeps the parent visible.
- **Local cascade:** local cascade deletes still need tests that assert synced user-delete tombstones on cascade descendants instead of only `foreignKeyCascade` visibility.
- **Test 3:** later child deletion/detachment is covered for one remote delete + one detached child, but not for multiple restrict children or broader detach/delete orderings.
- **Test 4/6/7 merge projection discipline:** local `SET NULL` / `SET DEFAULT` material-action behavior is covered by CRUD tests, but remote merge repairs should explicitly assert that ordinary child `CrdtDataField` HLCs are not advanced by projection.
- **Invalid `SET NULL`:** no non-nullable `ON DELETE SET NULL` relation proves it falls through to deterministic blocking.
- **Missing-parent repair:** no remote insert/update references a parent that is absent, so database constraint failures before projection are not exposed.
- **Replay metadata churn:** cascade replay checks `CrdtDataRow.visibility` only; projection-row churn for `CrdtDataForeignKey` is not snapshotted.
- **Test 11:** no fourth-degree alternating cascade/restrict/set-null/set-default chain, and no comparison against a full recomputation oracle.
- **Test 12:** no permitted FK cycle test.
- **Test 13:** no unique-indexed FK repair test.
- **Test 15:** no test asserts that non-indexed, non-FK updates do not reconsider rows outside the affected closure.
- **Composite FKs:** not covered and currently unsupported.

## Duplication and easy performance cleanup items

### PERF-1: Extract duplicated CRDT field upsert logic

`_recordUpdatedFields` (`recorder.dart:520-615`) and `recordFieldsUpdatedByTable` (`recorder.dart:682-746`) both load existing `CrdtDataField` rows, build `(rowId, columnId)` maps, increment HLCs, and split inserts vs updates. Extract a shared helper that takes `(tableName, crdtRows, schemaColumns, skippedFields?)`. This will also make it easier to ensure FK projection never accidentally records repair writes as user field updates.

### PERF-2: Batch projection upserts instead of querying one row at a time

`_upsertForeignKeyProjection` performs `findFirstRow` for every field (`foreign_key_projector.dart:814-857`), even though `_loadForeignKeyProjectionState` already bulk-loads projections. Add the projection row id to `_ForeignKeyProjectionRow`, reuse loaded state, and batch inserts/updates. The same helper can be used by `_recordForeignKeyAttemptsForRows`, which currently upserts inside nested row/column loops.

### PERF-3: Index parent and child lookups inside projection state

`_parentRowForValue` scans all rows for every lookup (`foreign_key_projector.dart:784-796`), and `_childrenReferencingParent` scans all rows for every parent edge (`foreign_key_projector.dart:798-811`). `_cascadeClosureForDelete`, `_closureBlockedByForeignKeys`, and `_materializeForeignKeyValues` repeatedly call those scans, producing O(edges × rows²) behavior. Build maps such as `(parentTable, parentColumn, value) -> row` and `(childTable, childColumn, attemptedValue) -> children` once per projection state.

### PERF-4: Avoid re-querying CRDT rows already present in projection state

`_setProjectedRowVisibility` receives `_ProjectedForeignKeyRow.crdtRowId` and current visibility, but it groups row UUIDs and calls `_findCrdtRows` again before updating visibility (`foreign_key_projector.dart:551-585`). Store enough row data in `_ProjectedForeignKeyRow` or issue batched `updateWhere` calls by CRDT row id and target visibility.

### PERF-5: Batch domain FK materialization writes

`_materializeForeignKeyValues` calls `_updateDomainRows` per child/edge whenever one FK value changes (`foreign_key_projector.dart:648-657`). Group by table/column/value where possible, or use a generated `CASE` update for rows with different projected values. This matters once projection is still full-global.

### PERF-6: Precompute foreign-key edges by parent and child table

The projector repeatedly evaluates `_foreignKeyEdges.where((edge) => edge.parentTableName == rowKey.$1)` and filters rows by child table in hot loops (`foreign_key_projector.dart:453-455`, `490-492`, `595-598`). Build `edgesByParentTable` and `edgesByChildTable` once on the recorder.

### PERF-7: Avoid full projection per row in `Database.update(List<T>)`

`CrdtDatabase.update` delegates to `updateRow` inside a loop (`database.dart:289-304`), and each `updateRow` triggers `afterUpdate` and `_projectForeignKeys`. For a list update, this can run global FK projection N times. Implement list update as one delegate `update`/`updateWhere` call followed by one recorder call and one projection pass.

### PERF-8: Avoid N+1 sync projection lookups

`_streamUpdates` fetches fields in one query, but `_fetchColumnValueForField` runs a projection lookup per field (`sync.dart:401-435`, `547-609`). `_streamInserts` fetches each domain row, then `_applyProjectedForeignKeyAttempts` queries all fields for that row (`sync.dart:360-399`, `520-600`). Include `foreignKey` in the field query for updates and/or prefetch projection rows by field id; for inserts, fetch only FK fields or prefetch all projection rows for streamed row ids.

## Validation notes

- Ran `dart test test/serverpod_offline_sync_test_server/test/integration/merge/foreign_key_invariant_test.dart --reporter=expanded --concurrency=1`; it passed all 21 tests.
- Passing that file does not cover the local cascade policy divergence, missing-parent cases, composite/cycle cases, or the performance/incremental-closure requirement above.
