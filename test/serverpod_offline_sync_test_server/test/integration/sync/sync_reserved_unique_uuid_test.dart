import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseUniqueViolationException, Transaction;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../../dst/framework/dst_random.dart';
import '../../dst/framework/dst_snapshot.dart';
import '../../dst/framework/dst_world.dart';
import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  const reserved = UuidValue.raw('1384ce72-7ccf-8b5f-afc4-4fb11ac066d9');
  const ordinary = UuidValue.raw('660e8400-e29b-41d4-a716-446655440000');
  const other = UuidValue.raw('660e8400-e29b-41d4-a716-446655440001');

  group('Given an ordinary unique UUID record and a reserved version-8 input, ', () {
    late SyncNode node;
    late UniqueUuid row;
    late UniqueUuid invalid;
    late UniqueUuid fresh;
    late UniqueUuid earlier;
    late UniqueUuid valid;
    late Object before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      row = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueUuid.db.insertRow(node.offlineSync, row, transaction: tx);
      });
      before = await _state(node);
      invalid = row.copyWith(value: reserved);
      fresh = invalid.copyWith(id: const Uuid().v7obj());
      earlier = UniqueUuid(id: const Uuid().v7obj(), value: other);
      valid = UniqueUuid(id: const Uuid().v7obj(), value: const Uuid().v7obj());
    });

    group('when an insert authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.insertRow(node.offlineSync, fresh, transaction: tx);
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a batch insert authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.insert(node.offlineSync, [
              valid,
              fresh,
            ], transaction: tx);
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a full-row update authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.updateRow(node.offlineSync, invalid, transaction: tx);
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a value-only update authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.updateRow(
              node.offlineSync,
              invalid,
              columns: (t) => [t.value],
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a batch update authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.update(node.offlineSync, [
              earlier.copyWith(value: valid.value),
              invalid,
            ], transaction: tx);
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when an upsert of a new record authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.upsertRow(
              node.offlineSync,
              fresh,
              conflictColumns: (t) => [t.id],
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when an upsert of the existing record authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.upsertRow(
              node.offlineSync,
              invalid,
              conflictColumns: (t) => [t.id],
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a batch upsert authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.upsert(
              node.offlineSync,
              [valid, invalid],
              conflictColumns: (t) => [t.id],
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });

    group('when a predicate update authors the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.updateWhere(
              node.offlineSync,
              columnValues: (t) => [t.value(reserved)],
              where: (t) => t.id.equals(row.id),
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });
  });

  group('Given a deleted unique UUID record and a reserved version-8 input, ', () {
    late SyncNode node;
    late UniqueUuid row;
    late UniqueUuid invalid;
    late UniqueUuid earlier;
    late Object before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      row = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueUuid.db.insertRow(node.offlineSync, row, transaction: tx);
        await UniqueUuid.db.deleteRow(node.offlineSync, row, transaction: tx);
      });
      before = await _state(node);
      invalid = row.copyWith(value: reserved);
      earlier = UniqueUuid(id: const Uuid().v7obj(), value: other);
    });

    group('when an upsert restores the record with the reserved value, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            // An earlier valid write must roll back along with the rejected input.
            await UniqueUuid.db.insertRow(node.offlineSync, earlier, transaction: tx);
            await UniqueUuid.db.upsertRow(
              node.offlineSync,
              invalid,
              conflictColumns: (t) => [t.id],
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the entire transaction is rejected without domain or sync changes.',
        () async {
          expect(
            failure,
            isA<OfflineSyncReservedValueException>()
                .having((e) => e.tableName, 'table', 'unique_uuid')
                .having((e) => e.columnName, 'column', 'value')
                .having((e) => e.value, 'value', reserved.toString()),
          );
          expect(await _state(node), before);
        },
      );
    });
  });

  group('Given a visible UUID claim displayed as a generated conflict alternative, ', () {
    late SyncNode node;
    late SyncNode target;
    late UniqueUuid displayed;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final winner = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      final loser = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(node.offlineSync, winner, transaction: tx),
      );
      await mergeIndependentInsert(
        node.offlineSync,
        loser,
        space: testCrdtUserId,
        tables: [UniqueUuid.t],
      );

      displayed = (await UniqueUuid.db.find(
        node.offlineSync,
        where: (t) => t.id.equals(loser.id) & t.includeHiddenRows,
      )).single;
    });

    group('when its unchanged model is updated and exported, ', () {
      late List<CrdtMergeChange> changes;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueUuid.db.updateRow(node.offlineSync, displayed, transaction: tx);
        });
        changes = await _export(node);
        await pushChanges(node, target);
      });

      test(
        'then its original claim survives and a fresh device reconstructs the same state.',
        () async {
          expect(displayed.value.version, 8);
          expect(
            changes.whereType<CrdtMergeInsert>().map(
              (c) => (c.data as UniqueUuid).value,
            ),
            everyElement(ordinary),
          );
          expect(
            changes.whereType<CrdtMergeUpdate>().map((c) => c.value),
            everyElement(ordinary),
          );
          expect(await _domain(target), await _domain(node));
          expect(await _facts(target), await _facts(node));
        },
      );
    });

    group('when its unchanged model is upserted and exported, ', () {
      late List<CrdtMergeChange> changes;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueUuid.db.upsertRow(
            node.offlineSync,
            displayed,
            conflictColumns: (t) => [t.id],
            transaction: tx,
          );
        });
        changes = await _export(node);
        await pushChanges(node, target);
      });

      test(
        'then its original claim survives and a fresh device reconstructs the same state.',
        () async {
          expect(displayed.value.version, 8);
          expect(
            changes.whereType<CrdtMergeInsert>().map(
              (c) => (c.data as UniqueUuid).value,
            ),
            everyElement(ordinary),
          );
          expect(
            changes.whereType<CrdtMergeUpdate>().map((c) => c.value),
            everyElement(ordinary),
          );
          expect(await _domain(target), await _domain(node));
          expect(await _facts(target), await _facts(node));
        },
      );
    });
  });

  group('Given a deleted UUID claim displayed as a generated hidden alternative, ', () {
    late SyncNode node;
    late SyncNode target;
    late UniqueUuid displayed;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final winner = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      final loser = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(node.offlineSync, winner, transaction: tx),
      );
      await mergeIndependentInsert(
        node.offlineSync,
        loser,
        space: testCrdtUserId,
        tables: [UniqueUuid.t],
      );

      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.deleteRow(node.offlineSync, loser, transaction: tx),
      );

      displayed = (await UniqueUuid.db.find(
        node.offlineSync,
        where: (t) => t.id.equals(loser.id) & t.includeHiddenRows,
      )).single;
    });

    group('when an insert restores its unchanged model and exports it, ', () {
      late List<CrdtMergeChange> changes;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueUuid.db.insertRow(node.offlineSync, displayed, transaction: tx);
        });
        changes = await _export(node);
        await pushChanges(node, target);
      });

      test(
        'then its original claim survives and a fresh device reconstructs the same state.',
        () async {
          expect(displayed.value.version, 8);
          expect(
            changes.whereType<CrdtMergeInsert>().map(
              (c) => (c.data as UniqueUuid).value,
            ),
            everyElement(ordinary),
          );
          expect(
            changes.whereType<CrdtMergeUpdate>().map((c) => c.value),
            everyElement(ordinary),
          );
          expect(await _domain(target), await _domain(node));
          expect(await _facts(target), await _facts(node));
        },
      );
    });

    group('when an upsert restores its unchanged model and exports it, ', () {
      late List<CrdtMergeChange> changes;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueUuid.db.upsertRow(
            node.offlineSync,
            displayed,
            conflictColumns: (t) => [t.id],
            transaction: tx,
          );
        });
        changes = await _export(node);
        await pushChanges(node, target);
      });

      test(
        'then its original claim survives and a fresh device reconstructs the same state.',
        () async {
          expect(displayed.value.version, 8);
          expect(
            changes.whereType<CrdtMergeInsert>().map(
              (c) => (c.data as UniqueUuid).value,
            ),
            everyElement(ordinary),
          );
          expect(
            changes.whereType<CrdtMergeUpdate>().map((c) => c.value),
            everyElement(ordinary),
          );
          expect(await _domain(target), await _domain(node));
          expect(await _facts(target), await _facts(node));
        },
      );
    });
  });

  group('Given a generated conflict UUID whose winning competitor was deleted, ', () {
    late SyncNode node;
    late UniqueUuid displayed;
    late UuidValue reclaimed;
    late Object before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final winner = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      final loser = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(node.offlineSync, winner, transaction: tx),
      );
      await mergeIndependentInsert(
        node.offlineSync,
        loser,
        space: testCrdtUserId,
        tables: [UniqueUuid.t],
      );
      displayed = (await UniqueUuid.db.findById(node.offlineSync, loser.id!))!;
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.deleteRow(node.offlineSync, winner, transaction: tx),
      );
      reclaimed = (await UniqueUuid.db.find(node.offlineSync)).single.value;
      before = await _state(node);
    });

    group('when an insert explicitly claims the now-unoccupied alternative, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueUuid.db.insertRow(
              node.offlineSync,
              displayed.copyWith(id: const Uuid().v7obj()),
              transaction: tx,
            );
          });
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the reserved value is rejected regardless of the current domain data.',
        () async {
          expect(displayed.value.version, 8);
          expect(reclaimed, ordinary);
          expect(
            failure,
            isA<OfflineSyncReservedValueException>().having(
              (e) => e.value,
              'generated alternative',
              displayed.value.toString(),
            ),
          );
          expect(await _state(node), before);
        },
      );
    });

    group(
      'when a value-only update explicitly claims the now-unoccupied alternative, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await UniqueUuid.db.updateRow(
                node.offlineSync,
                displayed,
                columns: (t) => [t.value],
                transaction: tx,
              );
            });
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the reserved value is rejected regardless of the current domain data.',
          () async {
            expect(displayed.value.version, 8);
            expect(reclaimed, ordinary);
            expect(
              failure,
              isA<OfflineSyncReservedValueException>().having(
                (e) => e.value,
                'generated alternative',
                displayed.value.toString(),
              ),
            );
            expect(await _state(node), before);
          },
        );
      },
    );
    group(
      'when a value-only upsert explicitly claims the now-unoccupied alternative, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await UniqueUuid.db.upsertRow(
                node.offlineSync,
                displayed,
                conflictColumns: (t) => [t.id],
                updateColumns: (t) => [t.value],
                transaction: tx,
              );
            });
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the reserved value is rejected regardless of the current domain data.',
          () async {
            expect(displayed.value.version, 8);
            expect(reclaimed, ordinary);
            expect(
              failure,
              isA<OfflineSyncReservedValueException>().having(
                (e) => e.value,
                'generated alternative',
                displayed.value.toString(),
              ),
            );
            expect(await _state(node), before);
          },
        );
      },
    );
  });

  group('Given an incoming insert batch containing a reserved unique UUID, ', () {
    late SyncNode target;
    late List<CrdtMergeChange> invalid;
    late Object before;

    setUp(() async {
      final source = await syncNode(await createAdditionalTestSession(), [
        UniqueUuid.t,
      ]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final row = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(source.offlineSync, row, transaction: tx),
      );

      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(
          source.offlineSync,
          UniqueUuid(id: const Uuid().v7obj(), value: const Uuid().v7obj()),
          transaction: tx,
        ),
      );
      invalid = (await _export(source)).map((change) {
        if (change is CrdtMergeInsert && change.uuidRowId == row.id) {
          return change.copyWith(data: row.copyWith(value: reserved));
        }

        return change;
      }).toList();
      await target.offlineSync.db.transactionForUser(testCrdtUserId, (_) async {});
      before = await _state(target);
    });

    group('when it is delivered repeatedly and in reversed order, ', () {
      Object? firstFailure;
      Object? reversedFailure;
      Object? repeatedFailure;
      late Object afterFirst;
      late Object afterReversed;
      late Object afterRepeated;

      setUp(() async {
        firstFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          firstFailure = error;
        }
        afterFirst = await _state(target);

        reversedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(
            invalid.reversed.toList(),
            userId: testCrdtUserId,
          );
        } on Object catch (error) {
          reversedFailure = error;
        }
        afterReversed = await _state(target);

        repeatedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          repeatedFailure = error;
        }
        afterRepeated = await _state(target);
      });

      test(
        'then every delivery is rejected without changing data or sync progress.',
        () async {
          expect(firstFailure, isA<OfflineSyncReservedValueException>());
          expect(afterFirst, before);
          expect(reversedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterReversed, before);
          expect(repeatedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterRepeated, before);
        },
      );
    });
  });

  group('Given an incoming update batch containing a reserved typed UUID, ', () {
    late SyncNode target;
    late List<CrdtMergeChange> invalid;
    late Object before;

    setUp(() async {
      final source = await syncNode(await createAdditionalTestSession(), [
        UniqueUuid.t,
      ]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final row = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(source.offlineSync, row, transaction: tx),
      );

      await pushChanges(source, target);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.updateRow(
          source.offlineSync,
          row.copyWith(value: other),
          columns: (t) => [t.value],
          transaction: tx,
        ),
      );

      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(
          source.offlineSync,
          UniqueUuid(id: const Uuid().v7obj(), value: const Uuid().v7obj()),
          transaction: tx,
        ),
      );
      invalid = (await _export(source)).map((change) {
        if (change is CrdtMergeUpdate) return change.copyWith(value: reserved);

        return change;
      }).toList();
      await target.offlineSync.db.transactionForUser(testCrdtUserId, (_) async {});
      before = await _state(target);
    });

    group('when it is delivered repeatedly and in reversed order, ', () {
      Object? firstFailure;
      Object? reversedFailure;
      Object? repeatedFailure;
      late Object afterFirst;
      late Object afterReversed;
      late Object afterRepeated;

      setUp(() async {
        firstFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          firstFailure = error;
        }
        afterFirst = await _state(target);

        reversedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(
            invalid.reversed.toList(),
            userId: testCrdtUserId,
          );
        } on Object catch (error) {
          reversedFailure = error;
        }
        afterReversed = await _state(target);

        repeatedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          repeatedFailure = error;
        }
        afterRepeated = await _state(target);
      });

      test(
        'then every delivery is rejected without changing data or sync progress.',
        () async {
          expect(firstFailure, isA<OfflineSyncReservedValueException>());
          expect(afterFirst, before);
          expect(reversedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterReversed, before);
          expect(repeatedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterRepeated, before);
        },
      );
    });
  });

  group('Given an incoming update batch containing a reserved UUID string, ', () {
    late SyncNode target;
    late List<CrdtMergeChange> invalid;
    late Object before;

    setUp(() async {
      final source = await syncNode(await createAdditionalTestSession(), [
        UniqueUuid.t,
      ]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      final row = UniqueUuid(id: const Uuid().v7obj(), value: ordinary);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(source.offlineSync, row, transaction: tx),
      );

      await pushChanges(source, target);
      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.updateRow(
          source.offlineSync,
          row.copyWith(value: other),
          columns: (t) => [t.value],
          transaction: tx,
        ),
      );

      await source.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(
          source.offlineSync,
          UniqueUuid(id: const Uuid().v7obj(), value: const Uuid().v7obj()),
          transaction: tx,
        ),
      );
      invalid = (await _export(source)).map((change) {
        if (change is CrdtMergeUpdate) {
          return change.copyWith(value: reserved.toString());
        }

        return change;
      }).toList();
      await target.offlineSync.db.transactionForUser(testCrdtUserId, (_) async {});
      before = await _state(target);
    });

    group('when it is delivered repeatedly and in reversed order, ', () {
      Object? firstFailure;
      Object? reversedFailure;
      Object? repeatedFailure;
      late Object afterFirst;
      late Object afterReversed;
      late Object afterRepeated;

      setUp(() async {
        firstFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          firstFailure = error;
        }
        afterFirst = await _state(target);

        reversedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(
            invalid.reversed.toList(),
            userId: testCrdtUserId,
          );
        } on Object catch (error) {
          reversedFailure = error;
        }
        afterReversed = await _state(target);

        repeatedFailure = null;
        try {
          await target.offlineSync.db.mergeChanges(invalid, userId: testCrdtUserId);
        } on Object catch (error) {
          repeatedFailure = error;
        }
        afterRepeated = await _state(target);
      });

      test(
        'then every delivery is rejected without changing data or sync progress.',
        () async {
          expect(firstFailure, isA<OfflineSyncReservedValueException>());
          expect(afterFirst, before);
          expect(reversedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterReversed, before);
          expect(repeatedFailure, isA<OfflineSyncReservedValueException>());
          expect(afterRepeated, before);
        },
      );
    });
  });

  group('Given ordinary version-4, version-5, and version-7 unique UUIDs, ', () {
    late SyncNode source;
    late SyncNode target;
    late List<UuidValue> values;

    setUp(() async {
      source = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      target = await syncNode(await createAdditionalTestSession(), [UniqueUuid.t]);
      values = [
        ordinary,
        const UuidValue.raw('1384ce72-7ccf-5b5f-afc4-4fb11ac066d9'),
        const Uuid().v7obj(),
      ];
    });

    group('when they are inserted and synchronized, ', () {
      setUp(() async {
        await source.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueUuid.db.insert(
            source.offlineSync,
            values
                .map((value) => UniqueUuid(id: const Uuid().v7obj(), value: value))
                .toList(),
            transaction: tx,
          ),
        );
        await pushChanges(source, target);
      });

      test('then all authored UUIDs remain unchanged.', () async {
        expect(
          (await UniqueUuid.db.find(target.offlineSync)).map((r) => r.value),
          unorderedEquals(values),
        );
      });
    });
  });

  group('Given an untracked unique UUID table and a version-8 input, ', () {
    late SyncNode node;
    late UniqueUuid row;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [City.t]);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (_) async {});
      final space = (await OfflineSyncSpace.db.find(node.raw)).single;
      row = UniqueUuid(id: const Uuid().v7obj(), spaceId: space.id, value: reserved);
    });

    group('when the value is inserted twice through the sync session, ', () {
      Object? failure;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueUuid.db.insertRow(node.offlineSync, row, transaction: tx),
        );
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => UniqueUuid.db.insertRow(
              node.offlineSync,
              row.copyWith(id: const Uuid().v7obj()),
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database accepts the first claim and enforces ordinary uniqueness.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect((await UniqueUuid.db.find(node.offlineSync)).single.value, reserved);
        },
      );
    });
  });

  group(
    'Given version-8 primary keys, foreign keys, and a non-unique UUID column, ',
    () {
      late SyncNode source;
      late SyncNode target;
      late Person person;
      late Town town;
      late Types types;
      late UniqueCascadeReference reference;

      setUp(() async {
        final tables = [Person.t, Town.t, Types.t, UniqueCascadeReference.t];
        source = await syncNode(await createAdditionalTestSession(), tables);
        target = await syncNode(await createAdditionalTestSession(), tables);
        person = Person(id: reserved, name: 'mayor');
        town = Town(id: const Uuid().v7obj(), name: 'town', mayorId: reserved);
        types = Types(
          id: const Uuid().v7obj(),
          aBool: true,
          aDateTime: DateTime.utc(2026),
          aText: reserved.toString(),
          anInt: 1,
          anInt64: BigInt.one,
          aReal: 1,
          aBlob: ByteData(0),
          optionalUuid: reserved,
        );
        reference = UniqueCascadeReference(
          id: const Uuid().v7obj(),
          name: 'unique reference',
          parentId: reserved,
        );
      });

      group('when they are inserted and synchronized, ', () {
        setUp(() async {
          await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(source.offlineSync, person, transaction: tx);
            await Town.db.insertRow(source.offlineSync, town, transaction: tx);
            await Types.db.insertRow(source.offlineSync, types, transaction: tx);
            await UniqueCascadeReference.db.insertRow(
              source.offlineSync,
              reference,
              transaction: tx,
            );
          });
          await pushChanges(source, target);
        });

        test('then these UUIDs remain valid ordinary data.', () async {
          expect((await Person.db.find(target.offlineSync)).single.id, reserved);
          expect((await Town.db.find(target.offlineSync)).single.mayorId, reserved);
          expect(
            (await Types.db.find(target.offlineSync)).single.optionalUuid,
            reserved,
          );
          expect(
            (await UniqueCascadeReference.db.find(target.offlineSync)).single.parentId,
            reserved,
          );
        });
      });
    },
  );
  group('Given a unique UUID column and a generated version-8 input, ', () {
    late DstReplica replica;
    late UuidValue space;
    late DstSnapshot before;
    late DstOperations operations;
    late UniqueUuid row;

    setUp(() async {
      final random = DstRandom(62);
      final ids = DstIds(random);
      space = ids.next();
      replica = await DstReplica.create(
        name: 'reserved-uuid',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      before = await DstSnapshot.capture(replica);
      operations = DstOperations(random, ids);
      row = UniqueUuid(id: ids.next(), value: reserved);
    });

    group('when the DST tries to author it, ', () {
      late DstOperationOutcome result;

      setUp(() async {
        result = await operations.perform(
          replica,
          space,
          table: DstTable.uniqueUuid,
          action: DstAction.insert,
          body: (Transaction tx, evidence, refusal) async {
            evidence.write('unique_uuid', row.toJson());
            await UniqueUuid.db.insertRow(replica.session, row, transaction: tx);
            return DstOperationOutcome.applied;
          },
        );
      });

      test(
        'then it predicts the precise refusal and verifies complete rollback.',
        () async {
          expect(result, DstOperationOutcome.rejected);
          expect(operations.rejections, [
            'Reserved generated unique value for unique_uuid.value: $reserved',
          ]);
          expect(
            (await DstSnapshot.capture(replica)).renderRawMetadata(),
            before.renderRawMetadata(),
          );
        },
      );
    });
  });
}

Future<List<CrdtMergeChange>> _export(SyncNode node) => node.sync
    .collectPendingChanges(
      node.raw,
      checkpointsBySpaceUuid: {testCrdtUserId: 0},
    )
    .toList();

Future<List<Object?>> _facts(SyncNode node) async =>
    (await _export(node)).map((c) => c.toJson()).toList();

Future<Map<String, String>> _domain(SyncNode node) async => {
  for (final row in await UniqueUuid.db.find(
    node.offlineSync,
    where: (t) => t.includeHiddenRows,
  ))
    row.id.toString(): row.value.toString(),
};

Future<Object> _state(SyncNode node) async => [
  await _domain(node),
  await _facts(node),
  for (final row in await OfflineSyncSpace.db.find(node.raw)) row.toJson(),
];
