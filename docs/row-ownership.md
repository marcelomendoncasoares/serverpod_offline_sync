# Row ownership and scope isolation

Status: accepted design, implementation pending (see *Implementation plan*).
The *Future: shared scopes* section is direction, not commitment.

## Summary

Synced rows are physically shared on the server while their CRDT metadata is
tracked per user. Ownership is therefore implicit: nothing in the data model
prevents two users from tracking the same `(table, uuidRowId)` pair, but the
storage model cannot actually represent that state. Deletes survive it because
visibility is per-user metadata; field values cannot, so concurrent updates by
different users silently overwrite each other across tenant boundaries.

This document makes ownership explicit. The core decisions:

> **Every synced row is owned by exactly one scope.** Two scopes never sync
> the same row. Sharing, when it arrives, will be modeled as shared scopes
> that multiple identities subscribe to — never as two scopes aliasing one
> row.

> **Every synced table declares `scopeId`, identically on server and
> client.** The column is a hard requirement, never `scope=serverOnly`, so
> both databases run one schema shape and the package has exactly one code
> path. "Single user" is a usage pattern (a database that happens to contain
> one scope), not a mode: there are no mode flags, no schema branching, and
> no per-mode test matrix.

> **The sync layer owns the column: stamp if null, assert if set — and the
> value leaves the way it came in.** On every insert, a null `scopeId` is
> stamped from the effective scope; a non-null one must equal it or the
> operation throws. Stamped values are stripped back to null on returned
> rows and on scoped reads, so the database-local value never leaks into
> endpoint payloads; explicitly provided values are kept on the way out.
> One rule serves both personalities: users who never want to think about
> tenancy never do, and users who pass it explicitly get verified
> explicitness and keep seeing what they manage. After insert the column is
> immutable.

The package contract for a synced table is two structural requirements, both
validated at `initialize()` with paste-ready error messages:

```yaml
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### Owner scope of this row. Maintained by the CRDT sync layer.
  scopeId: int?
```

No model inheritance is needed: like the UUID primary key requirement, the
contract is structural (a reserved column name with a required type, checked
by `CrdtSchemaRegistry`), not nominal (a base class), which is the only
option anyway since Serverpod models cannot extend models from an imported
module. The same constraint shapes the implementation: with no common
interface to call, the package stamps the field through dynamic dispatch —
`(row as dynamic).copyWith(scopeId: …)` (or the plain field setter, since
generated fields are mutable). The field name is a compile-time constant, so
the serialization manager's `patchTableRow` would be the wrong tool here: its
serialize–patch–deserialize round-trip costs 50–200× a dynamic call and is
justified only where field names are data-driven, as in the merge path.

## Goals and constraints

1. **One ownership model, one schema shape, one code path.** Earlier drafts
   explored an optional column and then schema-presence modes; both were
   rejected because every mechanism (CRUD, merge, sync, unique and FK
   invariants) would need building and testing per branch. Requiring the
   column everywhere deletes the mode system, the schema-projection
   generator feature it needed, and the per-mode test matrix. The cost — an
   int column (~1–2 bytes per row in SQLite) and a visible read-only field
   on domain models — is accepted.
2. **No external model inheritance.** Serverpod does not let application
   models extend models from an imported module, so a base class cannot
   carry shared columns into user tables. Requirements are enforced by
   runtime validation, and generic field access by dynamic dispatch or
   `patchTableRow`.
3. **Roles are not hard-coded.** Nothing in the package assumes the server
   is multi-user or the client single-user. Multi-account devices and
   single-tenant servers are the same code path with different scope counts.
4. **Application code cannot get tenancy wrong.** The package must verify
   any user-supplied scope against the effective scope regardless (a tenant
   id from application code can never be trusted), so correctness never
   rests on call-site discipline.
5. **Multi-device per user keeps working unchanged.** Devices of one user
   share the user's scope and merge into one chain.
6. **Sharing must not be foreclosed.** Collaborative data is a core
   local-first use case; the design must leave a clean path to it.

## Problem: ownership is implicit

The server holds one physical domain row per `(table, uuidRowId)`, while CRDT
metadata (`crdt_data_rows` and its children) is keyed per
`(scopeId, tblId, uuidRowId)`. The unique index allows multiple scopes to
track the same row. Symptoms, in increasing severity:

1. **Tombstone masking.** A tombstone recorded by one user (or for another
   table) used to hide unrelated rows sharing a UUID. Fixed by scoping the
   visibility predicates — but the fix required defining what an *unscoped*
   query means ("hidden only when hidden for every tracking user"), an
   aggregate query shape, and a covering index we could not afford on
   clients. Complexity that exists only because multiple trackers can.
2. **Update leakage is unrepresentable.** Field values materialize into the
   single shared domain row. If two users' chains track it, each chain has
   its own LWW history, but there is only one cell to materialize into.
   Whoever merges last wins, across tenant boundaries, with no record of the
   conflict. This is not a policy gap — divergent per-user values cannot be
   stored at all.
3. **Merge-insert overwrites other users' rows.** `_applyMergeInsertForMissingRow`
   treats "missing" as "no CRDT row *for the merging user*" and writes the
   domain row update-then-insert. A client that syncs an insert reusing
   another user's row UUID overwrites that user's data through the normal
   sync path. (Updates and deletes are already safe: they no-op when the
   merging user has no tracker.)
4. **Unique-conflict resolution crosses tenants.** Domain unique indexes are
   global on the server and the flag policy (see
   `unique-constraint-invariants.md`) picks the winner by HLC with no notion
   of ownership. One user's insert can cause another user's newer row to have
   its unique value rewritten.

All four share one root cause: the metadata says who owns a row, but nothing
enforces that the answer is unique, and the domain storage assumes it is.

"Leave it up to users" is rejected explicitly: symptom 2 means the storage
model cannot represent what multi-scope tracking promises, so allowing it is
not granting flexibility — it is permitting silent cross-tenant data
corruption. Applications that need shared data need shared *scopes* (see
*Future: shared scopes*), which preserve the one-chain-per-row property that
makes LWW merging coherent.

## The `scopeId` column

### Contract

`scopeId` is a reserved column name, required on every synced table:

- The value references `crdt_scopes.id` (the table currently named
  `crdt_users`; renamed in Phase 1) — the scope that owns the row. Today a
  scope is a user; the name is chosen deliberately so shared scopes can be
  added later without renaming storage again.
- **The value is database-local.** It is a normalization of the scope UUID
  into the local `crdt_scopes` table; the client's int for a scope is not
  the server's int for the same scope. The sync layer re-maps it on merge
  and never ships it as data, and application code cannot ship it by
  accident either, because scoped reads return it stripped (see *Keeping
  the value off the wire*). This is also why the field is nullable: a model
  outside the database honestly carries "not mine to say" instead of a
  meaningless local id.
- `scope=serverOnly` is **rejected**: it would reintroduce asymmetric
  schemas and with them the mode branching this design exists to delete.
  The client-side registry sees the column missing and says exactly that.
- The column is **owned by the sync layer** and immutable after insert.
  The value round-trips the way it came in: callers that never provide it
  never receive it (stamped values are stripped from returned rows, and
  scoped reads return null), explicit callers keep seeing what they passed,
  and unscoped admin reads always return it populated (see *Keeping the
  value off the wire*).

### Write semantics: stamp if null, assert if set

On every local insert (and batch insert), the database proxy resolves the
effective scope — transaction scope, else persistent scope, else the
operation throws, exactly as recording already requires — and applies one
rule per row:

- `scopeId == null` → the row is stamped with the effective scope before the
  delegate insert (one write, not an UPDATE after the fact). Stamping uses a
  dynamic call, since no base interface can declare the field; this is the
  per-row hot path of every insert, which is why the heavier `patchTableRow`
  stays out of it. In-place mutation is preferred (generated fields are
  mutable, so no per-row allocation); dynamic `copyWith` is the fallback
  only if rows were ever immutable.
- `scopeId != null` → it must equal the effective scope, or the operation
  throws. Explicit callers get verification for free.

Consequences of the rule:

- **Cross-scope writes cannot succeed.** A model carrying another scope's id
  trips the assertion; a model carrying null is stamped with the acting
  scope and then the scoped `WHERE` filter (which includes
  `scopeId = <scope>`) matches no foreign row, so the update or delete fails
  with "no rows" instead of touching another tenant's data.
- **The column never appears in update SET lists**, exactly like `id`
  (`_updateRowWithoutRecording` already filters `columnName != 'id'`).
  A tampered model cannot attempt to move a row across scopes.
- **Merges stamp from the merging scope** (each merge acts in exactly one
  scope), and incoming payloads have the field stripped by
  `_sanitizeMergeRowData` — it is not portable data.

### Keeping the value off the wire

The wire discipline is enforced by construction and respects the caller's
choice: **the field leaves the package the way it came in.**

- **Stamped values stay internal.** When a model comes in with `scopeId`
  null, the proxy stamps the effective scope for the database write, and
  the rows handed back by that operation carry null again. The same applies
  to scoped reads, which have no input model to respect. Callers who never
  provide the value never observe it, and cannot serialize the
  database-local int into endpoint payloads even by accident.
- **Explicit values are respected.** When a model comes in with `scopeId`
  set (and verified by the assert arm), the rows returned by that operation
  keep it — the package does not hide a value the caller knowingly manages.
  In batch operations the rule applies per row.
- **Unscoped (admin) reads keep it populated.** Within a scoped read the
  value is redundant — it always equals the acting scope — but for admin
  reads it is the only per-row ownership information, and those results are
  consumed server-side.

Mechanically this stays on the cheap path: rows returned by the delegate are
fresh, package-owned instances, so stripping is a per-row in-place setter
with no allocation, applied at the same proxy layer that injects the
visibility predicates. The caller's own input instance is never left
observably mutated by a stamp: the implementation either stamps a copy bound
for the database or restores the field after the write.

This mirrors mature row-level-security practice, where the tenant column is
populated from session context (`DEFAULT current_setting(...)`) precisely so
application code cannot get it wrong, rather than passed through call sites.

A convenience accessor exposing the effective scope's normalized id (e.g. on
the transaction or the database) may be added for explicit callers and
custom filtering; it is not required by any flow, and its documentation
carries the database-local warning above.

### Sync-layer exclusions

`scopeId` is infrastructure that happens to live in the domain row. Keyed by
the reserved name, it is excluded from:

- `crdt_schema_columns` registration and field-level CRDT metadata (it has no
  HLC history; it is never merged as a field) — which also keeps it out of
  the synced-schema hash symmetrically on both sides;
- update recording (`afterUpdate` ignores it) and merge payload sanitization.

### Validation

`CrdtSchemaRegistry` extends the existing UUID primary key check:

- every synced table must have a nullable `int` column named `scopeId`
  (missing or mistyped → error with the paste-ready yaml, including the
  "remove `scope=serverOnly`" hint when the server schema has the column and
  the client schema does not);
- unique indexes on synced tables that do not include `scopeId` produce a
  startup *warning*, so globally-unique-on-purpose (an `email` column, say)
  is a visible decision rather than an accident.

## Unique indexes

Per-scope uniqueness is declared by the application as an ordinary composite
index, which now exists identically on both databases:

```yaml
indexes:
  person_scope_name_unique_idx:
    fields: scopeId, name
    unique: true
```

Whether a unique value is per-scope or global is deliberately the
application's choice — only the domain knows that an email is global and a
nickname is not. On a deployment that happens to contain one scope, a
composite unique with a constant `scopeId` accepts exactly the same rows as
a plain unique; nothing degrades.

The unique-conflict resolver discovers indexes from the table definitions,
so per-scope groups fall out with no special casing: rows in different
scopes never form a conflict group under a composite index. For indexes kept
global on purpose, conflict groups can span scopes, and one guard is added:
**a foreign scope's claim always yields** — resolution never rewrites a row
owned by another scope, regardless of HLC. The flag policy (see
`unique-constraint-invariants.md`) is otherwise unchanged.

## Enforcement mechanics

1. **Local writes: stamp-or-assert** (see *Write semantics*), with the
   effective scope required exactly as it already is for CRDT recording.
2. **Merge-insert ownership check.** `_applyMergeInsertForMissingRow` reads
   the existing domain row before writing. If it exists and its `scopeId`
   differs from the merging scope, the incoming insert is **skipped and
   logged**: a structured session-log warning carrying operation, table, row
   id, owning scope, and merging scope. (A dedicated `crdt_sync_audit` table
   is deferred until a concrete consumer exists.) This mirrors how updates
   and deletes already no-op without a tracker. Re-keying the incoming row
   to a synthetic UUID was considered (non-lossy, consistent with the unique
   flag policy) but rejected: row identity re-keying breaks the incoming
   chain's own foreign key references to that UUID, which would require
   alias tracking across the whole merge. UUIDv7 collisions between honest
   clients are negligible; a collision is a bug or an attack, and skipping
   is the safe response to both.
3. **Foreign keys stay within a scope.** A synced row may only reference
   synced rows of its own scope. Locally,
   `_assertVisibleForeignKeyTargets` gains a scope-equality check next to
   its visibility check; in merges, a foreign-scope target is treated
   exactly like an invisible target, so the existing attempt/override
   machinery (see `foreign-key-invariants.md`) repairs the reference instead
   of linking across scopes. Cascade deletes and SET NULL projections
   therefore never cross a scope boundary. References to non-synced tables
   are unaffected.
4. **No metadata backstop constraint.** An earlier draft added a unique index
   on `crdt_data_rows (tblId, uuidRowId)` as defense-in-depth. It is dropped:
   with visibility predicates keyed through the row's own `scopeId` (below),
   a stray foreign tracker is *inert* — it is never consulted. Not shipping
   it also avoids ~21 bytes per CRDT row on every database.

## Read path

Ownership on the row collapses every visibility predicate into an
index-covered probe; the aggregate (`GROUP BY`/`MIN`) form, its full-scan
cost (~95 ms per point lookup at 1M CRDT rows in the SQLite benchmark), and
the covering index it wanted never ship.

- **Scoped query** (a `transactionForUser` read, or the persistent default
  scope): rows are filtered by `scopeId = <scope>` — the isolation promise,
  and the central point of the design — plus the existing correlated
  `NOT EXISTS` visibility probe on `(scopeId, tblId, uuidRowId)`.
- **Unscoped query** (no transaction scope, no persistent scope — admin
  reads): no isolation filter; the visibility probe is keyed by the row's
  own column — `NOT EXISTS (… WHERE c.scopeId = t."scopeId" AND tblId = ?
  AND uuidRowId = t.id AND visibility > …)` — fully covered by the existing
  unique index. A row is visible while its owner sees it.

On a database containing one scope, the two views return the same rows; no
code anywhere branches on scope count. Rows with a null `scopeId` — created
behind the sync layer's back (raw SQL, seed fixtures) — are visible only to
unscoped reads; seeding flows must stamp scopes, which ties into the
reference-table open question.

Multi-scope deployments additionally gain Postgres row-level security as an
option, since policies can reference `scopeId` directly — the package's
isolation filter and RLS become two enforcements of one predicate.

## API surface

The package is unreleased, so renames land directly, with no aliases and no
data migration. Public API stays user-first (that is the semantics
developers expect to write); internals and storage are named after what they
actually key — scopes:

- **`transactionForUser(userId, fn)`** keeps its name and shape: it resolves
  the user's UUID to the local scope and pins the transaction to it — writes
  stamp and assert against it, reads are isolated to it. The optional
  `scopeId` parameter is reserved for shared scopes (see *Future*).
- **`persistentUserId`** remains the way to pin a default scope outside
  explicit transactions — the standard single-user client configuration.
- **`mergeChanges(scopeId: …)`** keys the chain being merged — the parameter
  is renamed from `userId` to what it always was.
- **Internals and storage** adopt scope naming in one sweep: `crdt_users` →
  `crdt_scopes` (`CrdtUser` → `CrdtScope`, `uuidUserId` → `uuidScopeId`),
  `crdt_data_rows.userId` → `scopeId` (matching the domain column),
  `userForTransaction`, the effective-user helpers, and the HLC manager
  keys. Doing this now is what keeps the *Future: shared scopes* section a
  pure addition instead of a rename project.
- **Unscoped reads** remain supported as admin reads.

Consequences for application code, stated as contract:

1. **Every synced table declares `id: UuidValue` and `scopeId: int?`.**
   Startup fails with a paste-ready error otherwise.
2. **`scopeId` round-trips the way it came in** — left null, the sync layer
   stamps it internally and returns it null (scoped reads return it null
   too); provided explicitly, it must match the effective scope or the
   operation throws, and it stays visible on the way out. The column is
   immutable after insert.
3. **Scoped reads are isolated to their scope.** Reading across scopes is an
   explicit unscoped (admin) read.
4. **Merge-inserts colliding with another scope's row are skipped and
   logged**, never applied over the owner's data.
5. **Foreign keys on synced tables target same-scope rows.** Cross-scope
   references are repaired by the existing FK override machinery instead of
   being linked.

## Implementation plan

Each phase lands independently green; later phases depend on earlier ones
only where stated. No generator or Serverpod fork changes are required.

- **Phase 1 — naming, contract, validation.** The user→scope renames in
  internals and storage (above), done first so later phases build on the
  final names. `CrdtSchemaRegistry`: the `scopeId` presence/type check with
  the `serverOnly` hint, and the unique-index warning. Reserved-name
  exclusions: `crdt_schema_columns` registration, field-level merge, update
  recording, merge payload sanitization. Test models gain `scopeId`.
- **Phase 2 — write-path enforcement.** Stamp-or-assert in the proxy insert
  paths (dynamic dispatch on the known field); `scopeId` excluded from
  update SET lists; ownership assertion on update/delete/reinsert;
  merge-insert ownership check with skip-and-log; merge stamping from the
  merging scope; FK same-scope assertion and merge repair routing;
  cross-scope yield guard in the unique resolver for global indexes.
- **Phase 3 — read paths.** Isolation filter for scoped reads; row-keyed
  visibility probe for unscoped reads; stripping of `scopeId` from scoped
  read results; delete the `GROUP BY`/`MIN` form and the server-only-index
  TODO from `tombstone.dart`.
- **Phase 4 — tests and benchmarks.** The plan below, plus updating
  `TombstoneScopeBenchmark` to ownership-conformant seeding (one tracker per
  row); its current second-tracker fixtures survive only as the enforcement
  scenario.

### Test plan

Because no code branches on scope count or deployment role, mechanisms are
tested **once**, not per combination:

- **Mechanism suites (run once).** All existing CRUD, tombstone visibility,
  unique-conflict, FK-invariant, merge, and sync suites continue on the
  uniform model; test models declare `scopeId` and are otherwise unchanged
  (the stamp rule means call sites do not change).
- **Enforcement tests.** Stamping on insert; assert-on-mismatch throwing for
  insert and update; immutability of the column; round-trip symmetry (null
  in → null out, explicit in → kept, per row in batches); stripping on
  scoped reads and retention on unscoped reads; the caller's input instance
  left unmutated; merge-insert collision skip-and-log (the multi-user
  fixtures in `tombstone_scope_test.dart` become these tests); FK
  cross-scope repair; cross-scope unique yield on a deliberately global
  index.
- **Combination smoke tests (one each, not per mechanism).** A two-scope
  database proving read isolation and per-scope uniqueness on SQLite; one
  `withServerpod` sync roundtrip proving the wiring end to end. These exist
  to prove deployment shapes compose, not to re-verify mechanisms.

## Future: shared scopes

`crdt_scopes` is the entity everything is keyed by: sync, locking, HLC
chains, and visibility. Sharing becomes an indirection in front of it, not a
change to row ownership:

- an authenticated identity maps to one personal scope plus any number of
  shared scopes;
- a shared list/document/workspace is a scope that several identities
  subscribe to and sync;
- every row still has exactly one owning scope (its `scopeId`), so merging
  stays one chain per row and nothing in this document's enforcement
  changes.

This is the standard shape of sharing in local-first systems, and it is the
reason the column and concept are named `scope` rather than `user`. The rest
of this section sketches the direction in enough detail to keep today's
decisions compatible with it; it is not committed design.

### Users authenticate, scopes act

The two concepts separate cleanly:

- a **user** is an authentication identity — what endpoints and the sync
  handshake verify;
- a **scope** is the unit of replication and ownership — what transactions
  act in, what chains and tombstones are keyed by, what `scopeId`
  references.

Two conventions bridge them with no storage migration:

1. **A user's personal scope has the user's own UUID.** This is already true
   (the scope UUID keys the chain today), so every deployment without
   sharing is the degenerate case "each user has exactly one scope: their
   personal one". Shared scopes are new `crdt_scopes` rows whose UUID is no
   user's id.
2. **Membership** is a server-side relation, `crdt_scope_members(scopeId,
   userUuid, role?)`, managed by application code (invitations and roles are
   app domain). Personal-scope membership is implicit; no row is stored for
   it.

### The transaction API

`transactionForUser` keeps its name and user-first semantics — that is what
developers expect to write — and gains an optional scope:

```dart
db.transactionForUser(userId, fn);                  // acts in the personal scope
db.transactionForUser(userId, fn, scopeId: listId); // acts in a shared scope
```

- Without `scopeId`, the scope resolves to the user's personal scope — by
  convention 1, simply `userId` itself, which is exactly today's behavior.
- With `scopeId`, the `userId` argument is **not dead weight**: the package
  asserts `membership(userId, scopeId)` before acting. The parameter pair
  reads as "authenticated as `userId`, acting in `scopeId`, verified
  member" — the same predicate row-level security policies mirror. The
  caller remains responsible for `userId` being authenticated, exactly as
  today.
- A transaction acts in **exactly one scope**. Cross-scope writes need
  separate transactions; this is deliberate honesty about CRDT semantics,
  since two scopes' chains replicate independently and remote replicas can
  never observe a cross-scope write atomically anyway.

### Reads: membership-wide; writes: scope-pinned

A user-scoped read in a sharing world naturally means "rows in any scope I am
a member of": the isolation filter becomes `scopeId IN (<member scopes>)`
instead of `scopeId = <scope>`. The visibility probe is the row-keyed form —
the same probe as unscoped admin reads — so sharing simplifies the predicate
matrix rather than growing it: reads differ only in their membership filter
(one scope, a user's scopes, or none for admin).

This is also exactly the shape of a Postgres row-level security policy
(`scopeId IN (SELECT scopeId FROM crdt_scope_members WHERE userUuid =
current_setting(...))`), which is the standard practice for multi-tenant
isolation and on the Serverpod backlog; the package's application-level
filter and RLS become two enforcements of one predicate.

### Sync and clients

- A device syncs one chain per scope it holds: the sync session (or one
  session per scope) enumerates the authenticated user's member scopes,
  verified server-side against `crdt_scope_members` at the handshake; the
  membership table itself is not synced.
- Every database is already sharing-capable schema-wise — the column is
  universal — so a sharing-enabled client simply holds several scopes' rows.
  One database file per scope remains a valid alternative layout.
- Checkpoints stay per `(scope, node)`; a device is a node in each scope's
  chain it participates in.

### What sharing does not change

Every enforcement rule in this document survives unchanged: rows have exactly
one owning scope, merge-insert ownership checks compare scopes, unique
conflict groups form within a scope (or yield to the owner across scopes),
and stamp-or-assert applies with the transaction's resolved scope. Sharing
adds a membership layer in front of scopes; it does not touch row ownership.

## Resolved during review

Decisions that were open questions in earlier drafts, kept here so they are
not relitigated by accident:

- **Optional vs. required `scopeId`:** required, on every synced table and
  in both schemas. The optional-column draft and the schema-presence-mode
  draft were both rejected: each created a second ownership architecture (or
  a second schema shape) that every mechanism would have to support and
  test. Requiring the column everywhere deleted the mode system, the
  index-projection generator feature, and the per-mode test matrix, at the
  cost of ~1–2 bytes per row and a visible read-only field on domain models.
- **`scope=serverOnly` on the column:** rejected (would reintroduce
  asymmetric schemas); validation forbids it.
- **Stamp-or-assert as the single write path:** chosen over required
  explicit passing (ceremony without added security — the package must
  verify any supplied value anyway, and the persistent-user client pattern
  has no transaction object in hand) and over dual documented paths (two
  mental models). Explicit callers still get verified explicitness through
  the assert arm.
- **Nullability:** nullable, permanently. The int is database-local, so a
  non-nullable field would force clients to serialize a meaningless local
  id into endpoint payloads; null honestly means "not mine to say". The
  sync layer guarantees the value on every synced row.
- **Wire transport prevented by construction, respecting the caller:** the
  value leaves the way it came in — stamped values are stripped from
  returned rows and scoped reads; explicitly provided (and verified) values
  are kept on the way out; unscoped admin reads keep the value as the only
  per-row ownership information server-side. Mechanism: in-place dynamic
  mutation on package-owned instances (preferred over `copyWith`, the
  fallback only under immutability; `patchTableRow` is reserved for the
  merge path, where field names are data-driven and its 50–200× cost is
  justified), never leaving the caller's input observably mutated.
- **Unscoped-read semantics:** an unscoped read is an admin view; a row is
  visible while its owner sees it. Scoped reads are isolated to their scope
  — confirmed as the central goal of the design.
- **Skip vs. re-key on colliding inserts:** skip and log; re-keying row
  identity would break the incoming chain's own FK references.
- **Metadata backstop index:** dropped; foreign trackers are inert under
  row-keyed probes.
- **Audit surface:** structured session-log warnings now; an audit table
  deferred until a consumer exists.
- **No compatibility constraints:** the package is unreleased, so renames
  (storage and API parameters) land without aliases, and there is no
  backfill or data migration to design.

## Open questions

1. **Globally shared reference tables.** Read-only data synced to every user
   would violate "every row has one owning scope" and is out of scope; if
   the use case materializes, it likely becomes a third table kind rather
   than a relaxation of the contract. Related: rows seeded behind the sync
   layer's back carry a null `scopeId` and are visible only to admin reads.
2. **`scopeId` naming collisions.** The name is reserved by convention; an
   application with a pre-existing, semantically different `scopeId` column
   on a synced table has no escape hatch other than renaming its column.
   Acceptable for now; revisit if it bites real users.
3. **Membership revocation semantics (sharing).** When a user loses
   membership of a scope, the server stops streaming it at the next
   handshake, but the device still holds the scope's data and may hold
   unsynced local changes for it. Purge-vs-keep policy, and whether revoked
   unsynced changes are surfaced or dropped, need their own design.
4. **Roles within a scope (sharing).** `crdt_scope_members.role` is sketched
   but undefined: read-only members would need write rejection at merge time
   (another skip-and-log case), and the interaction with offline-written
   changes by a demoted member overlaps with question 3.
