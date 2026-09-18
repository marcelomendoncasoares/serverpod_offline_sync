## Unreleased

- feat: BREAKING. Report merges through a structured `OfflineSyncMergeEvent`
  carrying the syncing user, space, peer node and the directional received and
  sent HLCs. `onMergeSuccess` callbacks now take a single event argument.
- feat: Register a server-wide merge handler with `pod.configureOfflineSync`.
  It receives the sync session's `Session` alongside the event, runs in addition
  to any per-sync observer, and is isolated from the committed synchronization.

## 0.0.8

- fix: BREAKING. Reject unique-text values ending in `__conflict__<UUID>`,
  `__hidden__<UUID>`, or `__park__<UUID>`, and unique version-8 UUIDs (except
  primary keys, foreign keys, and nullable UUID columns). Local writes and
  incoming sync throw `OfflineSyncReservedValueException` for these values.
- fix: Enforce database unique constraints on local writes and restores, and
  reject upsert batches that target the same record more than once.
- fix: Retain upserted values and explicit nulls when replacing a conflicting
  value, including upserts matched through another unique index.
- fix: Treat restored rows as fresh writes so field values and conflict ages
  stay consistent across sync and bootstrap.
- fix: Preserve UUID-shaped text and binary values during conflict resolution
  and sync, and encode restored values according to their column types.
- fix: Show UUIDs correctly in errors for references to deleted records.

## 0.0.7

- fix: Keep non-synced `updateRow` calls in the test harness transaction.
- fix: Allow generated client sync sessions to close their SQLite connections.
- fix: Resolve shared-package models and enums during projection and sync.
- fix: Preserve boolean types when syncing SQLite column updates.
- fix: Preserve JSON and JSONB field types and values through inserts, updates,
  and explicit nulls.

## 0.0.6

- refactor: BREAKING. Rename integration APIs and ownership scopes:
  - Rename `CrdtDatabase*` wrappers to `OfflineSyncDatabase*`.
  - Rename `CrdtSync` to `OfflineSyncEngine` and `CrdtSyncSession` to
    `OfflineSyncSubscription`.
  - Access sync through `.offlineSync` and `.offlineSyncDb` instead of
    `.crdt` and `.crdtDb`.
  - Replace `CrdtScope*` models and services with `OfflineSyncSpace*`
  - Change access to shared spaces through `.spaces` instead of `.scopes`.
  - Use `spaceId` in models and indexes, and `offline_sync_spaces` in
    ownership relations.
  - Initialize with `initializeOfflineSync` and use `offlineSyncDatabaseInterceptor`.
  - Import client helpers from `offline_sync.dart` instead of `crdt.dart`.
  - Rename the synchronization endpoint, serialized events, and space metadata
  tables.
- fix: Recompute `onDelete=SetDefault` repairs when default targets are
  inserted, deleted, restored, or hidden to preserve authored values.
- fix: Reject local deletes atomically when a needed `SetDefault` target is
  missing, hidden, owned by another space, or deleted in the same batch.
- fix: Preserve projection-selected nulls during inserts instead of reapplying
  column defaults, and apply fixed UUID foreign-key defaults in local upserts.
- fix: Resolve composite unique conflicts when only a fixed discriminator
  column changes.
- perf: Avoid redundant foreign-key projection for ordinary local writes and
  primary-key upserts, and batch dependency checks and field-clock writes.
- perf: Overlap independent membership reads and skip unnecessary space lookups
  for untracked tables.
- chore: Update Serverpod to `4.0.0` and use the published CLI.

## 0.0.5

- fix: BREAKING. Rebuilds foreign key and unique projection from authored facts.
- perf: Increases unique-conflict merge throughput by ~40%.
- perf: Increases foreign-key chain insert merge throughput by ~3.3×.
- perf: Increases foreign-key chain delete merge throughput by ~44%.
- perf: Reduces storage used by CRDT metadata on relations.
- chore: Updated Serverpod to `4.0.0-rc.2`.

## 0.0.4

- chore: Updated Serverpod to `4.0.0-rc.1`.

## 0.0.3

- fix: Requires non-nullable foreign keys to be `deferred`.
- fix: Rejects `onDelete=Restrict` on synced tables in favor of `onDelete=NoAction`.
- fix: Throws proper `DatabaseException` instead of bare `Exception` on the database.
- chore: Updated Serverpod to `4.0.0-rc.1`.

## 0.0.2

- fix: Skips tracking FKs for relations with non-sync tables.
- fix: Fixes batch `insert` of previously tombstoned rows not being tracked correctly.
- refactor: Moves the core implementation to the `serverpod_offline_sync` shared package.
- chore: Updated Serverpod to `4.0.0-beta.2`.

## 0.0.1

- chore: Initial version.
