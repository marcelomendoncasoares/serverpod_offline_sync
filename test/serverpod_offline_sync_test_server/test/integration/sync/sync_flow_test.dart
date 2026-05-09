// Uses serverpod_database types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  final syncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];

  late Directory serverDirectory;
  late DatabaseSession serverDataSession;
  late CrdtDatabaseSession serverCrdtSession;
  late CrdtDatabaseSession clientCrdtSession;

  setUp(() async {
    serverDirectory = await Directory.systemTemp.createTemp('crdt_sync_server_');
    serverDataSession = await testClient.createSession(
      p.join(serverDirectory.path, 'server.db'),
      isDebugMode: true,
    );
    serverCrdtSession = CrdtDatabaseSession.wraps(
      serverDataSession,
      syncTables: syncTables,
    );
    await serverCrdtSession.db.initialize();

    clientCrdtSession = CrdtDatabaseSession.wraps(
      testSession,
      syncTables: syncTables,
      persistentUserId: testCrdtUserId,
      syncCaller: _DirectSyncCaller(serverDataSession, testCrdtUserId),
    );
    await clientCrdtSession.db.initialize();

    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: serverDataSession.db.serializationManager,
    );
  });

  tearDown(() async {
    await (serverDataSession as dynamic).close();
    if (serverDirectory.existsSync()) {
      await serverDirectory.delete(recursive: true);
    }
  });

  group('Given one-way sync helpers', () {
    test(
      'when crdtDb syncOnce is called then the server merges the client pending changes.',
      () async {
        final personId = const Uuid().v7obj();

        await clientCrdtSession.db.transaction((tx) async {
          await client.Person.db.insertRow(
            clientCrdtSession,
            client.Person(id: personId, name: 'client-person'),
            transaction: tx,
          );
        });

        await clientCrdtSession.crdtDb.syncOnce();

        final serverPerson = await client.Person.db.findById(
          serverDataSession,
          personId,
        );
        expect(serverPerson, isNotNull);
        expect(serverPerson!.name, 'client-person');
      },
    );
  });

  group('Given bidirectional sync helpers', () {
    test(
      'when crdtDb syncContinuously is called then the client and server reach the same end state.',
      () async {
        final sharedPersonId = const Uuid().v7obj();

        await serverCrdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
          await client.Person.db.insertRow(
            serverCrdtSession,
            client.Person(
              id: sharedPersonId,
              name: 'base-name',
              surname: 'base-surname',
            ),
            transaction: tx,
          );
        });

        await clientCrdtSession.crdtDb.syncContinuously();

        final clientSharedPerson = await client.Person.db.findById(
          testSession,
          sharedPersonId,
        );

        await serverCrdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
          await client.Person.db.updateRow(
            serverCrdtSession,
            client.Person(
              id: sharedPersonId,
              name: 'server-name',
              surname: 'base-surname',
            ),
            columns: (t) => [t.name],
            transaction: tx,
          );
          await client.Person.db.insertRow(
            serverCrdtSession,
            client.Person(id: const Uuid().v7obj(), name: 'server-only'),
            transaction: tx,
          );
        });

        await clientCrdtSession.db.transaction((tx) async {
          await client.Person.db.updateRow(
            clientCrdtSession,
            clientSharedPerson!.copyWith(surname: 'client-surname'),
            columns: (t) => [t.surname],
            transaction: tx,
          );
          await client.Person.db.insertRow(
            clientCrdtSession,
            client.Person(id: const Uuid().v7obj(), name: 'client-only'),
            transaction: tx,
          );
        });

        final pendingChanges = await clientCrdtSession.db.collectPendingChanges(
          lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
          userId: testCrdtUserId,
        );
        expect(
          pendingChanges.inserts.whereType<CrdtMergeInsert>().map(
            (change) => (change.data as client.Person).name,
          ),
          contains('client-only'),
        );
        expect(
          pendingChanges.updates
              .where(
                (change) => change.columnName == client.Person.t.surname.columnName,
              )
              .map((change) => change.value),
          contains('client-surname'),
        );

        await clientCrdtSession.crdtDb.syncContinuously();

        final clientState = await _personState(
          () => client.Person.db.find(testSession, orderBy: (t) => t.id),
        );
        final serverState = await _personState(
          () => client.Person.db.find(serverDataSession, orderBy: (t) => t.id),
        );

        expect(clientState, serverState);
        expect(
          clientState,
          containsAll([
            '$sharedPersonId:server-name:client-surname',
            isA<String>().having(
              (value) => value.contains(':server-only:'),
              'server-only row',
              isTrue,
            ),
            isA<String>().having(
              (value) => value.contains(':client-only:'),
              'client-only row',
              isTrue,
            ),
          ]),
        );
      },
    );
  });
}

Future<List<String>> _personState(
  Future<List<client.Person>> Function() loadRows,
) async {
  final rows = await loadRows();
  return [
    for (final row in rows) '${row.id}:${row.name}:${row.surname ?? ''}',
  ];
}

class _DirectSyncCaller extends Caller {
  _DirectSyncCaller(this._serverSession, this._userId) : super(_NoopServerpodClient());

  final DatabaseSession _serverSession;
  final UuidValue _userId;

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    if (endpoint != 'serverpod_offline_sync.crdtSync' || method != 'syncOnce') {
      throw UnsupportedError('Unsupported sync call: $endpoint.$method');
    }

    await CrdtSync.instance.syncOnce(
      _serverSession,
      userId: _userId,
      syncTablesHash: args['syncTablesHash'] as String,
      changes: args['changes'] as CrdtMergeSet,
    );

    return null as T;
  }

  @override
  dynamic callStreamingServerEndpoint<T, G>(
    String endpoint,
    String method,
    Map<String, dynamic> args,
    Map<String, Stream> streams, {
    bool authenticated = true,
  }) {
    if (endpoint != 'serverpod_offline_sync.crdtSync' || method != 'syncStream') {
      throw UnsupportedError('Unsupported sync stream: $endpoint.$method');
    }

    return (() async* {
      final sync = CrdtSync.instance;
      final syncTablesHash = args['syncTablesHash'] as String;
      final pendingChanges = await sync.collectPendingChanges(
        _serverSession,
        userId: _userId,
        lastSyncHlc: args['lastSyncHlc'] as Hlc,
      );

      yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.inserts);
      yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.updates);
      yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.deletes);
      yield null;

      final incomingChanges = await _collectMergeSet(
        streams['changes']!.cast<CrdtMergeChange?>(),
      );
      if (incomingChanges == null || incomingChanges.isEmpty) return;

      await sync.syncOnce(
        _serverSession,
        userId: _userId,
        syncTablesHash: syncTablesHash,
        changes: incomingChanges,
      );
    })();
  }
}

Future<CrdtMergeSet?> _collectMergeSet(Stream<CrdtMergeChange?> changes) async {
  final inserts = <CrdtMergeInsert>[];
  final updates = <CrdtMergeUpdate>[];
  final deletes = <CrdtMergeDelete>[];
  var receivedStopSentinel = false;

  await for (final change in changes) {
    switch (change) {
      case null:
        receivedStopSentinel = true;
      case final CrdtMergeInsert insert:
        inserts.add(insert);
      case final CrdtMergeUpdate update:
        updates.add(update);
      case final CrdtMergeDelete delete:
        deletes.add(delete);
    }
    if (change == null) break;
  }

  if (!receivedStopSentinel) return null;

  return CrdtMergeSet(
    inserts: inserts,
    updates: updates,
    deletes: deletes,
  );
}

class _NoopServerpodClient extends ServerpodClientShared {
  _NoopServerpodClient()
    : super(
        'http://localhost/',
        client.Protocol(),
        connectionTimeout: const Duration(seconds: 30),
        streamingConnectionTimeout: const Duration(seconds: 30),
      );

  @override
  Map<String, EndpointRef> get endpointRefLookup => {};

  @override
  Map<String, ModuleEndpointCaller> get moduleLookup => {};
}
