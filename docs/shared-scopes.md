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
> scopes a session syncs is computed server-side from `crdt_scope_members` and
> re-resolved at the start of every sync cycle, so access changes take effect
> mid-session. The server dictates the set; the client adopts scopes it
> announces and drops the ones it does not. The reconciliation is directional —
> not a set operation toggled by a flag — and membership itself is never synced.

> **Row ownership is unchanged.** Every row still has exactly one owning
> `scopeId`, `(table, uuidRowId)` stays globally identified, and every
> enforcement rule in `row-ownership.md` survives untouched. Sharing adds a
> membership layer in front of scopes; it does not touch row ownership.

## Goals and constraints

1. **One call, every scope.** The public client API (`syncOnce`,
   `syncContinuously`) does not change shape: callers pass a session, never a
   scope. A device with only a personal scope behaves exactly as today.
2. **Smallest protocol delta.** The per-scope exchange is today's frames. The
   only additions are a per-cycle scope-set exchange and a scope tag on the
   per-scope frames. `collectNextBatch`, `collectPendingChanges`,
   `mergeInboundBatch`, and `recordSyncCheckpoint` are reused per scope without
   logic changes.
3. **Bounded memory.** A scope's changes are collected, streamed, merged, and
   released before the next scope is visited. A session never holds all scopes'
   pending changes at once.
4. **Membership cannot be forged.** The server computes its own scope set from
   `crdt_scope_members` (plus the implicit personal scope) and never widens it
   from anything the client sends. A scope the user is not a member of is never
   synced, even if the client names it.
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
- `role` is sketched but unenforced (see *Follow-ups*).

### Members vs. nodes

`crdt_scope_members` and the `nodes` list on a scope are orthogonal layers and
both stay:

- A **member** is an authorization fact: a user identity allowed to access a
  scope. It answers *who may sync, read, and write*.
- A **node** (`crdt_nodes`, the scope's `nodes` relation) is a CRDT causality
  fact: one replica's participation in one scope's HLC chain. It answers *whose
  changes, up to which HLC* and is what per-`(scope, node)` checkpoints key on.

They do not map one-to-one and neither replaces the other. One member may have
many nodes (one per device). The **server is a node** in every scope it syncs
but is not a member row. A freshly invited member has **zero nodes** until their
first device syncs. Nodes are created implicitly by sync (`getOrCreate`,
`recordSyncCheckpoint`); members are created by application code. Removing the
`nodes` list would break checkpointing and causal filtering — it is the chain
topology, not the access list.

### The client needs no membership table

`crdt_scope_members` is **server-only**. The client does not replicate it and
does not need it to scope reads and writes:

- The client's `crdt_scopes` rows already *are* its membership view. Every local
  scope is one the server authorized — the personal scope plus shares the client
  adopted from the server's announcements — and the per-cycle reconcile keeps it
  current (adopt on grant, drop on revoke). So a membership-wide read filters
  over the client's local scopes; it needs no `(scopeId, userUuid)` table.
- Writes are bounded by the scopes the client holds (it cannot act in a scope it
  has no local row for) and are re-verified by the server on sync, which remains
  the security boundary. Client-side checks are early-failure UX, not the
  enforcement point.
- The one thing the client cannot derive from holding a scope is a **role**
  (e.g. read-only). When roles arrive, the client needs the role *per held
  scope*, delivered as a per-scope datum at handshake — a field on the client's
  scope row, not a replicated `(scopeId, userUuid, role)` table. (Deferred; see
  *Follow-ups*.)

### Scope enumeration (server is the authority)

At the start of each sync cycle the server resolves the authoritative set:

```
memberScopes(userUuid) =
    { personal scope = userUuid }
  ∪ { m.scopeUuid : crdt_scope_members where userUuid = <auth user> }
```

This set bounds everything the cycle may sync. The client never expands it; it
only learns of additions through what the server announces.

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

`Connect` opens the session once; a scope-set exchange opens each cycle; the
per-scope exchange repeats within a cycle. Frame changes (regenerated models + a
migration on both client and server schemas):

- `CrdtSyncConnect { syncTablesHash }` — sent once by each peer. The schema hash
  is validated once, before any scope work. The scope list and the single
  `localNodeId` both leave `Connect`: the scope set is dynamic (per cycle) and
  node ids are per scope.
- `CrdtSyncScopeSet { scopeIds: List<UuidValue> }` — exchanged at the **start of
  every cycle**. The server's content is authoritative (re-resolved from
  `crdt_scope_members` each cycle); the client's is informational. This is the
  one frame that carries access changes mid-session — keeping it out of the
  one-time `Connect` is what lets a grant or a revoke take effect on the next
  cycle. For a one-shot `syncOnce` there is a single cycle, so it is exchanged
  exactly once.
- `CrdtSyncSinceHlc { uuidScopeId, localNodeId, nodeCheckpoints }` — per scope.
  Carries that scope's node id and per-node checkpoints. Exchanged on a scope's
  first visit (and again if a dropped scope is later re-adopted); checkpoints
  then live in memory for the rest of the session.
- `CrdtSyncMergeChunk { uuidScopeId, changes }` — a chunk tagged with its scope.
- `CrdtSyncEndOfBatch`, `CrdtSyncClose`, `CrdtSyncIdleTimeout` — unchanged.
  `EndOfBatch` terminates the current scope's batch; `Close` terminates the
  whole session after the final cycle.

`collectNextBatch` is unchanged: it is still called once per scope visit and
returns that scope's `CrdtMergeSet`. There is no per-round grouping map.

### The session state machine

```
handshake (once per session):
  send Connect(syncTablesHash); read peer Connect; validate syncTablesHash
  nodeCheckpoints: Map<scopeUuid, Map<nodeId, Hlc>> = {}
  handshaked: Set<scopeUuid> = {}

cycle (once: exactly one; continuous: forever):
  resolve my set; send ScopeSet(myScopeIds); read peer ScopeSet
  reconcile → orderedScopes        (see "reconciliation and lockstep")
  discard nodeCheckpoints/handshaked for scopes no longer in orderedScopes
  for scope in orderedScopes:
    if scope not in handshaked:
      exchange SinceHlc(scope) → seed nodeCheckpoints[scope]; handshaked.add(scope)
    collect pending for scope → send MergeChunk(scope)* + EndOfBatch   # send
    read peer batch for scope → mergeInboundBatch(scope)               # merge
      → advance nodeCheckpoints[scope]
  continuous: delay continuousSyncInterval, then next cycle

once: after the single cycle → send Close, read Close, drain (today's teardown)
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

### Scope-set reconciliation and lockstep

Both peers must cycle the **same ordered scope set** or send/receive desyncs.
Membership is asymmetric — the client trusts the server's membership claims, the
server trusts none of the client's — so the reconciliation is **directional**,
not a symmetric set operation:

- **Union is wrong** (insecure): a client could name a scope the user is not a
  member of and force the server to sync it.
- **Intersection is wrong** (cannot adopt): a brand-new share is not in the
  client's set yet, so it would never enter the intersection and never sync —
  the client cannot hold what it has not synced, and cannot sync what it does
  not hold.

The correct operation is neither: **the server dictates its set; the client
conforms.** Each cycle:

- **Server**: `orderedScopes = sort(memberScopes(userUuid))`, computed from
  `crdt_scope_members`. It never reads the client's `ScopeSet` for authority
  (constraint 4); the client's list is informational.
- **Client**: takes the server's `ScopeSet` as the set to cycle —
  `getOrCreate` (`CrdtScopeManager`) any scope it lacks, drop any local scope the
  server omitted — then `orderedScopes = sort(peer scopeIds)`.

This asymmetry is **not a boolean flag**. A flag invites the exact footgun of
"both sides set it" (→ neither adopts → intersection → new shares lost) or
"neither sets it" (→ both adopt → union → insecure). Instead it is a **resolver
injected at the call site**: the server endpoint constructs a membership
resolver (with `crdt_scope_members` access); the client driver constructs a
follower resolver. The two live at the two already-distinct call sites, so
"both authoritative" is unrepresentable, not merely discouraged. Frames stay
symmetric in *shape* — both carry `scopeIds` — exactly as `userId` is already
sourced differently per side today.

Because the client adopts straight from the cycle's `ScopeSet` *before* it
iterates, a newly granted scope syncs in the **same cycle**, not the next.
Sorting by scope UUID makes the order deterministic on both sides with no extra
negotiation. Frames carry `uuidScopeId` even though strict lockstep makes
position predictable: the tag is cheap, self-describing, and fails loud on
desync rather than merging a batch into the wrong scope.

Re-resolving `memberScopes` every cycle is an indexed `crdt_scope_members`
lookup on the server only; it may be throttled or invalidated by an
application hook if per-cycle querying becomes hot, at the cost of slower
propagation of access changes.

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

### Access changes during a session

Because the authoritative scope set is re-resolved and re-exchanged at the top of
every cycle (not pinned at `Connect`), a continuous session absorbs membership
changes without reconnecting:

- **Grant.** The server's next `ScopeSet` includes the new scope; the client
  adopts it before iterating and syncs it in that same cycle.
- **Revoke.** The server's next `ScopeSet` omits the scope; both sides stop
  cycling it immediately and discard its in-memory checkpoint state. The device
  still *holds* the revoked scope's rows; purging them (and the fate of any
  unsynced local changes) is the deferred revocation question, not a sync-loop
  concern.

The set changes only at a cycle boundary, where both sides exchange and reconcile
`ScopeSet` before iterating, so lockstep is preserved across the change. A
one-shot `syncOnce` has a single cycle, so it captures the set once; the next
`syncOnce` call picks up any change.

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
  changes (`Connect` minus `scopeIds`/`localNodeId`, new per-cycle
  `CrdtSyncScopeSet`, per-scope `SinceHlc`, `MergeChunk.uuidScopeId`) plus
  generate/migrate. Outer cycle loop in `CrdtSync.sync` with per-cycle
  `ScopeSet` exchange, per-scope handshake-on-first-visit, in-memory per-scope
  checkpoints, and the once/continuous cadence. Reconciliation via an injected
  resolver: the server endpoint supplies a `crdt_scope_members`-backed
  membership resolver; the client driver supplies a follower that adopts the
  server's set. Scope-aware `onMergeSuccess`. A personal-scope-only device
  behaves identically to today.
- **Phase 3 — transaction API.** `transactionForUser(userId, fn, {scopeId})`
  with the membership assertion; one scope per transaction.
- **Phase 4 — membership-wide reads.** Generalize the scoped read filter to
  `scopeId IN (…)` over the user's member scopes.
- **Phase 5 — lifecycle and docs.** Client adoption of newly announced shares;
  reconcile with the scope-purge semantics in `sync-non-sync-relations.md`.
  Revocation cleanup and roles are deferred (see *Follow-ups*).

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
  non-member scope is refused and never streamed; a newly granted scope is
  adopted and syncs in the same cycle.
- **Access changes mid-session.** During a continuous session, a grant added to
  `crdt_scope_members` appears and syncs on the next cycle; a revoke stops
  cycling that scope without dropping the session.
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
- **Membership authority:** the server, from `crdt_scope_members`. The
  reconciliation is directional — server dictates, client conforms — and is
  neither union (insecure) nor intersection (cannot adopt). It is an injected
  **resolver**, not a boolean: a flag invites the "both set it / neither sets
  it" footgun, whereas distinct resolvers at the two call sites make "both
  authoritative" unrepresentable. Frames stay symmetric in shape; only the
  values and the dictate-vs-conform behavior differ, as `userId` already does.
- **Scope set is per cycle, not per connect:** re-resolved and re-exchanged each
  cycle so grants and revokes take effect mid-session without reconnecting. A
  newly granted scope syncs in the *same* cycle, since the client adopts from the
  cycle's `ScopeSet` before iterating.
- **Members vs. nodes:** orthogonal layers, both kept. Members are authorization
  (`who`); nodes are CRDT causality (`whose changes, up to which HLC`). One
  member maps to many nodes; the server is a node but not a member; a new member
  has no node until first sync.
- **No client membership table:** the client's `crdt_scopes` is its membership
  view; reads filter over local scopes and the server re-verifies on sync. Only
  roles (read-only) would need a per-scope datum on the client, delivered at
  handshake — not a replicated members table.
- **Iteration order:** sorted scope UUIDs, so both peers stay in lockstep
  without negotiation. Frames are still scope-tagged to fail loud on desync.
- **One scope per transaction:** kept. Cross-scope writes need separate
  transactions; remote replicas cannot observe a cross-scope write atomically
  anyway.
- **Membership table is server-only and unsynced:** it is server/app state, not
  CRDT data.
- **Idle chatter accepted for the initial implementation:** an idle continuous
  cycle does one empty scope-turn per accessible scope rather than one per
  session. It is proportional to scope count and harmless to start; skipping
  scopes with no local pending changes and no expected inbound is an optional
  later optimization, not a launch blocker.
- **Initial-sync ordering is not a current concern:** a device joining many
  scopes cycles them one at a time on first sync. Prioritizing recently active
  scopes in the iteration order is a compatible refinement if cold-start latency
  over large scope counts ever matters, but it is not a present worry.

## Follow-ups

Deferred work, each needing its own design pass. Neither blocks the phased plan
above; both are tracked so the first implementation does not foreclose them.

1. **Membership revocation.** When a user loses membership, the server omits the
   scope from the next cycle's `ScopeSet` and both sides stop syncing it
   promptly, but the device still holds the scope's data and may hold unsynced
   local changes. Purge-vs-keep policy, and whether revoked unsynced changes are
   surfaced or dropped, need their own design. (Carried from `row-ownership.md`
   open question 3.)
2. **Roles within a scope.** `crdt_scope_members.role` is stored but unenforced.
   Read-only members would need write rejection at merge time (another
   fail-and-record case) and a per-scope role datum on the client to reject
   writes offline (see *The client needs no membership table*), which overlaps
   with revocation of offline-written changes by a demoted member. (Carried from
   `row-ownership.md` open question 4.)
