import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  final clientSyncTables = [client.Person.t, client.Unique.t];
  final serverSyncTables = [server.Person.t, server.Unique.t];

  group('Given a CRDT session with a unique conflict callback, ', () {
    test(
      'when a merge materializes multiple unique conflicts, '
      'then the callback is invoked once with all conflicts.',
      () async {
        final callbackConflicts = <UniqueConflictContext>[];
        UuidValue? callbackUserId;
        var callbackCount = 0;
        final crdtSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          onUniqueConflicts: (_, userId, conflicts) {
            callbackCount++;
            callbackUserId = userId;
            callbackConflicts.addAll(conflicts);
          },
        );
        await crdtSession.db.initialize();

        final winningRowId = const Uuid().v7obj();
        final firstLosingRowId = const Uuid().v7obj();
        final secondLosingRowId = const Uuid().v7obj();

        await crdtSession.db.mergeChanges(
          _uniqueInsertMergeSet(
            rowIds: [winningRowId, firstLosingRowId, secondLosingRowId],
          ),
          userId: testCrdtUserId,
        );

        expect(callbackCount, 1);
        expect(callbackUserId, testCrdtUserId);
        expect(callbackConflicts, hasLength(2));
        final conflictsByLosingRowId = {
          for (final conflict in callbackConflicts)
            (conflict.row as client.Unique).id!: conflict,
        };
        expect(conflictsByLosingRowId.keys, {
          firstLosingRowId,
          secondLosingRowId,
        });

        for (final losingRowId in [firstLosingRowId, secondLosingRowId]) {
          final conflict = conflictsByLosingRowId[losingRowId]!;
          final row = conflict.row as client.Unique;
          final existingRow = conflict.existingRow as client.Unique;

          expect(row.id, losingRowId);
          expect(row.name, _conflictName(losingRowId));
          expect(existingRow.id, winningRowId);
          expect(existingRow.name, 'shared-name');
          expect(conflict.columns, {client.Unique.t.name.columnName});
          expect(conflict.conflictingValues, {
            client.Unique.t.name.columnName: 'shared-name',
          });
          expect(conflict.replacementValues, {
            client.Unique.t.name.columnName: _conflictName(losingRowId),
          });
        }
      },
    );

    test(
      'when a callback operation fails, '
      'then the merge remains committed.',
      () async {
        var callbackWasCalled = false;
        final crdtSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          onUniqueConflicts: (callbackSession, _, _) async {
            callbackWasCalled = true;
            await client.Unique.db.insertRow(
              callbackSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );
          },
        );
        await crdtSession.db.initialize();

        final winningRowId = const Uuid().v7obj();
        final losingRowId = const Uuid().v7obj();
        await crdtSession.db.mergeChanges(
          _uniqueInsertMergeSet(rowIds: [winningRowId, losingRowId]),
          userId: testCrdtUserId,
        );

        final rows = await client.Unique.db.find(crdtSession);

        expect(callbackWasCalled, isTrue);
        expect(rows, hasLength(2));
        expect(rows.singleWhere((row) => row.id == winningRowId).name, 'shared-name');
        expect(
          rows.singleWhere((row) => row.id == losingRowId).name,
          _conflictName(losingRowId),
        );
      },
    );

    test(
      'when the callback updates a row, '
      'then the callback operation records a new local HLC.',
      () async {
        final losingRowId = const Uuid().v7obj();
        late UuidValue localNodeId;
        final crdtSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          onUniqueConflicts: (callbackSession, _, conflicts) async {
            final row = conflicts.single.row as client.Unique;
            await client.Unique.db.updateRow(
              callbackSession,
              row.copyWith(name: _callbackName(row.id!)),
              columns: (t) => [t.name],
            );
          },
        );
        await crdtSession.db.initialize();
        localNodeId = await crdtSession.db.currentNodeId(userId: testCrdtUserId);

        await crdtSession.db.mergeChanges(
          _uniqueInsertMergeSet(
            rowIds: [const Uuid().v7obj(), losingRowId],
          ),
          userId: testCrdtUserId,
        );

        final callbackFieldHlc = await _uniqueNameHlc(crdtSession, losingRowId);

        await _expectClientUniqueName(
          crdtSession,
          losingRowId,
          _callbackName(losingRowId),
        );
        expect(callbackFieldHlc.nodeId, localNodeId);
      },
    );
  });

  withServerpod(
    'Given a server and two client CRDT sessions with the same unique conflict callback, ',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      late client.Client syncHttpClient;
      late CrdtDatabaseSession serverSession;
      late CrdtDatabaseSession firstClientSession;
      late CrdtDatabaseSession secondClientSession;

      setUp(() async {
        syncHttpClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        firstClientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          onUniqueConflicts: _resolveLosingUniqueRows,
        );
        await firstClientSession.db.initialize();

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          onUniqueConflicts: _resolveLosingUniqueRows,
        );
        await secondClientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      test(
        'when both clients merge the same unique conflict and then exchange changes, '
        'then they converge to the same callback field HLC.',
        () async {
          final winningRowId = const Uuid().v7obj();
          final losingRowId = const Uuid().v7obj();
          final mergeSet = _uniqueInsertMergeSet(
            rowIds: [winningRowId, losingRowId],
          );

          await firstClientSession.db.mergeChanges(
            mergeSet,
            userId: testCrdtUserId,
          );
          await secondClientSession.db.mergeChanges(
            mergeSet,
            userId: testCrdtUserId,
          );

          await syncHttpClient.crdt.syncOnce(firstClientSession);
          await syncHttpClient.crdt.syncOnce(secondClientSession);
          await syncHttpClient.crdt.syncOnce(firstClientSession);
          await syncHttpClient.crdt.syncOnce(secondClientSession);
          await syncHttpClient.crdt.syncOnce(firstClientSession);

          final firstHlc = await _uniqueNameHlc(firstClientSession, losingRowId);
          final secondHlc = await _uniqueNameHlc(secondClientSession, losingRowId);
          final serverHlc = await _uniqueNameHlc(serverSession, losingRowId);

          expect(firstHlc, secondHlc);
          expect(secondHlc, serverHlc);
          await _expectClientUniqueName(
            firstClientSession,
            losingRowId,
            _callbackName(losingRowId),
          );
          await _expectClientUniqueName(
            secondClientSession,
            losingRowId,
            _callbackName(losingRowId),
          );
          await _expectServerUniqueName(
            serverSession,
            losingRowId,
            _callbackName(losingRowId),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    },
  );
}

CrdtMergeSet _uniqueInsertMergeSet({
  required List<UuidValue> rowIds,
}) {
  final firstHlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
  return [
    for (final (index, rowId) in rowIds.indexed)
      CrdtMergeInsert(
        tableName: client.Unique.t.tableName,
        uuidRowId: rowId,
        uuidNodeId: index == 0 ? firstHlc.nodeId : const Uuid().v7obj(),
        hlcDatetime: firstHlc.datetime.add(Duration(milliseconds: index)),
        hlcCounter: firstHlc.counter,
        data: client.Unique(id: rowId, name: 'shared-name'),
      ),
  ];
}

Future<void> _resolveLosingUniqueRows(
  DatabaseSession session,
  UuidValue _,
  List<UniqueConflictContext> conflicts,
) async {
  for (final conflict in conflicts) {
    final row = conflict.row as client.Unique;
    await client.Unique.db.updateRow(
      session,
      row.copyWith(name: _callbackName(row.id!)),
      columns: (t) => [t.name],
    );
  }
}

Future<Hlc> _uniqueNameHlc(DatabaseSession session, UuidValue rowId) async {
  final field = await CrdtDataField.db.findFirstRow(
    session,
    where: (t) =>
        t.row.uuidRowId.equals(rowId) &
        t.column.name.equals(client.Unique.t.name.columnName),
    include: CrdtDataField.include(node: CrdtNode.include()),
  );

  return field!.hlc;
}

Future<void> _expectClientUniqueName(
  DatabaseSession session,
  UuidValue rowId,
  String name,
) async {
  final row = await client.Unique.db.findById(session, rowId);

  expect(row, isNotNull);
  expect(row!.name, name);
}

Future<void> _expectServerUniqueName(
  DatabaseSession session,
  UuidValue rowId,
  String name,
) async {
  final row = await server.Unique.db.findById(session, rowId);

  expect(row, isNotNull);
  expect(row!.name, name);
}

String _conflictName(UuidValue rowId) {
  return 'shared-name__conflict__${rowId.uuid}';
}

String _callbackName(UuidValue rowId) {
  return 'callback-${rowId.uuid}';
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
