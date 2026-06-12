# Row ownership and scope isolation

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

> **`scopeId` is a reserved column name on synced tables, and its presence in
> a database's schema declares that database's mode.** A schema with
> `scopeId` is multi-scope: ownership lives in the column and any number of
> scopes may coexist. A schema without it is single-scope: the database holds
> exactly one scope's data, enforced structurally. The mode is a property of
> the schema, not of the client or server role.

> **Both modes are first-class and both are tested.** There is one ownership
> model (every row has one owning scope); single-scope is its degenerate
> case, not a second architecture. Features that interact with ownership —
> unique conflict resolution above all — carry tests for both branches.

Field scoping then composes the deployment patterns from one declaration:

| Declaration in the model               | Server schema | Client schema | Pattern |
| -------------------------------------- | ------------- | ------------- | ------- |
| `scopeId: int?, scope=serverOnly`      | multi-scope   | single-scope  | traditional: multi-tenant server, single-user devices |
| `scopeId: int?`                        | multi-scope   | multi-scope   | sharing-enabled and/or multi-account devices |
| *(absent)*                             | single-scope  | single-scope  | single-tenant deployments (e.g. self-hosted personal server) |

No model inheritance is needed: like the existing UUID primary key
requirement, the contract is structural (a reserved column name with a
required type, checked by `CrdtSchemaRegistry` at `initialize()`), not
nominal (a base class), which is the only option anyway since Serverpod
models cannot extend models from an imported module.

## Goals and constraints

1. **One ownership model, schema-selected modes.** An earlier draft made the
   column optional with metadata-only enforcement as the default; it was
   rejected because two *ownership architectures* double the test surface of
   every feature. This design has one architecture — rows owned by exactly
   one scope — and two query/enforcement modes derived mechanically from the
   schema. The modes do branch code and tests (accepted cost, kept small and
   localized); they do not branch the data model.
2. **No external model inheritance.** Serverpod does not let application
   models extend models from an imported module, so a base class cannot
   carry shared columns into user tables. Requirements are enforced by
   runtime validation instead.
3. **Roles are not hard-coded.** Nothing in the package may assume
   multi-scope means Postgres or single-scope means SQLite. Multi-account
   client databases and single-tenant servers are supported by declaration,
   not by exception.
4. **Schemas may differ per database, declarations may not.** A model is
   declared once; Serverpod field scoping (`scope=serverOnly`) and the index
   projection rule (below) derive each database's schema from it.
5. **Multi-device per user keeps working unchanged.** Devices of one user
   share the user's scope and merge into one chain.
6. **Sharing must not be foreclosed.** Collaborative data is a core
   local-first use case; the design must leave a clean path to it.

## Problem: ownership is implicit

The server holds one physical domain row per `(table, uuidRowId)`, while CRDT
metadata (`crdt_data_rows` and its children) is keyed per
`(userId, tblId, uuidRowId)`. The unique index allows multiple users to track
the same row. Symptoms, in increasing severity:

1. **Tombstone masking.** A tombstone recorded by one user (or for another
   table) used to hide unrelated rows sharing a UUID. Fixed by scoping the
   visibility predicates — but the fix required defining what an *unscoped*
   query means ("hidden only when hidden for every tracking user"), an
   aggregate query shape, and a covering index we ultimately could not afford
   on clients. Complexity that exists only because multiple trackers can.
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

`scopeId` is a **reserved column name** on synced tables. When declared:

```yaml
fields:
  ### Owner scope of this row. Maintained by the CRDT sync layer.
  scopeId: int?, scope=serverOnly   # or plain `int?` for multi-scope clients
```

- The value references `crdt_users.id` — the scope that owns the row. Today a
  scope is a user; the name is chosen deliberately so shared scopes can be
  added later without renaming storage.
- The column is **owned by the sync layer**: insert paths populate it from
  the effective scope of the transaction, and update/delete/merge paths
  assert it. Application code must treat it as read-only. It is declared
  nullable so the type system does not force application code to provide it;
  the sync layer guarantees it is set on every synced row (enforced after
  backfill, see *Migration*).
- Whether it carries `scope=serverOnly` decides which databases get the
  column — and with it, which databases run in multi-scope mode.

### Mode detection and validation

`CrdtSchemaRegistry` inspects the schema it actually runs against, extending
the existing UUID primary key check, with errors that contain the exact yaml
to paste:

- **Consistency:** all synced tables in one database must agree — all with
  `scopeId` (multi-scope) or all without (single-scope). A mix is an error,
  because one database cannot be both.
- **Type:** when present, `scopeId` must be a nullable `int` column.
- **Mode invariant, multi-scope:** any number of scopes; `transactionForUser`
  is unrestricted; unique indexes on synced tables that do not include
  `scopeId` produce a startup *warning*, so globally-unique-on-purpose (an
  `email` column, say) is a visible decision rather than an accident.
- **Mode invariant, single-scope:** `crdt_users` may contain **at most one
  user**. `getOrCreateUser` for a second scope throws. This is the entire
  enforcement of single-scope mode — no per-row checks are needed, because a
  second scope structurally cannot exist. `persistentUserId` is the
  convenient way to pin the scope, but a single-scope server driving
  `transactionForUser` with its one user is equally valid.

Note what is *not* validated: the mode of the *other* database. The
traditional pattern (multi-scope server, single-scope clients) is two
databases legitimately running different modes of the same declaration.
Mismatches that matter surface structurally — e.g. two client scopes syncing
into a single-scope server trip its one-user invariant on the second sync.

### Sync-layer exclusions

`scopeId` is infrastructure that happens to live in the domain row. Keyed by
the reserved name (regardless of field scoping), it is excluded from:

- `crdt_schema_columns` registration and field-level CRDT metadata (it has no
  HLC history; it is never merged as a field);
- the synced-schema hash, so `SyncTablesHashMismatchException` never triggers
  between databases whose schemas differ only by `scopeId`;
- update recording (`afterUpdate` ignores it) and merge payload sanitization
  (`_sanitizeMergeRowData` strips it from incoming data).

## Branching indexes between schemas

A per-scope unique constraint must be `(scopeId, name)` in a multi-scope
schema, but a single-scope schema has no `scopeId` column, and Serverpod
model yaml declares each index exactly once.

### Decision: the generator projects indexes onto each schema's columns

The Serverpod fork (which already owns client schema generation via
`database: all`) gains one rule:

> When generating a schema, index definitions are projected onto that
> schema's column set: fields the schema does not carry (e.g. `serverOnly`
> fields in the client schema) are dropped from the field list. If no fields
> remain, the index is omitted entirely. An explicit `serverOnly: true` flag
> on an index omits it from the client schema regardless of its fields.

So the application declares, once:

```yaml
indexes:
  person_scope_name_unique_idx:
    fields: scopeId, name
    unique: true
```

and gets `UNIQUE (scopeId, name)` wherever the schema is multi-scope and
`UNIQUE (name)` wherever it is single-scope. With a plain (non-`serverOnly`)
`scopeId`, no projection happens and both databases carry the composite. The
explicit flag also resolves the pending `crdt_data_rows_tbl_row_vis_idx` TODO
in the `CrdtDataRow` model, which wants a server-only index with no
server-only fields.

### Why the projection is sound

Dropping `scopeId` from a unique index changes its meaning — unless the
database only ever contains one scope. That is precisely what the mode
invariant guarantees: a schema without `scopeId` is single-scope *by
definition*, and the registry's one-user limit enforces it. Within a single
scope, `UNIQUE (scopeId, name)` and `UNIQUE (name)` accept exactly the same
rows, and scope isolation guarantees no other scope's rows ever sync into the
database to break the equivalence.

Multi-account apps that want several isolated users on one device have two
declarations to choose from: one database file per account (each single-scope,
the existing `createAdditionalTestSession` pattern), or a plain `scopeId`
making the device database genuinely multi-scope.

### Consequences for the unique-conflict resolver

The resolver discovers unique indexes from the table definitions of the
schema it runs on, so it follows the mode automatically:

- In a multi-scope schema, `(scopeId, name)` means rows in different scopes
  never form a conflict group; the HLC flag policy applies within a scope,
  unchanged.
- In a single-scope schema, the projected `(name)` index yields the same
  conflict groups because only one scope exists.
- Indexes kept global on purpose in a multi-scope schema can form conflict
  groups that span scopes. One guard is added for them: **a foreign scope's
  claim always yields** — resolution never rewrites a row owned by another
  scope, regardless of HLC.

Both branches — single- and multi-scope — get their own unique-conflict test
suites. This is the accepted cost of supporting both modes, and it is
bounded: the branching is in *which rows form a group* and *who may yield*,
not in the resolution policy itself.

## Enforcement mechanics

1. **Multi-scope merge-insert ownership check.**
   `_applyMergeInsertForMissingRow` reads the existing domain row before
   writing. If it exists and its `scopeId` differs from the merging scope,
   the incoming insert is **skipped and recorded for audit**, mirroring how
   updates and deletes already no-op without a tracker. Re-keying the
   incoming row to a synthetic UUID was considered (non-lossy, consistent
   with the unique flag policy) but rejected: row identity re-keying breaks
   the incoming chain's own foreign key references to that UUID, which would
   require alias tracking across the whole merge. UUIDv7 collisions between
   honest clients are negligible; a collision is a bug or an attack, and
   skipping is the safe response to both.
2. **Multi-scope local paths** set `scopeId` from the effective scope of the
   transaction on insert, and assert it on update, delete, and reinsert — a
   mismatch is the same collision case and is skipped and audited.
3. **Single-scope mode needs no per-row enforcement.** The one-user limit on
   `crdt_users` makes a second scope unrepresentable; collisions between
   scopes cannot occur within the database, and cross-database collisions are
   handled by whichever multi-scope database they meet in.
4. **No metadata backstop constraint.** An earlier draft added a unique index
   on `crdt_data_rows (tblId, uuidRowId)` as defense-in-depth. It is dropped:
   with visibility predicates keyed through the row's own `scopeId` (below),
   a stray foreign tracker is *inert* — it is never consulted — and in
   single-scope mode it cannot exist. Not shipping it also avoids ~21 bytes
   per CRDT row on every database for a constraint that is redundant in both
   modes.

## Read path

Ownership on the row collapses every visibility predicate into an
index-covered probe; the aggregate (`GROUP BY`/`MIN`) form, its full-scan
cost (~95 ms per point lookup at 1M CRDT rows in the SQLite benchmark), and
the covering index it wanted are all deleted from the design.

- **Multi-scope, scoped query** (a `transactionForUser` read, or a persistent
  default scope): rows are filtered by `scopeId = <scope>` — the isolation
  promise, new with this design — plus the existing correlated `NOT EXISTS`
  visibility probe on `(userId, tblId, uuidRowId)`.
- **Multi-scope, unscoped query** (admin reads): no scope filter; the
  visibility probe is keyed by the row's own column —
  `EXISTS (… WHERE userId = t."scopeId" AND tblId = ? AND uuidRowId = t.id
  AND visibility > …)` — fully covered by the existing unique index.
  "Hidden for every tracking user" reduces to "hidden for the owner".
- **Single-scope query**: the lone scope's id is resolved once (the
  persistent user, or the single `crdt_users` row) and the scoped probe is
  used for everything; before any scope exists there is nothing tombstoned
  and no predicate is needed.

Multi-scope databases additionally gain Postgres row-level security as an
option, since policies can reference `scopeId` directly.

## Migration and backfill

1. Ship the generator feature (index projection + `serverOnly: true` index
   flag), then add the column and composite indexes via normal Serverpod
   migrations.
2. Backfill `scopeId` from `crdt_data_rows`: each row's single tracker is its
   owner. Rows tracked by more than one user (violations of the new
   invariant) are reported with a runbook: the oldest tracker by row HLC is
   proposed as owner, newer trackers' metadata is detached for manual
   resolution, never silently dropped. Expected violation count on healthy
   deployments: zero.
3. Enable enforcement (merge checks, scoped read filters, single-scope user
   limit) only after backfill validates clean.
4. Test impact:
   - the multi-user fixtures in `tombstone_scope_test.dart` become the
     enforcement tests (expected: skipped and audited instead of merged);
   - "hidden for every tracking user" unscoped semantics tests reduce to
     owner-based assertions;
   - unique-conflict suites split into single-scope fixtures (current test
     models, unchanged) and multi-scope fixtures (test models declaring a
     plain `scopeId`, runnable on SQLite — no embedded-Postgres requirement);
   - the `serverOnly` projection itself (different schemas from one
     declaration) is exercised by the existing `withServerpod` sync suites.

## Future: shared scopes

`crdt_users` is already the scope entity in everything but name: sync,
locking, HLC chains, and visibility are all keyed by it. Sharing becomes an
indirection in front of it, not a change to row ownership:

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
  act in, what chains and tombstones are keyed by, what `scopeId` references.

Two conventions bridge them with no storage migration:

1. **A user's personal scope has the user's own UUID.** This is already true
   (`uuidUserId` keys the chain today), so every existing deployment is the
   degenerate case "each user has exactly one scope: their personal one".
   Shared scopes are new scope rows whose UUID is no user's id. (`crdt_users`
   should eventually be renamed `crdt_scopes`; until then the name is
   accepted debt.)
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
  member" — the same predicate row-level security policies mirror (below).
  The caller remains responsible for `userId` being authenticated, exactly
  as today.
- A transaction acts in **exactly one scope**. Cross-scope writes need
  separate transactions; this is deliberate honesty about CRDT semantics,
  since two scopes' chains replicate independently and remote replicas can
  never observe a cross-scope write atomically anyway.

Internally, everything currently keyed by "user" (recorder, HLC managers,
`userForTransaction`, merge) is re-keyed by scope — mechanically, since the
key value does not change for personal scopes.

### Reads: membership-wide; writes: scope-pinned

A user-scoped read in a sharing world naturally means "rows in any scope I am
a member of": the isolation filter becomes `scopeId IN (<member scopes>)`
instead of `scopeId = <scope>`. The visibility probe for such reads is the
row-keyed form (`userId = t."scopeId" AND …`) — the *same* probe as unscoped
admin reads, covered by the same unique index. Sharing therefore simplifies
the predicate matrix rather than growing it: every multi-scope read uses the
row-keyed probe, and reads differ only in their membership filter (one scope,
a user's scopes, or none for admin).

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
- A sharing-enabled client database uses the multi-scope schema (plain
  `scopeId`): one device user, several scopes. The single-scope client
  pattern remains valid for apps without sharing, or with one database file
  per scope.
- Checkpoints stay per `(scope, node)`; a device is a node in each scope's
  chain it participates in.

### What sharing does not change

Every enforcement rule in this document survives unchanged: rows have exactly
one owning scope, merge-insert ownership checks compare scopes, unique
conflict groups form within a scope (or yield to the owner across scopes),
and single-scope mode is still the one-scope degenerate case. Sharing adds a
membership layer in front of scopes; it does not touch row ownership.

## Open questions

1. **Audit surface for skipped operations.** Skipped colliding inserts and
   ownership-mismatch updates should be observable. A `crdt_sync_audit`
   table vs. structured logs is out of scope here.
2. **Generator feature shape.** Index projection plus the `serverOnly: true`
   index flag live in the Serverpod fork; decide whether to propose them
   upstream (they are generally useful for any `database: all` deployment)
   or keep them fork-local.
3. **Scoped reads as an isolation filter.** Adding `scopeId = <scope>` to
   scoped queries in multi-scope mode changes semantics for any application
   that relied on reading other users' rows through `transactionForUser`.
   This document treats that as the point of the design, but the behavior
   change deserves its own migration note.
4. **Column nullability.** `scopeId` is declared nullable for ergonomics but
   guaranteed non-null by the sync layer after backfill; decide whether to
   tighten it to `NOT NULL` at the database level in a follow-up migration.
5. **Per-table mode mixing.** All synced tables in a database must currently
   agree on mode. Globally shared read-only reference tables (synced to every
   user) would violate "every row has one owning scope" and are out of scope;
   if the use case materializes, it likely becomes a third table kind rather
   than a relaxation of the consistency rule.
6. **`scopeId` naming collisions.** The name is reserved by convention; an
   application with a pre-existing, semantically different `scopeId` column
   on a synced table has no escape hatch other than renaming its column.
   Acceptable for now; revisit if it bites real users.
7. **Membership revocation semantics (sharing).** When a user loses
   membership of a scope, the server stops streaming it at the next
   handshake, but the device still holds the scope's data and may hold
   unsynced local changes for it. Purge-vs-keep policy, and whether revoked
   unsynced changes are surfaced or dropped, need their own design.
8. **Roles within a scope (sharing).** `crdt_scope_members.role` is sketched
   but undefined: read-only members would need write rejection at merge time
   (another skip-and-audit case), and the interaction with offline-written
   changes by a demoted member overlaps with question 7.
