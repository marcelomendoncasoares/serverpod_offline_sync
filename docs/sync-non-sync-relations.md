# Sync and non-sync foreign key boundaries

Status: proposal for a separate implementation issue.

## Summary

Foreign keys that cross the sync boundary are unsafe by default. A synced row is
owned, collected, merged, hidden, and repaired through CRDT metadata. A
non-synced row has none of that state. Letting arbitrary database relations
cross that boundary lets the database mutate or constrain synced rows without
the CRDT layer recording the corresponding facts.

There are only two allowed sync/non-sync relation shapes:

1. the package-owned ownership link from each synced domain row to
   `crdt_scopes`;
2. a synced row referencing a non-synced, server-authoritative reference table,
   but only after the sync protocol can provision that reference data before
   CRDT merge.

The ownership link is:

```yaml
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### Owner scope of this row. Maintained by the CRDT sync layer.
  scopeId: int?, relation(optional, parent=crdt_scopes, onDelete=Cascade)
```

`scopeId == null` remains valid persisted state, but it means the row is
orphaned from CRDT ownership: it is never synced, never collected for outbound
sync, and not removed by deleting a scope. `scopeId != null` means the row is
owned by that scope, participates in CRDT, and is physically purged when the
scope is deleted.

All other foreign keys between synced and non-synced tables must fail
`initialize()`. Until the reference-data sync phase exists, `initialize()` must
also reject server-authoritative reference-table relations even when they use
`onDelete=Restrict`.

## Table classes

- **Synced table:** any application table passed to the CRDT `syncTables`
  configuration.
- **Non-synced table:** any other application table known to the Serverpod
  serialization manager.
- **Protocol-provisioned reference table:** a non-synced table whose rows are
  authored by the server, sent through a reference-data phase in the sync
  protocol, applied before CRDT merge, and not removed while synced rows
  reference them.
- **Package metadata table:** CRDT infrastructure tables owned by this package,
  especially `crdt_scopes`, `crdt_nodes`, `crdt_data_rows`,
  `crdt_data_fields`, `crdt_data_tombstone`, and FK projection tables.

`crdt_scopes` is not a synced domain table. The `scopeId -> crdt_scopes.id`
relation is a special package-owned purge boundary, not an application-level
foreign key.

## Allowed relations

### Synced -> synced

Allowed under the normal FK invariant rules:

- the child and parent are both in `syncTables`;
- supported FK shapes are single-column child references to single-column
  parent references;
- local writes assert same-scope visibility;
- merge-time FK projection repairs hidden, missing, or foreign-scope targets.

### Non-synced -> non-synced

Ignored by CRDT. These relations are normal application/database relations.

### Synced -> `crdt_scopes` through `scopeId`

Allowed, and required once this proposal is implemented. The relation must be
exactly:

- child table is a synced domain table;
- child column is the reserved `scopeId` column;
- child column type is nullable `int`;
- parent table is `crdt_scopes`;
- parent column is `id`;
- `onDelete` is `Cascade`;
- `onUpdate` is `NoAction` or unspecified database default.

This relation exists only to make terminal scope purge database-enforced. It
does not change normal CRDT deletes, which remain soft deletes recorded in
CRDT metadata.

### Future: synced -> protocol-provisioned reference table

Allowed when every referenced row is server-authoritative reference data, such
as a global category table used to group synced rows, and when the sync
protocol provisions that table before applying CRDT changes. The relation must
be strictly constraining: it may prevent reference-table deletion, but it must
never cause the database to mutate synced rows behind the CRDT recorder.

This exception must not be implemented as a schema-only relaxation. The same
implementation issue that permits this relation must also add the reference-data
sync phase described below.

The allowed shape is:

- child table is a synced domain table;
- parent table is a non-synced application table;
- parent table is declared in sync configuration as protocol-provisioned
  reference data;
- the FK is single-column child reference to single-column parent reference;
- `onDelete` is exactly `Restrict`;
- `onUpdate` is `Restrict`, `NoAction`, or unspecified database default;
- the referenced parent key is treated as immutable by application policy;
- referenced parent rows are applied before any local insert, local update, or
  incoming merge can use them.

`NoAction` is intentionally not accepted for `onDelete`: the delete must fail
immediately rather than being deferrable to transaction end. `Cascade`,
`SetNull`, and `SetDefault` are forbidden because they can physically delete or
mutate synced rows without CRDT tombstones or field HLCs.

This exception does not make the reference table offline-first. Creating,
renaming, deleting, or otherwise syncing reference rows is outside CRDT. The
server authors reference data, and clients cache the latest server snapshot or
delta before CRDT merge.

This exception also does not expand the global unique-index exception. A unique
index involving a FK to a protocol-provisioned reference table is
application-level uniqueness and must include `scopeId` unless another explicit
policy is added.

## Reference-data sync phase

The sync protocol must treat server-authoritative reference data as an ordered
precondition for CRDT merge:

1. The sync handshake includes the client's reference-data versions or hashes.
2. The server sends missing reference-data snapshots or deltas before CRDT
   changes that may reference them.
3. The client applies those reference rows to local non-synced tables.
4. Only after the reference-data phase succeeds does the client apply incoming
   CRDT operations.
5. If an incoming CRDT row references missing reference data after that phase,
   the sync fails as a protocol violation. FK projection must not repair it.

Reference data has server-authoritative replacement/delta semantics, not CRDT
semantics. Clients do not author reference rows, and conflicts are not resolved
through HLCs, unique conflict projection, or FK projection.

## Forbidden relations

### Non-synced -> synced

Always forbidden.

A non-synced child has no CRDT row, no scope ownership, and no merge history.
If it references a synced parent, then a CRDT soft delete can hide the parent
while the database FK still sees the physical parent row. Delete actions and
visibility checks become incoherent, and the current recorder can also reach
paths that assume the child table has CRDT schema metadata.

### Synced -> other non-synced application table

Forbidden, except for:

- the special `scopeId -> crdt_scopes.id` relation;
- the protocol-provisioned reference-table relation above.

The apparent safe use case is an app user/auth table, because that table is
server-authoritative and must exist before offline data can be synced. That can
fit the protocol-provisioned reference-table rule only when user rows are
provisioned by the sync reference-data phase and never deleted while synced rows
reference them. If account deletion must erase synced data, it should not rely
on a direct app-user FK cascade. A direct unrestricted FK from synced rows to a
non-synced table is unsafe:

- merge inserts and updates cannot project or repair missing non-synced
  parents;
- database FK failures become raw merge failures, not deterministic CRDT
  projection;
- deleting the non-synced parent with `CASCADE`, `SET NULL`, or `SET DEFAULT`
  can change synced child rows without CRDT tombstones or field HLCs;
- `NoAction` is not strict enough for this boundary because it can be
  deferrable.

The app-user relation should be modeled outside synced domain rows. Account
deletion should revoke the user and purge the user's `CrdtScope`, not rely on
arbitrary application FKs into synced data.

### Synced -> package metadata table other than `crdt_scopes`

Forbidden. Domain rows must not reference CRDT metadata internals such as nodes,
schema rows, field rows, tombstones, or ownership violations.

### Non-synced -> package metadata table

Forbidden unless the relation is part of a future explicit package API. An
application table must not depend on metadata rows whose lifecycle is controlled
by sync, merge, or scope purge.

## Scope purge semantics

Deleting a scope is a terminal GDPR/account-erasure operation, not a CRDT
operation.

A safe purge workflow is:

1. Revoke the account or scope so no new sync session can start.
2. Mark the scope UUID as deleted, or otherwise make auth reject future
   `getOrCreate(uuidScopeId)` attempts for that UUID.
3. Delete `crdt_scopes.id`.
4. Let database cascades remove:
   - synced domain rows with `scopeId = deletedScope.id`;
   - `crdt_nodes` for that scope;
   - `crdt_data_rows` for that scope;
   - row fields, tombstones, and FK projection rows through their existing
     metadata cascades.
5. Delete or anonymize diagnostics that intentionally outlive metadata
   cascades, such as durable ownership violation rows. Those rows store
   denormalized table names and scope UUIDs only; they do not reference
   purged metadata through foreign keys.

If an old offline client later reconnects with data for a purged scope, sync
must fail with a terminal "scope deleted/reset required" response. The server
must not recreate the scope and must not accept the old CRDT chain, or erased
data can be resurrected.

Rows with `scopeId == null` are not affected by scope purge. They are
application-owned orphan/admin rows and remain outside CRDT.

## Initialize validation

`initialize()` must inspect all generated table definitions and classify every
foreign key by child and parent table class.

Validation rules:

- `synced -> synced`: allowed only when the existing FK invariant support can
  handle the FK shape.
- `non-synced -> non-synced`: ignored.
- `synced -> crdt_scopes` through reserved `scopeId`: allowed only when it
  matches the exact allowed shape above.
- `synced -> protocol-provisioned reference table`: allowed only when the
  reference-data sync phase is implemented, the parent table is declared as
  protocol-provisioned reference data, and the relation matches the exact
  allowed shape above. Without that protocol support, reject it even when the
  FK uses `onDelete=Restrict`.
- every other `synced <-> non-synced` or `domain <-> package metadata` FK:
  fail initialization with an error naming the offending constraint.

The error message should explain the allowed alternatives:

- make both tables synced;
- make both tables non-synced;
- remove the relation;
- use the future reference-data sync phase with `onDelete=Restrict` for
  immutable server-authoritative reference data;
- for account deletion, use the package-owned scope purge relation instead of
  an application FK.

## Tests

The implementation issue should add schema/initialize tests for:

- accepting `scopeId: int?, relation(optional, parent=crdt_scopes,
  onDelete=Cascade)` on every synced table;
- rejecting `sync -> non-sync` restricted reference-table FKs with
  `onDelete=Restrict` while the reference-data sync phase is absent;
- accepting `sync -> non-sync` protocol-provisioned reference-table FKs with
  `onDelete=Restrict` after the reference-data sync phase is implemented;
- applying reference-data deltas before CRDT merge when incoming rows reference
  those rows;
- failing sync as a protocol violation when incoming CRDT rows reference
  missing reference data after the reference-data phase;
- rejecting `non-sync -> sync`;
- rejecting `sync -> non-sync` application FKs with `NoAction`, `SetNull`,
  `SetDefault`, and `Cascade`;
- rejecting global unique indexes over protocol-provisioned reference FK
  columns unless the index includes `scopeId`;
- rejecting synced domain relations to package metadata tables other than
  `crdt_scopes`;
- preserving orphan rows with `scopeId == null` across scope purge;
- deleting a scope removes owned domain rows and CRDT metadata for that scope;
- stale clients for a purged scope cannot recreate the scope or sync old data.
