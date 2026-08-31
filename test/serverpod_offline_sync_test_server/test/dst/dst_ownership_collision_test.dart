@Tags(['dst'])
library;

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_world.dart';

/// Cross-scope UUID reuse is a terminal ownership collision, not a recoverable
/// conflict (`docs/row-ownership.md`). The merge must fail, record a durable
/// violation, and leave the existing owner's row untouched.
///
/// This sits with the simulation rather than the integration suite because it
/// is the failure mode the adversary must never be able to produce by accident:
/// the sweep asserts collisions do not happen, and this asserts what happens
/// when one is injected deliberately.
void main() {
  initTestClientSession();

  group('Given a row owned by one scope on a replica holding two scopes,', () {
    late DstReplica replica;
    late UuidValue ownerScopeUuid;
    late UuidValue intruderScopeUuid;
    late UuidValue rowId;

    setUp(() async {
      final ids = DstIds(DstRandom(1));
      final simulationClock = DstClock();

      ownerScopeUuid = ids.next();
      intruderScopeUuid = ids.next();
      rowId = ids.next();

      replica = await DstReplica.create(
        name: 'owner',
        scopeUuids: [ownerScopeUuid, intruderScopeUuid],
        nodeUuid: ids.next(),
        clock: simulationClock.clock,
      );

      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(ownerScopeUuid, (tx) async {
          await Person.db.insertRow(
            replica.session,
            Person(id: rowId, name: 'original owner'),
            transaction: tx,
          );
        }),
      );
    });

    group('when another scope merges an insert claiming the same row id,', () {
      late Object? mergeError;

      setUp(() async {
        final intrusion = CrdtMergeInsert(
          uuidScopeId: intruderScopeUuid,
          tableName: Person.t.tableName,
          uuidRowId: rowId,
          uuidNodeId: DstIds(DstRandom(2)).next(),
          hlcDatetime: DateTime.utc(2026, 1, 2),
          hlcCounter: 0,
          data: Person(id: rowId, name: 'intruder'),
        );

        try {
          await replica.merge([intrusion], intruderScopeUuid);
          mergeError = null;
        } on Exception catch (error) {
          mergeError = error;
        }
      });

      test('then the merge fails with a CrdtSyncIntegrityViolationException.', () {
        expect(mergeError, isA<CrdtSyncIntegrityViolationException>());
      });

      test('then a durable ownership-collision violation is recorded.', () async {
        final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
          replica.session,
          where: (t) => t.uuidRowId.equals(rowId),
        );

        expect(violation, isNotNull);
        expect(violation!.type, CrdtSyncViolationType.ownershipCollision);
        expect(violation.ownerScopeUuid, ownerScopeUuid);
        expect(violation.incomingScopeUuid, intruderScopeUuid);
      });

      test("then the owner's row is unchanged.", () async {
        final owned = await Person.db.findById(replica.session, rowId);

        expect(owned, isNotNull);
        expect(owned!.name, 'original owner');
      });
    });
  });
}
