# Outbound collection consistency

## Problem

[Issue #163](https://github.com/marcelomendoncasoares/serverpod_offline_sync/issues/163)
reports a permanent checkpoint gap when a commit lands between the separate
insert, update, and delete queries. This reproduces on `main` at `f59a90b`, after
PR #158.

For example, the insert query finishes before a transaction inserts `A` at `t1`,
updates `B` at `t2`, and inserts `C` at `t3`, where `t1 < t2 < t3`. The update
query emits `t2`. `OfflineSyncSpaceState.advanceCheckpoint` advances that space's
author checkpoint to `t2`, so the next collection selects `C` but never `A`.
The inbound merge persists the same incomplete progress, so reconnecting does
not repair it.

There is an equivalent update/delete gap: after the update query, a transaction
updates `B` and then deletes another row. Emitting the later deletion skips the
name update permanently. Both paths can complete collection and merge without
an integrity error.

Earlier versions of this document incorrectly described collection races as
always self-correcting. They are data convergence defects.

## Implementation

`collectPendingChanges` resolves stable space IDs, then captures every pending
change in one database transaction. The three metadata queries, included
attempted values, domain payload queries, and ownership checks all receive that
same transaction. It requests `IsolationLevel.repeatableRead`, which PostgreSQL
supports through Serverpod's adapter.

The complete captured list is emitted in insert, update, then delete order
**after the transaction completes**. A consumer may commit a write or pause
between changes without holding the capture transaction open. A commit is either
visible to the captured snapshot or deferred until the next pass; it cannot
contribute only its later change kind to the current checkpoint.

This also prevents payload reads from observing values newer than the metadata
snapshot. Genuine integrity failures abort capture; the durable violation is
recorded outside the rolled-back transaction. Stable space identities are
resolved before capture so a lazily initialized sync wrapper can initialize its
schema without opening a nested SQLite transaction.

Application membership lookups also retain their active transaction. In the
Serverpod 4.0.3 SQLite adapter, an application transaction queued behind capture
can otherwise hit a lock error when a visibility read starts outside that
transaction. Both personal-space and shared-membership reads receive the same
transaction; the existing concurrent lookups remain concurrent.

### Costs and boundaries

- The resolved Serverpod 4.0.3 SQLite adapter exposes `writeTransaction`, while
  the underlying `sqlite_async` connection supports `readTransaction`. SQLite
  writers therefore wait during capture. No SQLite write lock is held across
  an emitted change. An upstream read-transaction API would remove this
  contention without changing collection semantics.
- Capturing a whole pass uses memory proportional to its payloads and delays the
  first emitted change until capture completes. Wire chunk sizes remain bounded,
  but do not bound capture memory. This is a correctness fix, not a claimed
  collection performance improvement.
- PostgreSQL repeatable-read snapshots do not require row write locks on the
  collected spaces. All reads must retain the explicit transaction argument.
- Consume the collector outside application transactions, with no ambient
  session transaction. It captures committed data in its own transaction;
  nested SQLite collection is unsupported. Application queries inside write
  callbacks must also receive their transaction: unscoped reads can still hit
  Serverpod 4.0.3's lock-zone error when transactions overlap.
- A consistent snapshot cannot repair an already-invalid checkpoint, prove
  completeness of arbitrary partial wire chunks, or establish ordering of
  remote author facts received across independent relays. Projected attempted
  FK values may also reference absent rows by design.

## Why an HLC upper bound alone is insufficient for a common snapshot

The issue's proposed upper bound addresses the reproduced schedules if each
author's commits become visible in HLC order. It preserves lazy payload reads,
however: an insert below the bound can still fetch a domain value written after
the bound. Attempted values and ownership reads need consistency too.

Current local writes already lock and refresh their `CrdtNode` through
`lockAndRefreshCurrentNodeHlc`; this is distinct from proving ordered arrival
of relayed facts. The existing metadata indexes cover row and field identities,
not the proposed node/HLC descending lookups, so the claimed indexed-query cost
would also need validation or new indexes.

Silently deferring individual racy changes is unsafe if another emitted change
advances the same author's checkpoint past them. Faster or batched domain reads
reduce the race window but do not establish a snapshot.

## Regressions and DST

Run the deterministic regressions from the test-server package:

```sh
dart test test/integration/sync/outbound_snapshot_test.dart test/integration/sync/outbound_snapshot_concurrency_test.dart test/dst/dst_outbound_snapshot_test.dart
```

The SQLite integration cases use real peers, `mergeInboundBatch`, and persisted
`createSyncSinceHlc` vectors. On the original collector, three assertions fail:
collected inserts omit `A`, the peer lacks `A`, and the update/delete peer keeps
`B1` instead of `B2`. Two full-history recovery assertions pass. All five pass
with the snapshot fix. A sixth check covers lazy wrapper initialization,
cancellation after one change, and a subsequent write and collection.

The DST regressions drive the same interleavings through `DstAdversary` in delta
mode and drain exclusively through receiver checkpoints. Replacing the fixed
collector with the original makes both convergence assertions fail while the
interleaving coverage assertions still pass. This verifies that the harness
executes the race and cannot hide it with a full-history repair.

Additional integration and DST cases start an independent writer after the
real insert metadata query, before payload capture resumes. They reject a
mutation that keeps buffering but removes the transaction, which the
consumer-yield cases alone cannot detect. The integration suite also exercises
a membership-filtered read and insert queued behind capture: it fails with a
SQLite lock error when membership lookups lose their transaction.

Seeded simulations schedule two or three application operations either during
capture or at a selected collector yield. Capture-time writes run in an
independent zone with a bounded 500 ms opportunity to commit while capture is
paused; SQLite's transaction keeps them queued instead. The harness awaits
their completion before returning the batch, so clock and random state cannot
overlap later scheduling. The operation generator retains its ordinary authored
fact, rollback, and invariant checks. Interleavings run only during the scheduled
phase, in both full and delta modes; setup and draining remain quiescent.

Network metrics record attempts and committed transactions separately, including
the emitted change kind at yield suspension points. Separate capture metrics
count capture schedules and their eventual committed transactions after the
snapshot releases its lock. Runs of 100 or more rounds must commit at least one
write from each schedule type. These gates supplement existing commit and delta partial-batch
requirements.

Local stress validation used seed `163`, the sparse profile, and 100 rounds in
each topology and delivery mode. All four runs passed:

| Delivery | Topology | Commits at collector yields | Commits attempted during capture |
| --- | --- | --- | --- |
| full | cross_space | 20 | 18 |
| full | convergence | 19 | 16 |
| delta | cross_space | 12 | 12 |
| delta | convergence | 41 | 43 |

Both delta topologies reproduced identical complete metrics on replay. A
buffer-only mutation failed the randomized delta convergence run for seed
`163`, in addition to the pinned capture-time DST and integration regressions.

A separate PostgreSQL 16 adapter probe committed an independent writer after
the insert metadata read and before payload reads. Capture retained `B0`, then
the next collection delivered `A`, `C`, and the `B1` update. The probe generated
PostgreSQL SQL from the current schema definition in an isolated cluster; the
test server's checked-in migration SQL targets SQLite. Changing only the capture
isolation to read-committed makes that probe fail, confirming that buffering
without a repeatable snapshot is insufficient.

## Recovery

Fixing future collections cannot recover operations already below a receiver's
checkpoint. The tested recovery is an explicit full-history collection using
`checkpointsBySpaceUuid: {space: []}`, merged on the affected peer. Ordinary
checkpoint retries did not repair either original reproduction.
