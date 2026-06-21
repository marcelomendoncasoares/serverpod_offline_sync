import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show CrdtDatabase, CrdtScope;

import '../generated/protocol.dart';

/// Read-only inspection endpoint used by the offline-sync demo app to show the
/// server's merged truth for the authenticated user's scope.
class DemoDebugEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Returns every synced row visible to the caller's scope on the server. When
  /// [includeHidden] is true, also returns the physically-present rows that are
  /// CRDT-hidden in the scope (conflict losers, soft-deleted rows), read raw so
  /// the demo's "Server" panel can mirror the replica "show hidden" view.
  Future<DemoServerSnapshot> fetchScopeSnapshot(
    Session session, {
    bool includeHidden = false,
  }) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    final DemoServerSnapshot snapshot;
    if (db is CrdtDatabase) {
      // Run the reads in the caller's scope so the snapshot reflects what this
      // user sees, not an unscoped admin view across every scope.
      snapshot = await db.transactionForUser(
        userId,
        (transaction) => _loadSnapshot(session, transaction),
      );
    } else {
      snapshot = await _loadSnapshot(session, null);
    }

    if (includeHidden && db is CrdtDatabase) {
      snapshot.hiddenRows = await _loadHiddenRows(session, userId, snapshot);
    }
    return snapshot;
  }

  /// Reads each rendered table's physical rows for the caller's scope (raw, so
  /// CRDT-hidden rows are included) and returns those whose id is not in the
  /// visible [snapshot]. Best effort: a table that fails to read raw simply
  /// contributes no hidden rows.
  Future<List<DemoHiddenRow>> _loadHiddenRows(
    Session session,
    UuidValue userId,
    DemoServerSnapshot snapshot,
  ) async {
    final scope = await CrdtScope.db.findFirstRow(
      session,
      where: (t) => t.uuidScopeId.equals(userId),
    );
    final scopeId = scope?.id;
    if (scopeId == null) return [];

    Set<String> ids(Iterable<dynamic> rows) => {
      for (final row in rows)
        if (row.id != null) '${row.id.uuid}',
    };

    final visibleByTable = <String, Set<String>>{
      'person': ids(snapshot.people),
      'address': ids(snapshot.addresses),
      'city': ids(snapshot.cities),
      'town': ids(snapshot.towns),
      'unique': ids(snapshot.uniques),
      'unique_uuid': ids(snapshot.uniqueUuids),
      'restrict_child': ids(snapshot.restrictChildren),
      'types': ids(snapshot.types),
      'fk_chain_root': ids(snapshot.fkChainRoots),
      'fk_chain_cascade_middle': ids(snapshot.fkChainCascadeMiddles),
      'fk_chain_restrict_blocker': ids(snapshot.fkChainRestrictBlockers),
      'fk_chain_middle_set_null_child': ids(snapshot.fkChainMiddleSetNullChildren),
      'fk_chain_middle_cascade_child': ids(snapshot.fkChainMiddleCascadeChildren),
    };

    final hidden = <DemoHiddenRow>[];
    for (final entry in visibleByTable.entries) {
      final table = entry.key;
      final visibleIds = entry.value;
      try {
        final result = await session.db.unsafeQuery(
          'SELECT * FROM "${_escapeIdentifier(table)}" WHERE "scopeId" = $scopeId',
        );
        for (final row in result) {
          final map = {
            for (final entry in row.toColumnMap().entries)
              entry.key: _coerceColumnValue(entry.value),
          };
          final id = map['id'];
          if (id is! String || visibleIds.contains(id)) continue;
          hidden.add(
            DemoHiddenRow(table: table, encodedJson: jsonEncode(map)),
          );
        }
      } on Exception catch (_) {
        // Skip tables that cannot be read raw on this backend.
      }
    }
    return hidden;
  }

  /// Coerces a raw column value to a JSON-encodable form. The demo only needs
  /// the id, label, and foreign-key columns; uuids are stored as 16-byte blobs
  /// in SQLite, so those are rendered back to the canonical uuid string the
  /// client compares against.
  Object? _coerceColumnValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List<int> && value.length == 16) {
      return _uuidStringFromBytes(value);
    }
    return value.toString();
  }

  String _uuidStringFromBytes(List<int> bytes) {
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Hard-deletes every synced row and CRDT metadata row in the caller's scope,
  /// clearing the server for a fresh demo run.
  Future<void> resetScope(Session session) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is CrdtDatabase) {
      await db.initialize();
    }
    await db.transaction((transaction) async {
      final scope = await CrdtScope.db.findFirstRow(
        session,
        where: (t) => t.uuidScopeId.equals(userId),
        transaction: transaction,
      );
      final scopeId = scope?.id;
      if (scopeId == null) return;

      for (final tableName in _demoScopedTablesDeleteOrder) {
        await _deleteScopedRows(session, transaction, tableName, scopeId);
      }
      await _deleteCrdtRowsForScope(session, transaction, scopeId);
    });
    if (db is CrdtDatabase) {
      await db.initialize();
    }
  }

  /// Inserts demo rows of [kind] directly into the caller's scope on the server,
  /// without going through a replica. Lets the "Server" seed target exercise the
  /// fetch-from-scratch flow: seed here, reset a replica, then sync to pull it
  /// down. [text] carries an optional name/value for the single-row kinds.
  Future<void> seedScope(Session session, String kind, String? text) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is! CrdtDatabase) return;

    final tag = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

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

  Future<DemoServerSnapshot> _loadSnapshot(
    Session session,
    Transaction? transaction,
  ) async {
    return DemoServerSnapshot(
      people: await Person.db.find(session, transaction: transaction),
      addresses: await Address.db.find(session, transaction: transaction),
      cities: await City.db.find(session, transaction: transaction),
      towns: await Town.db.find(session, transaction: transaction),
      uniques: await Unique.db.find(session, transaction: transaction),
      uniqueUuids: await UniqueUuid.db.find(session, transaction: transaction),
      restrictChildren: await RestrictChild.db.find(
        session,
        transaction: transaction,
      ),
      types: await Types.db.find(session, transaction: transaction),
      fkChainRoots: await FkChainRoot.db.find(
        session,
        transaction: transaction,
      ),
      fkChainCascadeMiddles: await FkChainCascadeMiddle.db.find(
        session,
        transaction: transaction,
      ),
      fkChainRestrictBlockers: await FkChainRestrictBlocker.db.find(
        session,
        transaction: transaction,
      ),
      fkChainMiddleSetNullChildren: await FkChainMiddleSetNullChild.db.find(
        session,
        transaction: transaction,
      ),
      fkChainMiddleCascadeChildren: await FkChainMiddleCascadeChild.db.find(
        session,
        transaction: transaction,
      ),
    );
  }
}

const _demoScopedTablesDeleteOrder = [
  'address',
  'restrict_child',
  'required_set_null_child',
  'unique_set_null_child',
  'fk_chain_middle_cascade_child',
  'fk_chain_middle_set_null_child',
  'fk_chain_set_null_cascade_child',
  'fk_chain_set_null_restrict_child',
  'fk_chain_set_null_set_null_child',
  'fk_chain_restrict_blocker',
  'fk_chain_set_null_middle',
  'fk_chain_cascade_middle',
  'fk_chain_root',
  'person',
  'company',
  'organization',
  'town',
  'city',
  'types',
  'unique',
  'unique_composite',
  'unique_uuid',
];

Future<void> _deleteScopedRows(
  Session session,
  Transaction transaction,
  String tableName,
  int scopeId,
) async {
  await _executeResetSql(
    session,
    transaction,
    'delete $tableName rows for scope $scopeId',
    'DELETE FROM "${_escapeIdentifier(tableName)}" WHERE "scopeId" = $scopeId',
  );
}

Future<void> _deleteCrdtRowsForScope(
  Session session,
  Transaction transaction,
  int scopeId,
) async {
  await _executeResetSql(
    session,
    transaction,
    'delete projected foreign-key metadata for scope $scopeId',
    '''
DELETE FROM "crdt_data_foreign_key"
WHERE "fieldId" IN (
  SELECT f."id"
  FROM "crdt_data_fields" f
  WHERE f."rowId" IN (
    SELECT "id"
    FROM "crdt_data_rows"
    WHERE "scopeId" = $scopeId
  )
  OR NOT EXISTS (
    SELECT 1
    FROM "crdt_data_rows" r
    WHERE r."id" = f."rowId"
  )
)
OR NOT EXISTS (
  SELECT 1
  FROM "crdt_data_fields" f
  WHERE f."id" = "crdt_data_foreign_key"."fieldId"
)
''',
  );
  await _executeResetSql(
    session,
    transaction,
    'delete tombstone metadata for scope $scopeId',
    '''
DELETE FROM "crdt_data_tombstone"
WHERE "rowId" IN (
  SELECT "id"
  FROM "crdt_data_rows"
  WHERE "scopeId" = $scopeId
)
OR NOT EXISTS (
  SELECT 1
  FROM "crdt_data_rows" r
  WHERE r."id" = "crdt_data_tombstone"."rowId"
)
''',
  );
  await _executeResetSql(
    session,
    transaction,
    'delete field metadata for scope $scopeId',
    '''
DELETE FROM "crdt_data_fields"
WHERE "rowId" IN (
  SELECT "id"
  FROM "crdt_data_rows"
  WHERE "scopeId" = $scopeId
)
OR NOT EXISTS (
  SELECT 1
  FROM "crdt_data_rows" r
  WHERE r."id" = "crdt_data_fields"."rowId"
)
''',
  );
  await _executeResetSql(
    session,
    transaction,
    'detach current CRDT node for scope $scopeId',
    'UPDATE "crdt_scopes" SET "currentNodeId" = NULL WHERE "id" = $scopeId',
  );
  await _executeResetSql(
    session,
    transaction,
    'delete row metadata for scope $scopeId',
    'DELETE FROM "crdt_data_rows" WHERE "scopeId" = $scopeId',
  );
  await _executeResetSql(
    session,
    transaction,
    'delete node metadata for scope $scopeId',
    'DELETE FROM "crdt_nodes" WHERE "scopeId" = $scopeId',
  );
}

String _escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

Future<void> _executeResetSql(
  Session session,
  Transaction transaction,
  String label,
  String sql,
) async {
  try {
    await session.db.unsafeExecute(sql, transaction: transaction);
  } catch (error) {
    throw Exception('Failed to $label: $error');
  }
}
