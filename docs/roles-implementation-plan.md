# Implementation plan: complete shared-scope roles

Status: implemented. This finishes Follow-up #2 in `shared-scopes.md`
("Roles within a scope") and closes open question 4 in `row-ownership.md`.

## Goal

Make the `crdt_scope_members.role` column **enforced**, not just stored and
projected. A member whose role does not grant write access must not be able to
mutate a scope: the server (the security boundary) must reject such writes at
merge time and record a durable violation, and the client must reject them
offline as early-failure UX. Reads stay membership-wide and role-independent —
roles gate **writes only**.

## Current state (already done)

- `crdt_scope_members.role: CrdtScopeRole?` exists (`database: all`,
  `node/scope_member.spy.yaml`) and is **stored**.
- `CrdtScopeGrant { uuidScopeId, role }` carries the role on the wire
  (`sync/scope_grant.spy.yaml`).
- The authoritative server announces roles: `CrdtScopeMembership.memberGrants`
  selects `role` from the table.
- The follower **projects** roles into its local `crdt_scope_members` cache:
  `CrdtScopeMembership.projectFollowerMembership` upserts `(scopeId, userUuid,
  role)` on every grant-set change.
- Roles are enforced by the closed `CrdtScopeRole` enum: `readOnly` blocks
  writes, `readWrite` allows writes, and `null` remains writable for personal
  scopes and legacy shared memberships.

## Key design decisions

### 1. Roles are package-defined CRDT access roles

The package does not need app-defined free-form role names because this layer
only enforces one capability: whether the member may write CRDT rows in the
scope.

```dart
enum CrdtScopeRole {
  readOnly,
  readWrite,
}
```

- `readOnly` denies CRDT writes.
- `readWrite` allows CRDT writes.
- `null` remains writable for personal scopes and legacy shared memberships
  without an explicit role.

Domain roles such as owner, maintainer, commenter, or approver belong in
application tables and can be mapped by application code to this CRDT access
role when writing `crdt_scope_members`.

### 2. Enforcement points

| Where | Who | What | On violation |
|---|---|---|---|
| **Server inbound** (`CrdtSync._applyCycleBatch`, authoritative only) | Authenticated user's role in the merged scope, resolved authoritatively from `crdt_scope_members` | The real security boundary | Record `CrdtSyncIntegrityViolation(type: unauthorizedWrite)` and **throw to fail the session** (fail-and-record, exactly like ownership collisions) |
| **Client write gate** (`CrdtDatabase._assertCanActInScope`) | Projected role for the target scope | Early-failure UX; re-verified by server | Throw `CrdtScopeRoleException` **before** writing |
| **Client outbound skip** (`CrdtSync.sync` / `CrdtScopeSyncSession`, follower only) | Projected role per active scope | Optimization: a read-only follower never streams that scope's changes (still receives) | Silently omit the scope from outbound collection |

Why the server gate keys on the **authenticated user**, not per-authoring-node:
in this topology all cross-user sync flows through the server, and a member's
changes only ever enter via that member's own authenticated session. Gating the
inbound merge of a scope group by the session user's role is therefore exactly
"reject the read-only member's writes at merge time," without needing a
node→member map. The merge runs in `transactionForUser(scopeId, …)`, so the
authenticated user is **not** the tx user for shared scopes — resolve it from
`CrdtScopeSyncSession`'s session user (`_userId`), which is why enforcement lives
in the sync layer, before `_mergeInboundBatch`, not inside `mergeChanges`.

Reads are untouched: a read-only member still reads the scope membership-wide.

### 3. Scope of "complete"

In scope: enum model changes, server enforcement + durable violation, client
write gate + exception, follower outbound skip, role resolution helper, tests,
docs.

Explicitly **out of scope** (defer, note in docs): the fate of changes a member
authored **while still writable** and then synced **after demotion**. The server
rejects+records them (correct), but whether to purge/surface the now-orphaned
local pending changes overlaps with the deferred *membership revocation cleanup*
follow-up and is decided there. This plan only guarantees they are rejected and
recorded, never silently applied.

## Implementation steps

Land in independently green phases. Run tests with `--concurrency=1` (parallel
files break the embedded-server sync tests). Integration tests hit a live server
at `http://localhost:8081/`; ensure it is running (`serverpod start` in
`test/serverpod_offline_sync_test_server`) and restarted after server-side code
or protocol changes.

### Phase A — role enum plumbing

1. Add `CrdtScopeRole` (`readOnly`, `readWrite`, `serialized: byName`) and use
   `CrdtScopeRole?` for `CrdtScopeMember.role` and `CrdtScopeGrant.role`.
2. Add the `CrdtScopeRoleWriteAccess` extension in `crdt/roles.dart`, exported
   via `crdt.dart`: `role.canWrite` is false only for `readOnly`.
3. Add a role-resolution helper to `CrdtScopeMembership`
   (`crdt/scope_membership.dart`), raw-SQL like its siblings (works identically
   on server-authoritative and client-projected copies because the table is
   `database: all`):

   ```dart
   /// The role [userUuid] holds in [scopeUuid], or null if none is recorded
   /// (including the implicit personal scope). On the server this is
   /// authoritative; on a client it is the projected cache.
   static Future<CrdtScopeRole?> roleOf(
     DatabaseSession session, {
     required UuidValue userUuid,
     required UuidValue scopeUuid,
     Transaction? transaction,
   }) async { /* userUuid == scopeUuid → null; else SELECT role ... */ }
   ```

   Annotate `@internal` if only used in-package (it is). Add a focused unit test
   in the server package alongside `scope_membership_test.dart`.

### Phase B — server inbound enforcement (authoritative)

1. Expose the session user from `CrdtScopeSyncSession`
   (`crdt/scope_sync.dart`): add `UuidValue get userId => _userId`.
2. In `CrdtSync._applyCycleBatch` (`crdt/sync.dart`), authoritative mode only,
   for each **accepted** inbound scope group, **before** calling
   `_mergeInboundBatch`:
   - `final role = await CrdtScopeMembership.roleOf(session, userUuid:
     scopes.userId, scopeUuid: scopeId);`
   - if `!role.canWrite`: build a `CrdtSyncIntegrityViolation`
     (`type: CrdtSyncViolationType.unauthorizedWrite`, `operation:` from the
     first change in the group, `domainTableName`/`uuidRowId`/`uuidNodeId` from
     the first change, `incomingScopeUuid: scopeId`, `ownerScopeUuid: null`, hlc
     from the first change, timestamps now, occurrences 1), persist via
     `recordCrdtSyncIntegrityViolation`, then
     `throw CrdtSyncIntegrityViolationException(persisted);`.
   - Throwing here fails the session through the existing
     `on CrdtSyncStreamClosedException`/outer error path; confirm the merge tx is
     **not** opened for the rejected scope (the change must not be applied).
   - Followers do **not** enforce inbound (they trust the server).
3. The check is once per scope group (the role is constant for the
   authenticated user in a scope), not per row — cheaper than the per-row
   ownership probe and sufficient.

### Phase C — client write gate + follower outbound skip

1. `CrdtDatabase._assertCanActInScope` (`database/database.dart`): after the
   membership check passes and before returning, resolve the projected role
   (`CrdtScopeMembership.roleOf(_delegate.session, userUuid: userId, scopeUuid:
   scopeId)`) and, if `!role.canWrite`, throw a new
   `CrdtScopeRoleException`. Skip for the personal scope (`userId == scopeId`).
   The merge path calls `transactionForUser(scopeId, …)` with `userId ==
   scopeId`, so this gate never blocks server merges.
2. Add `CrdtScopeRoleException` to `crdt/exceptions.dart` (parallel to
   `CrdtScopeMembershipException`: fields `userId`, `scopeId`, optional `role`;
   clear `toString`). Export via `crdt.dart` (it is part of the public failure
   surface like `CrdtScopeMembershipException`).
3. Follower outbound skip (optimization): in `CrdtSync.sync`, when building the
   checkpoints passed to `collectPendingChanges`, a follower must drop scopes it
   cannot write. Add to `CrdtScopeSyncSession` a notion of writable scopes
   (resolve projected role per active scope against `role.canWrite`) and have
   `sendableCheckpoints` exclude non-writable scopes for a follower. The
   follower still receives those scopes' inbound changes. This prevents a
   read-only follower from repeatedly failing the session on new local writes
   (those are already blocked by the write gate, so in practice only matters for
   pre-demotion offline changes — keep the server enforcement regardless).

### Phase D — model + violation message

1. Add `unauthorizedWrite` to `CrdtSyncViolationType`
   (`server .../models/sync/violation_type.spy.yaml`, `serialized: byName`).
2. Run `serverpod generate` for the server package so the enum regenerates into
   both client and server protocol. Inspect the generated migration: a `byName`
   enum is stored as text, so **no schema migration** is expected — but verify
   `serverpod create-migration` produces nothing schema-affecting, and commit
   any generated protocol/migration the tool emits.
3. Add an `unauthorizedWrite` branch to
   `CrdtSyncIntegrityViolationException.toString()` in `crdt/exceptions.dart`
   (the `switch` is exhaustive over `CrdtSyncViolationType`).

### Phase E — tests and docs

Tests (server package + `test/serverpod_offline_sync_test_server`,
`--concurrency=1`):

- **Server rejects a read-only member's writes.** A member with `readOnly`
  syncing local changes for the
  shared scope → an `unauthorizedWrite` `CrdtSyncIntegrityViolation` is recorded,
  the session fails, and the change is **not** applied server-side.
- **Writable role syncs normally** for `readWrite`.
- **Client offline write gate.** `transactionForUser(user, fn, scopeId:
  readOnlyScope)` throws `CrdtScopeRoleException` before writing; the personal
  scope and writable shared scopes are unaffected.
- **Read-only member can still read** the shared scope's rows
  (membership-wide read is role-independent).
- **Follower outbound skip.** A read-only follower does not stream that scope's
  pending changes but still merges the server's inbound changes for it.
- **Demotion.** A member demoted to read-only mid-session: the projection flips
  the cached role (extends existing projection tests), the write gate starts
  rejecting, and pre-demotion offline changes are rejected+recorded by the
  server on next sync.
- **Personal scope always writable** because it has no explicit role.

Docs:

- `docs/shared-scopes.md`: move Follow-up #2 ("Roles within a scope") out of
  *Follow-ups* into the implemented behavior; document `CrdtScopeRole`, the
  three enforcement points, the reads-are-role-independent rule, and the
  null-role writable backward-compat guarantee. Note the demotion/offline-change
  purge question remains under the *Membership revocation* follow-up.
- `docs/row-ownership.md`: resolve/annotate open question 4.

## Acceptance criteria

- `dart analyze lib` clean in `serverpod_offline_sync_client`,
  `serverpod_offline_sync_server`, and `example/offline_sync_demo`.
- `serverpod generate` leaves the tree consistent (regenerated protocol
  committed; no unexpected schema migration).
- All existing tests stay green with the enum role behavior
  (`dart test --concurrency=1`).
- New role tests above pass.
- Public surface stays minimal: `CrdtScopeRole`, the nullable-role `canWrite`
  extension, and `CrdtScopeRoleException`; internal helpers (`roleOf`) are
  `@internal`.

## Touch list (files)

- `packages/serverpod_offline_sync_client/lib/src/crdt/roles.dart` (new)
- `packages/serverpod_offline_sync_client/lib/src/crdt/sync.dart`
- `packages/serverpod_offline_sync_client/lib/src/crdt/scope_sync.dart`
- `packages/serverpod_offline_sync_client/lib/src/crdt/scope_membership.dart`
- `packages/serverpod_offline_sync_client/lib/src/crdt/exceptions.dart`
- `packages/serverpod_offline_sync_client/lib/src/database/database.dart`
- `packages/serverpod_offline_sync_client/lib/src/database/session.dart`
- `packages/serverpod_offline_sync_client/lib/crdt.dart` (exports)
- `packages/serverpod_offline_sync_server/lib/src/business/crdt_sync.dart`
- `packages/serverpod_offline_sync_server/lib/src/models/sync/violation_type.spy.yaml`
- regenerated protocol (client + server) + any migration `serverpod generate`
  emits
- tests under `packages/serverpod_offline_sync_server/test/integration/` and
  `test/serverpod_offline_sync_test_server/test/integration/`
- `docs/shared-scopes.md`, `docs/row-ownership.md`
