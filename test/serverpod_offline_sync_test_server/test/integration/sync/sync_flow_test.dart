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

// The test drives two full null-delimited sync batches: one to bootstrap the
// shared row from server to client, and one to exchange the subsequent
// client/server changes while proving the stream remains alive.
const streamTestCycles = 2;

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
  late CrdtSyncClient clientSync;
  late UuidValue serverNodeId;

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
    );
    await clientCrdtSession.db.initialize();
    serverNodeId = await serverCrdtSession.db.currentNodeId(userId: testCrdtUserId);
    clientSync = CrdtSyncClient(_DirectSyncCaller(serverCrdtSession, testCrdtUserId));

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

        await clientSync.syncOnce(
          clientCrdtSession,
          otherNodeId: serverNodeId,
        );

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
      'when syncStream stays alive across multiple null-delimited batches then the client and server reach the same end state.',
      () async {
        final sharedPersonId = const Uuid().v7obj();
        final clientNodeId = await clientCrdtSession.db.currentNodeId(
          userId: testCrdtUserId,
        );
        final serverChanges = StreamController<CrdtMergeChange?>();
        final serverStream = StreamIterator(
          CrdtSync.instance.syncStream(
            serverCrdtSession,
            userId: testCrdtUserId,
            otherNodeId: clientNodeId,
            syncTablesHash: CrdtSync.instance.currentSyncTablesHash,
            changes: serverChanges.stream,
          ),
        );

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

        final initialServerChanges = await _collectMergeSet(serverStream);
        await clientCrdtSession.db.mergeChanges(
          initialServerChanges!,
          userId: testCrdtUserId,
        );

        final clientSharedPerson = await client.Person.db.findById(
          testSession,
          sharedPersonId,
        );

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

        final pendingChanges = await clientCrdtSession.db.collectPendingChanges(
          otherNodeId: serverNodeId,
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

        _addMergeSetToStream(serverChanges, pendingChanges);
        final streamedServerChanges = await _collectMergeSet(serverStream);
        await clientCrdtSession.db.mergeChanges(
          streamedServerChanges!,
          userId: testCrdtUserId,
        );
        await serverStream.cancel();
        unawaited(serverChanges.close());

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
      otherNodeId: args['otherNodeId'] as UuidValue,
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
      final otherNodeId = args['otherNodeId'] as UuidValue;
      final incomingStream = StreamIterator(
        streams['changes']!.cast<CrdtMergeChange?>(),
      );
      var cycles = 0;

      while (cycles < streamTestCycles) {
        final pendingChanges = await sync.collectPendingChanges(
          _serverSession,
          userId: _userId,
          otherNodeId: otherNodeId,
        );

        yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.inserts);
        yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.updates);
        yield* Stream<CrdtMergeChange>.fromIterable(pendingChanges.deletes);
        yield null;

        final incomingChanges = await _collectMergeSet(incomingStream);
        if (incomingChanges == null) return;

        await sync.syncOnce(
          _serverSession,
          userId: _userId,
          otherNodeId: otherNodeId,
          syncTablesHash: syncTablesHash,
          changes: incomingChanges,
        );
        final cycleCheckpoint = _maxHlc(
          pendingChanges.maxHlc,
          incomingChanges.maxHlc,
        );
        if (cycleCheckpoint != null) {
          await (_serverSession.db as CrdtDatabase).recordSyncCheckpoint(
            otherNodeId,
            cycleCheckpoint,
            userId: _userId,
          );
        }
        cycles++;
      }
    })();
  }
}

Future<CrdtMergeSet?> _collectMergeSet(
  StreamIterator<CrdtMergeChange?> changes,
) async {
  final inserts = <CrdtMergeInsert>[];
  final updates = <CrdtMergeUpdate>[];
  final deletes = <CrdtMergeDelete>[];
  var receivedStopSentinel = false;

  while (await changes.moveNext()) {
    final change = changes.current;
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

void _addMergeSetToStream(
  StreamController<CrdtMergeChange?> controller,
  CrdtMergeSet mergeSet,
) {
  mergeSet.inserts.forEach(controller.add);
  mergeSet.updates.forEach(controller.add);
  mergeSet.deletes.forEach(controller.add);
  controller.add(null);
}

Hlc? _maxHlc(Hlc? left, Hlc? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left > right ? left : right;
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
