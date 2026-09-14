import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show IncludeTombstonedRows, OfflineSyncDatabase, OfflineSyncSpace;

import '../generated/protocol.dart';

/// Read-only inspection endpoint used by the offline-sync demo app to show the
/// server's merged truth for the authenticated user's space.
class DemoDebugEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Returns every synced domain row in the caller's space on the server as a
  /// flat list of models. When [includeHidden] is true, the list also includes
  /// CRDT-hidden rows (conflict losers, soft-deleted rows) via the
  /// `t.includeHiddenRows` expression; otherwise only visible rows are returned.
  ///
  /// The rows cross the wire as `dynamic`: Serverpod tags each model with its
  /// class name — the same mechanism the CRDT sync layer uses — so the client
  /// deserializes them straight back into typed models with no per-table
  /// plumbing on either side. The client flags hidden rows by diffing a
  /// visible-only fetch against an include-hidden one.
  Future<List<dynamic>> fetchSpaceSnapshot(
    Session session, {
    bool includeHidden = false,
  }) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is! OfflineSyncDatabase) {
      return _loadRows(session, null, includeHidden: false, spaceId: null);
    }

    // Run the reads in the caller's space so the snapshot reflects what this
    // user sees, not an unscoped admin view across every space.
    return db.transactionForUser(userId, (transaction) async {
      final space = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(userId),
        transaction: transaction,
      );
      return _loadRows(
        session,
        transaction,
        includeHidden: includeHidden,
        spaceId: space?.id,
      );
    });
  }

  /// Clears the caller's space by deleting its `offline_sync_spaces` row. Every synced
  /// table cascades on `spaceId` → `offline_sync_spaces`, so all domain rows and CRDT
  /// metadata are removed with it — no manual per-table cleanup needed.
  ///
  /// The delete runs with `defer_foreign_keys` on: the spaceId cascade fans out
  /// across the CRDT metadata diamond (`crdt_data_rows`/`crdt_data_fields`/
  /// `crdt_data_tombstone` reference `crdt_nodes` with NO ACTION while both sides
  /// cascade off `offline_sync_spaces`), and SQLite's cascade order can transiently
  /// violate those immediate checks. Deferring them to commit lets the whole
  /// cascade complete first.
  Future<void> resetSpace(Session session) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is OfflineSyncDatabase) {
      await db.initialize();
    }
    final space = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(userId),
    );
    final spaceId = space?.id;
    if (spaceId != null) {
      await db.transaction((transaction) async {
        // TODO: Remove this explicit call to defer foreign keys once foreign
        // keys are deferrable by default on the Serverpod package.
        await db.unsafeExecute(
          'PRAGMA defer_foreign_keys = ON',
          transaction: transaction,
        );
        await OfflineSyncSpace.db.deleteWhere(
          session,
          where: (t) => t.id.equals(spaceId),
          transaction: transaction,
        );
      });
    }
    if (db is OfflineSyncDatabase) {
      await db.initialize();
    }
  }

  /// Inserts demo rows of [kind] directly into the caller's space on the server,
  /// without going through a replica. Lets the "Server" seed target exercise the
  /// fetch-from-scratch flow: seed here, reset a replica, then sync to pull it
  /// down. [text] carries an optional name/value for the single-row kinds.
  Future<void> seedSpace(Session session, String kind, String? text) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is! OfflineSyncDatabase) {
      throw StateError('This endpoint only works with a CRDT database.');
    }

    final tag = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

    // TODO: Expose the [transactionForUser] through an extension method on the
    // base [Database] class so the cast is unnecessary.
    await db.transactionForUser(userId, (transaction) async {
      switch (kind) {
        case 'basicGraph':
          final city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'Server City $tag'),
            transaction: transaction,
          );
          await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'Server Town $tag',
              cityId: city.id,
            ),
            transaction: transaction,
          );
          final person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'Server Person $tag',
              surname: 'Remote',
            ),
            transaction: transaction,
          );
          await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'Server Street $tag',
              inhabitantId: person.id,
            ),
            transaction: transaction,
          );
        case 'typedRow':
          await Types.db.insertRow(
            session,
            Types(
              id: const Uuid().v7obj(),
              aBool: true,
              aDateTime: DateTime.now().toUtc(),
              aText: 'server-typed-$tag',
              anInt: 7,
              anInt64: BigInt.parse('9007199254740993'),
              aReal: 1.5,
              aBlob: ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
              anEnum: TypesEnum.alpha,
              optionalText: 'server-$tag',
              optionalUuid: const Uuid().v7obj(),
            ),
            transaction: transaction,
          );
        case 'person':
          final name = (text == null || text.isEmpty)
              ? 'Server Person $tag'
              : '$text $tag';
          await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: name),
            transaction: transaction,
          );
        case 'restrictChild':
          final people = await Person.db.find(session, transaction: transaction);
          Person? parent;
          for (final person in people) {
            if (person.id != null) {
              parent = person;
              break;
            }
          }
          if (parent == null) {
            throw StateError(
              'Seed or sync a visible Person before adding RestrictChild.',
            );
          }
          await RestrictChild.db.insertRow(
            session,
            RestrictChild(
              id: const Uuid().v7obj(),
              name: 'Server restrict child $tag',
              parentId: parent.id,
            ),
            transaction: transaction,
          );
        case 'unique':
          await Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: text ?? 'server-unique-$tag'),
            transaction: transaction,
          );
        case 'uniqueUuid':
          final value = (text == null || text.isEmpty)
              ? const Uuid().v7obj()
              : UuidValue.withValidation(text);
          await UniqueUuid.db.insertRow(
            session,
            UniqueUuid(id: const Uuid().v7obj(), value: value),
            transaction: transaction,
          );
        case 'fkChain':
          final root = await FkChainRoot.db.insertRow(
            session,
            FkChainRoot(id: const Uuid().v7obj(), name: 'Server Root $tag'),
            transaction: transaction,
          );
          final middle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'Server Cascade middle $tag',
              rootId: root.id,
            ),
            transaction: transaction,
          );
          final blocker = await FkChainRestrictBlocker.db.insertRow(
            session,
            FkChainRestrictBlocker(
              id: const Uuid().v7obj(),
              name: 'Server Blocker $tag',
              cascadeMiddleId: middle.id,
            ),
            transaction: transaction,
          );
          await FkChainMiddleSetNullChild.db.insertRow(
            session,
            FkChainMiddleSetNullChild(
              id: const Uuid().v7obj(),
              name: 'Server set-null child $tag',
              restrictBlockerId: blocker.id,
            ),
            transaction: transaction,
          );
          await FkChainMiddleCascadeChild.db.insertRow(
            session,
            FkChainMiddleCascadeChild(
              id: const Uuid().v7obj(),
              name: 'Server cascade child $tag',
              restrictBlockerId: blocker.id,
            ),
            transaction: transaction,
          );
      }
    });
  }

  /// Loads every synced domain row in the caller's space as a flat list of
  /// models. When [includeHidden] is true, CRDT-hidden rows are returned too
  /// via the `t.includeHiddenRows` expression.
  ///
  /// `includeHiddenRows` is an extension on any [Table], so the read is uniform
  /// across every synced type — each table is listed once because Dart cannot
  /// turn a runtime [Table] back into the compile-time `T` that
  /// `session.db.find<T>` requires.
  Future<List<dynamic>> _loadRows(
    Session session,
    Transaction? transaction, {
    required bool includeHidden,
    required int? spaceId,
  }) async {
    final rows = <dynamic>[];
    Future<void> add<T extends TableRow>() async {
      rows.addAll(
        await session.db.find<T>(
          where: includeHidden ? _includeHiddenRowsInSpace<T>(session, spaceId) : null,
          transaction: transaction,
        ),
      );
    }

    await add<Person>();
    await add<Address>();
    await add<City>();
    await add<Town>();
    await add<Organization>();
    await add<Company>();
    await add<RestrictChild>();
    await add<RequiredSetNullChild>();
    await add<Unique>();
    await add<UniqueUuid>();
    await add<UniqueComposite>();
    await add<UniqueDiscriminator>();
    await add<UniqueSetNullChild>();
    await add<Types>();
    await add<FkChainRoot>();
    await add<FkChainCascadeMiddle>();
    await add<FkChainRestrictBlocker>();
    await add<FkChainMiddleSetNullChild>();
    await add<FkChainMiddleCascadeChild>();
    await add<FkChainSetNullMiddle>();
    await add<FkChainSetNullCascadeChild>();
    await add<FkChainSetNullRestrictChild>();
    await add<FkChainSetNullSetNullChild>();
    return rows;
  }

  Expression _includeHiddenRowsInSpace<T extends TableRow>(
    Session session,
    int? spaceId,
  ) {
    if (spaceId == null) {
      throw StateError('Cannot include hidden rows without a CRDT space.');
    }

    final table =
        session.db.serializationManager.getTableForType(T) ??
        (throw StateError('No table is registered for type $T.'));
    return _spaceIdColumn(table).equals(spaceId) & table.includeHiddenRows;
  }

  ColumnInt _spaceIdColumn(Table table) {
    for (final column in table.columns) {
      if (column.columnName == 'spaceId' && column is ColumnInt) {
        return column;
      }
    }
    throw StateError('Synced table "${table.tableName}" has no spaceId column.');
  }
}
