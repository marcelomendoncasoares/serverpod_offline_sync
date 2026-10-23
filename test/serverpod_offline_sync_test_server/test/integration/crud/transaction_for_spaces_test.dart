import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a user with a shared space and no prepared personal space,', () {
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
    });

    group('when one transaction writes to both declared spaces,', () {
      late Person personal;
      late Person other;
      late String result;
      late List<OfflineSyncSpace> prepared;
      late List<Person> rows;
      late List<CrdtDataRow> records;
      late CrdtNode node;
      late List<OfflineSyncSpaceNode> participation;

      setUp(() async {
        result = await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) async {
            // Reading through the raw session proves preparation has committed
            // before the domain transaction starts writing.
            prepared = await OfflineSyncSpace.db.find(testSession);

            personal = await spaces.runForSpace(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'personal'),
                transaction: tx,
              ),
            );

            other = await spaces.runForSpace(
              shared.uuidSpaceId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'shared'),
                transaction: tx,
              ),
            );

            return 'committed';
          },
        );

        rows = await Person.db.find(testSession);
        records = await CrdtDataRow.db.find(testSession);
        node = (await CrdtNode.db.find(testSession)).single;
        participation = await OfflineSyncSpaceNode.db.find(testSession);
      });

      test('then preparation is automatic and both callback results are returned.', () {
        expect(prepared.map((s) => s.uuidSpaceId).toSet(), {
          testCrdtUserId,
          shared.uuidSpaceId,
        });
        expect(node.localUserUuid, testCrdtUserId);
        expect(
          participation.map((p) => p.spaceId).toSet(),
          prepared.map((s) => s.id).toSet(),
        );
        expect(participation.map((p) => p.nodeId).toSet(), {node.id});

        expect(result, 'committed');
        expect(rows.map((row) => row.id).toSet(), {personal.id, other.id});
      });

      test('then domain rows and CRDT records belong to their acting spaces.', () {
        final personalSpace = prepared.singleWhere(
          (s) => s.uuidSpaceId == testCrdtUserId,
        );

        expect(rows.singleWhere((r) => r.id == personal.id).spaceId, personalSpace.id);
        expect(rows.singleWhere((r) => r.id == other.id).spaceId, shared.id);

        for (final row in rows) {
          final space = prepared.singleWhere((s) => s.id == row.spaceId);
          final record = records.singleWhere((r) => r.uuidRowId == row.id);

          expect(record.spaceId, space.id);
          expect(record.nodeId, node.id);
        }
      });
    });

    group('when its first nested shared write rolls back before a personal write,', () {
      late Hlc committedClock;
      late CrdtNode node;
      late OfflineSyncSpace sharedAfter;
      late OfflineSyncSpace personalAfter;
      late List<Person> rows;

      setUp(() async {
        final failure = Exception('discard shared write');
        await withClock(Clock.fixed(DateTime.utc(2030)), () {
          return session.db.transactionForSpaces(
            testCrdtUserId,
            {testCrdtUserId, shared.uuidSpaceId},
            (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
              try {
                await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                  await Person.db.insertRow(
                    session,
                    Person(name: 'discard'),
                    transaction: tx,
                  );
                  throw failure;
                });
              } on Exception catch (error) {
                if (!identical(error, failure)) rethrow;
              }

              await Person.db.insertRow(
                session,
                Person(name: 'committed'),
                transaction: tx,
              );
            }),
          );
        });

        rows = await Person.db.find(testSession);
        committedClock = (await CrdtDataRow.db.find(
          testSession,
          include: CrdtDataRow.include(node: CrdtNode.include()),
        )).single.hlc;
        node = (await CrdtNode.db.find(testSession)).single;
        sharedAfter = (await OfflineSyncSpace.db.findById(testSession, shared.id!))!;
        personalAfter = (await OfflineSyncSpace.db.findFirstRow(
          testSession,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
        ))!;
      });

      test('then only the successful write advances its user and space clocks.', () {
        expect(rows.map((row) => row.name), ['committed']);
        expect(node.lastHlc, committedClock);
        expect(personalAfter.lastHlc, committedClock);
        expect(sharedAfter.lastHlc, isNull);
        expect(committedClock.counter, 0);
      });
    });

    group('when a nested shared scope succeeds between personal writes,', () {
      late List<Person> rows;
      late OfflineSyncSpace personalSpace;

      setUp(() async {
        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
            await Person.db.insertRow(session, Person(name: 'before'), transaction: tx);

            await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'shared'),
                transaction: tx,
              );
            });

            await Person.db.insertRow(session, Person(name: 'after'), transaction: tx);
          }),
        );

        rows = await Person.db.find(testSession);
        personalSpace = (await OfflineSyncSpace.db.findFirstRow(
          testSession,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
        ))!;
      });

      test('then the outer space binding is restored.', () {
        expect(rows.map((r) => (r.name, r.spaceId)).toSet(), {
          ('before', personalSpace.id),
          ('shared', shared.id),
          ('after', personalSpace.id),
        });
      });
    });

    test(
      'when an undeclared space is requested, '
      'then it is rejected before its callback runs.',
      () async {
        var callbackRan = false;

        await session.db.transactionForSpaces(testCrdtUserId, {testCrdtUserId}, (
          spaces,
        ) async {
          await expectLater(
            spaces.runForSpace(shared.uuidSpaceId, (_) async {
              callbackRan = true;
            }),
            throwsArgumentError,
          );
        });

        expect(callbackRan, isFalse);
        expect(await Person.db.count(testSession), 0);
      },
    );

    test(
      'when the caller mutates its declared set after starting the operation, '
      'then the transaction keeps the original set of spaces.',
      () async {
        final declared = {testCrdtUserId};
        var callbackRan = false;

        final operation = session.db.transactionForSpaces(testCrdtUserId, declared, (
          spaces,
        ) async {
          await spaces.runForSpace(testCrdtUserId, (_) async {});

          await expectLater(
            spaces.runForSpace(shared.uuidSpaceId, (_) async {
              callbackRan = true;
            }),
            throwsArgumentError,
          );
        });

        declared
          ..clear()
          ..add(shared.uuidSpaceId);
        await operation;

        expect(callbackRan, isFalse);
      },
    );
  });

  group('Given a shared space without membership,', () {
    late OfflineSyncSpace shared;

    setUp(() async {
      shared = await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
    });

    test(
      'when a transaction declares that space, '
      'then authorization fails before the transaction callback.',
      () async {
        var callbackRan = false;

        await expectLater(
          session.db.transactionForSpaces(testCrdtUserId, {shared.uuidSpaceId}, (
            _,
          ) async {
            callbackRan = true;
          }),
          throwsA(isA<OfflineSyncSpaceMembershipException>()),
        );

        expect(callbackRan, isFalse);
        expect(await CrdtNode.db.count(testSession), 0);
      },
    );
  });

  group('Given a shared space with read-only membership,', () {
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
          role: OfflineSyncSpaceRole.readOnly,
        ),
      );
    });

    test(
      'when a transaction declares that space, '
      'then write authorization fails before the transaction callback.',
      () async {
        var callbackRan = false;

        await expectLater(
          session.db.transactionForSpaces(testCrdtUserId, {shared.uuidSpaceId}, (
            _,
          ) async {
            callbackRan = true;
          }),
          throwsA(isA<OfflineSyncSpaceRoleException>()),
        );

        expect(callbackRan, isFalse);
        expect(await CrdtNode.db.count(testSession), 0);
      },
    );
  });
}
