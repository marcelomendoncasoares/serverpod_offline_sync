import 'dart:async';

import 'package:serverpod/serverpod.dart' show LockMode, Transaction;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a user with prepared personal and shared spaces,', () {
    late UuidValue sharedSpaceId;
    late OfflineSyncSpace firstSpace;
    late OfflineSyncSpace otherSpace;
    late int userNodeId;

    setUp(() async {
      sharedSpaceId = const Uuid().v7obj();

      final manager = OfflineSyncSpaceManager(testSession);
      await manager.getOrCreate(testCrdtUserId);
      userNodeId = (await manager.getOrCreateUserNode(testCrdtUserId)).id!;
      await OfflineSyncSpaceManager(testSession).getOrCreate(sharedSpaceId);

      firstSpace = (await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      ))!;
      otherSpace = (await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(sharedSpaceId),
      ))!;

      await OfflineSyncSpaceMember.db.insertRow(
        testSession,
        OfflineSyncSpaceMember(
          spaceId: otherSpace.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );
    });

    test(
      'when a failed scope is caught and retried after another space writes, '
      'then domain rows and CRDT records use the prepared space and node IDs.',
      () async {
        final failure = StateError('roll back the first write');

        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, sharedSpaceId},
          (spaces) async {
            await expectLater(
              spaces.runForSpace(testCrdtUserId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'discard'),
                  transaction: tx,
                );

                throw failure;
              }),
              throwsA(same(failure)),
            );

            await spaces.runForSpace(sharedSpaceId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'other'),
                transaction: tx,
              );
            });

            await spaces.runForSpace(testCrdtUserId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'retry'),
                transaction: tx,
              );
            });
          },
        );

        final rows = await Person.db.find(testSession);
        final records = await CrdtDataRow.db.find(testSession);

        expect(rows.map((row) => row.name).toSet(), {'other', 'retry'});

        for (final row in rows) {
          final expectedSpace = row.name == 'retry' ? firstSpace : otherSpace;
          final record = records.singleWhere((record) => record.uuidRowId == row.id);

          expect(row.spaceId, expectedSpace.id);
          expect(record.spaceId, expectedSpace.id);
          expect(record.nodeId, userNodeId);
        }
      },
    );

    test(
      'when a nested exception is caught and the outer scope writes again, '
      'then the outer space and read identity are restored.',
      () async {
        final failure = StateError('nested failure');
        late List<Person> visible;

        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, sharedSpaceId},
          (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
            await Person.db.insertRow(session, Person(name: 'before'), transaction: tx);

            await expectLater(
              spaces.runForSpace(sharedSpaceId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'discard'),
                  transaction: tx,
                );

                throw failure;
              }),
              throwsA(same(failure)),
            );

            await Person.db.insertRow(session, Person(name: 'after'), transaction: tx);

            visible = await Person.db.find(session, transaction: tx);
          }),
        );

        final rows = await Person.db.find(testSession);

        expect(rows.map((row) => row.name).toSet(), {'before', 'after'});
        expect(rows.map((row) => row.spaceId).toSet(), {firstSpace.id});
        expect(visible.map((row) => row.name).toSet(), {'before', 'after'});
      },
    );

    test(
      'when sibling scopes overlap on one transaction, '
      'then the second is rejected before its callback or savepoint can interfere.',
      () async {
        final entered = Completer<void>();
        final resume = Completer<void>();
        var siblingRan = false;

        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, sharedSpaceId},
          (spaces) async {
            final first = spaces.runForSpace(testCrdtUserId, (tx) async {
              entered.complete();
              await resume.future;

              await Person.db.insertRow(
                session,
                Person(name: 'first'),
                transaction: tx,
              );
            });
            await entered.future;

            try {
              await expectLater(
                spaces.runForSpace(sharedSpaceId, (tx) async {
                  siblingRan = true;
                  await Person.db.insertRow(
                    session,
                    Person(name: 'sibling'),
                    transaction: tx,
                  );
                }),
                throwsA(isA<StateError>()),
              );
            } finally {
              resume.complete();
              await first;
            }

            // The rejection must also leave the transaction available afterwards.
            await spaces.runForSpace(sharedSpaceId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'later'),
                transaction: tx,
              );
            });
          },
        );

        final rows = await Person.db.find(testSession);

        expect(siblingRan, isFalse);
        expect(rows.map((row) => (row.name, row.spaceId)).toSet(), {
          ('first', firstSpace.id),
          ('later', otherSpace.id),
        });
      },
    );

    group("and a row outside the acting user's memberships,", () {
      late Person unrelated;
      late OfflineSyncDatabaseSession otherWrapper;
      late OfflineSyncDatabaseSession persistent;

      setUp(() async {
        unrelated = await session.db.transactionForUser(
          const Uuid().v7obj(),
          (tx) =>
              Person.db.insertRow(session, Person(name: 'unrelated'), transaction: tx),
        );

        otherWrapper = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: testSyncTables,
        );
        persistent = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: testSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await otherWrapper.db.initialize();
        await persistent.db.initialize();
      });

      group('when successful and failed scopes return to an unbound transaction,', () {
        Object? unboundWriteError;
        Object? failedScopeError;
        Object? laterWriteError;
        Object? findError;
        Object? byIdError;
        Object? firstError;
        Object? countError;
        Object? lockError;
        Object? wrappedReadError;
        Object? persistentReadError;
        Object? afterFailureReadError;
        late List<Person> visible;
        late List<Person> committed;
        late StateError failure;

        setUp(() async {
          failure = StateError('failed scope');
          late Transaction tx;

          await session.db.transactionForSpaces(
            testCrdtUserId,
            {testCrdtUserId, sharedSpaceId},
            (spaces) async {
              await spaces.runForSpace(testCrdtUserId, (scopeTx) async {
                tx = scopeTx;
                await Person.db.insertRow(
                  session,
                  Person(name: 'first'),
                  transaction: tx,
                );
              });

              unboundWriteError = await _errorOf(
                Person.db.insertRow(session, Person(name: 'unbound'), transaction: tx),
              );

              findError = await _errorOf(Person.db.find(session, transaction: tx));
              byIdError = await _errorOf(
                Person.db.findById(session, unrelated.id!, transaction: tx),
              );
              firstError = await _errorOf(
                Person.db.findFirstRow(session, transaction: tx),
              );
              countError = await _errorOf(Person.db.count(session, transaction: tx));
              lockError = await _errorOf(
                Person.db.lockRows(
                  session,
                  where: (t) => t.id.equals(unrelated.id),
                  lockMode: LockMode.forUpdate,
                  transaction: tx,
                ),
              );
              wrappedReadError = await _errorOf(
                Person.db.find(otherWrapper, transaction: tx),
              );
              persistentReadError = await _errorOf(
                Person.db.find(persistent, transaction: tx),
              );

              failedScopeError = await _errorOf(
                spaces.runForSpace(
                  sharedSpaceId,
                  (tx) async => throw failure,
                ),
              );

              laterWriteError = await _errorOf(
                Person.db.insertRow(
                  session,
                  Person(name: 'still unbound'),
                  transaction: tx,
                ),
              );
              afterFailureReadError = await _errorOf(
                Person.db.find(session, transaction: tx),
              );

              await spaces.runForSpace(sharedSpaceId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'other'),
                  transaction: tx,
                );

                visible = await Person.db.find(session, transaction: tx);
              });
            },
          );

          committed = await Person.db.find(testSession);
        });

        test(
          'then every tracked read entry point rejects the unbound transaction.',
          () {
            expect(findError, isA<StateError>());
            expect(byIdError, isA<StateError>());
            expect(firstError, isA<StateError>());
            expect(countError, isA<StateError>());
            expect(lockError, isA<StateError>());
          },
        );

        test(
          'then another wrapper or a persistent user cannot bypass the read guard.',
          () {
            expect(wrappedReadError, isA<StateError>());
            expect(persistentReadError, isA<StateError>());
          },
        );

        test('then a caught scope failure still leaves reads and writes rejected.', () {
          expect(unboundWriteError, isA<StateError>());
          expect(failedScopeError, same(failure));
          expect(laterWriteError, isA<StateError>());
          expect(afterFailureReadError, isA<StateError>());
        });

        test('then a later scope reads only memberships and commits normally.', () {
          expect(visible.map((row) => row.name).toSet(), {'first', 'other'});
          expect(committed.map((row) => row.name).toSet(), {
            'unrelated',
            'first',
            'other',
          });
        });
      });
    });

    test(
      'when both spaces write and the enclosing transaction rolls back, '
      'then domain and CRDT changes roll back while preparation survives.',
      () async {
        final beforeNode = (await CrdtNode.db.find(testSession)).single;
        final failure = StateError('whole transaction rollback');

        await expectLater(
          session.db.transactionForSpaces(
            testCrdtUserId,
            {testCrdtUserId, sharedSpaceId},
            (spaces) async {
              await spaces.runForSpace(testCrdtUserId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'first'),
                  transaction: tx,
                );
              });

              await spaces.runForSpace(sharedSpaceId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'other'),
                  transaction: tx,
                );
              });

              throw failure;
            },
          ),
          throwsA(same(failure)),
        );

        expect(await Person.db.count(testSession), 0);
        expect(await CrdtDataRow.db.count(testSession), 0);
        expect(await CrdtDataField.db.count(testSession), 0);
        expect(await CrdtDataDeleted.db.count(testSession), 0);

        expect(await OfflineSyncSpace.db.count(testSession), 2);
        expect(await OfflineSyncSpaceNode.db.count(testSession), 2);

        final afterNode = (await CrdtNode.db.find(testSession)).single;
        expect(afterNode.toJson(), beforeNode.toJson());
      },
    );

    test(
      'when a failed explicit scope returns to a persistent-user transaction, '
      'then unscoped writes are rejected and a declared scope keeps the acting user.',
      () async {
        final persistentUser = const Uuid().v7obj();
        final persistent = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: testSyncTables,
          persistentUserId: persistentUser,
        );
        await persistent.db.initialize();
        await persistent.db.currentNodeId();

        final failure = StateError('explicit scope failure');
        late Transaction tx;
        Object? unscopedError;

        await persistent.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, sharedSpaceId},
          (spaces) async {
            await expectLater(
              spaces.runForSpace(sharedSpaceId, (scopeTx) async {
                tx = scopeTx;
                await Person.db.insertRow(
                  persistent,
                  Person(name: 'discard'),
                  transaction: tx,
                );

                throw failure;
              }),
              throwsA(same(failure)),
            );

            unscopedError = await _errorOf(
              Person.db.insertRow(
                persistent,
                Person(name: 'undeclared persistent space'),
                transaction: tx,
              ),
            );

            await spaces.runForSpace(testCrdtUserId, (tx) {
              return Person.db.insertRow(
                persistent,
                Person(name: 'personal'),
                transaction: tx,
              );
            });
          },
        );

        final rows = await Person.db.find(testSession);
        final records = await CrdtDataRow.db.find(testSession);
        final actingNode = (await CrdtNode.db.findFirstRow(
          testSession,
          where: (t) => t.localUserUuid.equals(testCrdtUserId),
        ))!;

        expect(unscopedError, isA<StateError>());
        expect(rows.single.name, 'personal');
        expect(rows.single.spaceId, firstSpace.id);
        expect(records.single.spaceId, firstSpace.id);
        expect(records.single.nodeId, actingNode.id);
      },
    );

    group('with one existing person in each space,', () {
      late Person first;
      late Person other;

      setUp(() async {
        first = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              Person.db.insertRow(session, Person(name: 'original'), transaction: tx),
        );

        other = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              Person.db.insertRow(session, Person(name: 'original'), transaction: tx),
          spaceId: sharedSpaceId,
        );
      });

      group(
        'when a nested scope updates its row and the outer scope deletes its row,',
        () {
          late List<Person> remaining;
          late List<CrdtDataRow> records;
          late List<CrdtDataDeleted> deleted;

          setUp(() async {
            await session.db.transactionForSpaces(
              testCrdtUserId,
              {testCrdtUserId, sharedSpaceId},
              (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
                await spaces.runForSpace(
                  sharedSpaceId,
                  (tx) => Person.db.updateWhere(
                    session,
                    columnValues: (t) => [t.name('updated')],
                    where: (t) => t.name.equals('original'),
                    transaction: tx,
                  ),
                );

                await Person.db.deleteWhere(
                  session,
                  where: (t) => t.name.equals('original'),
                  transaction: tx,
                );
              }),
            );

            remaining = await Person.db.find(session);
            records = await CrdtDataRow.db.find(testSession);
            deleted = await CrdtDataDeleted.db.find(testSession);
          });

          test(
            'then only the nested space row remains visible with its updated value.',
            () {
              expect(remaining.single.id, other.id);
              expect(remaining.single.name, 'updated');
            },
          );

          test('then the deletion is recorded only against the outer space row.', () {
            final tombstoned = records.singleWhere((row) => row.uuidRowId == first.id);

            expect(tombstoned.spaceId, firstSpace.id);
            expect(deleted.single.rowId, tombstoned.id);
            expect(
              records.singleWhere((row) => row.uuidRowId == other.id).spaceId,
              otherSpace.id,
            );
          });
        },
      );
    });
  });
}

Future<Object?> _errorOf(Future<Object?> operation) async {
  try {
    await operation;
    return null;
  } on Object catch (error) {
    return error;
  }
}
