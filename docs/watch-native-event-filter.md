# Native watch events with an Offline Sync cache

This implementation uses the released `serverpod_database` and `sqlite_async`
packages. It installs no SQL triggers or notification tables. Native SQLite
notifications remain the only source of watch wakeups.

## What is filtered

A watch listens to its domain dependencies, the CRDT row/tombstone tables, the
schema registry, and the current user's space membership. Domain and schema
events always rerun the query. Membership notifications read the current set of
accessible space IDs; unchanged IDs (including a role-only change) do not rerun
it. This membership check also works for writes through the underlying database.

CRDT row/tombstone notifications are filtered using semantic effects recorded by
Offline Sync. Visibility is materialized in `CrdtDataRow.visibility`; watching
only tombstones would miss projection changes. Both direct visibility updates
and indirect foreign-key projections record their domain owners.

The cache stores a set of affected tables per active transaction and monotonic
committed versions per table. It does not expire entries after a debounce timer.
Completed transaction records are discarded; the bounded table-version map
remains for the context's lifetime.

## Commit and query ordering

`NativeWatchEffects.transaction` registers the transaction before its callback,
seals its effects before returning control to the driver's COMMIT, and publishes
committed versions before removing the sealed record. A native event arriving
before the transaction Future completes therefore still sees the pending set.
Failed transactions discard their sets. Explicit cancellation can leave a
conservative version advance because the public transaction interface does not
report cancellation; it does not publish a watch event or expose rolled-back rows.

Each query captures versions before reading and acknowledges that exact snapshot
only after the typed query and included-list loading succeed. Changes during a
query, throttle window, or subscription pause remain eligible. The cache never
waits for an application transaction to finish from inside a watch query.

Owned savepoint helpers checkpoint effects and restore them on rollback. Native
savepoints created directly by application code can leave extra affected tables
in the cache. This is safe: conservative reruns are permitted.

## Coverage boundary and fallback

Ordinary inserts, updates, deletes, merges, and projection rebuilds run inside
Offline Sync's observed transaction boundaries. Arbitrary application transaction
callbacks are marked uncertain because they can also use the raw delegate.
Their uncertainty survives until commit and is acknowledged like a table version.

A borrowed transaction's actual commit cannot be observed with the existing ORM
API. Once a borrowed transaction, raw request, or untracked mutation reaches the
wrapper without an observed transaction, metadata filtering is disabled for the
shared context's lifetime. It cannot be re-enabled after a timeout: the borrowed
transaction might still be open. Native events continue working normally.

Writes that bypass Offline Sync entirely cannot be detected in memory. If CRDT
metadata can be changed by another isolate, an independent database owner, or
code using the underlying database directly, configure the shared
`OfflineSyncDatabaseContext` with `filterMetadataChanges: false`. Domain-table
and membership events are observed regardless. This is an explicit ownership
contract, not a claim of automatic provenance detection from SQLite table names.

Wrappers over the same delegate or engine context share effects. If two already
active contexts are brought together, both become conservative rather than
losing the versions acknowledged by existing subscriptions.

## Merge results

`mergeChanges` returns an immutable set of domain tables potentially affected by
the committed merge, including indirect projection changes. It does not infer
this set from incoming operation names. Metadata-only and replayed merges return
an empty set. Conservative extra tables are allowed.

`onMergeSuccess(spaceUuid, syncedHlc, affectedTables)` reports that same set for
inbound merges. Outbound-only acknowledgements report an empty set. Membership
adoption is a separate operation and is not represented as an inbound row merge.

## Costs and deliberate limitations

Each active watch uses native lightweight notification queries plus the typed
query when eligible. Membership events read accessible space IDs. Domain writes
retain native table-level behavior, so same-value writes and some rolled-back
savepoint notifications can cause extra queries. Domain and metadata events
can also cause separate reruns when throttling is disabled.

The main database methods delegate transaction/savepoint bookkeeping to one
helper. The tradeoff for avoiding an ORM or driver extension is reduced filtering
precision for unobserved transaction lifetimes and an explicit configuration for
writers that bypass the wrapper.
