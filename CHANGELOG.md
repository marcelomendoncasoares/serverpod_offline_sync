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
