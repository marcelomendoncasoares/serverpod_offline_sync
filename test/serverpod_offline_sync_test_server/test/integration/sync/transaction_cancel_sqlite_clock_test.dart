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

  group('Given an incoming SQLite merge paused after locking its user clock,', () {
    late OfflineSyncDatabaseSession session;
    late OfflineSyncCancellation cancellation;
    late Completer<void> release;
    late Future<Object?> result;
    late UuidValue user;
    late UuidValue source;
    late client.Unique row;
    late Hlc? clockBefore;
    late List<CrdtMergeChange> changes;

    setUpAll(() async {
      user = const Uuid().v7obj();
      source = const Uuid().v7obj();
      release = Completer<void>();
      final entered = Completer<void>();
      session = OfflineSyncDatabaseSession(
        _HoldUserClock(observer.db, entered, release),
        syncTables: client.syncTables,
      );
      await session.db.initialize();
      await session.db.currentNodeId(userId: user);
      clockBefore = (await CrdtNode.db.findFirstRow(
        observer,
        where: (t) => t.localUserUuid.equals(user),
      ))!.lastHlc;
      row = client.Unique(id: const Uuid().v7obj(), name: const Uuid().v4());
      changes = [
        CrdtMergeInsert(
          uuidSpaceId: user,
          tableName: client.Unique.t.tableName,
          uuidRowId: row.id!,
          uuidNodeId: source,
          hlcDatetime: DateTime.now().toUtc(),
          hlcCounter: 0,
          data: row,
        ),
      ];
      cancellation = OfflineSyncCancellation();
      result = session.db
          .mergeChanges(changes, userId: user, cancellation: cancellation)
          .then<Object?>((_) => null, onError: (Object error) => error);
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await result;
      });
      await entered.future.timeout(const Duration(seconds: 10));
    });

    group('when cancellation arrives before the merge writes any payload,', () {
      late Object? error;
      late client.Unique? rowAfterCancel;
      late CrdtDataRow? metadataAfterCancel;
      late Hlc? clockAfterCancel;
      late Hlc? checkpointAfterCancel;
      late client.Unique? rowAfterRetry;

      setUpAll(() async {
        cancellation.cancel();
        release.complete();
        error = await result.timeout(const Duration(seconds: 10));
        rowAfterCancel = await client.Unique.db.findById(observer, row.id!);
        metadataAfterCancel = await CrdtDataRow.db.findFirstRow(
          observer,
          where: (t) => t.uuidRowId.equals(row.id),
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
        rowAfterRetry = await client.Unique.db.findById(observer, row.id!);
      });

      test('then the merge reports cancellation.', () {
        expect(error, isA<OfflineSyncCancelledException>());
      });

      test('then no domain data, metadata or progress survives.', () {
        expect(rowAfterCancel, isNull);
        expect(metadataAfterCancel, isNull);
        expect(clockAfterCancel, clockBefore);
        expect(checkpointAfterCancel, isNull);
      });

      test('then retrying the batch commits the row.', () {
        expect(rowAfterRetry?.name, row.name);
      });
    });
  });
}

/// Pauses after the real user-clock locking read, before any merge payload write.
class _HoldUserClock extends QueryCountingDatabase {
  // The delegate parameter belongs to the proxy's private implementation.
  // ignore: matching_super_parameters
  _HoldUserClock(super.database, this.entered, this.release);

  final Completer<void> entered;
  final Completer<void> release;

  @override
  Future<T?> findById<T extends TableRow>(
    Object id, {
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    final result = await super.findById<T>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (T == CrdtNode &&
        lockMode == LockMode.forNoKeyUpdate &&
        transaction != null &&
        !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return result;
  }
}
