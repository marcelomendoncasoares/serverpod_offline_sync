import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseQueryException, DatabaseUniqueViolationException, SqliteErrorCode;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given two local records with distinct unique names, ', () {
    late SyncNode node;
    late Unique occupied;
    late Unique free;
    late List<Object?> before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      occupied = Unique(id: const Uuid().v7obj(), name: 'occupied');
      free = Unique(id: const Uuid().v7obj(), name: 'free');
      await node.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insert(node.offlineSync, [occupied, free], transaction: tx),
      );
      before = await _export(node);
    });

    group('when a new record is inserted with the occupied name, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insertRow(
              node.offlineSync,
              Unique(id: const Uuid().v7obj(), name: 'occupied'),
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database rejects the write and both domain and sync facts roll back.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free']),
          );
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when a record with an automatically generated identity is inserted with the occupied name, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.insertRow(
                node.offlineSync,
                Unique(name: 'occupied'),
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the database rejects the write and both domain and sync facts roll back.',
          () async {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(
              (await Unique.db.find(node.offlineSync)).map((row) => row.name),
              unorderedEquals(['occupied', 'free']),
            );
            expect(await _export(node), before);
          },
        );
      },
    );

    group(
      'when a batch insert gives two new records the same previously unused name, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.insert(node.offlineSync, [
                Unique(id: const Uuid().v7obj(), name: 'new-name'),
                Unique(id: const Uuid().v7obj(), name: 'new-name'),
              ], transaction: tx),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the database rejects the write and both domain and sync facts roll back.',
          () async {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(
              (await Unique.db.find(node.offlineSync)).map((row) => row.name),
              unorderedEquals(['occupied', 'free']),
            );
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when a row update assigns the occupied name to the other record, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateRow(
              node.offlineSync,
              free.copyWith(name: 'occupied'),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database rejects the write and both domain and sync facts roll back.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free']),
          );
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when a batch update assigns both records the same previously unused name, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.update(
                node.offlineSync,
                [occupied.copyWith(name: 'new-name'), free.copyWith(name: 'new-name')],
                columns: (t) => [t.name],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the database rejects the write and both domain and sync facts roll back.',
          () async {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(
              (await Unique.db.find(node.offlineSync)).map((row) => row.name),
              unorderedEquals(['occupied', 'free']),
            );
            expect(await _export(node), before);
          },
        );
      },
    );

    group(
      'when a predicate update assigns both records the same previously unused name, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.updateWhere(
                node.offlineSync,
                columnValues: (t) => [t.name('new-name')],
                where: (t) => t.id.inSet(<UuidValue>{occupied.id!, free.id!}),
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the database rejects the write and both domain and sync facts roll back.',
          () async {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(
              (await Unique.db.find(node.offlineSync)).map((row) => row.name),
              unorderedEquals(['occupied', 'free']),
            );
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when an upsert inserts a new identity with the occupied name, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsertRow(
              node.offlineSync,
              Unique(id: const Uuid().v7obj(), name: 'occupied'),
              conflictColumns: (t) => [t.id],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database rejects the write and both domain and sync facts roll back.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free']),
          );
          expect(await _export(node), before);
        },
      );
    });

    group('when an upsert changes the other record to the occupied name, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsertRow(
              node.offlineSync,
              free.copyWith(name: 'occupied'),
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
        'then the database rejects the write and both domain and sync facts roll back.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free']),
          );
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when a batch upsert inserts two new identities with the same unused name, ',
      () {
        Object? failure;

        setUp(() async {
          failure = null;
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsert(
                node.offlineSync,
                [
                  Unique(id: const Uuid().v7obj(), name: 'new-name'),
                  Unique(id: const Uuid().v7obj(), name: 'new-name'),
                ],
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the database rejects the write and both domain and sync facts roll back.',
          () async {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(
              (await Unique.db.find(node.offlineSync)).map((row) => row.name),
              unorderedEquals(['occupied', 'free']),
            );
            expect(await _export(node), before);
          },
        );
      },
    );

    group('when a batch upsert affects the same identity twice, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsert(
              node.offlineSync,
              [free.copyWith(name: 'first-write'), free.copyWith(name: 'second-write')],
              conflictColumns: (t) => [t.id],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database rejects the write and both domain and sync facts roll back.',
        () async {
          expect(failure, isA<DatabaseQueryException>());
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free']),
          );
          expect(await _export(node), before);
        },
      );
    });

    group('when an upsert excludes the duplicate change with its predicate, ', () {
      Unique? saved;

      setUp(() async {
        saved = await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.upsertRow(
            node.offlineSync,
            free.copyWith(name: 'occupied'),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            updateWhere: (t) => t.name.equals('absent'),
            transaction: tx,
          ),
        );
      });

      test('then no row is updated and no sync facts change.', () async {
        expect(saved, isNull);
        expect(
          (await Unique.db.find(node.offlineSync)).map((row) => row.name),
          unorderedEquals(['occupied', 'free']),
        );
        expect(await _export(node), before);
      });
    });

    group(
      'when an insert batch ignores a duplicate and also contains an unused name, ',
      () {
        late List<Unique> saved;

        setUp(() async {
          saved = await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insert(
              node.offlineSync,
              [
                Unique(id: const Uuid().v7obj(), name: 'occupied'),
                Unique(id: const Uuid().v7obj(), name: 'accepted'),
              ],
              ignoreConflicts: true,
              transaction: tx,
            ),
          );
        });

        test('then only the nonconflicting record is inserted and exported.', () async {
          expect(saved.map((row) => row.name), ['accepted']);
          expect(
            (await Unique.db.find(node.offlineSync)).map((row) => row.name),
            unorderedEquals(['occupied', 'free', 'accepted']),
          );
          expect(await _export(node), hasLength(before.length + 1));
        });
      },
    );
  });

  group('Given a deleted record whose former name is now occupied,', () {
    late SyncNode node;
    late Unique deleted;
    late List<Object?> before;

    setUp(() async {
      node = await syncNode(await createAdditionalTestSession(), [Unique.t]);
      deleted = Unique(id: const Uuid().v7obj(), name: 'occupied');
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Unique.db.insertRow(node.offlineSync, deleted, transaction: tx);
        await Unique.db.deleteRow(node.offlineSync, deleted, transaction: tx);
        await Unique.db.insertRow(
          node.offlineSync,
          Unique(id: const Uuid().v7obj(), name: 'occupied'),
          transaction: tx,
        );
      });
      before = await _export(node);
    });

    group('when an insert restores the deleted record with its former name,', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insertRow(node.offlineSync, deleted, transaction: tx),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the occupied name is rejected and the tombstone and sync facts are unchanged.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(await Unique.db.findById(node.offlineSync, deleted.id!), isNull);
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'occupied',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group('when an upsert restores the deleted record with its former name,', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.upsertRow(
              node.offlineSync,
              deleted,
              conflictColumns: (t) => [t.id],
              transaction: tx,
            ),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the occupied name is rejected and the tombstone and sync facts are unchanged.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(await Unique.db.findById(node.offlineSync, deleted.id!), isNull);
          expect((await Unique.db.find(node.offlineSync)).map((row) => row.name), [
            'occupied',
          ]);
          expect(await _export(node), before);
        },
      );
    });

    group(
      'when a batch upsert restores the same identity twice without returning rows,',
      () {
        Object? failure;
        Object? nativeFailure;

        setUp(() async {
          failure = null;
          nativeFailure = null;
          final writes = [
            deleted.copyWith(name: 'first-write'),
            deleted.copyWith(name: 'second-write'),
          ];
          try {
            await node.raw.db.upsert(
              writes,
              conflictColumns: [Unique.t.id],
              noReturn: true,
            );
          } on Object catch (error) {
            nativeFailure = error;
          }
          try {
            await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => Unique.db.upsert(
                node.offlineSync,
                writes,
                conflictColumns: (t) => [t.id],
                noReturn: true,
                transaction: tx,
              ),
            );
          } on Object catch (error) {
            failure = error;
          }
        });

        test(
          'then the repeated target is rejected and the tombstone and sync facts are unchanged.',
          () async {
            expect(
              failure,
              isA<DatabaseQueryException>().having(
                (error) => error.message,
                'message',
                'ON CONFLICT DO UPDATE command cannot affect row a second time',
              ),
            );
            expect(await Unique.db.findById(node.offlineSync, deleted.id!), isNull);
            expect(await _export(node), before);
          },
        );

        test('then its error code matches an ordinary SQLite batch upsert.', () {
          expect(
            nativeFailure,
            isA<DatabaseQueryException>().having(
              (error) => error.code,
              'code',
              SqliteErrorCode.integrityConstraintViolation,
            ),
          );
          expect(
            failure,
            isA<DatabaseQueryException>().having(
              (error) => error.code,
              'code',
              (nativeFailure! as DatabaseQueryException).code,
            ),
          );
        });
      },
    );
  });

  group('Given two new records whose nullable unique value is null, ', () {
    late SyncNode node;
    late UniqueNullable first;
    late UniqueNullable second;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), [UniqueNullable.t]);
      first = UniqueNullable(id: const Uuid().v7obj());
      second = UniqueNullable(id: const Uuid().v7obj());
    });

    group('when both records are inserted in one local batch, ', () {
      setUpAll(() async {
        await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueNullable.db.insert(node.offlineSync, [
            first,
            second,
          ], transaction: tx),
        );
      });

      test('then ordinary nullable uniqueness permits both records.', () async {
        expect(
          (await UniqueNullable.db.find(node.offlineSync)).map((row) => row.value),
          [null, null],
        );
      });
    });
  });
}

Future<List<Object?>> _export(SyncNode node) => node.sync
    .collectPendingChanges(
      node.raw,
      checkpointsBySpaceUuid: {testCrdtUserId: 0},
    )
    .map((change) => change.toJson())
    .toList();
