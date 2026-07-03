# Scope management API

Status: implemented. Builds on the shared-scope
membership model in `shared-scopes.md`; this document specifies the developer-
facing API for *managing* membership, which that document deliberately left as
"app domain".

## Summary

The shared-scope machinery is complete for **resolving and enforcing**
membership (`CrdtScopeMembership.memberScopes` / `memberGrants` / `roleOf` /
`isMember`, the sync-loop enforcement, membership-wide reads). It has no API for
**managing** membership — creating a shared scope, adding a member with a role,
changing a role, revoking. `shared-scopes.md` says so outright: *"Rows are
managed by application code: invitations, acceptance, and role assignment are app
domain, outside this package."*

Today a developer must replicate what `scope_membership_test.dart` does — two
non-atomic raw `insertRow` calls against the **server** package's generated
`CrdtScope` / `CrdtScopeMember`, leaking every internal invariant
(`scopeId` vs `uuidScopeId`, the non-null `role` contract, the unique index,
personal-scope-UUID == user-UUID). This proposal replaces that with a small,
honest server-side service:

```dart
final scopeId = await session.crdt.scopes.create(owner: creatorUuid);
await session.crdt.scopes.grant(scope: scopeId, user: bob, role: CrdtScopeRole.readWrite);
await session.crdt.scopes.revoke(scope: scopeId, user: bob);
```

## Design decisions

These were settled in discussion; the reasoning is recorded so the
implementation issue does not relitigate them.

### A service, not an endpoint (the `AuthUsers` model)

The load-bearing constraint is `shared-scopes.md` #4: *membership cannot be
forged; the server never widens access from client-reported state*. If the
package auto-generated a management **endpoint**, any logged-in client could
self-grant into any scope and break that.

So the package ships a **server-side business service** the developer calls from
their **own** endpoint, after applying their **own** authorization policy. This
is exactly Serverpod's `AuthUsers`: `AuthUsers.create(session, ...)` is a
capability, not a policy — it does not check "may the caller create a user".
The sync path enforces roles internally only because it is *directly reachable
by untrusted clients*; the management service is server-only (no endpoint), so
its only caller is the developer's own server code.

The package owns the **data invariants**; the app owns the **authorization
policy**. That is the same division that makes invitations/acceptance app domain.

### No authorization check inside the service

An earlier sketch gated writes with a `by:` (acting-user) parameter checked
against an admin role. This was dropped:

- **`by` is forgeable, so it is not enforcement.** It is a `UuidValue` the
  caller supplies; the service cannot tell a real identity from a typed-in admin
  UUID. It prevents a bug, not an attacker — and only if someone upstream binds
  it to the true identity, which is the endpoint's job.
- The unforgeable identity is `session.authenticated` — the same source the sync
  endpoint already trusts (`crdt_sync_endpoint.dart`). It lives at the endpoint,
  which is where the app's policy lives anyway.
- The internal check is what forced a system/backend **bypass**; removing the
  check dissolves the bypass.

The service therefore performs **no** internal authorization. Authorization is
100% the endpoint's job, where the authenticated caller is unforgeable:

```dart
class TeamEndpoint extends Endpoint {
  Future<void> invite(Session s, UuidValue scope, UuidValue user, CrdtScopeRole role) async {
    final caller = UuidValue.withValidation(s.authenticated!.userIdentifier); // unforgeable
    if (!myApp.mayManage(caller, scope)) throw ...;                           // app policy
    await s.crdt.scopes.grant(scope: scope, user: user, role: role);
  }
}
```

### No `admin` role in the package

The discussion considered an `admin` tier in `CrdtScopeRole` so "any admin can
grant". It was rejected on the **enforce-vs-define** line: *the package should
own only what it enforces.*

- `readOnly` / `readWrite` are **enforced by the sync engine against untrusted
  clients** (the server rejects an unauthorized stream write and records
  `unauthorizedWrite`). This check cannot live in the app; it must be in the
  package.
- `admin` is **never consulted by the engine** — nothing in the sync path,
  merge, or read filter asks "is this user an admin". It would be a permission
  the package *defines but never acts on*, and it overlaps with Serverpod's own
  `Scope` mechanism (a second permission system the app must reconcile).

Everything uneasy traced back to `admin`: the forgeable `by`, the bypass, and a
"last-admin" orphan guard all evaporate once it leaves. `CrdtScopeRole` stays
`{ readOnly, readWrite }` — exactly what is already implemented — so this
proposal adds **no** enum churn.

Apps model "admin" with what they already have: a Serverpod `Scope` on the auth
user for global staff, or their own domain data for per-scope owners. If the
app's `TeamMember { teamId, userId, isAdmin }` is itself a synced CRDT table, an
"am I an admin" UI works offline for free. The two membership layers stay
separate: **access-membership** (`crdt_scope_members`, server-authoritative,
package-enforced: who may sync/read/write) vs **domain-membership** (app data:
who is an admin, display name, joined-at). The app keeps them in step — adding a
domain member also calls `scopes.grant` — the same split Serverpod has between
`AuthUser` and an app's user profile.

## Proposed API

Server-side, hung off the existing `session.crdt` (`CrdtSync`) accessor as
`session.crdt.scopes`. A pure data layer: atomic, transaction-threaded, no
internal auth.

```dart
/// Creates a shared scope and returns its UUID.
///
/// [owner], if given, is granted [CrdtScopeRole.readWrite]. [grants] adds any
/// further members. Both are applied in one transaction with the scope insert.
/// With no owner and no grants the scope is created dormant — it exists but no
/// one can sync it until membership is granted. Throws [ArgumentError] if
/// [owner] also appears in [grants].
Future<UuidValue> create({
  UuidValue? owner,
  Map<UuidValue, CrdtScopeRole>? grants,
  Transaction? transaction,
});

/// Grants [user] the given [role] in [scope], upserting an existing membership.
Future<void> grant({
  required UuidValue scope,
  required UuidValue user,
  required CrdtScopeRole role,
  Transaction? transaction,
});

/// Grants several members in one transaction; the bulk twin of [grant].
Future<void> grantAll(
  UuidValue scope,
  Map<UuidValue, CrdtScopeRole> grants, {
  Transaction? transaction,
});

/// Removes [user]'s membership in [scope]. A no-op if not a member.
Future<void> revoke({
  required UuidValue scope,
  required UuidValue user,
  Transaction? transaction,
});

/// The role [user] holds in [scope], or null if not a member. The read an app
/// wraps with its own admin policy before calling [grant] / [revoke].
Future<CrdtScopeRole?> roleOf({
  required UuidValue user,
  required UuidValue scope,
  Transaction? transaction,
});

/// The members of [scope] and their roles.
Future<Map<UuidValue, CrdtScopeRole>> members(
  UuidValue scope, {
  Transaction? transaction,
});
```

Notes:

- **`owner` is nullable** — a scope with no owner (and no grants) is valid but
  dormant. `create` skips the membership insert when `owner` is null.
- **`owner` and `grants` compose.** `owner` is ergonomic sugar for
  `{owner: readWrite}`; `grants` adds the rest. If `owner` also appears in
  `grants`, throw `ArgumentError` rather than silently pick a winner — a creator
  listed twice with a possibly-contradictory role is a caller bug.
- **`create` and `grantAll` share one internal helper** so the create path and
  the later bulk-grant path have a single implementation.
- **`create` returns a server-generated UUID** — the model already defaults
  `uuidScopeId` to `random_v7`. An optional explicit `uuidScopeId` param
  (app-chosen or idempotent create) is a compatible later addition; left out
  until there is a real need.
- Membership writes are plain `crdt_scope_members` / `crdt_scopes` rows — **not**
  CRDT-tracked, not part of the sync loop. Changes propagate to clients on the
  next sync cycle through the existing `ScopeSet` re-announcement path.

## Client side

Unchanged. Management is server-only; the client never writes membership. A
client learns of new scopes and role changes purely through the sync `ScopeSet`
announcement and the follower projection already implemented in
`shared-scopes.md`. There is no client `create`/`grant`/`revoke`.

## Test plan

- **Create.** `create(owner: u)` yields a scope with `u` at `readWrite` and a
  member-resolvable scope; `create()` (no owner) yields a dormant scope no user
  can sync; `create(owner: u, grants: {u: ...})` throws `ArgumentError`.
- **Grant/revoke.** `grant` inserts and upserts (role change); `revoke` removes
  and is a no-op for a non-member; `grantAll` applies a map atomically.
- **Reads.** `roleOf` returns the stored role or null; `members` returns the
  full map. Personal scope resolves to `readWrite` via the existing implicit
  path.
- **Propagation.** After a server-side `grant`, a continuous follower session
  adopts the new scope on the next cycle (covered by the existing access-change
  suite); after `revoke`, it stops cycling it.
- **Transaction threading.** A `create` folded into an app domain transaction
  rolls back atomically with the app write on failure.
