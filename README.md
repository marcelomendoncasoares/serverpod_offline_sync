# Serverpod Offline Sync

[![GitHub](https://img.shields.io/badge/GitHub-marcelomendoncasoares-181717.svg?style=flat&logo=github)](https://github.com/marcelomendoncasoares)
[![Pub Package](https://img.shields.io/pub/v/serverpod_offline_sync.svg)](https://pub.dev/packages/serverpod_offline_sync)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/serverpod_offline_sync.svg)](https://pub.dev/packages/serverpod_offline_sync)
[![License: BSD 3-Clause](https://img.shields.io/badge/license-BSD_3--Clause-yellow.svg)](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/main/LICENSE)
[![CI](https://github.com/marcelomendoncasoares/serverpod_offline_sync/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/marcelomendoncasoares/serverpod_offline_sync/actions/workflows/ci.yaml)

A plugin to build offline-first applications with Serverpod. Develop your app
as a normal offline app and use this non-invasive plugin to automatically
handle the sync process using CRDT (Conflict-free Replicated Data Type). Works
out-of-the-box with Serverpod's existing APIs.

- [Serverpod Offline Sync](#serverpod-offline-sync)
  - [Overview](#overview)
  - [Features](#features)
  - [Getting started](#getting-started)
    - [1. Add the package to the project](#1-add-the-package-to-the-project)
    - [2. Prepare the synced tables](#2-prepare-the-synced-tables)
    - [3. Configure the sync engine on the server](#3-configure-the-sync-engine-on-the-server)
    - [4. Configure the sync engine on the client](#4-configure-the-sync-engine-on-the-client)
    - [5. Wire the sync call on the client](#5-wire-the-sync-call-on-the-client)
  - [Usage](#usage)
    - [Scopes and sharing](#scopes-and-sharing)
    - [Data modeling limitations](#data-modeling-limitations)
  - [How it works](#how-it-works)
  - [Performance](#performance)
  - [Example](#example)
  - [Additional information](#additional-information)
  - [License](#license)

---

## Overview

**Serverpod Offline Sync** turns an ordinary [Serverpod](https://serverpod.dev)
backend into an offline-first, collaborative system, without changing how you
write your app. It is a delta-CRDT engine that runs **the same code on the
client and server databases**, transparently and with minimal configuration.

It sits nearly alone in the space of offline-first solutions, because most
others either use a non-relational database, require a new data API, or don't
preserve foreign-key/unique invariants while merging data. This package is built
on top of Serverpod, leveraging its ORM, server, and client to expose these
capabilities with almost nothing new to learn: you build a normal offline
Serverpod app (generated models, ordinary CRUD) and the plugin handles
replication automatically.

The sync engine is a **black box that "just works"**: changes are tracked
atomically with each operation and you never intervene in conflict resolution.
Conflicts that need a human decision **bubble up as visible state** for the end
user to act on (e.g. a delete reverted by a concurrent constraint reappears, so
the user can simply delete it again). Migrations work normally, and deleted rows
never leave their tables — they are transparently hidden from the user.

> The CRDT layer was inspired by the excellent work on
> [Synql](https://github.com/coast-team/synql)
> ([Ignat et al., DAIS 2024](https://inria.hal.science/hal-04969158v4/document)).
> This package goes beyond Synql by covering the full set of foreign-key
> `onDelete` actions, extending unique-constraint handling to deeply relational
> schemas, and shipping a production-ready implementation.

## Features

- **Offline-first, no new API.** Read and write generated models with ordinary
  Serverpod CRUD against a local database; the plugin replicates for you.
- **Same code on both ends.** Identical logic runs on the client's SQLite and
  the server's Postgres, so there are no asymmetric merge results to reconcile.
- **Automatic conflict resolution.** Field-level merges ordered by hybrid
  logical clocks, with a monotone causal-length tombstone governing row
  existence so add/delete/restore can never oscillate.
- **Relational integrity preserved.** All foreign-key `onDelete` actions
  (restrict / cascade / set null / set default) and unique constraints are
  honored after every merge, as if the merged data had existed in a single
  database at the time of each operation.
- **Conflicts surface to the user.** Resolutions that require a human decision
  become visible state instead of silent data loss.
- **Scopes and sharing.** Data is isolated per scope; each user has a personal
  scope and can be a member of any number of read-only or read-write shared
  scopes.
- **One-shot and continuous sync.** The same stream-based protocol powers both
  pull-to-refresh and near-real-time streaming.
- **Minimal overhead.** Metadata is normalized and never copies row data,
  keeping the storage and performance penalty small (see [Performance](#performance)).

## Getting started

Using the package on a project takes just five steps. After this setup, you
develop the app with normal repository calls against the wrapped `session`.

> [!NOTE]
> This package is still in development and is not yet ready for production use.
> Although the package is functional and feature-complete, it will still pass
> through some refactors and breaking changes for a better integration on real
> Serverpod projects.

### 1. Add the package to the project

Since this package is still in development and not yet released to pub.dev,
you need to add it as a git reference to the project. First, add it normally
on the server and client `pubspec.yaml` files.

```yaml
# your_project_client/pubspec.yaml
dependencies:
  serverpod_offline_sync_client: 4.0.0-beta.0
```

```yaml
# your_project_server/pubspec.yaml
dependencies:
  serverpod_offline_sync_server: 4.0.0-beta.0
```

Then, on the workspace root `pubspec.yaml` file, add the following overrides:

```yaml
dependency_overrides:
  serverpod_offline_sync_client:
    git:
      url: https://github.com/marcelomendoncasoares/serverpod_offline_sync.git
      path: packages/serverpod_offline_sync_client
      ref: main
  serverpod_offline_sync_server:
    git:
      url: https://github.com/marcelomendoncasoares/serverpod_offline_sync.git
      path: packages/serverpod_offline_sync_server
      ref: main
  serverpod_offline_sync_shared:
    git:
      url: https://github.com/marcelomendoncasoares/serverpod_offline_sync.git
      path: packages/serverpod_offline_sync_shared
      ref: main
```

Be mindful that installing the package as a git reference to `main` is subject
to sudden changes when resolving dependencies. If you want to use a specific
version, pin the commit hash on the `ref` field instead.

After adding the dependencies, list the `serverpod_offline_sync` module on the
`generator.yaml` file:

```yaml
modules:
  serverpod_offline_sync:
    nickname: offline_sync
```

The next call to `serverpod generate` and `serverpod create-migration` will
include the `offline_sync` module in the project. Note that the client tables
will only be present on the client's migration if at least one model on the
project is defined with `database: all` or `database: client`.

### 2. Prepare the synced tables

Each model you want to sync must be defined with `database: all` (so it exists
on both the client and the server), have a UUID primary key, and declare a
`scopeId` field. You mostly never set `scopeId` nor see its value on reads; it
is maintained by the CRDT sync layer.

```yaml
class: Person
table: person
database: all
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### Owner scope of this row. Maintained by the CRDT sync layer.
  ### The user never sets this field nor sees its value on reads.
  scopeId: int?, relation(parent=crdt_scopes, onDelete=Cascade)
  name: String
```

### 3. Configure the sync engine on the server

On the server, the `databaseInterceptor` is what ensures that all `session.db`
objects are database instances that tracks operations for sync.

```dart
final pod = Serverpod(
  args,
  Protocol(),
  Endpoints(),
  // Add the database interceptor.
  databaseInterceptor: crdtDatabaseInterceptor,
);

// Initialize the sync engine before pod.start() is called.
pod.initializeCrdtSync(
  syncTables: [Person.t, Book.t, Author.t],
);
```

Don't forget to also configure the authentication following the regular
Serverpod auth setup. Authentication is required because the sync needs a
logged in user to synchronize data.

### 4. Configure the sync engine on the client

On the client, the regular `DatabaseSession` must be replaced by a wrapped
version that includes the sync engine.

```dart
final session = CrdtDatabaseSession.wraps(
  await client.createSession(databasePath, isDebugMode: kDebugMode),
  syncTables: [Person.t, Book.t, Author.t], // Must be the same as on the server.
  persistentUserId: persistentUserId,
);

// Initialize the sync engine.
await session.db.initialize();
```

Then, store the `session` instance in the service locator.

> [!NOTE]
> The list of synced tables must be the same on the server and the client.
> Otherwise, all sync attempts will fail with a schema mismatch error.

### 5. Wire the sync call on the client

Be sure to authenticate the client before calling the sync methods. Otherwise,
the sync operation will fail with a `Unauthorized` error.

```dart
// Push local changes and merge remote ones once (i.e. pull-to-refresh).
await client.crdt.syncOnce(session);

// Or stream changes both ways until cancelled for a near-real-time sync.
final syncSession = client.crdt.syncContinuously(session);
```

## Usage

Once wired up, use normal generated-model CRUD against the `session` instance —
`Person.db.insertRow(session, person)`, `session.db.find<Person>()`, and so on.
The sync layer tracks every operation atomically; you never touch conflict
resolution.

### Scopes and sharing

Data is isolated per **scope**. Each user has their own implicit personal scope
and can be a member of any number of shared scopes, with read-only or read-write
access.

- **On the server**, wrap database operations in `session.db.transactionForUser`
  to target the correct scope.
- **On the client**, set a `persistentUserId` to target the personal scope by
  default, or use `transactionForUser` to target a shared scope.

### Data modeling limitations

Because of the nature of merge conflicts, the package imposes some data-modeling
limitations, enforced at runtime during initialization. Most are fundamental to
the design and can never be lifted.

- Every synced table must:
  - Exist on both the client and the server with `database: all`.
  - Have a UUID primary key.
  - Declare the field `scopeId: int?, relation(parent=crdt_scopes, onDelete=Cascade)`.
- Unique indexes must include `scopeId` together with the target columns.
- Global unique indexes are unsupported, except for FK-only indexes.
- Unique indexes are only supported with at least one
  `String`/`UuidValue`/nullable column.
- All 1:1 relations must have the foreign-key column nullable (`optional`
  relation).
- The only allowed non-synced-to-synced relation is `scopeId -> crdt_scopes.id`.
- All foreign-key relations must be `deferrable` (pending [serverpod#5338](https://github.com/serverpod/serverpod/issues/5338)).

Respecting these limitations, all other database invariants — including
foreign-key actions — are preserved, with the exception of check constraints,
which Serverpod does not support either.

## How it works

- **Architecture.** The engine is a transparent layer between the application
  and its database. Because identical code runs on the client's SQLite and the
  server's Postgres, there are no asymmetric merge results to reconcile.
  Migrations are generated symmetrically for both ends. The engine respects the
  three mathematical properties a CRDT must hold to be consistent: idempotence,
  associativity, and commutativity.
- **Metadata model.** Three metadata tables track change history *without copying
  row data*: `crdt_data_rows` (insert + visibility), `crdt_data_fields` (update),
  and `crdt_data_tombstone` (delete/restore). Hybrid logical clocks order
  field-level values and break ties. A monotone causal-length tombstone governs
  row existence, so add/delete/restore advance generations forward and can never
  oscillate.
- **Visibility as a pure function.** Replicas never coordinate. Each merge
  applies remote facts monotonically, then derives the visible database —
  tombstone state, unique-conflict winners, and foreign-key repair — as a
  deterministic projection computed to a fixed point.
- **Ownership & scopes.** A *scope* is the unit of replication and ownership; a
  *user* is an authentication identity. Each row is globally identified by
  `(table, rowId)` and owned by exactly one scope, so merging is always one chain
  per row. Scopes can be purged for GDPR / account erasure via a
  database-enforced cascade.
- **Sync protocol.** A session handshakes once to validate that both ends share
  the same table schema. Per cycle, the server sends the authoritative scope set,
  and every scope the user can access is synced (transferred all at once in
  chunks, merged one at a time). The same stream-based implementation powers both
  one-shot and continuous sync.

For a deeper dive, see the design docs in [`docs/`](docs):
[row ownership](docs/row-ownership.md),
[foreign-key invariants](docs/foreign-key-invariants.md),
[unique-constraint invariants](docs/unique-constraint-invariants.md), and
[sync/non-sync relations](docs/sync-non-sync-relations.md).

## Performance

Since all operations are tracked, a CRDT layer can weigh heavily on storage and
speed. This package was built to keep that penalty minimal. The benchmark below
uses 1,000 rows to measure the impact against a baseline of the same operations
without the CRDT layer, both on SQLite (a fresh report is posted as a comment
on every pull request):

```
📊 SELECT performance impact:
  Time: 12.62 ms --> 12.67 ms (48.50 μs)
  CRDT overhead: 0.38% slower

📊 INSERT performance impact:
  Delay per insert: 231.04 μs

📊 UPDATE performance impact:
  Delay per update: 1.88 ms

📊 DELETE performance impact:
  Delay per delete: 408.75 μs

💽 Storage impact (base footprint removed):
  Storage overhead range: 62.07% --> 300.00%
```

Despite the high *percentage* slowdown on insert/update/delete, the absolute
impact is mostly in the microsecond range — barely noticeable in practice, and
far below the network delay those operations would incur through an online
endpoint. Storage tops out at ~3× the base size, an acceptable trade for
offline-first speed and availability.

## Example

The bundled desktop demo shows the model directly: two independent replicas of
one account side by side, plus the server's merged truth. Drive each replica's
sync independently and watch them converge. It visualizes hidden / tombstoned
rows and every foreign-key `onDelete` action, with guided scenarios for the
restrict / cascade / set-null / set-default / unique-conflict cases.

Run it by starting the test server — the app launches alongside it:

```sh
cd test/serverpod_offline_sync_test_server
serverpod start
```

See [`example/offline_sync_demo`](example/offline_sync_demo) for details; the
entire integration lives in ~60 lines in
[`lib/src/offline_replica.dart`](example/offline_sync_demo/lib/src/offline_replica.dart).

## Additional information

The package is tested extensively following Serverpod's testing principles. The
vast majority of the tests live in the `serverpod_offline_sync_test_server`
package, whose server is shared with the `example/offline_sync_demo` project.

## License

This package is distributed under the BSD 3-Clause License. See the LICENSE
file for more information.
