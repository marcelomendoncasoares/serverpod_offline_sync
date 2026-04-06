# Drift Offline Sync

[![GitHub](https://img.shields.io/badge/GitHub-marcelomendoncasoares-181717.svg?style=flat&logo=github)](https://github.com/marcelomendoncasoares)
[![Pub Package](https://img.shields.io/pub/v/drift_offline_sync.svg)](https://pub.dev/packages/drift_offline_sync)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/drift_offline_sync.svg)](https://pub.dev/packages/drift_offline_sync)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://github.com/marcelomendoncasoares/drift_offline_sync/blob/main/LICENSE)
[![CI](https://github.com/marcelomendoncasoares/drift_offline_sync/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/marcelomendoncasoares/drift_offline_sync/actions/workflows/ci.yaml)

A plugin to build offline-first applications with Drift. Develop your app as a
normal offline app and use this non-invasive plugin to automatically handle the
sync process using CRDT (Conflict-free Replicated Data Type). Works
out-of-the-box with Drift's existing APIs.

- [Drift Offline Sync](#drift-offline-sync)
  - [What is this package?](#what-is-this-package)
  - [Usage](#usage)
  - [How does it work?](#how-does-it-work)
  - [Performance considerations](#performance-considerations)
  - [License](#license)

---

## What is this package?

This package is an adapter for a Drift database that can transform any offline application into offline-first with multi-device support. It can be plugged into any application developed with an offline database (managed in Drift) to provide full synchronization with a remote server. The only required change is the replacement of the original `Migrator` object in the database declaration by the one provided in this package and that all tables have a UUID as part of its primary key.

Under the hood, the sync engine uses Conflict-free Replicated Data Types (CRDT) to merge updates and solve merge conflicts. Beyond traditional CRDT approaches, it implements a robust mechanism to preserve invariants of the system (foreign key and unique constraints, for example) and handle migrations. This is what enables this engine to be safely used with traditional relational data instead of sacrificing data integrity and strict typing to use key-value storages.

## Usage

Just use the `OfflineSyncMigrator` in the `createMigrator` method of your database class.

```dart
class TodoDb extends _$TodoDb {
  TodoDb(super.e);

  @override
  int schemaVersion = 1;

  // This is what needs to be added to the user database class to make it CRDT aware.
  @override
  OfflineSyncMigrator createMigrator() => OfflineSyncMigrator(
    this,
    userId: userId,
    nodeId: nodeId,
    synchronizedTables: [
      todosTable,
      categories,
      users,
      sharedTodos,
    ],
    excludeTables: [
      listing,
      product,
    ],
  );
}
```

Make sure that all tables have a UUID as part of its primary key - standard practice for distributed systems.

## How does it work?

When the database is initialized, the `OfflineSyncMigrator` will create a few control tables and add triggers to all user tables listed for synchronization (defaults to all tables). Each table will receive three triggers: after insert, after update and after delete. The triggers serve to populate the main CRDT control table with all the changes (granular, individualized to field updates and their invariance preserving rules). Each update is marked with an HLC (Hybrid Logical Clock) timestamp that will be used as reference to further merging changes between devices.

During migrations, as triggers are created expecting the current table schema, they must be removed to avoid errors - like trying to compare a column that was removed. So, after migration is finished, a `regenerate` is called to compare the changes and synchronize the central CRDT registry. In the meantime, changes to the schema (like column addition and deletion) are reflected to the stored data on the central registry.

Although schema changes does not get propagated through the merging process—there is no CRDT registry for table schemas—this is not a concern, as changes can only be synchronized if the databases match version. So, after migration, all databases will converge to the same schema, with each carrying their pending merge data to the new format. Only then, sync will occur.

## Performance considerations

The greater costs of this adapter are:

- Database size can be doubled or more.
- Each insert/update/delete happen twice.
- Migrations require a regenerate process that increases time considerably.

The advantages are:

- Offline-first sync.
- No performance cost on read operations.
- Simple offline app development.
- Invariant safety - no weird states in the data.
- Plug and play to any existing offline app.
- No dealing with remote-aware repositories.

## License

This package is distributed under the MIT License. See the LICENSE file for
more information.
