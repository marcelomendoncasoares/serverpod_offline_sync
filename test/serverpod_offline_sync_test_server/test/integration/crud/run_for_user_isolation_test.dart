import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  test(
    'Given a personal space that has not been prepared, '
    'when it is requested inside a caller transaction, '
    'then the callback is rejected without creating metadata.',
    () async {
      var callbackRan = false;
      await session.db.transaction((tx) async {
        await expectLater(
          session.db.runForUser(testCrdtUserId, (tx) async {
            callbackRan = true;
          }, transaction: tx),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('prepareForUser'),
            ),
          ),
        );
      });

      expect(callbackRan, isFalse);
      expect(await OfflineSyncSpace.db.count(testSession), 0);
      expect(await CrdtNode.db.count(testSession), 0);
      expect(await OfflineSyncSpaceNode.db.count(testSession), 0);
    },
  );

  group('Given a space row without prepared replica metadata,', () {
    setUp(() async {
      await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: testCrdtUserId),
      );
    });

    test(
      'when it is requested inside a caller transaction, '
      'then the callback is rejected without repairing metadata.',
      () async {
        var callbackRan = false;
        await session.db.transaction((tx) async {
          await expectLater(
            session.db.runForUser(testCrdtUserId, (tx) async {
              callbackRan = true;
            }, transaction: tx),
            throwsA(isA<StateError>()),
          );
        });

        expect(callbackRan, isFalse);
        expect(await CrdtNode.db.count(testSession), 0);
        expect(await OfflineSyncSpaceNode.db.count(testSession), 0);
      },
    );
  });

  group('Given a prepared space accessed through a new uninitialized wrapper,', () {
    late OfflineSyncDatabaseSession fresh;

    setUp(() async {
      await session.db.prepareForUser(testCrdtUserId);
      fresh = OfflineSyncDatabaseSession.wraps(
        testSession,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
    });

    test(
      'when it joins an existing transaction, '
      'then it requests initialization before executing the callback.',
      () async {
        var callbackRan = false;
        await session.db.transaction((tx) async {
          await expectLater(
            fresh.db
                .runForUser(testCrdtUserId, (tx) async {
                  callbackRan = true;
                }, transaction: tx)
                .timeout(const Duration(seconds: 2)),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('initialize()'),
              ),
            ),
          );
        });

        expect(callbackRan, isFalse);
        expect(await OfflineSyncSpace.db.count(testSession), 1);
        expect(await CrdtNode.db.count(testSession), 1);
      },
    );
  });

  group('Given a prepared shared space without a membership for the user,', () {
    late OfflineSyncSpace shared;

    setUp(() async {
      shared = await OfflineSyncSpaceManager(
        testSession,
      ).getOrCreate(const Uuid().v7obj());
    });

    group(
      'when membership is granted and a row is written in the same transaction,',
      () {
        late List<Person> visible;

        setUp(() async {
          await session.db.transaction((tx) async {
            await OfflineSyncSpaceMember.db.insertRow(
              session,
              OfflineSyncSpaceMember(
                spaceId: shared.id!,
                userUuid: testCrdtUserId,
                role: OfflineSyncSpaceRole.readWrite,
              ),
              transaction: tx,
            );
            await session.db.runForUser(
              testCrdtUserId,
              (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'shared'),
                  transaction: tx,
                );
                visible = await Person.db.find(session, transaction: tx);
              },
              spaceId: shared.uuidSpaceId,
              transaction: tx,
            );
          });
        });

        test('then the callback can read its uncommitted row.', () {
          expect(visible.map((row) => row.name), ['shared']);
        });
      },
    );
  });

  group('Given a prepared shared space with a read-only member,', () {
    late OfflineSyncSpace shared;

    setUp(() async {
      await session.db.prepareForUser(testCrdtUserId);
      shared = await OfflineSyncSpaceManager(
        testSession,
      ).getOrCreate(const Uuid().v7obj());
      await OfflineSyncSpaceMember.db.insertRow(
        testSession,
        OfflineSyncSpaceMember(
          spaceId: shared.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readOnly,
        ),
      );
    });

    test(
      'when a nested shared write is rejected and its exception is caught, '
      'then the callback is skipped and the outer personal scope can continue.',
      () async {
        var sharedCallbackRan = false;
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await expectLater(
            session.db.runForUser(
              testCrdtUserId,
              (tx) async {
                sharedCallbackRan = true;
              },
              spaceId: shared.uuidSpaceId,
              transaction: tx,
            ),
            throwsA(isA<OfflineSyncSpaceRoleException>()),
          );
          await Person.db.insertRow(session, Person(name: 'personal'), transaction: tx);
        });

        final row = (await Person.db.find(testSession)).single;
        final space = await OfflineSyncSpace.db.findById(testSession, row.spaceId!);
        expect(sharedCallbackRan, isFalse);
        expect(space!.uuidSpaceId, testCrdtUserId);
      },
    );
  });

  group('Given two prepared personal spaces,', () {
    late UuidValue otherUser;
    late OfflineSyncSpace firstSpace;
    late OfflineSyncSpace otherSpace;

    setUp(() async {
      otherUser = const Uuid().v7obj();
      await session.db.prepareForUser(testCrdtUserId);
      await session.db.prepareForUser(otherUser);
      firstSpace = (await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      ))!;
      otherSpace = (await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(otherUser),
      ))!;
    });

    test(
      'when a failed scope is caught and retried after another space writes, '
      'then domain rows and CRDT records use the prepared space and node IDs.',
      () async {
        final failure = StateError('roll back the first write');
        await session.db.transaction((tx) async {
          await expectLater(
            session.db.runForUser(testCrdtUserId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'discard'),
                transaction: tx,
              );
              throw failure;
            }, transaction: tx),
            throwsA(same(failure)),
          );
          await session.db.runForUser(otherUser, (tx) async {
            await Person.db.insertRow(session, Person(name: 'other'), transaction: tx);
          }, transaction: tx);
          await session.db.runForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(session, Person(name: 'retry'), transaction: tx);
          }, transaction: tx);
        });

        final rows = await Person.db.find(testSession);
        final records = await CrdtDataRow.db.find(testSession);
        expect(rows.map((row) => row.name).toSet(), {'other', 'retry'});
        for (final row in rows) {
          final expectedSpace = row.name == 'retry' ? firstSpace : otherSpace;
          final record = records.singleWhere((record) => record.uuidRowId == row.id);
          expect(row.spaceId, expectedSpace.id);
          expect(record.spaceId, expectedSpace.id);
          expect(record.nodeId, expectedSpace.currentNodeId);
        }
      },
    );

    test(
      'when a nested exception is caught and the outer scope writes again, '
      'then the outer space and read identity are restored.',
      () async {
        final failure = StateError('nested failure');
        late List<Person> visible;
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(session, Person(name: 'before'), transaction: tx);
          await expectLater(
            session.db.runForUser(otherUser, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'discard'),
                transaction: tx,
              );
              throw failure;
            }, transaction: tx),
            throwsA(same(failure)),
          );
          await Person.db.insertRow(session, Person(name: 'after'), transaction: tx);
          visible = await Person.db.find(session, transaction: tx);
        });

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
        await session.db.transaction((tx) async {
          final first = session.db.runForUser(testCrdtUserId, (tx) async {
            entered.complete();
            await resume.future;
            await Person.db.insertRow(session, Person(name: 'first'), transaction: tx);
          }, transaction: tx);
          await entered.future;
          try {
            await expectLater(
              session.db.runForUser(otherUser, (tx) async {
                siblingRan = true;
                await Person.db.insertRow(
                  session,
                  Person(name: 'sibling'),
                  transaction: tx,
                );
              }, transaction: tx),
              throwsA(isA<StateError>()),
            );
          } finally {
            resume.complete();
            await first;
          }
          // The rejection must also leave the transaction available afterwards.
          await session.db.runForUser(otherUser, (tx) async {
            await Person.db.insertRow(session, Person(name: 'later'), transaction: tx);
          }, transaction: tx);
        });

        final rows = await Person.db.find(testSession);
        expect(siblingRan, isFalse);
        expect(rows.map((row) => (row.name, row.spaceId)).toSet(), {
          ('first', firstSpace.id),
          ('later', otherSpace.id),
        });
      },
    );

    test(
      'when successful and failed scopes return to an unbound transaction, '
      'then neither leaves a writable space or a read identity behind.',
      () async {
        final failure = StateError('failed scope');
        late List<Person> visible;
        await session.db.transaction((tx) async {
          await session.db.runForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(session, Person(name: 'first'), transaction: tx);
          }, transaction: tx);
          await expectLater(
            Person.db.insertRow(session, Person(name: 'unbound'), transaction: tx),
            throwsA(isA<StateError>()),
          );
          await expectLater(
            session.db.runForUser(
              otherUser,
              (tx) async => throw failure,
              transaction: tx,
            ),
            throwsA(same(failure)),
          );
          await expectLater(
            Person.db.insertRow(
              session,
              Person(name: 'still unbound'),
              transaction: tx,
            ),
            throwsA(isA<StateError>()),
          );
          await session.db.runForUser(otherUser, (tx) async {
            await Person.db.insertRow(session, Person(name: 'other'), transaction: tx);
          }, transaction: tx);
          visible = await Person.db.find(session, transaction: tx);
        });

        expect(visible.map((row) => row.name).toSet(), {'first', 'other'});
      },
    );

    test(
      'when both spaces write and the enclosing transaction rolls back, '
      'then domain and CRDT changes roll back while preparation survives.',
      () async {
        final beforeNode = (await CrdtNode.db.find(testSession)).single;
        final failure = StateError('whole transaction rollback');
        await expectLater(
          session.db.transaction((tx) async {
            await session.db.runForUser(testCrdtUserId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'first'),
                transaction: tx,
              );
            }, transaction: tx);
            await session.db.runForUser(otherUser, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'other'),
                transaction: tx,
              );
            }, transaction: tx);
            throw failure;
          }),
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
      'then later writes use the persistent personal space.',
      () async {
        final persistent = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: testSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await persistent.db.initialize();
        final failure = StateError('explicit scope failure');
        await persistent.db.transaction((tx) async {
          await expectLater(
            persistent.db.runForUser(otherUser, (tx) async {
              await Person.db.insertRow(
                persistent,
                Person(name: 'discard'),
                transaction: tx,
              );
              throw failure;
            }, transaction: tx),
            throwsA(same(failure)),
          );
          await Person.db.insertRow(
            persistent,
            Person(name: 'personal'),
            transaction: tx,
          );
        });

        final row = (await Person.db.find(testSession)).single;
        expect(row.name, 'personal');
        expect(row.spaceId, firstSpace.id);
        expect((await CrdtDataRow.db.find(testSession)).single.spaceId, firstSpace.id);
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
          otherUser,
          (tx) =>
              Person.db.insertRow(session, Person(name: 'original'), transaction: tx),
        );
      });

      group(
        'when a nested scope updates its row and the outer scope deletes its row,',
        () {
          late List<Person> remaining;
          late List<CrdtDataRow> records;
          late List<CrdtDataDeleted> deleted;

          setUp(() async {
            await session.db.transactionForUser(testCrdtUserId, (tx) async {
              await session.db.runForUser(
                otherUser,
                (tx) => Person.db.updateWhere(
                  session,
                  columnValues: (t) => [t.name('updated')],
                  where: (t) => t.name.equals('original'),
                  transaction: tx,
                ),
                transaction: tx,
              );
              await Person.db.deleteWhere(
                session,
                where: (t) => t.name.equals('original'),
                transaction: tx,
              );
            });
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
