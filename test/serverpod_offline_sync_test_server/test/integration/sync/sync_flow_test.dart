// Uses serverpod_database and serverpod_test types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/endpoints.dart'
    as generated;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as generated;
import 'package:serverpod_test/serverpod_test.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  final clientSyncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];
  final serverSyncTables = [
    generated.Address.t,
    generated.Person.t,
    generated.Types.t,
    generated.Unique.t,
  ];

  late TestServerpod<_NoopInternalTestEndpoints> testServerpod;
  late String previousWorkingDirectory;
  late String testServerPackagePath;
  late Session serverSession;
  late CrdtDatabaseSession serverCrdtSession;
  late CrdtDatabaseSession clientCrdtSession;
  late CrdtSyncClient clientSync;
  late CrdtSyncEndpoint syncEndpoint;
  late UuidValue serverNodeId;

  setUpAll(() async {
    testServerPackagePath = _findTestServerPackagePath();
    previousWorkingDirectory = Directory.current.path;
    Directory.current = Directory(testServerPackagePath);
    testServerpod = TestServerpod<_NoopInternalTestEndpoints>(
      testEndpoints: _NoopInternalTestEndpoints(),
      endpoints: generated.Endpoints(),
      serializationManager: generated.Protocol(),
      isDatabaseEnabled: true,
      serverpodLoggingMode: ServerpodLoggingMode.normal,
      runMode: ServerpodRunMode.test,
      applyMigrations: true,
      testServerOutputMode: TestServerOutputMode.normal,
    );
    await testServerpod.start();
    Directory.current = previousWorkingDirectory;
  });

  tearDownAll(() async {
    Directory.current = Directory(testServerPackagePath);
    await testServerpod.shutdown();
    Directory.current = previousWorkingDirectory;
  });

  setUp(() async {
    serverSession = _authenticatedSession(testServerpod);
    await _clearServerTables(serverSession);

    serverCrdtSession = CrdtDatabaseSession.wraps(
      serverSession,
      syncTables: serverSyncTables,
    );
    await serverCrdtSession.db.initialize();

    clientCrdtSession = CrdtDatabaseSession.wraps(
      testSession,
      syncTables: clientSyncTables,
      persistentUserId: testCrdtUserId,
    );
    await clientCrdtSession.db.initialize();

    CrdtSync.initialize(
      syncTables: serverSyncTables,
      serializationManager: serverSession.db.serializationManager,
    );
    syncEndpoint = CrdtSyncEndpoint();
    clientSync = CrdtSyncClient(
      _EndpointSyncCaller(testServerpod, syncEndpoint),
    );
    serverNodeId = await serverCrdtSession.db.currentNodeId(userId: testCrdtUserId);
  });

  tearDown(() async {
    await serverSession.close();
  });

  group('Given one-way sync helpers', () {
    test(
      'when client syncOnce is called then the server merges the client pending changes.',
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

        final serverPerson = await generated.Person.db.findById(
          serverCrdtSession,
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
          syncEndpoint.syncStream(
            _authenticatedSession(testServerpod),
            syncTablesHash: CrdtSync.instance.currentSyncTablesHash,
            otherNodeId: clientNodeId,
            changes: serverChanges.stream,
          ),
        );

        await serverCrdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
          await generated.Person.db.insertRow(
            serverCrdtSession,
            generated.Person(
              id: sharedPersonId,
              name: 'base-name',
              surname: 'base-surname',
            ),
            transaction: tx,
          );
        });

        final initialServerChanges = await collectMergeSetFromIterator(
          serverStream,
        );
        await clientCrdtSession.db.mergeChanges(
          _toClientMergeSet(initialServerChanges!),
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
          await generated.Person.db.updateRow(
            serverCrdtSession,
            generated.Person(
              id: sharedPersonId,
              name: 'server-name',
              surname: 'base-surname',
            ),
            columns: (t) => [t.name],
            transaction: tx,
          );
          await generated.Person.db.insertRow(
            serverCrdtSession,
            generated.Person(id: const Uuid().v7obj(), name: 'server-only'),
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

        addMergeSetWithSentinel(serverChanges.add, _toServerMergeSet(pendingChanges));
        final streamedServerChanges = await collectMergeSetFromIterator(
          serverStream,
        );
        await clientCrdtSession.db.mergeChanges(
          _toClientMergeSet(streamedServerChanges!),
          userId: testCrdtUserId,
        );
        await serverStream.cancel();
        unawaited(serverChanges.close());

        final clientState = await _personState(
          () => client.Person.db.find(testSession, orderBy: (t) => t.id),
        );
        final serverState = await _serverPersonState(
          () => generated.Person.db.find(serverCrdtSession, orderBy: (t) => t.id),
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

Future<List<String>> _serverPersonState(
  Future<List<generated.Person>> Function() loadRows,
) async {
  final rows = await loadRows();
  return [
    for (final row in rows) '${row.id}:${row.name}:${row.surname ?? ''}',
  ];
}

Session _authenticatedSession(TestServerpod testServerpod) {
  final session =
      testServerpod.createSession(
        rollbackDatabase: RollbackDatabase.disabled,
      )..updateAuthenticated(
        AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        ),
      );
  return session;
}

Future<void> _clearServerTables(Session session) async {
  await session.db.unsafeExecute('PRAGMA foreign_keys = OFF');
  final result = await session.db.unsafeQuery('''
    SELECT name
    FROM sqlite_master
    WHERE (type = 'table') AND (name NOT LIKE 'serverpod_%')
  ''');
  for (final row in result) {
    final tableName = row[0] as String;
    await session.db.unsafeExecute('DELETE FROM "$tableName"');
  }
  await session.db.unsafeExecute('PRAGMA foreign_keys = ON');
}

String _findTestServerPackagePath() {
  final candidates = [
    p.normalize(
      p.join(
        Directory.current.path,
        'test',
        'serverpod_offline_sync_test_server',
      ),
    ),
    Directory.current.path,
  ];

  for (final candidate in candidates) {
    if (File(p.join(candidate, 'config', 'test.yaml')).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Could not locate the test server package directory.');
}

CrdtMergeSet _toClientMergeSet(CrdtMergeSet mergeSet) => buildMergeSet(
  inserts: [
    for (final insert in mergeSet.inserts)
      insert.copyWith(data: _toClientRow(insert.tableName, insert.data)),
  ],
  updates: mergeSet.updates,
  deletes: mergeSet.deletes,
);

CrdtMergeSet _toServerMergeSet(CrdtMergeSet mergeSet) => buildMergeSet(
  inserts: [
    for (final insert in mergeSet.inserts)
      insert.copyWith(data: _toServerRow(insert.tableName, insert.data)),
  ],
  updates: mergeSet.updates,
  deletes: mergeSet.deletes,
);

TableRow _toClientRow(String tableName, dynamic row) {
  final json = Map<String, dynamic>.from((row as dynamic).toJson() as Map);
  return switch (tableName) {
    'address' => client.Address.fromJson(json),
    'person' => client.Person.fromJson(json),
    'types' => client.Types.fromJson(json),
    'unique' => client.Unique.fromJson(json),
    _ => throw StateError('Unsupported client sync row table: $tableName'),
  };
}

TableRow _toServerRow(String tableName, dynamic row) {
  final json = Map<String, dynamic>.from((row as dynamic).toJson() as Map);
  return switch (tableName) {
    'address' => generated.Address.fromJson(json),
    'person' => generated.Person.fromJson(json),
    'types' => generated.Types.fromJson(json),
    'unique' => generated.Unique.fromJson(json),
    _ => throw StateError('Unsupported server sync row table: $tableName'),
  };
}

class _EndpointSyncCaller extends Caller {
  _EndpointSyncCaller(this._testServerpod, this._endpoint)
    : super(_NoopServerpodClient());

  final TestServerpod _testServerpod;
  final CrdtSyncEndpoint _endpoint;

  Session _buildSession() => _authenticatedSession(_testServerpod);

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

    final session = _buildSession();
    try {
      await _endpoint.syncOnce(
        session,
        syncTablesHash: args['syncTablesHash'] as String,
        otherNodeId: args['otherNodeId'] as UuidValue,
        changes: _toServerMergeSet(args['changes'] as CrdtMergeSet),
      );
    } finally {
      await session.close();
    }

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

    final session = _buildSession();
    return (() async* {
      try {
        yield* _endpoint
            .syncStream(
              session,
              syncTablesHash: args['syncTablesHash'] as String,
              otherNodeId: args['otherNodeId'] as UuidValue,
              changes: (() async* {
                await for (final change
                    in streams['changes']!.cast<CrdtMergeChange?>()) {
                  yield switch (change) {
                    null => null,
                    final CrdtMergeInsert insert => insert.copyWith(
                      data: _toServerRow(insert.tableName, insert.data),
                    ),
                    final CrdtMergeUpdate update => update,
                    final CrdtMergeDelete delete => delete,
                  };
                }
              })(),
            )
            .map(
              (change) => switch (change) {
                null => null,
                final CrdtMergeInsert insert => insert.copyWith(
                  data: _toClientRow(insert.tableName, insert.data),
                ),
                final CrdtMergeUpdate update => update,
                final CrdtMergeDelete delete => delete,
              },
            );
      } finally {
        await session.close();
      }
    })();
  }
}

class _NoopInternalTestEndpoints implements InternalTestEndpoints {
  @override
  void initialize(
    DatabaseSerializationManager serializationManager,
    EndpointDispatch endpoints,
  ) {}
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
