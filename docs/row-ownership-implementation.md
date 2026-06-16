# Row ownership — implementation plan

Companion to [row-ownership.md](row-ownership.md), which holds the design and
its rationale. This document is the concrete execution plan: files, symbols,
ordered steps, and verification per phase. Each phase lands green on its own
(analyzer clean, full test suite passing) and is a natural PR boundary.

## Conventions and standing gotchas

- **Codegen cycle after any model change:**
  `dart run melos generate && dart run melos create-migration` from the repo
  root. The melos script already runs generate twice on the module (known
  generator quirk) and orders module before test project. Generated code and
  migrations are gitignored; only `*.spy.yaml` and handwritten sources are
  reviewed.
- **Test command:** `dart test test/ --concurrency=1` inside
  `test/serverpod_offline_sync_test_server`. Parallel test files break the
  embedded-server sync suites with spurious failures; never diagnose from a
  default-concurrency run. Current green baseline: 252 tests.
- **Recorder's nested session stays lazy.** `CrdtMutationRecorder._session`
  wraps a second, never-initialized `CrdtDatabase`. Any new logic on the
  query path must not touch recorder state (schema map, scope cache) unless
  the table is a synced UUID-PK domain table — keep resolutions inside
  closures/late paths, as `mergeWhereWithTombstone` does today.
- **Dynamic access pattern** for the reserved domain column (no shared
  interface exists): read `(row as dynamic).scopeId as int?`; write via
  `copyWith(scopeId: …)` for caller-supplied instances (never mutate them
  observably) and via plain setter assignment for package-owned instances
  (delegate-returned rows). `patchTableRow` stays merge-only.

---

## Phase 1 — naming, contract, validation

Goal: final names everywhere, the two-column contract validated, and the
reserved column invisible to every metadata path. No behavior changes beyond
validation errors.

### 1.1 Storage and protocol renames (module models)

In `packages/serverpod_offline_sync_server/lib/src/models/`:

- `node/user.spy.yaml` → `node/scope.spy.yaml`: class `CrdtUser` →
  `CrdtScope`, table `crdt_users` → `crdt_scopes`, field `uuidUserId` →
  `uuidScopeId`, relation name `user_nodes` → `scope_nodes`.
- `node/node.spy.yaml`: the `CrdtUser` relation becomes `CrdtScope`
  (generated FK column `userId` → `scopeId`).
- `data/row.spy.yaml`: `user: CrdtUser?` relation → `scope: CrdtScope?`
  (column `userId` → `scopeId`); index `crdt_data_rows_user_tbl_row_idx` →
  `crdt_data_rows_scope_tbl_row_idx` with `fields: scopeId, tblId,
  uuidRowId`; **delete the commented-out `crdt_data_rows_tbl_row_vis_idx`
  block** (obsolete per the spec's read path).
- `sync/violation.spy.yaml`: add the sparse durable
  `crdt_sync_ownership_violations` table for terminal ownership violations.
  It is keyed by `(domainTableName, uuidRowId, ownerScopeUuid,
  incomingScopeUuid)` and stores operation, nullable table/row/node
  relations, HLC datetime/counter, and first/last seen plus occurrence count.
  If a merge rollback removes the incoming node row, recording may recreate
  that node identity without `lastReceivedHlc` for inspection. It does not
  store the rejected payload or a payload hash.
- Sweep `data/`, `merge/`, `sync/`, `schema/` models for `user`-named fields
  that key a scope (none found in yaml today; endpoint/method parameters are
  covered in 1.2).

Run the codegen cycle; fix fallout in handwritten code mechanically.

### 1.2 Dart-side renames (client package `lib/src/`)

- `managers/user.dart` → `managers/scope.dart`: `CrdtUserManager` →
  `CrdtScopeManager`.
- `managers/hlc.dart`: `HlcManager.forUser` → `forScope`,
  `normalizedUserId` → `normalizedScopeId`.
- `database/database.dart`: `userForTransaction` → `scopeForTransaction`
  (still keyed by `Transaction` identity); `mergeChanges({userId})` →
  `mergeChanges({scopeId})`; `transactionForUser` and `persistentUserId`
  **keep their names** (user-first public API per the spec).
- `database/recorder.dart`: `_getEffectiveUser` → `_getEffectiveScope`,
  `userScopeForQueries` → `scopeForQueries`, `getOrCreateUser` →
  `getOrCreateScope`, `_userManager` → `_scopeManager`, plus the
  `CrdtUser` → `CrdtScope` type sweep through `merge.dart`,
  `merge_utils/*.dart`, `crdt/sync.dart`, and
  `packages/serverpod_offline_sync_server/lib/src/endpoints/`.

Verification: analyzer clean across `packages/ test/ benchmark/`; full test
suite green (renames only).

### 1.3 Contract validation in `CrdtSchemaRegistry`

`packages/serverpod_offline_sync_client/lib/src/database/schema.dart`,
constructor, next to the existing UUID-PK check:

- For every sync table, find `columns` entry with `columnName == 'scopeId'`.
  Missing → `StateError` listing the offending tables with the paste-ready
  snippet (`scopeId: int?`) and the hint "if the column is declared with
  `scope=serverOnly`, remove the scope — the column must exist on every
  database".
- Present but not `Column<int>` → same error, mistyped variant.

In `recorder.dart` `initialize()` (where `_tableDefinitionsByName` provides
index definitions): reject every non-primary unique index on a synced table
whose elements do not include `scopeId`, except the single-column FK unique
indexes Serverpod requires for one-to-one relations to another synced row.
Ordinary global unique indexes are forbidden until the package has a
deterministic cross-scope conflict policy.

### 1.4 Reserved-name exclusions

All keyed on the literal column name `scopeId`:

- `schema.dart` `_columnsPerTableName`: filter `scopeId` out, so it is never
  registered in `crdt_schema_columns` (this also keeps it out of the synced
  schema hash, which is derived from registered columns).
- `recorder.dart` `_syncedTableColumnNamesForMerge`: filter `scopeId`.
- `recorder.dart` `_recordUpdatedFields` / column selection: extend the
  existing `columnName != 'id'` filters to also exclude `scopeId`
  (`database.dart::_updateRowWithoutRecording` has the same filter — change
  both).
- `merge.dart` `_sanitizeMergeRowData` (line ~709): strip `scopeId` from
  incoming data maps.
- `crdt/sync.dart` `_streamInserts`: null the field on the serialized
  `data:` payload (dynamic setter on the copy) so outbound sync never emits
  it. (`_streamUpdates` needs nothing: `scopeId` has no field metadata after
  the exclusions above.)

### 1.5 Test models gain the column

Add `scopeId: int?` (with the doc comment from the spec) to every synced
model in `test/serverpod_offline_sync_test_server/lib/src/models/`:
`address`, `city`, `company`, `organization`, `person`,
`required_set_null_child`, `restrict_child`, `town`, `types`, `unique`,
`unique_composite`, `unique_set_null_child`, `unique_uuid`, and the nine
`fk_chain/*` models. (`types_enum` is not a table.) Run the codegen cycle.

Phase 1 exit: analyzer clean; 252 tests green with the column present but
not yet enforced.

---

## Phase 2 — write-path enforcement

Goal: stamp-or-assert, immutability, atomic merge ownership, FK and unique
guards.

### 2.1 Stamp-or-assert in the proxy (`database/database.dart`)

Add a private helper used by `insert` and `insertRow` (inside their
`runInTransactionOrSavepoint` blocks, where the effective scope is
resolvable via `_recorder`):

- Per input row, read `(row as dynamic).scopeId as int?` — guarded by
  `_recorder.isCrdtTracked<T>()`, so untracked tables and CRDT-internal
  models skip the path entirely (preserves the nested-session laziness
  rule).
- `null` → build the database-bound instance with
  `(row as dynamic).copyWith(scopeId: effectiveScope.id)`; record the index
  as *stamped*. The caller's instance is untouched.
- non-null and `!= effectiveScope.id` → throw with table, row id, provided
  vs effective scope.
- After the delegate insert, strip returned rows at stamped indices via the
  plain dynamic setter (delegate rows are package-owned; in-place,
  allocation-free). Explicit indices keep the value (round-trip symmetry,
  per row in batches).

The reinsert path inside `insertRow`'s catch block follows the same rule.

### 2.2 Immutability and update/delete assertions (`database.dart`)

- `update`/`updateRow`: assert the model's `scopeId` (non-null → must equal
  effective scope); strip it from the SET list (1.4 already excludes it
  from the column filter); strip/keep returned rows per the round-trip
  rule.
- `updateWhere`/`updateById`: scan the caller's `columnValues` for
  `column.columnName == 'scopeId'` → throw ("scopeId is immutable and owned
  by the sync layer").
- `deleteWhere`/`deleteRow`/`delete`: no model assertion needed — the
  scoped read in `deleteWhere` (Phase 3 isolation filter) bounds them — but
  the `upsert`/`upsertRow` stubs get the assertion comment for when they
  are implemented.

### 2.3 Atomic merge-insert ownership check (`database/merge.dart`)

Restructure `_applyMergeInsert`'s `currentRow == null` branch per the
spec's five steps:

1. Read the existing domain row by id through `_db` (the inner database —
   no visibility predicate), extracting `scopeId` dynamically.
2. Owner == merging scope → proceed as the same-scope update path (recovery
   for lost trackers).
3. Foreign owner → roll back the merge work for the incoming change, record a
   durable `crdt_sync_ownership_violations` row (operation, table, row id,
   owning scope UUID, merging scope UUID, nullable table/row/node relations,
   and node/HLC metadata), and throw
   `CrdtSyncOwnershipViolationException`.
4. No row → proceed to insert with `scopeId` stamped on the patched row.
5. Wrap the whole application — `_upsertMergeRow`, unique resolution
   (`_resolveForIncomingInsert`), FK-safe handling, domain write — in a
   savepoint (`DatabaseUtil.runInTransactionOrSavepoint` with the active
   transaction). On a domain PK violation, roll back the savepoint, re-read
   the row, and re-apply the ownership decision. **Nothing from a rejected
   insert survives**: no CRDT row, no released unique values, no FK attempts.
   Since `mergeChanges` itself runs inside `transactionForUser`, the merge
   transaction throws a rich ownership exception and `CrdtDatabase.mergeChanges`
   records the violation after that transaction rolls back, then rethrows with
   the persisted violation id.

`_applyMergeInsertForExistingRow` (tracker exists) asserts the domain row's
owner equals the merging scope before updating; mismatch → record and throw
(tracker/domain disagreement is corrupted state, not a valid path).

### 2.4 FK same-scope enforcement

- `recorder.dart` `_assertVisibleForeignKeyTargets`: extend the target
  query/check with `parent.scopeId == effectiveScope.id` next to the
  visibility condition.
- `merge.dart` `_safeIncomingForeignKeyData` /
  `merge_utils/foreign_key_projector.dart`: a target row owned by another
  scope is classified exactly like an invisible target, flowing into the
  existing attempt/override repair.

### 2.5 Scoped unique conflict resolution (`merge_utils/unique_resolver.dart`)

Where conflict groups are resolved: use `scopeId` as part of the unique lookup
predicate, but never as a releasable/updateable column. Since global unique
indexes are rejected at startup, conflict groups are same-scope only and the
existing HLC comparison remains deterministic.

Phase 2 exit: suite green; the multi-user fixtures in
`tombstone_scope_test.dart` will start failing here — convert them in the
same PR into the enforcement expectations (fail-and-record) or temporarily
mark them for the Phase 4 rewrite.

---

## Phase 3 — read paths and sync

### 3.1 Predicates (`database/tombstone.dart`)

- Scoped branch: add the isolation filter `t.scopeId = <scope>` (raw
  `Expression` on the domain table's `scopeId` column, resolved via
  `table.columns`) AND the existing correlated `NOT EXISTS` probe (metadata
  column now named `scopeId` after 1.1).
- Unscoped branch: replace the `GROUP BY`/`MIN` form with the row-keyed
  probe — `NOT EXISTS (… WHERE c.scopeId = t."scopeId" AND tblId = ? AND
  uuidRowId = t.id AND visibility > …)` — and **delete the server-only-index
  TODO comment block**.
- The same branch applies to include-graph tables in
  `_walkIncludeGraphForTombstone` (root and `IncludeObject`/`IncludeList`
  paths already share `whereVisibleOnCrdtRow`).

### 3.2 Result stripping (`database/database.dart`)

Post-process rows returned by `find`/`findFirstRow`/`findById` when the
query had a scope (admin reads skip this): null `scopeId` in place on each
row, then walk the `Include` graph — for each include key, resolve the
nested object (or list) dynamically by field name and strip recursively.
Only synced tables are touched (`isCrdtTracked` per table), preserving
laziness.

### 3.3 Outbound sync owner checks (`crdt/sync.dart`)

- `_streamInserts` (line ~366): after fetching the physical domain rows,
  fail and record a durable violation when `scopeId` differs from the
  collecting scope's id.
- `_streamUpdates` (~414): verify the owning domain row before emitting
  field values, same fail-and-record rule.
- `_streamDeletes` (~460): when the domain row still exists, verify the
  owner before emitting the tombstone, same fail-and-record rule.

Phase 3 exit: full suite green, including `find_test.dart` semantics
unchanged for single-scope fixtures (isolation filter is a no-op with one
scope; stamped rows match it by construction).

---

## Phase 4 — tests and benchmarks

### 4.1 Enforcement suite

New `test/integration/crud/scope_enforcement_test.dart` (absorbing and
replacing the multi-user groups of `tombstone_scope_test.dart`):

- stamp on insert (single + batch, mixed explicit/null rows);
- assert-on-mismatch throws for insert and update;
- `updateWhere`/`updateById` rejection of `scopeId` column values;
- round-trip symmetry: null in → null out, explicit in → kept, per row;
  caller's input instance left unmutated;
- stripping on scoped reads incl. include graphs; retention on unscoped
  reads;
- merge-insert collision fail-and-record, including the PK-race regression
  (two scopes, same UUID, savepoint leaves no metadata/unique-release/FK
  residue, durable violation survives rollback);
- stale foreign tracker fails before producing outbound insert/update/delete
  payloads and records a durable violation;
- FK cross-scope repair; cross-scope unique yield on a deliberately global
  index.

### 4.2 Combination smoke tests

- Two-scope SQLite database: read isolation both directions; per-scope
  uniqueness on a composite `(scopeId, name)` index added to the `Unique`
  test model.
- One `withServerpod` sync roundtrip (existing suites already cover the
  wiring; assert rows arrive stamped with the receiving database's local
  scope id and that `scopeId` never appears in stream payloads).

### 4.3 Benchmarks (`benchmark/utils/scope.dart`)

`TombstoneScopeBenchmark`: seeding becomes ownership-conformant — noise CRDT
rows get matching `scopeId` on their (metadata-only) trackers, second-tracker
seeding is removed from the timing scenarios and survives only as an
enforcement-scenario fixture. `run.dart` wiring unchanged; re-run
`dart run run.dart` and update the published numbers note.

### 4.4 Docs

Update `docs/row-ownership.md` status line to "implemented"; sweep
`foreign-key-invariants.md` and `unique-constraint-invariants.md` for
cross-references to user/scope naming.

---

## Suggested PR slicing

| PR | Content | Risk profile |
| -- | ------- | ------------ |
| 1  | 1.1 + 1.2 (renames + codegen) | mechanical, large diff, zero behavior |
| 2  | 1.3 + 1.4 + 1.5 (validation, exclusions, test models) | small, behavior = startup errors only |
| 3  | 2.1 + 2.2 (proxy stamp/assert/immutability) | core write semantics |
| 4  | 2.3 + 2.4 + 2.5 (merge ownership, FK, unique guards) | the security fixes |
| 5  | 3.1 + 3.2 (predicates + stripping) | read semantics; deletes the GROUP BY form |
| 6  | 3.3 (outbound sync checks) | closes the last leak |
| 7  | 4.x (test consolidation + benchmarks + docs) | hardening |

Each PR: `dart analyze packages/ test/ benchmark/` clean and
`dart test test/ --concurrency=1` green in the test server package before
review.
