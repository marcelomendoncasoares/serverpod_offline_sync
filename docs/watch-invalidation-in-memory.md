# Alternative A: In-memory watch invalidation in the ORM

Status: design proposal, not implemented. Recorded on 2026-11-04 before
evaluating a hybrid of native table notifications and transaction metadata.

Related work: [issue #204](https://github.com/marcelomendoncasoares/serverpod_offline_sync/issues/204)
and [draft PR #205](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/205).
The draft currently implements a trigger-backed revision table. This document
describes an alternative to that implementation.

## Problem

Physical writes to shared CRDT metadata tables do not identify which domain
queries need to rerun. A clock or checkpoint update may leave visible data
unchanged, while a visibility or membership change may alter a query without
physically updating its domain table.

Offline sync should decide which domain tables have observable changes using
the data it already processes. Notifications can remain table-level: this is
not a system for proving that each individual query result changed.

## Scope and ownership

- No SQL triggers, auxiliary notification table, or changes to `sqlite_async`.
- Writers and watches share a database-scoped notification owner in one isolate.
  Separate wrappers must share that owner; merely running in one isolate is
  insufficient. Delivery to other isolates or browser tabs is out of scope.
- Offline sync determines affected domain tables after successful writes,
  winning merges, projection changes, and membership changes. Clock updates,
  losing operations, and unchanged visible state do not create invalidations.
- `serverpod_database` owns transaction lifecycle integration and a watch
  invalidation extension point. It does not interpret CRDT metadata.
- Existing query construction, dependency discovery, include handling, and
  deserialization remain in the ORM.

## Isolated bookkeeping

A dedicated `WatchChangeTracker` owns pending changes, savepoint checkpoints,
deduplication, and publication. Database methods report lifecycle events with
one-line calls. These names are illustrative, not a settled public API.

| Event | Tracker call |
| --- | --- |
| Transaction starts | `changes.begin(tx);` |
| Operation affects visible data | `changes.record(tx, affectedTables);` |
| Savepoint created | `changes.savepoint(tx, id);` |
| Savepoint released | `changes.release(tx, id);` |
| Rolled back to savepoint | `changes.rollbackTo(tx, id);` |
| Outer transaction committed | `changes.commit(tx);` |
| Transaction state can be discarded | `changes.discard(tx);` |

Each transaction keeps a set of affected tables and savepoint checkpoints.
Recording a change does not publish it. Savepoint lifecycle calls follow
successful database commands.

Rollback restores the set at the checkpoint, rather than subtracting names.
For example, a Person change before a savepoint must survive rollback of a
second Person change after that savepoint. Rollback to a savepoint removes
later checkpoints but retains its target. Releasing a savepoint removes its
checkpoint and later checkpoints while preserving their pending changes.

Only successful completion of the underlying outer transaction permits
publication. Returning from its callback is not proof of commit: deferred
constraints can still reject it. Cancellation, exceptions, and commit failure
must leave no pending notifications. An idempotent `discard()` in cleanup can
also run after successful publication.

The same rules apply when callers supply transactions or create savepoints
directly through the ORM. Arbitrary transaction-control SQL bypassing those
lifecycle methods is not covered by this proposal.

## Watch integration

Tracked tables use committed explicit invalidations. Untracked tables retain
native database notifications. Mixed queries combine these sources before
query scheduling. Adding explicit events while retaining all broad metadata
triggers would preserve the existing unnecessary reruns.

Dependency matching must include the root table, joins, filters, ordering,
nested includes, and `alsoTriggerOnTables`. Existing ORM dependency discovery
should be reused instead of copied into offline sync.

The watch implementation must subscribe without losing commits around its
initial read, retain invalidations arriving during a query or pause, apply
throttling, and run queries outside transaction lock contexts. Subscriber
failures must not turn a successful commit into an apparent transaction failure.

Notifications are invalidation hints, not a durable event log or a guarantee
of one query execution per transaction. A changed table can invalidate a query
whose result is unchanged. Changes later reversed within a successful transaction
can also produce a conservative invalidation unless net-effect tracking is added.

## Tradeoffs and write coverage

The expected performance benefit is removing per-row trigger work and revision
writes. In-memory sets and savepoint checkpoints still have a cost. No benchmark
of this alternative has been run.

The principal correctness risk is omitting a reporting path. Coverage must
include local CRUD, inbound merges, indirect projection changes, grants,
revocations, and relevant cleanup operations. Raw SQL or writes through an
independent owner can bypass explicit notifications.

The proposed default is explicit notifications for tracked tables and native
notifications for untracked tables. Retaining a native fallback for tracked
tables would catch more bypass writes but allow additional reruns, including
same-value writes. This boundary must be explicit in the public contract.

The tracker keeps the main database code small but does not remove lifecycle
complexity. The change requires an ORM extension and offline sync adoption;
release coordination and compatibility with external implementations of ORM
interfaces must be considered.

## Validation required

- Tracker tests: overlapping table sets, nested savepoints, rollback followed
  by further writes, release of an ancestor, cancellation, and cleanup.
- ORM integration tests: publication after actual commit, failed commit,
  caller-owned transactions, and shared ownership across wrappers.
- Watch tests: startup races, changes during reads, pause/resume, cancellation,
  throttling, mixed tracked/untracked dependencies, and nested includes.
- Offline sync tests: local CRUD, merge insert/update/delete, cascade hide and
  restore without domain-row writes, membership changes, unrelated writes,
  repeated grants, replayed operations, and unchanged sync passes.
- Native and browser execution, plus bulk-write comparison against the current
  trigger implementation and a baseline without the new invalidation work.

Tracker unit tests alone cannot establish that all production paths report
the required changes.
