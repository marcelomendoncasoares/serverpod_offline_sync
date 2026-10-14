import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given three records competing for the same unique name, ', () {
    late SyncNode node;
    late List<Object?> before;
    late Map<UuidValue?, String> names;
    late List<Unique> swap;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      final first = Unique(id: const Uuid().v7obj(), name: 'contested');
      final second = Unique(id: const Uuid().v7obj(), name: 'contested');
      final third = Unique(id: const Uuid().v7obj(), name: 'contested');
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Unique.db.insertRow(node.offlineSync, first, transaction: tx);
      });
      await mergeIndependentInsert(
        node.offlineSync,
        second,
        space: testCrdtUserId,
        tables: [Unique.t],
      );
      await mergeIndependentInsert(
        node.offlineSync,
        third,
        space: testCrdtUserId,
        tables: [Unique.t],
      );
      before = await _export(node);
      names = Map.fromEntries(
        (await Unique.db.find(
          node.offlineSync,
        )).map((row) => MapEntry(row.id, row.name)),
      );
      final winner = names.entries.singleWhere((entry) => entry.value == 'contested');
      final loser = names.entries.firstWhere((entry) => entry.value != 'contested');
      swap = [
        Unique(id: winner.key, name: loser.value),
        Unique(id: loser.key, name: winner.value),
      ];
    });

    group('when a batch update adopts a displayed generated alternative, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.update(
              node.offlineSync,
              swap,
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the reserved claim is rejected and the entire batch rolls back.',
        () async {
          expect(failure, isA<OfflineSyncReservedValueException>());
          expect(
            Map.fromEntries(
              (await Unique.db.find(
                node.offlineSync,
              )).map((row) => MapEntry(row.id, row.name)),
            ),
            names,
          );
          expect(await _export(node), before);
        },
      );
    });

    group('when a batch upsert adopts a displayed generated alternative, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsert(
              node.offlineSync,
              swap,
              conflictColumns: (t) => [t.id],
              updateColumns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the reserved claim is rejected and the entire batch rolls back.',
        () async {
          expect(failure, isA<OfflineSyncReservedValueException>());
          expect(
            Map.fromEntries(
              (await Unique.db.find(
                node.offlineSync,
              )).map((row) => MapEntry(row.id, row.name)),
            ),
            names,
          );
          expect(await _export(node), before);
        },
      );
    });
  });

  group('Given an ordinary unique name, ', () {
    late SyncNode node;
    late Unique row;
    late List<Object?> before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      row = Unique(id: const Uuid().v7obj(), name: 'ordinary');
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(node.offlineSync, row, transaction: tx),
      );
      before = await _export(node);
    });

    group('when a batch insert tries to author a reserved conflict name, ', () {
      const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insert(node.offlineSync, [
              Unique(id: const Uuid().v7obj(), name: 'also-ordinary'),
              Unique(id: const Uuid().v7obj(), name: reserved),
            ], transaction: tx),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a name-only update tries to author a reserved conflict name, ', () {
      const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateRow(
              node.offlineSync,
              row.copyWith(name: reserved),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when an upsert of the existing record tries to author a reserved conflict name, ',
      () {
        const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsertRow(
                node.offlineSync,
                row.copyWith(name: reserved),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the write is rejected without changing domain or sync facts.',
          () async {
            expect(
              failure,
              isA<OfflineSyncReservedValueException>()
                  .having((error) => error.tableName, 'table', 'unique')
                  .having((error) => error.columnName, 'column', 'name')
                  .having((error) => error.value, 'value', reserved),
            );
            expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
              'ordinary',
            ]);
            expect(await _export(node), before);
          },
        );
      },
    );

    group(
      'when an upsert of a new record tries to author a reserved conflict name, ',
      () {
        const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsertRow(
                node.offlineSync,
                Unique(id: const Uuid().v7obj(), name: reserved),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the write is rejected without changing domain or sync facts.',
          () async {
            expect(
              failure,
              isA<OfflineSyncReservedValueException>()
                  .having((error) => error.tableName, 'table', 'unique')
                  .having((error) => error.columnName, 'column', 'name')
                  .having((error) => error.value, 'value', reserved),
            );
            expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
              'ordinary',
            ]);
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when a predicate update tries to author a reserved conflict name, ', () {
      const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateWhere(
              node.offlineSync,
              columnValues: (t) => [t.name(reserved)],
              where: (t) => t.id.equals(row.id),
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a batch insert tries to author a reserved hidden name, ', () {
      const reserved = 'name__hidden__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insert(node.offlineSync, [
              Unique(id: const Uuid().v7obj(), name: 'also-ordinary'),
              Unique(id: const Uuid().v7obj(), name: reserved),
            ], transaction: tx),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a name-only update tries to author a reserved hidden name, ', () {
      const reserved = 'name__hidden__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateRow(
              node.offlineSync,
              row.copyWith(name: reserved),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when an upsert of the existing record tries to author a reserved hidden name, ',
      () {
        const reserved = 'name__hidden__550e8400-e29b-41d4-a716-446655440111';
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsertRow(
                node.offlineSync,
                row.copyWith(name: reserved),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the write is rejected without changing domain or sync facts.',
          () async {
            expect(
              failure,
              isA<OfflineSyncReservedValueException>()
                  .having((error) => error.tableName, 'table', 'unique')
                  .having((error) => error.columnName, 'column', 'name')
                  .having((error) => error.value, 'value', reserved),
            );
            expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
              'ordinary',
            ]);
            expect(await _export(node), before);
          },
        );
      },
    );

    group(
      'when an upsert of a new record tries to author a reserved hidden name, ',
      () {
        const reserved = 'name__hidden__550e8400-e29b-41d4-a716-446655440111';
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsertRow(
                node.offlineSync,
                Unique(id: const Uuid().v7obj(), name: reserved),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the write is rejected without changing domain or sync facts.',
          () async {
            expect(
              failure,
              isA<OfflineSyncReservedValueException>()
                  .having((error) => error.tableName, 'table', 'unique')
                  .having((error) => error.columnName, 'column', 'name')
                  .having((error) => error.value, 'value', reserved),
            );
            expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
              'ordinary',
            ]);
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when a predicate update tries to author a reserved hidden name, ', () {
      const reserved = 'name__hidden__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateWhere(
              node.offlineSync,
              columnValues: (t) => [t.name(reserved)],
              where: (t) => t.id.equals(row.id),
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a batch insert tries to author a reserved park name, ', () {
      const reserved = 'name__park__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insert(node.offlineSync, [
              Unique(id: const Uuid().v7obj(), name: 'also-ordinary'),
              Unique(id: const Uuid().v7obj(), name: reserved),
            ], transaction: tx),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a name-only update tries to author a reserved park name, ', () {
      const reserved = 'name__park__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateRow(
              node.offlineSync,
              row.copyWith(name: reserved),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when an upsert of the existing record tries to author a reserved park name, ',
      () {
        const reserved = 'name__park__550e8400-e29b-41d4-a716-446655440111';
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsertRow(
                node.offlineSync,
                row.copyWith(name: reserved),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the write is rejected without changing domain or sync facts.',
          () async {
            expect(
              failure,
              isA<OfflineSyncReservedValueException>()
                  .having((error) => error.tableName, 'table', 'unique')
                  .having((error) => error.columnName, 'column', 'name')
                  .having((error) => error.value, 'value', reserved),
            );
            expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
              'ordinary',
            ]);
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when an upsert of a new record tries to author a reserved park name, ', () {
      const reserved = 'name__park__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsertRow(
              node.offlineSync,
              Unique(id: const Uuid().v7obj(), name: reserved),
              conflictColumns: (t) => [t.id],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when a predicate update tries to author a reserved park name, ', () {
      const reserved = 'name__park__550e8400-e29b-41d4-a716-446655440111';
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateWhere(
              node.offlineSync,
              columnValues: (t) => [t.name(reserved)],
              where: (t) => t.id.equals(row.id),
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the write is rejected without changing domain or sync facts.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((error) => error.tableName, 'table', 'unique')
                .having((error) => error.columnName, 'column', 'name')
                .having((error) => error.value, 'value', reserved),
          );
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'ordinary',
          ]);
          expect(await _export(node), before);
        },
      );
    });
  });

  group('Given a complete remote insert batch containing a reserved unique name, ', () {
    late SyncNode target;
    late List<CrdtMergeChange> invalid;
    late List<Object?> before;

    setUpAll(() async {
      final source = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      target = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      final row = Unique(id: const Uuid().v7obj(), name: 'ordinary');
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insert(source.offlineSync, [
          row,
          Unique(id: const Uuid().v7obj(), name: 'unrelated'),
        ], transaction: tx),
      );

      const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      final changes = await source.sync
          .collectPendingChanges(
            source.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: const []},
          )
          .toList();
      invalid = changes.map((change) {
        if (change is CrdtMergeInsert && change.uuidRowId == row.id) {
          return change.copyWith(data: row.copyWith(name: reserved));
        }
        return change;
      }).toList();
      before = await _export(target);
    });

    group('when the batch is delivered repeatedly in different list orders, ', () {
      Object? firstFailure;
      Object? reversedFailure;
      Object? repeatedFailure;
      late List<Object?> afterFirst;
      late List<Object?> afterReversed;
      late List<Object?> afterRepeated;

      setUpAll(() async {
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          firstFailure = error;
        }
        afterFirst = await _export(target);

        try {
          await target.offlineSync.db.mergeChanges(
            invalid.reversed.toList(),
            userId: testCrdtUserId,
          );
        } on Object catch (error) {
          reversedFailure = error;
        }
        afterReversed = await _export(target);

        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          repeatedFailure = error;
        }
        afterRepeated = await _export(target);
      });

      test('then each delivery is rejected without accepting any facts.', () {
        expect(firstFailure, isA<OfflineSyncReservedValueException>());
        expect(afterFirst, before);
        expect(reversedFailure, isA<OfflineSyncReservedValueException>());
        expect(afterReversed, before);
        expect(repeatedFailure, isA<OfflineSyncReservedValueException>());
        expect(afterRepeated, before);
      });
    });
  });

  group('Given a complete remote update batch containing a reserved unique name, ', () {
    late SyncNode target;
    late List<CrdtMergeChange> invalid;
    late List<Object?> before;

    setUpAll(() async {
      final source = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      target = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      final row = Unique(id: const Uuid().v7obj(), name: 'ordinary');
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insert(source.offlineSync, [
          row,
          Unique(id: const Uuid().v7obj(), name: 'unrelated'),
        ], transaction: tx),
      );

      await pushChanges(source, target);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.updateRow(
          source.offlineSync,
          row.copyWith(name: 'changed'),
          columns: (t) => [t.name],
          transaction: tx,
        ),
      );

      const reserved = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      final changes = await source.sync
          .collectPendingChanges(
            source.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: const []},
          )
          .toList();
      invalid = changes.map((change) {
        if (change is CrdtMergeUpdate) {
          return change.copyWith(value: reserved);
        }
        return change;
      }).toList();
      before = await _export(target);
    });

    group('when the batch is delivered repeatedly in different list orders, ', () {
      Object? firstFailure;
      Object? reversedFailure;
      Object? repeatedFailure;
      late List<Object?> afterFirst;
      late List<Object?> afterReversed;
      late List<Object?> afterRepeated;

      setUpAll(() async {
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          firstFailure = error;
        }
        afterFirst = await _export(target);

        try {
          await target.offlineSync.db.mergeChanges(
            invalid.reversed.toList(),
            userId: testCrdtUserId,
          );
        } on Object catch (error) {
          reversedFailure = error;
        }
        afterReversed = await _export(target);

        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          repeatedFailure = error;
        }
        afterRepeated = await _export(target);
      });

      test('then each delivery is rejected without accepting any facts.', () {
        expect(firstFailure, isA<OfflineSyncReservedValueException>());
        expect(afterFirst, before);
        expect(reversedFailure, isA<OfflineSyncReservedValueException>());
        expect(afterReversed, before);
        expect(repeatedFailure, isA<OfflineSyncReservedValueException>());
        expect(afterRepeated, before);
      });
    });
  });

  group('Given a non-unique text column, ', () {
    late SyncNode node;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), [City.t]);
    });

    group('when a value matching the generated suffix is inserted, ', () {
      const name = 'name__conflict__550e8400-e29b-41d4-a716-446655440111';
      late City row;

      setUpAll(() async {
        row = await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => City.db.insertRow(
            node.offlineSync,
            City(id: const Uuid().v7obj(), name: name),
            transaction: tx,
          ),
        );
      });

      test('then the ordinary text field retains that value.', () async {
        expect((await City.db.findById(node.offlineSync, row.id!))!.name, name);
      });
    });
  });

  group('Given names that resemble the generated suffix without matching it, ', () {
    late SyncNode source;
    late SyncNode target;
    const invalidUuid = 'name__conflict__not-a-uuid';
    const extraSuffix = 'name__hidden__550e8400-e29b-41d4-a716-446655440111-more';
    const missingUuid = 'name__park__';

    setUpAll(() async {
      source = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      target = await syncNode(await createAdditionalTestSession(), [Unique.t]);
    });

    group('when those names are inserted and an empty peer bootstraps, ', () {
      setUpAll(() async {
        await source.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insert(source.offlineSync, [
            Unique(id: const Uuid().v7obj(), name: invalidUuid),
            Unique(id: const Uuid().v7obj(), name: extraSuffix),
            Unique(id: const Uuid().v7obj(), name: missingUuid),
          ], transaction: tx),
        );
        await pushChanges(source, target);
      });

      test('then their exact text is retained.', () async {
        expect(
          (await Unique.db.find(target.offlineSync)).map((row) => row.name),
          unorderedEquals([invalidUuid, extraSuffix, missingUuid]),
        );
      });
    });
  });
}

Future<List<Object?>> _export(SyncNode node) => node.sync
    .collectPendingChanges(
      node.raw,
      checkpointsBySpaceUuid: {testCrdtUserId: const []},
    )
    .map((change) => change.toJson())
    .toList();
