import 'dart:async';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Server session node clock serialization',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final raw = sessionBuilder.build();

      group('Given two server wrappers with cached clocks sharing a node,', () {
        late OfflineSyncDatabaseSession first;
        late OfflineSyncDatabaseSession second;
        late UuidValue space;
        late DateTime start;

        setUpAll(() async {
          first = OfflineSyncDatabaseSession.wraps(raw, syncTables: [server.Unique.t]);
          second = OfflineSyncDatabaseSession.wraps(
            sessionBuilder.build(),
            syncTables: [server.Unique.t],
          );
          await first.db.initialize();
          await second.db.initialize();

          space = const Uuid().v7obj();
          start = DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch,
            isUtc: true,
          );

          await withClock(Clock.fixed(start), () async {
            await first.db.transactionForUser(space, (tx) async {
              await server.Unique.db.insertRow(
                first,
                server.Unique(id: const Uuid().v7obj(), name: 'prime first'),
                transaction: tx,
              );
            });

            await second.db.transactionForUser(space, (tx) async {
              await server.Unique.db.insertRow(
                second,
                server.Unique(id: const Uuid().v7obj(), name: 'prime second'),
                transaction: tx,
              );
            });
          });
        });

        tearDownAll(() async {
          await first.clearUserTables();
        });

        group('when a stale wrapper writes while a newer node clock is committing,', () {
          late Hlc firstClock;
          late Hlc secondClock;
          late Hlc persistedClock;

          setUpAll(() async {
            final firstWritten = Completer<void>();
            final releaseFirst = Completer<void>();

            final firstRow = server.Unique(
              id: const Uuid().v7obj(),
              name: 'future first',
            );
            final secondRow = server.Unique(
              id: const Uuid().v7obj(),
              name: 'later second',
            );

            final writingFirst = withClock(
              Clock.fixed(start.add(const Duration(seconds: 10))),
              () => first.db.transactionForUser(space, (tx) async {
                await server.Unique.db.insertRow(first, firstRow, transaction: tx);
                firstWritten.complete();
                await releaseFirst.future;
              }),
            );
            await firstWritten.future;

            final writingSecond = withClock(
              Clock.fixed(start),
              () => second.db.transactionForUser(space, (tx) async {
                await server.Unique.db.insertRow(second, secondRow, transaction: tx);
              }),
            );

            releaseFirst.complete();
            await Future.wait([writingFirst, writingSecond]);

            firstClock = (await CrdtDataRow.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(firstRow.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            ))!.hlc;
            secondClock = (await CrdtDataRow.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(secondRow.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            ))!.hlc;

            persistedClock = (await OfflineSyncSpace.db.findFirstRow(
              raw,
              where: (t) => t.uuidSpaceId.equals(space),
              include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
            ))!.currentNode!.lastHlc!;
          });

          test(
            'then the later transaction observes the committed clock without regression.',
            () {
              expect(secondClock.compareTo(firstClock), greaterThan(0));
              expect(persistedClock, secondClock);
            },
          );
        });
      });
    },
  );
}
