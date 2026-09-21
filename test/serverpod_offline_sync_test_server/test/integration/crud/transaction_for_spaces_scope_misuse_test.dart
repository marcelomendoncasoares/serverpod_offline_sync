import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a user with prepared personal and shared spaces,', () {
    late OfflineSyncSpace shared;

    setUp(() async {
      shared = await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
      await OfflineSyncSpaceMember.db.insertRow(
        testSession,
        OfflineSyncSpaceMember(
          spaceId: shared.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );
      await session.db.transactionForSpaces<void>(
        testCrdtUserId,
        {testCrdtUserId, shared.uuidSpaceId},
        (_) async {},
      );
    });

    group('when unrelated code inspects binding maps while a scope is paused,', () {
      Object? inspectionError;
      Object? transactionError;
      late List<OfflineSyncSpace> inspectedSpaces;
      late List<UuidValue> inspectedUsers;
      late List<Person> rows;
      late List<CrdtDataRow> records;

      setUp(() async {
        inspectionError = null;
        transactionError = null;
        inspectedSpaces = [];
        inspectedUsers = [];
        final entered = Completer<void>();
        final resume = Completer<void>();
        final operation = session.db
            .transactionForSpaces<void>(testCrdtUserId, {testCrdtUserId}, (
              spaces,
            ) async {
              await spaces.runForSpace(testCrdtUserId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'before'),
                  transaction: tx,
                );
                entered.complete();
                await resume.future;
                await Person.db.insertRow(
                  session,
                  Person(name: 'after'),
                  transaction: tx,
                );
              });
            })
            .catchError((Object error) {
              transactionError = error;
            });
        await entered.future;
        try {
          // Diagnostics outside the transaction must not invalidate its scope.
          inspectedSpaces = spaceForTransaction.values.toList();
          inspectedUsers = userForTransaction.entries
              .map((entry) => entry.value)
              .toList();
          spaceForTransaction.toString();
          userForTransaction.toString();
        } on Object catch (error) {
          inspectionError = error;
        } finally {
          resume.complete();
          await operation;
        }
        rows = await Person.db.find(testSession);
        records = await CrdtDataRow.db.find(testSession);
      });

      test(
        'then inspection succeeds and the transaction commits its domain and CRDT writes.',
        () {
          expect(inspectionError, isNull);
          expect(transactionError, isNull);
          expect(inspectedSpaces.single.uuidSpaceId, testCrdtUserId);
          expect(inspectedUsers, [testCrdtUserId]);
          expect(rows.map((row) => row.name).toSet(), {'before', 'after'});
          expect(
            records.map((record) => record.uuidRowId).toSet(),
            rows.map((row) => row.id).toSet(),
          );
          expect(records.map((record) => record.spaceId).toSet(), {
            inspectedSpaces.single.id,
          });
        },
      );
    });

    group('when a parent writes while its child is running and catches the error,', () {
      Object? writeError;
      Object? transactionError;
      late int rows;
      late int records;

      setUp(() async {
        writeError = null;
        transactionError = null;
        final entered = Completer<void>();
        final resume = Completer<void>();
        await session.db
            .transactionForSpaces<void>(
              testCrdtUserId,
              {testCrdtUserId, shared.uuidSpaceId},
              (spaces) async {
                try {
                  await spaces.runForSpace(testCrdtUserId, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'before'),
                      transaction: tx,
                    );
                    final child = spaces.runForSpace<void>(shared.uuidSpaceId, (
                      _,
                    ) async {
                      entered.complete();
                      await resume.future;
                    });
                    await entered.future;
                    try {
                      await Person.db.insertRow(
                        session,
                        Person(name: 'private'),
                        transaction: tx,
                      );
                    } on Object catch (error) {
                      writeError = error;
                    } finally {
                      resume.complete();
                      await child;
                    }
                  });
                } on Object {
                  // Catching a scope error must not permit the poisoned root to commit.
                }
              },
            )
            .catchError((Object error) {
              transactionError = error;
            });
        rows = await Person.db.count(testSession);
        records = await CrdtDataRow.db.count(testSession);
      });

      test('then the misuse throws and no private row or earlier write commits.', () {
        expect(writeError, isA<StateError>());
        expect(transactionError, isA<StateError>());
        expect(rows, 0);
        expect(records, 0);
      });
    });

    group('when a parent reads while its child is running and catches the error,', () {
      Object? readError;
      Object? transactionError;
      late int rows;
      late int records;

      setUp(() async {
        readError = null;
        transactionError = null;
        final entered = Completer<void>();
        final resume = Completer<void>();
        await session.db
            .transactionForSpaces<void>(
              testCrdtUserId,
              {testCrdtUserId, shared.uuidSpaceId},
              (spaces) async {
                try {
                  await spaces.runForSpace(testCrdtUserId, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'before'),
                      transaction: tx,
                    );
                    final child = spaces.runForSpace<void>(shared.uuidSpaceId, (
                      _,
                    ) async {
                      entered.complete();
                      await resume.future;
                    });
                    await entered.future;
                    try {
                      await Person.db.find(session, transaction: tx);
                    } on Object catch (error) {
                      readError = error;
                    } finally {
                      resume.complete();
                      await child;
                    }
                  });
                } on Object {
                  // The root must still fail even when the caller handles scope errors.
                }
              },
            )
            .catchError((Object error) {
              transactionError = error;
            });
        rows = await Person.db.count(testSession);
        records = await CrdtDataRow.db.count(testSession);
      });

      test('then the read is rejected and the earlier write rolls back.', () {
        expect(readError, isA<StateError>());
        expect(transactionError, isA<StateError>());
        expect(rows, 0);
        expect(records, 0);
      });
    });

    group(
      'when a caller destroys a scope savepoint and catches its rollback failure,',
      () {
        Object? scopeError;
        Object? transactionError;
        late int rows;
        late int records;

        setUp(() async {
          scopeError = null;
          transactionError = null;
          await session.db
              .transactionForSpaces<void>(testCrdtUserId, {testCrdtUserId}, (
                spaces,
              ) async {
                final tx = await spaces.runForSpace(testCrdtUserId, (tx) async => tx);
                final earlierSavepoint = await tx.createSavepoint();
                try {
                  await spaces.runForSpace(testCrdtUserId, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'must not commit'),
                      transaction: tx,
                    );
                    // Releasing an earlier savepoint destroys all later ones.
                    await earlierSavepoint.release();
                    throw StateError('scope action failed');
                  });
                } on Object catch (error) {
                  scopeError = error;
                }
              })
              .catchError((Object error) {
                transactionError = error;
              });
          rows = await Person.db.count(testSession);
          records = await CrdtDataRow.db.count(testSession);
        });

        test(
          'then the enclosing transaction fails and the failed scope cannot commit.',
          () {
            expect(scopeError, isA<RollbackToSavepointFailedException>());
            expect(transactionError, isA<StateError>());
            expect(rows, 0);
            expect(records, 0);
          },
        );
      },
    );

    group('and a nested parent with a child suspended on I/O,', () {
      late Completer<void> finishParent;
      late Future<void> operation;
      Object? parentError;
      Object? transactionError;

      setUp(() async {
        finishParent = Completer<void>();
        parentError = null;
        transactionError = null;
        final childEntered = Completer<void>();
        final parentReady = Completer<void>();
        final resumeChild = Completer<void>();
        late Future<void> child;
        operation = session.db
            .transactionForSpaces<void>(
              testCrdtUserId,
              {testCrdtUserId, shared.uuidSpaceId},
              (spaces) async {
                try {
                  await spaces.runForSpace(testCrdtUserId, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'before'),
                      transaction: tx,
                    );
                    try {
                      await spaces.runForSpace(shared.uuidSpaceId, (_) async {
                        child = spaces.runForSpace<void>(testCrdtUserId, (tx) async {
                          childEntered.complete();
                          await resumeChild.future;
                          await Person.db.insertRow(
                            session,
                            Person(name: 'late child'),
                            transaction: tx,
                          );
                        });
                        unawaited(child.catchError((Object _) {}));
                        await childEntered.future;
                        parentReady.complete();
                        await finishParent.future;
                      });
                    } on Object catch (error) {
                      parentError = error;
                    } finally {
                      resumeChild.complete();
                      await child.catchError((Object _) {});
                    }
                    // The child is fully drained before the enclosing callback ends.
                    // Merely checking for unfinished scopes at root exit misses this.
                    await Person.db.insertRow(
                      session,
                      Person(name: 'after'),
                      transaction: tx,
                    );
                  });
                } on Object {
                  // All scope failures are caught; root health must prevent a commit.
                }
              },
            )
            .catchError((Object error) {
              transactionError = error;
            });
        await parentReady.future;
      });

      group(
        'when the parent returns before the child and both finish before root exit,',
        () {
          late int rows;
          late int records;

          setUp(() async {
            finishParent.complete();
            await operation;
            rows = await Person.db.count(testSession);
            records = await CrdtDataRow.db.count(testSession);
          });

          test('then catching the scope errors cannot commit misdirected writes.', () {
            expect(parentError, isA<StateError>());
            expect(transactionError, isA<StateError>());
            expect(rows, 0);
            expect(records, 0);
          });
        },
      );

      group(
        'when the parent throws before the child and both finish before root exit,',
        () {
          late int rows;
          late int records;

          setUp(() async {
            finishParent.completeError(StateError('parent action failed'));
            await operation;
            rows = await Person.db.count(testSession);
            records = await CrdtDataRow.db.count(testSession);
          });

          test('then catching the scope errors cannot commit misdirected writes.', () {
            expect(parentError, isA<StateError>());
            expect(transactionError, isA<StateError>());
            expect(rows, 0);
            expect(records, 0);
          });
        },
      );
    });
  });
}
