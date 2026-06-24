# Shared scopes

Status: planned. Implements the direction sketched in `row-ownership.md`
§*Future: shared scopes* and depends on the row-ownership work (implemented).
This document is the committed plan for that section; where the two disagree,
this one wins.

## Summary

A user is an authentication identity; a scope is the unit of replication and
ownership. Today every user has exactly one scope — their personal one — and a
sync session is pinned to it. Shared scopes let one identity belong to its
personal scope plus any number of shared scopes, and the load-bearing
requirement is:

> **A single `sync` call syncs every scope the authenticated user has access
> to.** One `syncOnce` cycles through all accessible scopes exactly once; a
> continuous session keeps cycling forever. There is no separate stream or
> separate call per scope.

The row-ownership work already keys storage, locking, HLC chains, visibility,
and ownership by **scope**, not user, so sharing is an indirection in front of
`crdt_scopes`, not a re-architecture. The two new pieces are a server-side
membership relation and a sync protocol that iterates scopes.

> **Scopes are synced one at a time, sequentially.** Within a session the unit
> that repeats is a single scope's `send → receive → merge` turn — exactly
> today's per-scope state machine — wrapped in an outer loop over the
> accessible scopes. Scopes are never multiplexed across one round. Only one
> scope's pending changes are ever held in memory, and the wire protocol stays
> a near-verbatim repetition of today's frames.

> **The server is the authority on membership; the client follows.** The set of
> scopes a session syncs is computed server-side from `crdt_scope_members` at
> the handshake. The client adopts scopes the server announces and drops its
> own scopes the server does not. Membership itself is never synced.

> **Row ownership is unchanged.** Every row still has exactly one owning
> `scopeId`, `(table, uuidRowId)` stays globally identified, and every
> enforcement rule in `row-ownership.md` survives untouched. Sharing adds a
> membership layer in front of scopes; it does not touch row ownership.

## Goals and constraints

1. **One call, every scope.** The public client API (`syncOnce`,
   `syncContinuously`) does not change shape: callers pass a session, never a
   scope. A device with only a personal scope behaves exactly as today.
2. **Smallest protocol delta.** The per-scope exchange is today's frames. The
   only additions are a scope list in the handshake and a scope tag on the
   per-scope frames. `collectNextBatch`, `collectPendingChanges`,
   `mergeInboundBatch`, and `recordSyncCheckpoint` are reused per scope without
   logic changes.
3. **Bounded memory.** A scope's changes are collected, streamed, merged, and
   released before the next scope is visited. A session never holds all scopes'
   pending changes at once.
4. **Membership cannot be forged.** The server verifies every scope against
   `crdt_scope_members` (plus the implicit personal scope). A client-announced
   scope the user is not a member of is refused, never synced.
5. **One scope per transaction.** Reads are membership-wide; writes stay pinned
   to exactly one scope. This is deliberate honesty about CRDT semantics: two
   scopes' chains replicate independently and a remote replica can never
   observe a cross-scope write atomically.
6. **Roles are not hard-coded.** Single-tenant servers and multi-account
   devices remain the same code path with different scope counts.

## Membership

### The `crdt_scope_members` table

```yaml
class: CrdtScopeMember
table: crdt_scope_members
database: server
fields:
  scope: CrdtScope?, relation(name=scope_members, onDelete=Cascade)
  userUuid: UuidValue
  role: String?
indexes:
  crdt_scope_member_unique_idx:
    fields: scopeId, userUuid
    unique: true
```

- The table is **server-only** (`database: server`) and **not** in
  `syncTables`. It is application/server state, never CRDT-replicated.
- Rows are managed by application code: invitations, acceptance, and role
  assignment are app domain, outside this package.
- **Personal-scope membership is implicit.** By convention a user's personal
  scope has the user's own UUID (already true: the scope UUID keys the chain),
  so no `crdt_scope_members` row is stored for it. Shared scopes are
  `crdt_scopes` rows whose UUID is no user's id, with explicit membership rows.
- `role` is sketched but unenforced (see *Open questions*).

### Scope enumeration (server is the authority)

At the sync handshake the server resolves the authoritative set:

```
memberScopes(userUuid) =
    { personal scope = userUuid }
  ∪ { m.scopeUuid : crdt_scope_members where userUuid = <auth user> }
```

This set bounds everything the session may sync. The client never expands it;
it only learns of additions through what the server announces.

## Sync: one call syncs every accessible scope

### Why sequential, one scope per turn

Merge is inherently one scope at a time: a merge runs in exactly one scope's
transaction and lock. Syncing all scopes inside one round would force
scope-tagged framing, per-scope grouping inside `collectNextBatch`, and several
scopes' checkpoint state and pending changes held at once — protocol and memory
cost for no throughput gain, since the merges still serialize. Sequencing the
scopes instead reuses the existing per-scope state machine as the inner body
and adds an outer loop. It is a strictly smaller diff, cleaner on the wire, and
lighter on memory.

### Protocol frames

One `Connect` per session; the per-scope exchange is the repeating unit. Frame
changes (regenerated models + a migration on both client and server schemas):

- `CrdtSyncConnect { syncTablesHash, scopeIds: List<UuidValue> }` — sent once by
  each peer. The schema hash is validated once. `scopeIds` is the peer's offered
  scope set, used to agree on the ordered cycle (below). The single
  `localNodeId` is removed from `Connect`; node ids are per scope.
- `CrdtSyncSinceHlc { uuidScopeId, localNodeId, nodeCheckpoints }` — per scope.
  Carries that scope's node id and per-node checkpoints. Exchanged on a scope's
  first visit; checkpoints then live in memory for the rest of the session.
- `CrdtSyncMergeChunk { uuidScopeId, changes }` — a chunk tagged with its scope.
- `CrdtSyncEndOfBatch`, `CrdtSyncClose`, `CrdtSyncIdleTimeout` — unchanged.
  `EndOfBatch` terminates the current scope's batch; `Close` terminates the
  whole session after the single pass.

`collectNextBatch` is unchanged: it is still called once per scope visit and
returns that scope's `CrdtMergeSet`. There is no per-round grouping map.

### The session state machine

```
handshake (once):
  send Connect(syncTablesHash, myScopeIds)
  read peer Connect; validate syncTablesHash
  reconcile → orderedScopes        (see "reconciliation and lockstep")
  nodeCheckpoints: Map<scopeUuid, Map<nodeId, Hlc>> = {}

pass (once: a single pass; continuous: forever):
  for scope in orderedScopes:
    if first visit:
      exchange SinceHlc(scope) → seed nodeCheckpoints[scope]
    collect pending for scope → send MergeChunk(scope)* + EndOfBatch   # send
    read peer batch for scope → mergeInboundBatch(scope)               # merge
      → advance nodeCheckpoints[scope]
  continuous: delay continuousSyncInterval after each full cycle, then repeat

once: after the single pass → send Close, read Close, drain (today's teardown)
```

This is today's `while (true) { collect → send → receive → merge }` lifted one
level: the inner body is one scope-turn, the outer loop is the scope cycle.
`collectPendingChanges`, `mergeInboundBatch`, `recordSyncCheckpoint`, and the
ownership-violation internals (`_streamInserts`/`Updates`/`Deletes`,
`_fetchDomainRow`, the durable-violation path) are already scope-parameterized
and are invoked per scope unchanged. Each scope merges in its own
`transactionForUser`/lock, so scopes do not contend; any scope's merge failure
(for example an ownership collision) records the durable violation and fails the
session, preserving today's fail-fast semantics.

`onMergeSuccess` becomes scope-aware: `Function(UuidValue scopeUuid, Hlc hlc)`.
This touches three test call sites and the example app's `demo_controller`.

### Scope-list reconciliation and lockstep

Both peers must cycle the **same ordered scope list** or send/receive desyncs.
Membership is asymmetric — the server is the authority — so the reconciliation
rule is the one honest asymmetry, passed into `CrdtSync.sync` as a role:

- **Server**: `orderedScopes = sort(memberScopes(userUuid))`. It ignores any
  client-announced scope not in that set (constraint 4).
- **Client**: it adopts server-announced scopes it lacks
  (`CrdtScopeManager.getOrCreate`), drops its own scopes the server did not
  announce, then `orderedScopes = sort(peer scopeIds)`.

After the handshake both iterate `sort(memberScopes)`. Sorting by scope UUID
makes the order deterministic on both sides with no extra negotiation. Frames
carry `uuidScopeId` even though strict lockstep makes position predictable: the
tag is cheap, self-describing, and fails loud on desync rather than merging a
batch into the wrong scope.

### Checkpoints, once vs. continuous

Checkpoints stay per `(scope, node)`, exactly as today
(`CrdtNode.scopeId` + `lastReceivedHlc`, resolved by `recordSyncCheckpoint`). A
device is a distinct node in each scope's chain. `SinceHlc` is exchanged once
per scope on first visit; later cycles reuse the in-memory
`nodeCheckpoints[scope]`, advanced as chunks are sent and as inbound batches
merge — the multi-scope analogue of today's single-scope continuous loop, which
already keeps checkpoints in memory across rounds.

The continuous interval delay moves to **after each full cycle**, not after each
scope, to keep per-scope latency low while still preventing a busy loop when
idle.

### Newly shared scopes

A client announces its scope list in `Connect` before it has read the server's,
so a brand-new share is absent from the client's first `Connect`. The client
adopts it on reading the server's `Connect` and syncs it starting the **next
cycle** (continuous) or the **next `syncOnce`** call. A first share therefore
carries one round of latency. A mid-session re-handshake to pull new scopes
sooner is deliberately not added; the latency is marginal and continuous
sessions absorb it on the following cycle.

## Transaction API

`transactionForUser` keeps its name and user-first semantics and gains an
optional scope:

```dart
db.transactionForUser(userId, fn);                  // acts in the personal scope
db.transactionForUser(userId, fn, scopeId: listId); // acts in a shared scope
```

- Without `scopeId`, the scope resolves to the user's personal scope —
  `userId` itself by convention — which is exactly today's behavior.
- With `scopeId`, the package asserts `membership(userId, scopeId)` before
  acting. The pair reads as "authenticated as `userId`, acting in `scopeId`,
  verified member". The caller remains responsible for `userId` being
  authenticated, as today.
- A transaction acts in **exactly one** scope (constraint 5). The write path —
  stamp-or-assert, the scoped `WHERE`, `scopeId` immutability — is unchanged
  beyond which scope is resolved.

## Read path: membership-wide

A user-scoped read in a sharing world means "rows in any scope I am a member
of". The single-scope resolver becomes a set:

- `mergeWhereWithTombstone` currently isolates a scoped read with
  `scopeId = <scope>` via a `CrdtScopeIdResolver` returning one `int?`.
  Generalize it to `scopeId IN (<member scope ids>)`. The visibility probe is
  already the row-keyed form for the multi-scope case, so sharing simplifies the
  predicate matrix rather than growing it: reads differ only in their membership
  filter (one scope, a user's scopes, or none for admin).
- This is the shape of a Postgres row-level-security policy
  (`scopeId IN (SELECT scopeId FROM crdt_scope_members WHERE userUuid = …)`); the
  package's application-level filter and RLS become two enforcements of one
  predicate.

Writes stay scope-pinned (above); only reads widen.

## What sharing does not change

Every enforcement rule in `row-ownership.md` survives unchanged:
`(table, uuidRowId)` stays globally identified; rows have exactly one owning
scope; merge-insert ownership checks compare scopes; unique conflict groups form
within a scope; ordinary global unique indexes stay rejected; stamp-or-assert
applies with the transaction's resolved scope; the durable
`crdt_sync_integrity_violations` contract is untouched. The merge, FK, and
unique engines already key on the scope the merge runs in and need no changes.

## Implementation plan

Each phase lands independently green; later phases depend on earlier ones only
where stated. Run tests with `--concurrency=1`.

- **Phase 1 — membership foundation.** Add `crdt_scope_members`
  (server-only, unsynced) and its migration. Add the server enumeration helper
  `memberScopes(userUuid)`. No behavior change yet: a personal-scope-only set
  reproduces today's single-scope sync exactly.
- **Phase 2 — sequential multi-scope sync (the requirement).** Protocol model
  changes (`Connect.scopeIds`, per-scope `SinceHlc`, `MergeChunk.uuidScopeId`)
  plus generate/migrate. Outer scope loop in `CrdtSync.sync` with per-scope
  handshake-on-first-visit, in-memory per-scope checkpoints, the once/continuous
  cycle, and reconciliation with the server as authority. Scope-aware
  `onMergeSuccess`. The endpoint passes the authenticated user plus the
  membership resolver; the client resolves its local set and adopts announced
  scopes. A personal-scope-only device behaves identically to today.
- **Phase 3 — transaction API.** `transactionForUser(userId, fn, {scopeId})`
  with the membership assertion; one scope per transaction.
- **Phase 4 — membership-wide reads.** Generalize the scoped read filter to
  `scopeId IN (…)` over the user's member scopes.
- **Phase 5 — lifecycle and docs.** Client adoption of newly announced shares;
  reconcile with the scope-purge semantics in `sync-non-sync-relations.md`.
  Revocation cleanup and roles are deferred (see *Open questions*).

## Test plan

Because no code branches on scope count or deployment role, mechanisms are
tested once, not per combination.

- **Regression.** Every existing single-scope suite passes unchanged on the
  personal-scope-only path.
- **Protocol.** `Connect`/`SinceHlc` round-trip a multi-scope list; merge chunks
  route to the correct scope by `uuidScopeId`; per-scope checkpoints advance
  independently across cycles.
- **One call, every scope.** A single `syncOnce` converges N scopes in one pass;
  a continuous session keeps cycling; memory holds only one scope's pending
  changes at a time.
- **Membership.** The server syncs personal + shared scopes; a client-announced
  non-member scope is refused and never streamed; a newly shared scope is
  adopted and syncs on the following cycle.
- **Isolation under sharing.** Two users sharing scope X both converge on X
  while their personal scopes stay isolated; an ownership collision in one scope
  records a durable violation and fails the session without corrupting another
  scope's merge.
- **Smoke.** One `withServerpod` round-trip with one personal plus one shared
  scope, proving the end-to-end wiring (mirrors `sync_flow_test.dart`).

## Resolved during review

- **Sequential vs. multiplexed sync:** sequential, one scope per turn. Merges
  serialize regardless, so multiplexing buys no throughput while costing
  protocol surface and memory. Sequencing reuses the existing per-scope state
  machine as the inner loop.
- **Membership authority:** the server, from `crdt_scope_members`. The client
  follows the server's announced list. The asymmetry is explicit (a role passed
  into `CrdtSync.sync`), not smuggled into otherwise-symmetric frames.
- **Iteration order:** sorted scope UUIDs, so both peers stay in lockstep
  without negotiation. Frames are still scope-tagged to fail loud on desync.
- **One scope per transaction:** kept. Cross-scope writes need separate
  transactions; remote replicas cannot observe a cross-scope write atomically
  anyway.
- **Membership table is server-only and unsynced:** it is server/app state, not
  CRDT data.
- **New-share latency of one cycle:** accepted. A mid-session re-handshake is
  not worth the protocol surface.

## Open questions

1. **Membership revocation.** When a user loses membership, the server stops
   announcing the scope at the next handshake, but the device still holds the
   scope's data and may hold unsynced local changes. Purge-vs-keep policy, and
   whether revoked unsynced changes are surfaced or dropped, need their own
   design. (Carried from `row-ownership.md` open question 3.)
2. **Roles within a scope.** `crdt_scope_members.role` is stored but unenforced.
   Read-only members would need write rejection at merge time (another
   fail-and-record case), which overlaps with revocation of offline-written
   changes by a demoted member. (Carried from `row-ownership.md` open
   question 4.)
3. **Idle chatter.** An idle continuous cycle now does one empty scope-turn per
   accessible scope instead of one per session. It is proportional to scope
   count and harmless, but if it bites, a later optimization can skip scopes
   with no local pending changes and no expected inbound.
4. **Initial-sync latency at scale.** A device joining many scopes cycles them
   one at a time on first sync. If cold-start latency over large scope counts
   becomes a problem, prioritizing recently active scopes in the iteration order
   is a compatible refinement.
