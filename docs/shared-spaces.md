# Shared spaces

Status: implemented. This records the shared-space behavior built on top of
the row-ownership work in `row-ownership.md`. Revocation cleanup is still a
deferred follow-up; where the ownership summary and this document differ, this
one wins.

## Summary

A user is an authentication identity; a space is the unit of replication and
ownership. Each user has a personal space and may also belong to any number of
shared spaces. The load-bearing
requirement is:

> **A single `sync` call syncs every space the authenticated user has access
> to.** One `syncOnce` cycles through all accessible spaces exactly once; a
> continuous session keeps cycling forever. There is no separate stream or
> separate call per space.

The row-ownership work keys storage, locking, HLC chains, visibility, and
ownership by **space**, not user, so sharing is an indirection in front of
`offline_sync_spaces`, not a re-architecture. The implemented pieces are a server-side
membership relation and a sync protocol that iterates spaces.

> **Merges serialize one space at a time.** A merge runs in exactly one space's
> transaction and lock, so spaces always serialize on the merge step regardless
> of framing. A cycle's outbound changes are instead collected in a single pass
> over the active spaces and carried in one combined batch, each change tagged
> with its `uuidSpaceId`; the receiver regroups by space and merges each group
> in its own transaction. The wire stays a near-verbatim repetition of today's
> frames, now space-tagged.

> **The server is the authority on membership; the client follows.** The set of
> spaces a session syncs is computed server-side from `offline_sync_space_members` and
> re-resolved at the start of every sync cycle, so access changes take effect
> mid-session. The server dictates the set; the client adopts spaces it
> announces and stops cycling the ones it omits. The reconciliation is
> directional — not a set operation toggled by a flag — and membership itself is
> never synced. Local data cleanup for omitted spaces is a separate revocation
> policy, not part of the sync loop.

> **Row ownership is unchanged.** Every row still has exactly one owning
> `spaceId`, `(table, uuidRowId)` stays globally identified, and every
> enforcement rule in `row-ownership.md` survives untouched. Sharing adds a
> membership layer in front of spaces; it does not touch row ownership.

## Goals and constraints

1. **One call, every space.** The public client API (`syncOnce`,
   `syncContinuously`) does not change shape: callers pass a session, never a
   space. A device with only a personal space behaves exactly as today.
2. **Smallest protocol delta.** The exchanged frames are today's, plus a
   per-cycle space-set exchange and a space tag on each frame. `collectNextBatch`
   demultiplexes a cycle's combined batch, `collectPendingChanges` collects every
   active space in one pass, and the per-space merge plus `recordSyncCheckpoint`
   run once per inbound space group.
3. **Chunked streaming.** Outbound changes are collected in a single pass over
   the active spaces and streamed in `syncBatchSize` chunks, so the wire payload
   stays bounded regardless of space count. The collection step itself
   materializes a cycle's pending rows across the active spaces (one
   `spaceId IN (…)` query per change kind), so peak memory tracks a cycle's
   pending rows rather than being held strictly one space at a time. See
   `outbound-collection-consistency.md`.
4. **Membership cannot be forged.** The server computes its own space set from
   `offline_sync_space_members` (plus the implicit personal space) and never widens it
   from anything the client sends. A space the user is not a member of is never
   synced, even if the client names it.
5. **One space per transaction.** Reads are membership-wide; writes stay pinned
   to exactly one space. This is deliberate honesty about CRDT semantics: two
   spaces' chains replicate independently and a remote replica can never
   observe a cross-space write atomically.
6. **Roles are closed CRDT access roles.** The package stores and projects
   non-null `OfflineSyncSpaceRole` values in space grants and shared memberships:
   `readWrite` allows CRDT writes and `readOnly` blocks them. The implicit
   personal space is announced as a `readWrite` grant, so single-tenant servers
   and multi-account devices remain the same code path with different space
   counts.

## Membership

### The `offline_sync_space_members` table

```yaml
class: OfflineSyncSpaceMember
table: offline_sync_space_members
database: all
fields:
  space: OfflineSyncSpace?, relation(onDelete=Cascade)
  userUuid: UuidValue
  role: OfflineSyncSpaceRole
indexes:
  offline_sync_space_member_unique_idx:
    fields: userUuid, spaceId
    unique: true
```

- The table is **`database: all`** but **not** in `syncTables`. It exists on
  every node so membership resolves with the same code on both ends, but it is
  never CRDT-replicated by this package. The server is the authoritative writer;
  a client copy (once populated) is a read-only cache for UI and offline role
  checks — see *The client membership table*.
- The index **leads with `userUuid`** so the per-cycle `WHERE userUuid = ?`
  resolution is index-covered.
- Rows are managed through `session.offlineSync.spaces` (`OfflineSyncSpaces`). Invitations,
  acceptance, and authorization policy remain app domain.
- **Personal-space membership is implicit.** By convention a user's personal
  space has the user's own UUID (already true: the space UUID keys the chain),
  so no `offline_sync_space_members` row is stored for it. Shared spaces are
  `offline_sync_spaces` rows whose UUID is no user's id, with explicit membership rows.
- `role` is a required CRDT access enum. Shared memberships always store an
  explicit role: `readWrite` allows writes, while `readOnly` denies
  shared-space writes.

### Read transaction visibility

Space-scoped ORM reads cache personal and shared space IDs in the database context.
Before reusing an entry, a transaction reads and share-locks the singleton
`offline_sync_space_cache_versions` row. Its database UUID and revision identify the
committed membership state across sessions and server processes. Subsequent
reads in that transaction reuse the resolved IDs without another membership
query. Standalone space-scoped reads open a transaction for the complete query.

Space and membership mutations through the CRDT database wrapper take an
exclusive lock on that row and advance its revision atomically. Each transaction
keeps private cache entries after a mutation and publishes them only after the
database commits. Cancellation, failures and savepoint rollback discard private
changes; savepoint release retains them until the enclosing transaction commits.
Transactions created outside the wrapper resolve memberships without caching.

Readers can share the lock and ordinary domain writes remain concurrent. A
membership writer waits for active readers; new readers wait for a writer.
PostgreSQL domain reads still follow the caller's isolation setting. Transactions
that read before changing membership can encounter a lock-upgrade deadlock;
PostgreSQL aborts a participant and the caller can retry the whole transaction.
The wrapper does not replay application callbacks. Prefer changing membership
before space-scoped reads within a transaction and keep membership transactions short.

Every process that changes spaces or memberships must use the wrapper's ORM
operations, including generated insert, update, upsert and delete variants.
Direct SQL or a database connection that bypasses the wrapper does not advance
the cache revision. The coordination row is internal, local database state and
is not replicated through CRDT. Shared-space write-role checks and sync-cycle
membership resolution continue to read authoritative membership rows.

### Members vs. nodes

`offline_sync_space_members` and the `nodes` list on a space are orthogonal layers and
both stay:

- A **member** is an authorization fact: a user identity allowed to access a
  space. It answers *who may sync, read, and write*.
- A **node** (`crdt_nodes`) is a stable CRDT replica identity. A space's
  `nodes` relation points at `offline_sync_space_nodes`, which records that replica's
  participation and checkpoint state in that space. Together they answer
  *whose changes, up to which HLC* and are what per-`(space, node)` checkpoints
  key on.

They do not map one-to-one and neither replaces the other. One member may have
many nodes (one per replica/database install). The **server is a node** in every
space it syncs but is not a member row. A freshly invited member has **zero
space-node rows** until their first device syncs. Nodes and space-node rows are
created implicitly by sync (`getOrCreate`, `recordSyncCheckpoint`); membership
rows are managed through `session.offlineSync.spaces` from application endpoints.
Removing the `nodes` list would break checkpointing and causal filtering — it is
the chain topology, not the access list.

### The client membership table

`offline_sync_space_members` is `database: all`, so the table exists on the client and
is **populated as a read-only projection** of the server's authoritative grants
— without being bidirectionally CRDT-synced:

- The client's projected `offline_sync_space_members` rows plus the implicit personal
  space are its membership view for *membership gating*: a membership-wide read
  filters over projected membership, and a local `offline_sync_spaces` row by itself
  does not grant access. The members table also carries **roles**, which the
  client consults before local writes.
- The authoritative `OfflineSyncSpaceSet` carries `OfflineSyncSpaceGrant`s — `(uuidSpaceId,
  role)` — not bare UUIDs. Every grant has an explicit role; the personal space
  is announced as `readWrite` but remains implicit in storage. When the follower
  *receives* an announcement, `projectFollowerMembership` reconciles the local
  table from it: upsert a row per shared grant (the personal space is skipped),
  delete rows whose space is no longer granted. Since the authoritative peer
  announces only when its grants change, projection runs only on change and an
  idle session writes nothing.
- This is a **server-authored, client-read-only projection**, never a synced
  members table: the client never writes membership the server reads, so it
  cannot self-grant. The server stays the security boundary and re-verifies on
  sync.
- A revoke takes effect for sync as soon as the server omits the space from a
  cycle's `SpaceSet`: the client stops cycling it and discards in-memory
  checkpoint state for it. The space row and domain rows may remain stored
  locally until the deferred revocation cleanup policy decides whether to purge
  or keep them, but membership-wide reads stop returning those rows.
- Writes are bounded by projected membership and by the projected role. They are
  re-verified by the server on sync, which remains the security boundary.
  Client-side checks are early-failure UX, not the enforcement point.

### Role write access

The package exposes a closed CRDT access role enum rather than free-form role
strings:

```dart
enum OfflineSyncSpaceRole {
  readOnly,
  readWrite,
}
```

Only `readWrite` allows writes. `readOnly` denies writes. The implicit personal
space has no stored membership row, but its authoritative grant and role lookup
resolve to `readWrite`.

Roles gate **writes only**. Reads stay membership-wide and role-independent.
The authoritative server enforces role writes before applying inbound changes:
for each accepted inbound space group, it resolves the authenticated user's
role from `offline_sync_space_members`; if the role is not `readWrite`, the server
records `OfflineSyncIntegrityViolation(type: unauthorizedWrite)` and fails the
sync session before opening the merge transaction for that space. The rejected
change is not applied and checkpoints do not advance past it.

The client uses the same enum as early UX: `transactionForUser(userId, fn,
spaceId: sharedSpace)` resolves the projected role and throws
`OfflineSyncSpaceRoleException` before any local write when the role cannot write. A
follower also omits non-writable shared spaces from outbound pending-change
collection while still receiving inbound changes for those spaces. This avoids
repeatedly streaming local read-only changes; the server enforcement remains the
security boundary for stale, misconfigured, or hostile clients.

### Space enumeration (server is the authority)

At the start of each sync cycle the server resolves the authoritative set:

```
memberGrants(userUuid) =
    { personal space = userUuid, role = readWrite }
  ∪ { (s.uuidSpaceId, m.role)
      : offline_sync_space_members m
        join offline_sync_spaces s on s.id = m.spaceId
        where m.userUuid = <auth user> }
```

This grant set bounds everything the cycle may sync and carries the role used by
followers for outbound filtering. The client never expands it; it only learns of
additions through what the server announces.

## Sync: one call syncs every accessible space

### One `sync`, two cadences: bounded `once`, idle-silent `continuous`

Merge is inherently one space at a time: a merge runs in exactly one space's
transaction and lock, so the spaces always serialize regardless of framing. A
single `sync` method serves both `syncOnce` and `syncContinuously`, branching on
`once` only where they genuinely differ — read discipline and termination — so
there is no duplicated send/merge logic:

1. **Establishment (shared, lockstep).** After `Connect`, both peers exchange the
   `SpaceSet`. Doing this *before* the loop is what removes the announce/adopt
   offset that would otherwise make a follower act before it knows the agreed
   set.
2. **Data loop (shared, idle-silent).** Each cycle is **one combined batch**: the
   space announcement (only when this peer's grants changed), a `SinceHlc` for
   each newly active space, and merge chunks whose changes carry their space,
   all closed by a single `EndOfBatch`. Continuous mode omits the terminator when
   nothing was sent. The receive phase demultiplexes the peer's batch by type
   until that terminator or — when the peer was idle — an idle timeout. An idle
   continuous cycle therefore sends nothing and idles out **once**, regardless of
   space count.

`once` stays in the data loop until every active space has exchanged `SinceHlc`
and had one sendable data cycle, then performs the symmetric `Close` handshake.
`continuous` loops instead, with no per-cycle chatter; it handshakes its initial
spaces in the first cycle and absorbs membership changes as they are announced
(a newly granted space is announced, adopted, and established over the following
cycles — its data deferred until its `SinceHlc` round-trips).

### Protocol frames

`Connect` opens the session once. After that the frames are the same in both
cadences; only *when* they are sent differs (`once`: a fixed sequence per space;
`continuous`: only on change, inside one combined batch). Frame changes
(regenerated models + a migration on both client and server schemas):

- `OfflineSyncConnect { syncTablesHash, localNodeId }` — sent once by each peer. The
  schema hash is validated once, before any space work. `localNodeId` identifies
  this peer's CRDT node for the whole session. The space list is dynamic and
  exchanged per cycle.
- `OfflineSyncSpaceSet { spaces: List<OfflineSyncSpaceGrant> }` (each grant a
  `uuidSpaceId` + `role`) — the server's content is authoritative (resolved from
  `offline_sync_space_members`, roles included). Followers send an empty set because the
  authoritative peer never widens access from follower-reported state. In `once`
  it is exchanged exactly once. In `continuous` a peer re-announces it
  **only when its own grant set changed** since the last announcement — this is
  the frame that carries access changes mid-session, and gating it on change is
  what keeps an idle session silent while still letting a grant or revoke take
  effect.
- `OfflineSyncSinceHlc { uuidSpaceId, nodeCheckpoints }` — per space. Carries that
  space's per-node checkpoints. Exchanged when a space first becomes active
  (and again if a dropped space is later re-adopted);
  checkpoints then live in memory for the rest of the session.
- `OfflineSyncMergeChunk { changes }` — each change carries `uuidSpaceId`, letting
  a combined batch carry every space's changes and regroup them on receive.
- `OfflineSyncEndOfBatch`, `OfflineSyncClose`, `OfflineSyncIdleTimeout` — unchanged. A
  single `EndOfBatch` terminates a cycle's combined batch (and is itself omitted
  when nothing was sent, so an idle peer resolves to an empty batch instead).
  `Close` ends the streaming session. Because it is an intentional peer control
  frame, it may arrive even after frames for a partial cycle; the receiver
  discards that partial cycle and records no checkpoint progress for it.

The data cycle's receive uses `collectNextBatch`, which demultiplexes one
cycle's frames by type into `{ spaceSet?, sinceHlcs, changes }`,
returning on the single `EndOfBatch`, on `Close` with a closed result, or —
when the peer was idle — on the idle timeout. A raw transport close without a
`Close` frame is stricter: it is graceful only between continuous-session
batches and is treated as truncation once a partial batch has arrived.

### The session state machine

```
handshake (both cadences):
  send Connect(syncTablesHash, localNodeId); read peer Connect; validate
  syncTablesHash; store peer localNodeId

establishment (both cadences, lockstep):
  send SpaceSet(myGrants); read peer SpaceSet → adopt → activeSpaces
  follower: materialize activeSpaces, project membership
data loop (both cadences, one combined batch per cycle):
  loop:
    resolve activeSpaces      (authoritative: my set; follower: adopted peerGrants)
    discard state for spaces no longer active
    # send phase — emit only what changed; track whether any frame was sent
    if myGrants != announcedGrants: send SpaceSet(myGrants)
    for space in activeSpaces not yet sinceHlcSent: send SinceHlc(space)
    if peer checkpoints exist: send MergeChunk(changes)*  # follower skips non-writable spaces
    if anything was sent (or once): send EndOfBatch
    # receive phase
    batch = collectNextBatch(allowCloseBeforeBatch: !once)   # {spaceSet?, sinceHlcs, changes} | idle | closed
    if closed: return
    adopt batch.spaceSet (follower: materialize + project); store sinceHlcs;
      group changes by uuidSpaceId; mergeInboundBatch each group
    if once: send Close; read Close; drain; return
    delay continuousSyncInterval
```

The shared establishment exchanges the space set so a follower never acts before
it knows the agreed set. Both cadences handshake initial and newly added spaces
through the loop's own `SinceHlc` exchange.

`collectPendingChanges`, `mergeInboundBatch`, `recordSyncCheckpoint`, and the
ownership-violation internals (`_streamInserts`/`Updates`/`Deletes`,
`_fetchDomainRow`, the durable-violation path) are space-parameterized and merge
each inbound space group in its own `transactionForUser`/lock; any space's merge
failure (for example an ownership collision or unauthorized role write) records
the durable violation and fails the session, preserving today's fail-fast
semantics.

Because `continuous` defers a space's data until both peers have exchanged its
`SinceHlc`, a newly active space is established over the **following** cycles
rather than in lockstep — the deliberate trade for keeping the steady state
silent. A peer only honors inbound `SinceHlc`/`MergeChunk` frames for spaces it
authorizes (authoritative: its own membership; follower: the announced set), so
the combined batch tolerates a peer's informational extras without widening
access.

`onMergeSuccess` becomes space-aware: `Function(UuidValue spaceUuid, Hlc hlc)`.
This touches three test call sites and the example app's `demo_controller`.

### Space-set reconciliation and lockstep

Both peers must cycle the **same ordered space set** or send/receive desyncs.
Membership is asymmetric — the client trusts the server's membership claims, the
server trusts none of the client's — so the reconciliation is **directional**,
not a symmetric set operation:

- **Union is wrong** (insecure): a client could name a space the user is not a
  member of and force the server to sync it.
- **Intersection is wrong** (cannot adopt): a brand-new share is not in the
  client's set yet, so it would never enter the intersection and never sync —
  the client cannot hold what it has not synced, and cannot sync what it does
  not hold.

The correct operation is neither: **the server dictates its set; the client
conforms.** Each cycle:

- **Server**: `orderedSpaces = sort(memberGrants(userUuid).uuidSpaceId)`,
  computed from `offline_sync_space_members` plus the implicit personal grant. It never
  reads the client's `SpaceSet` for authority (constraint 4).
- **Client**: takes the server's `SpaceSet` as the set to cycle —
  `getOrCreate` (`OfflineSyncSpaceManager`) any space it lacks, ignore any local space
  the server omitted for this cycle — then `orderedSpaces = sort(peer spaceIds)`.

This asymmetry is expressed by a **`OfflineSyncPeerMode` enum**
(`authoritative` / `follower`) passed at the call site: the server endpoint
passes `authoritative`, the client driver passes `follower`. Membership is
resolved from the same shared `offline_sync_space_members` table (via
`OfflineSyncSpaceMembership`); the mode varies only the cycle *direction* —
authoritative dictates its own set, follower adopts the peer's.
Once the data is unified, a closed enum is the right shape: there is no
per-role enumeration callback left to inject. Security does not rest on the
enum — a malicious client passing `authoritative` only fails to adopt the
peer's set; writes are still gated server-side by
`OfflineSyncSpaceMembership.roleOf(...).canWrite` against the authoritative table.

In `once`, the client adopts straight from the cycle's `SpaceSet` *before* it
iterates, so a newly granted space syncs in that same round. In `continuous`,
adoption happens when the announcement arrives and the space's data follows over
the next cycles once its `SinceHlc` round-trips. Sorting by space UUID makes the
order deterministic on both sides with no extra negotiation. Frames carry
`uuidSpaceId` so a receiver groups each chunk into the right space and fails loud
on an unauthorized tag rather than merging a batch into the wrong space.

Re-resolving `memberGrants` every cycle is an indexed `offline_sync_space_members`
lookup on the server only; it may be throttled or invalidated by an
application hook if per-cycle querying becomes hot, at the cost of slower
propagation of access changes.

### Checkpoints, once vs. continuous

Checkpoint rows stay per `(space, node)` in `offline_sync_space_nodes`, while
`crdt_nodes` stores the stable replica identity. The same local replica node can
participate in multiple spaces, with separate `lastReceivedHlc` values per
space. `SinceHlc` is exchanged once per space on first visit; later cycles reuse
the in-memory
`nodeCheckpoints[space]`, advanced as chunks are sent and as inbound batches
merge — the multi-space analogue of today's single-space continuous loop, which
already keeps checkpoints in memory across rounds.

The continuous interval delay moves to **after each full cycle**, not after each
space, to keep per-space latency low while still preventing a busy loop when
idle.

### Access changes during a session

Because the authoritative space set is re-resolved every cycle and re-announced
whenever it changes (not pinned at `Connect`), a continuous session absorbs
membership changes without reconnecting:

- **Grant.** The server re-announces a `SpaceSet` that includes the new space;
  the client adopts and materializes it, then handshakes and syncs it over the
  next cycles. (The server detects the grant on its next cycle, so propagation
  is bounded by one idle poll plus the handshake round-trip.)
- **Revoke.** The server re-announces a `SpaceSet` that omits the space; both
  sides stop cycling it and discard its in-memory checkpoint state, and the
  follower's `projectFollowerMembership` deletes its members-table row. The
  device can still store the revoked space's rows locally, but membership-wide
  reads no longer return them. Purging stored rows (and the fate of any unsynced
  local changes) is the deferred revocation question, not a sync-loop concern.
- **Demote.** The server re-announces the same space with a different role; the
  follower projection updates the cached role. The next local write consults
  the new role and fails early if it is read-only. Pending local changes already
  authored before demotion are not silently applied by the server: if streamed,
  they are rejected and recorded as `unauthorizedWrite`. Whether the client
  purges, surfaces, or keeps skipped pending changes is part of the deferred
  revocation-cleanup design.

The authoritative peer originates every set change, so both sides converge on
the same active set from the same announcement and stay in step across it. A
one-shot `syncOnce` captures the set once; the next `syncOnce` call picks up any
change.

## Transaction API

`transactionForUser` keeps its name and user-first semantics and gains an
optional space:

```dart
db.transactionForUser(userId, fn);                  // acts in the personal space
db.transactionForUser(userId, fn, spaceId: listId); // acts in a shared space
```

- Without `spaceId`, the space resolves to the user's personal space —
  `userId` itself by convention — which is exactly today's behavior.
- With `spaceId`, the package resolves the member role with
  `OfflineSyncSpaceMembership.roleOf` — no injected validator. On the server that table
  is authoritative; on a persistent client it is the server-projected membership
  cache. A missing role throws `OfflineSyncSpaceMembershipException`; anything other
  than `readWrite` throws `OfflineSyncSpaceRoleException` before the transaction starts.
- A transaction acts in **exactly one** space (constraint 5). The write path —
  stamp-or-assert, the space-scoped `WHERE`, `spaceId` immutability — is unchanged
  beyond which space is resolved.

## Read path: membership-wide

A user-space-scoped read in a sharing world means "rows in any space I am a member
of". The single-space resolver becomes a set:

- `mergeWhereWithTombstone` isolates space-scoped reads with `spaceId IN (<member
  space ids>)` through `OfflineSyncSpaceIdsResolver`. For writes, the resolver supplies
  the single acting space. For reads, both server sessions and persistent
  clients resolve the set from `OfflineSyncSpaceMembership.memberSpaces`
  (authoritative on the server, projected on the client); unscoped admin reads
  still pass no space filter.
- The visibility probe is the row-keyed form for the multi-space case, so
  sharing simplifies the predicate matrix rather than growing it: reads differ
  only in their membership filter (one space, a user's spaces, or none for
  admin).
- This is the shape of a Postgres row-level-security policy
  (`spaceId IN (SELECT spaceId FROM offline_sync_space_members WHERE userUuid = …)`); the
  package's application-level filter and RLS become two enforcements of one
  predicate.

Writes stay space-pinned (above); only reads widen.

## What sharing does not change

Every enforcement rule in `row-ownership.md` survives unchanged:
`(table, uuidRowId)` stays globally identified; rows have exactly one owning
space; merge-insert ownership checks compare spaces; unique conflict groups form
within a space; ordinary global unique indexes stay rejected; stamp-or-assert
applies with the transaction's resolved space; the durable
`offline_sync_integrity_violations` contract now also records unauthorized role
writes. The merge, FK, and unique engines already key on the space the merge
runs in and need no ownership changes for sharing.

## Implementation status

The implementation landed in independently green phases. Tests should continue
to run with `--concurrency=1`.

- **Phase 1 — membership foundation.** Implemented `offline_sync_space_members`
  (`database: all`, unsynced) and its migration. Added the shared
  `OfflineSyncSpaceMembership` helpers (`memberGrants`, `memberSpaces`, `roleOf`,
  `isMember`, and the follower projection path). No behavior change yet: a
  personal-space-only set reproduces today's single-space sync exactly.
- **Phase 2 — sequential multi-space sync (the requirement).** Implemented
  protocol model
  changes (`Connect` with session `localNodeId`, new per-cycle
  `OfflineSyncSpaceSet`, per-space `SinceHlc`, `MergeChunk.uuidSpaceId`) plus
  generate/migrate. Outer cycle loop in `OfflineSyncEngine.sync` with per-cycle
  `SpaceSet` exchange with role-carrying `OfflineSyncSpaceGrant`s, per-space
  handshake-on-first-visit, in-memory per-space checkpoints, and the
  once/continuous cadence. Reconciliation via a
  `OfflineSyncPeerMode` enum: the server endpoint passes `authoritative` (cycles
  `OfflineSyncSpaceMembership.memberGrants`); the client driver passes `follower`
  (adopts the server's set). Space-aware `onMergeSuccess`. A personal-space-only
  device behaves identically to today.
- **Phase 3 — transaction API.** Implemented
  `transactionForUser(userId, fn, {spaceId})` with the membership assertion;
  one space per transaction.
- **Phase 4 — membership-wide reads.** Implemented the space-scoped read filter as
  `spaceId IN (…)` over the user's member spaces.
- **Phase 5 — lifecycle and docs.** Documented client adoption of newly
  announced shares; reconcile with the space-purge semantics in
  `sync-non-sync-relations.md`.
  Revocation cleanup is deferred (see *Follow-ups*).
- **Phase 6 — idle-silent sync, one method.** Reworked the single `sync` method
  (no separate once/continuous bodies) into a shared lockstep establishment plus
  a shared combined data loop: each cycle coalesces into one space-scoped-change batch
  terminated by a single `EndOfBatch`, with `SpaceSet`/`SinceHlc`/`MergeChunk`
  sent only on change and read via `collectNextBatch`. An idle continuous
  session now sends zero frames and idles out once per cycle regardless of space
  count (Phase 2's loop re-announced the set and an `EndOfBatch` per space every
  tick). `once` runs one data cycle then closes; mid-session continuous spaces are
  deferred until their `SinceHlc` round-trips, and inbound frames are honored
  only for authorized spaces.
- **Phase 7 — roles within a space.** Implemented the closed
  `OfflineSyncSpaceRole` enum (`readOnly`, `readWrite`) on server and client.
  `readWrite` is the only shared-space write grant. Added authoritative inbound
  enforcement that records
  `unauthorizedWrite` and fails before merge, client-side
  `OfflineSyncSpaceRoleException` early rejection, and follower outbound skipping for
  non-writable shared spaces while reads remain membership-wide.
- **Phase 8 — space management service.** Implemented the server-side
  `session.offlineSync.spaces` service (`create`, `createFor`, `grant`, `grantAll`,
  `revoke`, `members`) with transaction/savepoint threading. Single grants reuse
  the bulk-grant path; unknown-space grants throw `OfflineSyncSpaceNotFoundException`.
  Invitations, acceptance, and authorization policy stay in app endpoints.

## Test plan

Because no code branches on space count or deployment role, mechanisms are
tested once, not per combination.

- **Regression.** Every existing single-space suite passes unchanged on the
  personal-space-only path.
- **Protocol.** `Connect`/`SinceHlc` round-trip a multi-space list; merge chunks
  route to the correct space by `uuidSpaceId`; per-space checkpoints advance
  independently across cycles.
- **One call, every space.** A single `syncOnce` converges N spaces in one pass;
  a continuous session keeps cycling. Outbound changes for the active spaces are
  collected in one pass and streamed in `syncBatchSize` chunks; the receive
  groups a cycle's inbound chunks by space before merging each in its own
  transaction.
- **Idle silence.** A continuous session with no pending changes settles and then
  emits no further frames — neither peer re-announces the space set nor sends an
  `EndOfBatch` while idle.
- **Membership.** The server syncs personal + shared spaces; a client-announced
  non-member space is refused and never streamed; a newly granted space is
  adopted and syncs within the same `syncOnce` call.
- **Roles.** `readOnly` can still read shared rows, local writes fail before
  mutation, `readWrite` syncs normally, a follower skips outbound pending changes
  for non-writable spaces while still receiving inbound changes, and a stale or
  hostile client write is rejected and recorded by the server as
  `unauthorizedWrite`. Personal spaces remain writable through their implicit
  `readWrite` grant.
- **Access changes mid-session.** During a continuous session, a grant added to
  `offline_sync_space_members` appears and syncs on the next cycle; a revoke stops
  cycling that space without dropping the session.
- **Isolation under sharing.** Two users sharing space X both converge on X
  while their personal spaces stay isolated; an ownership collision in one space
  records a durable violation and fails the session without corrupting another
  space's merge.
- **Smoke.** One `withServerpod` round-trip with one personal plus one shared
  space, proving the end-to-end wiring (mirrors `sync_flow_test.dart`).

## Resolved during review

- **Combined sync batch:** merges serialize regardless, so combining spaces is
  not a throughput optimization. Both cadences use the same combined batch shape:
  each change carries its `uuidSpaceId`, and receive groups changes by space
  before merging each space group. Continuous mode omits idle frames so idle
  latency is constant in space count.
- **Membership authority:** the server, from `offline_sync_space_members`. The
  reconciliation is directional — server dictates, client conforms — and is
  neither union (insecure) nor intersection (cannot adopt). It is a
  **`OfflineSyncPeerMode` enum** (`authoritative` / `follower`): membership still
  resolves through `OfflineSyncSpaceMembership`, so the only residual variation is
  cycle direction — a closed enum, not a callback. The enum is not the security
  boundary; server-side
  `OfflineSyncSpaceMembership.roleOf(...).canWrite` gates every applied write
  regardless of the client's declared mode.
- **Space set is dynamic, not pinned at connect:** the authoritative peer
  re-resolves its set every cycle and re-announces a `SpaceSet` whenever it
  changed, so grants and revokes take effect mid-session without reconnecting.
  In `syncOnce` the client adopts from the initial `SpaceSet`, exchanges
  `SinceHlc`, then runs the sendable data cycle; in `syncContinuously` a newly
  announced space is adopted then established over the next cycles as its
  `SinceHlc` round-trips.
- **Members vs. nodes:** orthogonal layers, both kept. Members are authorization
  (`who`); nodes are CRDT causality (`whose changes, up to which HLC`). One
  member maps to many nodes; the server is a node but not a member; a new member
  has no node until first sync.
- **Client membership table:** `database: all` puts the table on the client,
  populated as a read-only projection. The `OfflineSyncSpaceSet` carries
  `OfflineSyncSpaceGrant`s (`uuidSpaceId` + `role`), and each follower cycle reconciles
  the local table from the announcement (upsert granted, delete revoked; only
  when the set changed). The projected members table drives shared-space
  membership gating and roles for UI and offline role-gated writes; local
  `offline_sync_spaces` rows alone do not grant access. It is a server-authored,
  client-read-only projection — never a
  bidirectionally-synced members table, so a client cannot self-grant.
- **Iteration order:** sorted space UUIDs, so both peers stay in lockstep
  without negotiation. Each merge change carries its space UUID, so receive can
  regroup a combined batch deterministically.
- **One space per transaction:** kept. Cross-space writes need separate
  transactions; remote replicas cannot observe a cross-space write atomically
  anyway.
- **Membership table is `database: all` but unsynced:** the schema exists on
  every node, yet it is server-authoritative app state, never CRDT-replicated.
- **Idle chatter removed:** continuous sync has one combined data loop per
  cycle. When neither peer has grants, handshakes, or changes to send, it emits
  no `SpaceSet`, `SinceHlc`, `MergeChunk`, or `EndOfBatch`; `collectNextBatch`
  resolves the idle cycle from the timeout once per session cycle, not once per
  space.
- **Initial-sync ordering is not a current concern:** a device joining many
  spaces cycles them one at a time on first sync. Prioritizing recently active
  spaces in the iteration order is a compatible refinement if cold-start latency
  over large space counts ever matters, but it is not a present worry.

## Follow-ups

Deferred work needing its own design pass. It does not block the implemented
role enforcement above.

1. **Membership revocation.** When a user loses membership, the server omits the
   space from the next cycle's `SpaceSet` and both sides stop syncing it
   promptly. The device may still store the space's data and unsynced local
   changes, though membership-wide reads no longer expose revoked rows.
   Purge-vs-keep policy, and whether revoked or demoted unsynced changes are
   surfaced, dropped, or kept pending locally, need their own design. (Carried
   from `row-ownership.md` open question 3.)
2. **Outbound collection consistency.** Collection reads CRDT metadata and the
   domain data separately and lock-free, so a concurrent delete — or an FK
   reference to a row inserted after the insert snapshot — can fail a healthy
   stream sync and record a durable violation for a race that the next round
   would resolve. The single-pass multi-space collection widened this window.
   Failing the session for a transient, self-correcting race is the weakness to
   fix; the leading direction is a read-only snapshot (MVCC, not a lock). See
   `outbound-collection-consistency.md`.
