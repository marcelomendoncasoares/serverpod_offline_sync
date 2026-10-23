import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);
  late ClientDatabaseSession observer;

  setUpAll(() async {
    observer = await createAdditionalTestSession();
  });

  OfflineSyncDatabaseContext context() => OfflineSyncDatabaseContext(
    syncTables: client.syncTables,
    serializationManager: observer.db.serializationManager,
  );

  Future<OfflineSyncDatabaseSession> wrapper(
    OfflineSyncDatabaseContext context, {
    Database? database,
  }) async {
    final session = OfflineSyncDatabaseSession(
      database ?? observer.db,
      syncTables: client.syncTables,
      context: context,
    );
    await session.db.initialize();
    return session;
  }

  group('Given a sync stream paused after writing merge metadata,', () {
    late UuidValue user;
    late UuidValue source;
    late OfflineSyncDatabaseSession session;
    late Completer<void> release;
    late Completer<void> inboundCancelled;
    late StreamController<OfflineSyncStreamEvent> inbound;
    late StreamSubscription<OfflineSyncStreamEvent> subscription;
    late List<CrdtMergeChange> changes;
    late Hlc? clockBefore;
    late List<Object> streamErrors;

    setUpAll(() async {
      user = const Uuid().v7obj();
      source = const Uuid().v7obj();
      final shared = context();
      release = Completer<void>();
      final entered = Completer<void>();
      session = await wrapper(
        shared,
        database: _HoldMerge(observer.db, entered, release),
      );
      await session.db.currentNodeId(userId: user);
      clockBefore = (await CrdtNode.db.findFirstRow(
        observer,
        where: (t) => t.localUserUuid.equals(user),
      ))!.lastHlc;
      final rows = [
        client.Unique(id: const Uuid().v7obj(), name: const Uuid().v4()),
        client.Unique(id: const Uuid().v7obj(), name: const Uuid().v4()),
      ];
      changes = [
        for (final (index, row) in rows.indexed)
          CrdtMergeInsert(
            uuidSpaceId: user,
            tableName: client.Unique.t.tableName,
            uuidRowId: row.id!,
            uuidNodeId: source,
            hlcDatetime: DateTime.now().toUtc(),
            hlcCounter: index,
            data: row,
          ),
      ];
      final engine = OfflineSyncEngine(
        syncTables: client.syncTables,
        serializationManager: observer.db.serializationManager,
        databaseContext: shared,
      );
      inboundCancelled = Completer<void>();
      inbound = StreamController<OfflineSyncStreamEvent>(
        onCancel: () => inboundCancelled.complete(),
      );
      streamErrors = [];
      subscription = engine
          .sync(
            session,
            userId: user,
            inbound: inbound.stream,
            mode: OfflineSyncPeerMode.follower,
          )
          .listen(
            (_) {},
            onError: (Object error) => streamErrors.add(error),
          );
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await subscription.cancel();
        await inbound.close();
      });
      inbound
        ..add(
          OfflineSyncConnect(
            localNodeId: source,
            syncTablesHash: engine.currentSyncTablesHash,
            spaces: [
              OfflineSyncSpaceGrant(
                uuidSpaceId: user,
                role: OfflineSyncSpaceRole.readWrite,
              ),
            ],
          ),
        )
        ..add(OfflineSyncSinceHlc(uuidSpaceId: user, nodeCheckpoints: []))
        ..add(OfflineSyncReady())
        ..add(OfflineSyncMergeChunk(batchId: 1, changes: changes))
        ..add(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: false));
      await entered.future.timeout(const Duration(seconds: 10));
    });

    group(
      'when the stream is cancelled and its pending database call returns,',
      () {
        late bool completedBeforeRelease;
        late List<client.Unique> rowsAfterCancel;
        late List<CrdtDataRow> metadataAfterCancel;
        late Hlc? clockAfterCancel;
        late Hlc? checkpointAfterCancel;
        late List<client.Unique> rowsAfterRetry;

        setUpAll(() async {
          var completed = false;
          final cancellation = subscription.cancel().then((_) {
            completed = true;
          });
          await inboundCancelled.future.timeout(const Duration(seconds: 10));
          completedBeforeRelease = completed;
          release.complete();
          await cancellation.timeout(const Duration(seconds: 10));

          final ids = changes.map((change) => change.uuidRowId).toSet();
          rowsAfterCancel = await client.Unique.db.find(
            observer,
            where: (t) => t.id.inSet(ids),
          );
          metadataAfterCancel = await CrdtDataRow.db.find(
            observer,
            where: (t) => t.uuidRowId.inSet(ids),
          );
          clockAfterCancel = (await CrdtNode.db.findFirstRow(
            observer,
            where: (t) => t.localUserUuid.equals(user),
          ))!.lastHlc;
          checkpointAfterCancel = (await OfflineSyncSpaceNode.db.findFirstRow(
            observer,
            where: (t) => t.node.uuidNodeId.equals(source),
          ))?.lastReceivedHlc;

          await session.db.mergeChanges(changes, userId: user);
          rowsAfterRetry = await client.Unique.db.find(
            observer,
            where: (t) => t.id.inSet(ids),
          );
        });

        test('then cancellation waits for the transaction to settle.', () {
          expect(completedBeforeRelease, isFalse);
          expect(streamErrors, isEmpty);
        });

        test(
          'then domain writes, metadata, clock and checkpoint roll back together.',
          () {
            expect(rowsAfterCancel, isEmpty);
            expect(metadataAfterCancel, isEmpty);
            expect(clockAfterCancel, clockBefore);
            expect(checkpointAfterCancel, isNull);
          },
        );

        test('then retrying the same batch commits every row.', () {
          expect(rowsAfterRetry, hasLength(2));
        });
      },
    );
  });
}

/// Holds a real transaction after its first CRDT row insert.
class _HoldMerge extends QueryCountingDatabase {
  // The delegate parameter belongs to the proxy's private implementation.
  // ignore: matching_super_parameters
  _HoldMerge(super.database, this.entered, this.release);

  final Completer<void> entered;
  final Completer<void> release;

  @override
  Future<T> insertRow<T extends TableRow>(T row, {Transaction? transaction}) async {
    final result = await super.insertRow(row, transaction: transaction);
    await _hold(row is CrdtDataRow, transaction);
    return result;
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    final result = await super.insert(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
    await _hold(rows.any((row) => row is CrdtDataRow), transaction);
    return result;
  }

  Future<void> _hold(bool wroteMetadata, Transaction? transaction) async {
    if (wroteMetadata && transaction != null && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
  }
}
