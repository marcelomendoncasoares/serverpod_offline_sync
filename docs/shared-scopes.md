# Shared scopes

Status: implemented. This records the shared-scope behavior built on top of
the row-ownership work in `row-ownership.md`. Revocation cleanup and roles are
still deferred follow-ups; where the ownership summary and this document differ,
this one wins.

## Summary

A user is an authentication identity; a scope is the unit of replication and
ownership. Each user has a personal scope and may also belong to any number of
shared scopes. The load-bearing
requirement is:

> **A single `sync` call syncs every scope the authenticated user has access
> to.** One `syncOnce` cycles through all accessible scopes exactly once; a
> continuous session keeps cycling forever. There is no separate stream or
> separate call per scope.

The row-ownership work keys storage, locking, HLC chains, visibility, and
ownership by **scope**, not user, so sharing is an indirection in front of
`crdt_scopes`, not a re-architecture. The implemented pieces are a server-side
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
> announces and stops cycling the ones it omits. The reconciliation is
> directional — not a set operation toggled by a flag — and membership itself is
> never synced. Local data cleanup for omitted scopes is a separate revocation
> policy, not part of the sync loop.

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
database: all
fields:
  scope: CrdtScope?, relation(onDelete=Cascade)
  userUuid: UuidValue
  role: String?
indexes:
  crdt_scope_member_unique_idx:
    fields: userUuid, scopeId
    unique: true
```

- The table is **`database: all`** but **not** in `syncTables`. It exists on
  every node so membership resolves with the same code on both ends, but it is
  never CRDT-replicated by this package. The server is the authoritative writer;
  a client copy (once populated) is a read-only cache for UI and offline role
  checks — see *The client membership table*.
- The index **leads with `userUuid`** so the per-cycle `WHERE userUuid = ?`
  resolution is index-covered.
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

### The client membership table

`crdt_scope_members` is `database: all`, so the table exists on the client and
is **populated as a read-only projection** of the server's authoritative grants
— without being bidirectionally CRDT-synced:

- The client's `crdt_scopes` rows remain its membership view for *gating*: a
  membership-wide read filters over local scopes, and the `crdt_scopes`-presence
  rule authorizes writes. The members table adds **roles**, for UI and (future)
  offline role-gated writes.
- The authoritative `CrdtSyncScopeSet` carries `CrdtScopeGrant`s — `(scopeUuid,
  role)` — not bare UUIDs. When the follower *receives* an announcement,
  `projectFollowerMembership` reconciles the local table from it: upsert a row
  per shared grant (the personal scope is implicit and skipped), delete rows
  whose scope is no longer granted. Since the authoritative peer announces only
  when its grants change, projection runs only on change and an idle session
  writes nothing.
- This is a **server-authored, client-read-only projection**, never a synced
  members table: the client never writes membership the server reads, so it
  cannot self-grant. The server stays the security boundary and re-verifies on
  sync.
- A revoke takes effect for sync as soon as the server omits the scope from a
  cycle's `ScopeSet`: the client stops cycling it and discards in-memory
  checkpoint state for it. The scope row and domain rows remain local until the
  deferred revocation cleanup policy decides whether to purge or keep them.
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

### Two cadences: bounded `once`, idle-silent `continuous`

Merge is inherently one scope at a time: a merge runs in exactly one scope's
transaction and lock, so the scopes always serialize regardless of framing. The
two drivers want different things around that core, so they take different
shapes:

- **`syncOnce` (`_syncOnce`)** runs a single bounded round. It keeps the simple
  per-scope state machine: exchange the scope set, then for each scope
  handshake → send `MergeChunk`\* + `EndOfBatch` → read that scope's batch →
  merge, then close. One round-trip per scope *is* the whole session, so there
  is no idle phase to optimize and no reason to coalesce.
- **`syncContinuously` (`_syncContinuously`)** runs forever, so a per-scope
  request/response *every* cycle is a problem: an idle session would re-announce
  the scope set and emit an `EndOfBatch` per scope on every tick, and would idle
  out once *per scope* (latency growing with scope count). So the continuous
  loop coalesces each cycle into **one combined batch**: the scope announcement,
  per-scope `SinceHlc`s and scope-tagged `MergeChunk`s all ride one batch closed
  by a single `EndOfBatch`, and every frame is emitted only when there is
  something to say. An idle cycle sends nothing and idles out **once**,
  regardless of scope count — the scope-tagged framing and per-scope grouping
  this needs (rejected earlier as throughput-only cost) earn their keep here by
  buying zero idle chatter and constant idle latency, not throughput.

### Protocol frames

`Connect` opens the session once. After that the frames are the same in both
cadences; only *when* they are sent differs (`once`: a fixed sequence per scope;
`continuous`: only on change, inside one combined batch). Frame changes
(regenerated models + a migration on both client and server schemas):

- `CrdtSyncConnect { syncTablesHash }` — sent once by each peer. The schema hash
  is validated once, before any scope work. The scope list and the single
  `localNodeId` both leave `Connect`: the scope set is dynamic and node ids are
  per scope.
- `CrdtSyncScopeSet { scopes: List<CrdtScopeGrant> }` (each grant a
  `scopeUuid` + `role`) — the server's content is authoritative (resolved from
  `crdt_scope_members`, roles included); the client's is informational. In
  `once` it is exchanged exactly once. In `continuous` a peer re-announces it
  **only when its own grant set changed** since the last announcement — this is
  the frame that carries access changes mid-session, and gating it on change is
  what keeps an idle session silent while still letting a grant or revoke take
  effect.
- `CrdtSyncSinceHlc { uuidScopeId, localNodeId, nodeCheckpoints }` — per scope.
  Carries that scope's node id and per-node checkpoints. Exchanged when a scope
  first becomes active (and again if a dropped scope is later re-adopted);
  checkpoints then live in memory for the rest of the session.
- `CrdtSyncMergeChunk { uuidScopeId, changes }` — a chunk tagged with its scope.
  The tag is what lets `continuous` carry every scope's changes in one batch and
  regroup them on receive.
- `CrdtSyncEndOfBatch`, `CrdtSyncClose`, `CrdtSyncIdleTimeout` — unchanged. In
  `once`, `EndOfBatch` terminates the current scope's batch; in `continuous` a
  single `EndOfBatch` terminates the whole cycle's combined batch (and is itself
  omitted when nothing was sent, so the peer idles out instead). `Close`
  terminates a `once` session after its final scope.

`once` uses `collectNextBatch` once per scope visit, exactly as before.
`continuous` uses `_collectCycleBatch`, which demultiplexes one cycle's frames
by type and scope into `{ scopeSet?, sinceHlcs, groups }`, returning on the
single `EndOfBatch` or — when the peer was idle — on the idle timeout.

### The session state machine

```
handshake (both cadences):
  send Connect(syncTablesHash); read peer Connect; validate syncTablesHash

once (_syncOnce) — one bounded round, then close:
  send ScopeSet(myGrants); read peer ScopeSet → reconcile → orderedScopes
  for scope in orderedScopes:
    exchange SinceHlc(scope) → seed nodeCheckpoints[scope]
    collect pending for scope → send MergeChunk(scope)* + EndOfBatch   # send
    read peer batch for scope (collectNextBatch) → mergeInboundBatch   # merge
  send Close; read Close; drain (today's teardown)

continuous (_syncContinuously) — forever, one combined batch per cycle:
  announcedGrants = null; peerGrants = []; sinceHlcSent = {}; checkpoints = {}
  loop:
    resolve activeScopes      (authoritative: my set; follower: adopted peerGrants)
    discard state for scopes no longer active
    # send phase — emit only what changed; track whether any frame was sent
    if myGrants != announcedGrants: send ScopeSet(myGrants)
    for scope in activeScopes not yet sinceHlcSent: send SinceHlc(scope)
    for scope in activeScopes with peer checkpoints: send MergeChunk(scope)*
    if anything was sent: send EndOfBatch
    # receive phase
    batch = collectCycleBatch()         # {scopeSet?, sinceHlcs, groups} | idle | closed
    if closed: return
    adopt batch.scopeSet (follower: project membership); store sinceHlcs;
      mergeInboundBatch each group  (only for authorized scopes)
    delay continuousSyncInterval
```

`collectPendingChanges`, `mergeInboundBatch`, `recordSyncCheckpoint`, and the
ownership-violation internals (`_streamInserts`/`Updates`/`Deletes`,
`_fetchDomainRow`, the durable-violation path) are already scope-parameterized
and are invoked per scope unchanged by both flows. Each scope merges in its own
`transactionForUser`/lock, so scopes do not contend; any scope's merge failure
(for example an ownership collision) records the durable violation and fails the
session, preserving today's fail-fast semantics.

Because `continuous` defers a scope's data until both peers have exchanged its
`SinceHlc`, a newly active scope is established over the **following** cycles
rather than in lockstep — the deliberate trade for keeping the steady state
silent. A peer only honors inbound `SinceHlc`/`MergeChunk` frames for scopes it
authorizes (authoritative: its own membership; follower: the announced set), so
the combined batch tolerates a peer's informational extras without widening
access.

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
  `getOrCreate` (`CrdtScopeManager`) any scope it lacks, ignore any local scope
  the server omitted for this cycle — then `orderedScopes = sort(peer scopeIds)`.

This asymmetry is expressed by a **`CrdtSyncPeerMode` enum**
(`authoritative` / `follower` / `personalOnly`) passed at the call site: the
server endpoint passes `authoritative`, the client driver passes `follower`.
Both sides enumerate membership from the same shared `crdt_scope_members` table
(via `CrdtScopeMembership`), so the only thing the mode varies is the cycle
*direction* — authoritative dictates its own set, follower adopts the peer's.
Once the data is unified, a closed enum is the right shape: there is no
per-role enumeration callback left to inject. Security does not rest on the
enum — a malicious client passing `authoritative` only fails to adopt the
peer's set; writes are still gated server-side by `CrdtScopeMembership.isMember`
against the authoritative table. Frames stay symmetric in *shape* — both carry
`scopes` (the follower's roles null) — exactly as `userId` is already sourced
differently per side today.

In `once`, the client adopts straight from the cycle's `ScopeSet` *before* it
iterates, so a newly granted scope syncs in that same round. In `continuous`,
adoption happens when the announcement arrives and the scope's data follows over
the next cycles once its `SinceHlc` round-trips. Sorting by scope UUID makes the
order deterministic on both sides with no extra negotiation. Frames carry
`uuidScopeId` so a receiver groups each chunk into the right scope and fails loud
on an unauthorized tag rather than merging a batch into the wrong scope.

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

Because the authoritative scope set is re-resolved every cycle and re-announced
whenever it changes (not pinned at `Connect`), a continuous session absorbs
membership changes without reconnecting:

- **Grant.** The server re-announces a `ScopeSet` that includes the new scope;
  the client adopts and materializes it, then handshakes and syncs it over the
  next cycles. (The server detects the grant on its next cycle, so propagation
  is bounded by one idle poll plus the handshake round-trip.)
- **Revoke.** The server re-announces a `ScopeSet` that omits the scope; both
  sides stop cycling it and discard its in-memory checkpoint state, and the
  follower's `projectFollowerMembership` deletes its members-table row. The
  device still *holds* the revoked scope's rows; purging them (and the fate of
  any unsynced local changes) is the deferred revocation question, not a
  sync-loop concern.

The authoritative peer originates every set change, so both sides converge on
the same active set from the same announcement and stay in step across it. A
one-shot `syncOnce` captures the set once; the next `syncOnce` call picks up any
change.

## Transaction API

`transactionForUser` keeps its name and user-first semantics and gains an
optional scope:

```dart
db.transactionForUser(userId, fn);                  // acts in the personal scope
db.transactionForUser(userId, fn, scopeId: listId); // acts in a shared scope
```

- Without `scopeId`, the scope resolves to the user's personal scope —
  `userId` itself by convention — which is exactly today's behavior.
- With `scopeId`, the package asserts membership before acting by calling
  `CrdtScopeMembership.isMember` directly against the shared table — no injected
  validator. On the server that table is authoritative; a persistent client
  whose copy is empty falls back to "holds the scope locally" for offline UX,
  and the server remains the security boundary and re-verifies on sync.
- A transaction acts in **exactly one** scope (constraint 5). The write path —
  stamp-or-assert, the scoped `WHERE`, `scopeId` immutability — is unchanged
  beyond which scope is resolved.

## Read path: membership-wide

A user-scoped read in a sharing world means "rows in any scope I am a member
of". The single-scope resolver becomes a set:

- `mergeWhereWithTombstone` isolates scoped reads with `scopeId IN (<member
  scope ids>)` through `CrdtScopeIdsResolver`. For writes, the resolver supplies
  the single acting scope. For reads, non-persistent (server) sessions resolve
  the set from `CrdtScopeMembership.memberScopes`; persistent clients use their
  local `crdt_scopes` rows; unscoped admin reads still pass no scope filter.
- The visibility probe is the row-keyed form for the multi-scope case, so
  sharing simplifies the predicate matrix rather than growing it: reads differ
  only in their membership filter (one scope, a user's scopes, or none for
  admin).
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

## Implementation status

The implementation landed in independently green phases. Tests should continue
to run with `--concurrency=1`.

- **Phase 1 — membership foundation.** Implemented `crdt_scope_members`
  (`database: all`, unsynced) and its migration. Added the shared
  `CrdtScopeMembership` helpers (`memberScopes` / `isMember`). No behavior change
  yet: a personal-scope-only set reproduces today's single-scope sync exactly.
- **Phase 2 — sequential multi-scope sync (the requirement).** Implemented
  protocol model
  changes (`Connect` minus `scopeIds`/`localNodeId`, new per-cycle
  `CrdtSyncScopeSet`, per-scope `SinceHlc`, `MergeChunk.uuidScopeId`) plus
  generate/migrate. Outer cycle loop in `CrdtSync.sync` with per-cycle
  `ScopeSet` exchange, per-scope handshake-on-first-visit, in-memory per-scope
  checkpoints, and the once/continuous cadence. Reconciliation via a
  `CrdtSyncPeerMode` enum: the server endpoint passes `authoritative` (cycles
  `CrdtScopeMembership.memberScopes`); the client driver passes `follower`
  (adopts the server's set). Scope-aware `onMergeSuccess`. A personal-scope-only
  device behaves identically to today.
- **Phase 3 — transaction API.** Implemented
  `transactionForUser(userId, fn, {scopeId})` with the membership assertion;
  one scope per transaction.
- **Phase 4 — membership-wide reads.** Implemented the scoped read filter as
  `scopeId IN (…)` over the user's member scopes.
- **Phase 5 — lifecycle and docs.** Documented client adoption of newly
  announced shares; reconcile with the scope-purge semantics in
  `sync-non-sync-relations.md`.
  Revocation cleanup and roles are deferred (see *Follow-ups*).
- **Phase 6 — idle-silent continuous loop.** Split the cadences:
  `_syncOnce` keeps Phase 2's per-scope round; `_syncContinuously` coalesces each
  cycle into one combined, scope-tagged batch terminated by a single
  `EndOfBatch`, sends `ScopeSet`/`SinceHlc`/`MergeChunk` only on change, and
  reads via `_collectCycleBatch`. An idle continuous session now sends zero
  frames and idles out once per cycle regardless of scope count (Phase 2's outer
  loop re-announced the set and an `EndOfBatch` per scope every tick). A scope's
  data is deferred until its `SinceHlc` round-trips, and inbound frames are
  honored only for authorized scopes.

## Test plan

Because no code branches on scope count or deployment role, mechanisms are
tested once, not per combination.

- **Regression.** Every existing single-scope suite passes unchanged on the
  personal-scope-only path.
- **Protocol.** `Connect`/`SinceHlc` round-trip a multi-scope list; merge chunks
  route to the correct scope by `uuidScopeId`; per-scope checkpoints advance
  independently across cycles.
- **One call, every scope.** A single `syncOnce` converges N scopes in one pass;
  a continuous session keeps cycling. `syncOnce` holds only one scope's pending
  changes at a time; the continuous receive groups a cycle's inbound chunks by
  scope before merging.
- **Idle silence.** A continuous session with no pending changes settles and then
  emits no further frames — neither peer re-announces the scope set nor sends an
  `EndOfBatch` while idle.
- **Membership.** The server syncs personal + shared scopes; a client-announced
  non-member scope is refused and never streamed; a newly granted scope is
  adopted and syncs within the same `syncOnce` call.
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

- **Sequential vs. multiplexed sync:** merges serialize regardless, so
  multiplexing never buys *throughput*. `syncOnce` therefore stays sequential,
  one scope per turn, reusing the per-scope state machine. `syncContinuously`
  does coalesce each cycle's scopes into one scope-tagged batch — not for
  throughput but to keep an idle session silent and its idle latency constant
  in scope count (a per-scope round every tick cannot).
- **Membership authority:** the server, from `crdt_scope_members`. The
  reconciliation is directional — server dictates, client conforms — and is
  neither union (insecure) nor intersection (cannot adopt). It is a
  **`CrdtSyncPeerMode` enum** (`authoritative` / `follower` / `personalOnly`):
  with the table shared, both sides enumerate via the same `CrdtScopeMembership`
  query, so the only residual variation is cycle direction — a closed enum, not
  a callback. The enum is not the security boundary; server-side
  `CrdtScopeMembership.isMember` gates every applied write regardless of the
  client's declared mode. Frames stay symmetric in shape; only the values and
  the dictate-vs-conform behavior differ, as `userId` already does.
- **Scope set is dynamic, not pinned at connect:** the authoritative peer
  re-resolves its set every cycle and re-announces a `ScopeSet` whenever it
  changed, so grants and revokes take effect mid-session without reconnecting.
  In `syncOnce` the client adopts from the round's `ScopeSet` before iterating,
  so a grant syncs in that same round; in `syncContinuously` a newly announced
  scope is adopted then established over the next cycles as its `SinceHlc`
  round-trips.
- **Members vs. nodes:** orthogonal layers, both kept. Members are authorization
  (`who`); nodes are CRDT causality (`whose changes, up to which HLC`). One
  member maps to many nodes; the server is a node but not a member; a new member
  has no node until first sync.
- **Client membership table:** `database: all` puts the table on the client,
  populated as a read-only projection. The `CrdtSyncScopeSet` carries
  `CrdtScopeGrant`s (`scopeUuid` + `role`), and each follower cycle reconciles
  the local table from the announcement (upsert granted, delete revoked; only
  when the set changed). The client's `crdt_scopes` still drives gating; the
  members table adds roles for UI and future offline role-gated writes. It is a
  server-authored, client-read-only projection — never a bidirectionally-synced
  members table, so a client cannot self-grant.
- **Iteration order:** sorted scope UUIDs, so both peers stay in lockstep
  without negotiation. Frames are still scope-tagged to fail loud on desync.
- **One scope per transaction:** kept. Cross-scope writes need separate
  transactions; remote replicas cannot observe a cross-scope write atomically
  anyway.
- **Membership table is `database: all` but unsynced:** the schema exists on
  every node, yet it is server-authoritative app state, never CRDT-replicated.
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
2. **Roles within a scope.** `crdt_scope_members.role` is now **propagated** to
   the client (the follower projection carries it), but still **unenforced**.
   Read-only members would need write rejection at merge time (another
   fail-and-record case) and a client-side check that consults the projected
   role to reject writes offline (the datum is now present — see *The client
   membership table*), which overlaps with revocation of offline-written changes
   by a demoted member. (Carried from `row-ownership.md` open question 4.)
