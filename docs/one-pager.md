# Serverpod Offline Sync — Product One-Pager

*This is a one-pager that describes the product and its features, plus a roadmap for the transference process to Serverpod's monorepo.*

## Overview

**Serverpod Offline Sync** is a Dart plugin that turns an ordinary [Serverpod](https://serverpod.dev) backend into an offline-first, collaborative system, without changing how developers write their app. It is a delta-CRDT (Conflict-free Replicated Data Type) engine that runs **the same code on the client and server databases**, transparently and with minimal configuration.

It sits nearly alone in the space of offline-first solutions, because most other solutions either use a non-relational database, require a new data API, or don't preserve foreign-key/unique invariants while merging data. The solution is built on top of the Serverpod framework, leveraging its ORM, server and client to expose such complex capabilities with minimal configuration.

The work on this package was inspired by the excellent work on [Synql](https://github.com/coast-team/synql) ([Ignat et al., DAIS 2024](https://inria.hal.science/hal-04969158v4/document)), which provided the foundation for the CRDT layer. This package goes beyond `Synql` by covering the full set of foreign-key `onDelete` actions, extending unique-constraint handling to deeply relational schemas, and shipping a production-ready implementation.

### The developer experience

The main selling point of the package is that there is almost nothing to learn. The app is built
as a normal offline Serverpod app (generated models, ordinary CRUD) and the plugin handles replication automatically.

The four steps below contain all required changes on a project to use the package:

1. Prepare the synced tables by adding the `scopeId` field to the models.
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

2. Configure the sync engine on the server.
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

3. Configure the sync engine on the client.
    ```dart
    final session = CrdtDatabaseSession.wraps(
      await client.createSession(databasePath, isDebugMode: kDebugMode),
      syncTables: [Person.t, Book.t, Author.t],
      persistentUserId: persistentUserId,
    );

    // Initialize the sync engine.
    // Then store the `session` instance in the service locator.
    await session.db.initialize();
    ```

4. Wire the sync call on the client.
    ```dart
    // Push local changes and merge remote ones once (i.e. pull-to-refresh).
    await client.crdt.syncOnce(session);

    // Or stream changes both ways until cancelled for a near-real-time sync.
    final syncSession = client.crdt.syncContinuously(session);
    ```

After this setup, the app can be developed using normal repository calls against the `session` instance.

The sync engine is a **black box that "just works"**: changes are tracked atomically with each operation and the developer never intervenes in conflict resolution. Conflicts that need a human decision **bubble up as visible state** for the end user of the app to act on (e.g. a delete reverted by a concurrent constraint reappears, so the user can simply delete it again). Migrations work normally, and the same applies to deleted rows — which never leave their tables, but are transparently hidden from the user.

Understanding the behavior is also straightforward: conflict resolution respects unique and relational constraints, mirroring what would be expected if the merged data existed in a single database at the time of each operation.

Finally, the data is isolated per scope: each user has their own implicit personal scope, and can be a member of any number of shared scopes - with read-only or read-write access. On the server, database operations need to be wrapped in a special `session.db.transactionForUser` method to target the correct scope. On the client, it is possible to set a `persistentUserId` to target the personal scope by default, or use the `transactionForUser` to target a shared scope.

#### Data modeling limitations

Due to the nature of merge conflicts, the package imposes some limitations on the data modeling that are enforced at runtime during the initialization. Most of these limitations are fundamental to the design of the package and can never be lifted.

- Every synced table must:
  - Have a UUID primary key.
  - Declare the field `scopeId: int?, relation(parent=crdt_scopes, onDelete=Cascade)`.
- Unique indexes must include `scopeId` together with the target columns.
- Global unique indexes are unsupported, except for FK-only indexes.
- Unique indexes are only supported with at least one `String`/`UuidValue`/nullable column.
- All 1:1 relations must have the foreign-key column nullable (`optional` relation).
- The only allowed non-synced-to-synced relation is `scopeId -> crdt_scopes.id`.
- All foreign-key relations must be `deferrable`* (see the technical debts section).

Respecting these limitations, all other database invariants, including foreign-key actions, are preserved - with the exception of check constraints, which are also not supported by Serverpod.

### The end-user experience

The bundled desktop demo shows the model directly: two independent replicas of one account side by side, plus the server's merged truth. Drive each replica's sync independently and watch them converge under all common usage scenarios. It visualizes hidden / tombstoned rows and every foreign-key `onDelete` action, with guided scenarios for the restrict / cascade / set-null / set-default / unique-conflict cases.

### Performance

One common concern about offline-first solutions is the performance impact of the CRDT layer. Since all operations are tracked, it can weigh heavily on both storage and speed. This package was created with this concern in mind, achieving a minimal performance penalty.

Below is one of the last performance reports of the package (available at each pull request as a comment). It uses 1,000 rows to measure the performance against a baseline of the same operations without the CRDT layer, both on SQLite:

```
📊 SELECT performance impact:
  Time: 12.62 ms --> 12.67 ms (48.50 μs)
  CRDT overhead: 0.38% slower
```
```
📊 INSERT performance impact:
  Time: 251.01 ms --> 482.05 ms (231.04 ms)
  CRDT overhead: 92.04% slower
  Delay per insert: 231.04 μs
```
```
📊 UPDATE performance impact:
  Time: 249.57 ms --> 2.13 s (1.88 s)
  CRDT overhead: 753.54% slower
  Delay per update: 1.88 ms
```
```
📊 DELETE performance impact:
  Time: 11.53 ms --> 420.28 ms (408.75 ms)
  CRDT overhead: 3,546.27% slower
  Delay per delete: 408.75 μs
```
```
🔭 SELECT scope impact (100 extra users, 100,000 CRDT noise rows):
  find all (1,000 rows): 9.91 ms --> 10.91 ms scoped (+10.07%) / 11.19 ms unscoped (+12.96%)
  findById (per lookup): 295.04 μs --> 375.24 μs scoped (+27.19%) / 348.88 μs unscoped (+18.25%)
```
```
💽 Storage impact (base footprint removed):
  Base database size: 540.00 KB --> 540.00 KB
  INSERT only:
    Net storage: 116.00 KB --> 188.00 KB (+72.00 KB)
    CRDT overhead: 62.07% increase
    Extra storage per inserted row: +73.73 B
  INSERT + UPDATE:
    Net storage: 128.00 KB --> 472.00 KB (+344.00 KB)
    CRDT overhead: 268.75% increase
    Extra storage per updated column: +34.82 B
  INSERT + UPDATE + DELETE:
    Net storage: 128.00 KB --> 512.00 KB (+384.00 KB)
    CRDT overhead: 300.00% increase
    Extra storage per deleted row: +40.96 B
  Storage overhead range: 62.07% --> 300.00%
```

Despite the high percentage of slowdown in the insert/update/delete operations, the absolute impact is mostly in the microsecond range, making it barely noticeable in most cases - and way below a network delay if those operations were to be performed through an online endpoint.

The storage impact is also minimal, reaching at most 3x the base storage size, which is perfectly acceptable for the benefits of offline-first speed and availability.

A report similar to the one above is generated per pull request as a comment on the CI to track the performance evolution of the package.

## Technical fundamentals

**Architecture.** The engine is a transparent layer between the application and its database. Its models and database implementation live in the shared package, while the client package only binds the generated module caller to the shared sync transport. Because identical code runs on the client's SQLite and the server's Postgres, there are no asymmetric merge results to reconcile. Migrations are also generated symmetrically for both ends, which makes the migration process result in the exact same data on both ends. The entire engine is built respecting the three mathematical properties that must hold for a CRDT to be consistent: idempotence, associativity, and commutativity.

**Metadata model.** Three metadata tables track change history *without copying row data*: `crdt_data_rows` (insert + visibility), `crdt_data_fields` (update), and `crdt_data_tombstone` (delete/restore). HLCs are used to order field-level values and break ties. A monotone causal-length tombstone governs row existence, so add/delete/restore advance generations forward and can never oscillate. All metadata is normalized, with normalized IDs cached, to keep both the storage and performance impact minimal.

**Visibility as a pure function.** Replicas never coordinate. Each merge applies remote facts monotonically, then derives the visible database — tombstone state, unique-conflict winners, and foreign-key repair — as a deterministic projection computed to a fixed point. This is the architecture introduced by *Synql* (Ignat et al., DAIS 2024), extended here to the full set of `ON DELETE` actions and to unique constraints over deeply relational schemas.

**Ownership & scopes.** A *scope* is the unit of replication and ownership; a *user* is an authentication identity. Each row is globally identified by `(table, rowId)` and owned by exactly one scope (`scopeId`), so merging is always one chain per row. Sharing is a membership layer in front of scopes, not a change to row ownership. Scopes can be purged for GDPR / account erasure via a database-enforced cascade. Ownership collisions (the same `(table, rowId)` claimed by two scopes, which is mostly a malicious attack vector) fail the sync and are recorded in a durable `crdt_sync_integrity_violations` table.

**Sync protocol.** A session handshakes once to validate both ends have the same table schema and ensure that a merge will reach the same result. Then, per cycle the server sends the authoritative scope set and all scopes that the user has access to are synced (data is transferred all at once, but merged one at a time). The data is transferred in chunks to avoid pressuring the bandwidth with too many small messages. This same stream-based implementation is used for both "one-shot" and "continuous" sync modes, so a one-shot sync with large amounts of data will be as performant as a continuous sync. It also means that all tests hold for both sync modes with minimal duplication.

## Testing

The package is tested extensively following the Serverpod testing principles. The vast majority of the tests live in the `serverpod_offline_sync_test_server` package, which is a Serverpod project that is used to test the package. Its server is also shared with the `example/offline_sync_demo` project, which is a real-world application that uses the package.

## Roadmap

The package is functionally in a production-ready state, but some APIs need to improve the UX and it must naturally pass through a review process to be merged into the Serverpod monorepo. Before the review, some minor technical debts must be solved.

### Technical debts

- **Require that all foreign-key relations are declared deferrable**. Because the package does not store a copy of the data with the metadata, there are some scenarios in which the stored data might violate the causal order of the foreign-key constraints and a merge can fail irreversibly. To prevent this, all foreign-key constraints must be deferrable, which will be enabled by Serverpod's issue #5338.
- **Rename the `scope` name for data isolation to `space`**. This is a small refactor to avoid confusion with the `scope` keyword used in the Serverpod Auth modules. Using `space` is also clearer for usage on an application level.

### Post-integration UX improvements

The package already requires minimal configuration from the developer, but it can be even smoother if the `serverpod_cli` is made aware of the offline sync capabilities.

- **Add a fourth `sync` option for the `database` keyword to be used on models**. Models that use it will automatically receive the `scopeId` relation and be included in a generated list of synced tables on the server and client. This feature will enable all improvements below.
- **Simplify the `Serverpod` initialization by generating the class**. This is mapped on Serverpod's issue #4544 and will allow the CRDT database interceptor to be injected on the `Serverpod` constructor without the user having to call it manually whenever a `sync` model exists.
- **Move the restrictions that are runtime-enforced to a static analysis step**. The package enforces the limitations of the CRDT layer at runtime (during the initialization), but a better UX would be to apply the restrictions to `sync` models during static analysis of `generate`.
- **Inject the `serverpod_offline_sync` packages on the `pubspec.yaml` file**. This would remove the last manual step from the developer to make the solution work. Otherwise, the user will have to manually add the dependencies to their `pubspec.yaml` to generate the project.

If these changes are made, all a user will have to do is to add the `sync` keyword to the `database` keyword on synced table models and the package will be completely wired up.

Given that all these changes are on the `serverpod_cli`, it doesn't even require other internal packages to depend on the `serverpod_offline_sync` packages.

### Review strategy

Besides not being that big (~35k LOC for the packages, ~14k LOC for the tests), the codebase is dense on the logic. So the best way to review it is to read the performance reports first, then all tests, and finally the main files of the packages as needed.

The design docs can also be used as a reference to understand the architecture and the implementation, as they were kept in sync throughout the development process.

### Transference process

The license transfer and transference process will be done following the steps below:

1. A branch transferring the copyrights to the Serverpod organization will be merged into the main branch of the original repository.
2. The original repository with the updated license will be made public on GitHub by the author. This copy will be kept for historical purposes and as a portfolio of the author's work.
3. The package will be reviewed by the Serverpod team on the original repository to prepare the codebase for the transference.
4. After all changes originated from the review are merged into the main branch, a PR will be created to merge the packages on the Serverpod monorepo, preserving its commit history.
5. With the PR merged on Serverpod's monorepo, the original repository will be archived with a note about the new location of the package.
