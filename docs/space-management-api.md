# Space management API

Status: implemented. Builds on the shared-space
membership model in `shared-spaces.md`; this document specifies the developer-
facing API for *managing* membership while leaving invitations, acceptance, and
authorization policy in app domain.

## Summary

The shared-space machinery is complete for **resolving and enforcing**
membership (`OfflineSyncSpaceMembership.memberSpaces` / `memberGrants` / `roleOf` /
`isMember`, the sync-loop enforcement, membership-wide reads), but those helpers
are package internals. The developer-facing API for **managing** membership is
the server-side `session.offlineSync.spaces` service: creating a shared space, adding a
member with a role, changing a role, revoking, and listing explicit members.
`shared-spaces.md` records the same boundary: rows are managed through
`session.offlineSync.spaces`, while invitations, acceptance, and authorization policy
remain app domain.

The service avoids making developers replicate what `space_membership_test.dart`
used to do — two non-atomic raw `insertRow` calls against the **server**
package's generated `OfflineSyncSpace` / `OfflineSyncSpaceMember`, leaking every internal
invariant (`spaceId` vs `uuidSpaceId`, the non-null `role` contract, the unique
index, personal-space-UUID == user-UUID):

```dart
final spaceId = await session.offlineSync.spaces.createFor(creatorUuid);
await session.offlineSync.spaces.grant(space: spaceId, user: bob, role: OfflineSyncSpaceRole.readWrite);
await session.offlineSync.spaces.revoke(space: spaceId, user: bob);
```

## Design decisions

These were settled in discussion; the reasoning is recorded so the
implementation issue does not relitigate them.

### A service, not an endpoint (the `AuthUsers` model)

The load-bearing constraint is `shared-spaces.md` #4: *membership cannot be
forged; the server never widens access from client-reported state*. If the
package auto-generated a management **endpoint**, any logged-in client could
self-grant into any space and break that.

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
  endpoint already trusts (`offline_sync_endpoint.dart`). It lives at the endpoint,
  which is where the app's policy lives anyway.
- The internal check is what forced a system/backend **bypass**; removing the
  check dissolves the bypass.

The service therefore performs **no** internal authorization. Authorization is
100% the endpoint's job, where the authenticated caller is unforgeable:

```dart
class TeamEndpoint extends Endpoint {
  Future<void> invite(Session s, UuidValue space, UuidValue user, OfflineSyncSpaceRole role) async {
    final caller = UuidValue.withValidation(s.authenticated!.userIdentifier); // unforgeable
    if (!myApp.mayManage(caller, space)) throw ...;                           // app policy
    await s.offlineSync.spaces.grant(space: space, user: user, role: role);
  }
}
```

### No `admin` role in the package

The discussion considered an `admin` tier in `OfflineSyncSpaceRole` so "any admin can
grant". It was rejected on the **enforce-vs-define** line: *the package should
own only what it enforces.*

- `readOnly` / `readWrite` are **enforced by the sync engine against untrusted
  clients** (the server rejects an unauthorized stream write and records
  `unauthorizedWrite`). This check cannot live in the app; it must be in the
  package.
- `admin` is **never consulted by the engine** — nothing in the sync path,
  merge, or read filter asks "is this user an admin". It would be a permission
  the package *defines but never acts on*, and it overlaps with Serverpod's own
  `Space` mechanism (a second permission system the app must reconcile).

Everything uneasy traced back to `admin`: the forgeable `by`, the bypass, and a
"last-admin" orphan guard all evaporate once it leaves. `OfflineSyncSpaceRole` stays
`{ readOnly, readWrite }` — exactly what is already implemented — so this
implementation adds **no** enum churn.

Apps model "admin" with what they already have: a Serverpod `Space` on the auth
user for global staff, or their own domain data for per-space owners. If the
app's `TeamMember { teamId, userId, isAdmin }` is itself a synced CRDT table, an
"am I an admin" UI works offline for free. The two membership layers stay
separate: **access-membership** (`offline_sync_space_members`, server-authoritative,
package-enforced: who may sync/read/write) vs **domain-membership** (app data:
who is an admin, display name, joined-at). The app keeps them in step — adding a
domain member also calls `spaces.grant` — the same split Serverpod has between
`AuthUser` and an app's user profile.

## API

Server-side, hung off the `session.offlineSync` accessor (the session-bound
`OfflineSyncSession` facade) as `session.offlineSync.spaces`. A pure data layer: atomic,
transaction-threaded, no internal auth.

```dart
/// Creates a shared space and returns its UUID.
///
/// [grants], if given, adds each user as a member with its role, applied in
/// one transaction with the space insert. With no grants the space is created
/// dormant — it exists but no one can sync it until membership is granted.
Future<UuidValue> create({
  Map<UuidValue, OfflineSyncSpaceRole>? grants,
  Transaction? transaction,
});

/// Creates a shared space granting [user] the given [role], in one
/// transaction.
///
/// Pure sugar for [create] with a single-entry grants map — the member has no
/// special bond to the space and can be re-granted or revoked like any other.
Future<UuidValue> createFor(
  UuidValue user, {
  OfflineSyncSpaceRole role = OfflineSyncSpaceRole.readWrite,
  Transaction? transaction,
});

/// Grants [user] the given [role] in [space], upserting an existing membership.
Future<void> grant({
  required UuidValue space,
  required UuidValue user,
  required OfflineSyncSpaceRole role,
  Transaction? transaction,
});

/// Grants several members in one transaction; the bulk twin of [grant].
Future<void> grantAll(
  UuidValue space,
  Map<UuidValue, OfflineSyncSpaceRole> grants, {
  Transaction? transaction,
});

/// Removes [user]'s membership in [space]. A no-op if not a member.
Future<void> revoke({
  required UuidValue space,
  required UuidValue user,
  Transaction? transaction,
});

/// The members of [space] and their roles.
Future<Map<UuidValue, OfflineSyncSpaceRole>> members(
  UuidValue space, {
  Transaction? transaction,
});
```

Notes:

- **There is no "owner".** An earlier sketch had an `owner` parameter on
  `create`, but the name implied a durable bond the data model does not have —
  the space row stores no owner, and the creator ends up an ordinary
  `readWrite` member. It was replaced by `createFor`, which is honest sugar:
  create a space and grant one member, atomically, with no special standing.
  Removing `owner` also dissolved the owner-appears-in-`grants` `ArgumentError`
  special case. A durable creator/owner concept is app domain, like `admin`.
- **`grants` may be empty or absent** — a space with no members is valid but
  dormant. `create()` skips the membership insert entirely.
- **`create` and `grantAll` share one internal helper** so the create path and
  the later bulk-grant path have a single implementation.
- **Unknown-space grants throw `OfflineSyncSpaceNotFoundException`** rather than a
  generic argument error, so callers can distinguish a stale or invalid space
  UUID from other failures.
- **`create` returns a server-generated UUID** — the model already defaults
  `uuidSpaceId` to `random_v7`. An optional explicit `uuidSpaceId` param
  (app-chosen or idempotent create) is a compatible later addition; left out
  until there is a real need.
- Membership writes are plain `offline_sync_space_members` / `offline_sync_spaces` rows — **not**
  CRDT-tracked, not part of the sync loop. Changes propagate to clients on the
  next sync cycle through the existing `SpaceSet` re-announcement path.

## Client side

Unchanged. Management is server-only; the client never writes membership. A
client learns of new spaces and role changes purely through the sync `SpaceSet`
announcement and the follower projection already implemented in
`shared-spaces.md`. There is no client `create`/`grant`/`revoke`.

## Test plan

- **Create.** `createFor(u)` yields a space with `u` at `readWrite` and a
  member-resolvable space; `createFor(u, role: ...)` stores the explicit role;
  `create()` (no grants) yields a dormant space no user can sync;
  `create(grants: {...})` stores every entry with its role.
- **Grant/revoke.** `grant` inserts and upserts (role change); `revoke` removes
  and is a no-op for a non-member; `grantAll` applies a map atomically.
- **Reads.** `members` returns the explicit member-role map. Internal role
  resolution still covers stored, missing, and implicit personal membership.
- **Propagation.** After a server-side `grant`, a continuous follower session
  adopts the new space on the next cycle (covered by the existing access-change
  suite); after `revoke`, it stops cycling it.
- **Transaction threading.** A `create` folded into an app domain transaction
  rolls back atomically with the app write on failure.
