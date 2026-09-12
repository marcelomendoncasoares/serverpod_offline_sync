import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  test(
    'Given people sharing an organization and an address attached to an unassigned person, '
    'when more people are inserted and the unassigned person joins the organization offline, '
    'then their references and authored facts survive synchronization without changing their siblings.',
    () async {
      final author = await syncNode(testSession, testSyncTables);
      final observer = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final organization = Organization(id: const Uuid().v7obj(), name: 'organization');
      final siblings = [
        for (var i = 0; i < 24; i++)
          Person(
            id: const Uuid().v7obj(),
            name: 'person-$i',
            organizationId: organization.id,
          ),
      ];
      final newcomer = Person(id: const Uuid().v7obj(), name: 'newcomer');
      final address = Address(
        id: const Uuid().v7obj(),
        street: 'street',
        inhabitantId: newcomer.id,
      );
      await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Organization.db.insertRow(author.crdt, organization, transaction: tx);
        await Person.db.insert(author.crdt, siblings, transaction: tx);
        await Person.db.insertRow(author.crdt, newcomer, transaction: tx);
        await Address.db.insertRow(author.crdt, address, transaction: tx);
      });
      final siblingHlcs = {
        for (final person in siblings)
          person.id!: await rowHlc(person.id!, databaseSession: author.crdt),
      };
      final added = [
        for (var i = 24; i < 48; i++)
          Person(
            id: const Uuid().v7obj(),
            name: 'person-$i',
            organizationId: organization.id,
          ),
      ];

      await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insert(author.crdt, added, transaction: tx, noReturn: true);
        await Person.db.updateRow(
          author.crdt,
          newcomer.copyWith(organizationId: organization.id),
          columns: (t) => [t.organizationId],
          transaction: tx,
        );
      });
      await syncWithServer(author, observer);

      for (final node in [author, observer]) {
        final people = await Person.db.find(node.crdt);
        expect(
          {for (final person in people) person.id},
          {
            for (final person in [...siblings, ...added, newcomer]) person.id,
          },
        );
        expect(
          people.map((person) => person.organizationId),
          everyElement(organization.id),
        );
        expect(
          (await Address.db.findById(node.crdt, address.id!))!.inhabitantId,
          newcomer.id,
        );
        expect(await CrdtDataAttemptedValue.db.count(node.crdt), 0);
        for (final person in siblings) {
          expect(
            await rowHlc(person.id!, databaseSession: node.crdt),
            siblingHlcs[person.id],
          );
        }
      }
    },
  );

  test(
    'Given a merged town waiting for a missing mayor, '
    'when that person is inserted locally, '
    'then the town recovers its authored reference without advancing its field clock.',
    () async {
      final mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
      final town = Town(id: const Uuid().v7obj(), name: 'town', mayorId: mayor.id);
      final hlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
      await session.db.mergeChanges([
        CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Town.t.tableName,
          uuidRowId: town.id!,
          uuidNodeId: hlc.nodeId,
          hlcDatetime: hlc.datetime,
          hlcCounter: hlc.counter,
          data: town,
        ),
      ], scopeId: testCrdtUserId);
      expect((await Town.db.findById(session, town.id!))!.mayorId, isNull);
      expect(
        (await attemptedValue(rowId: town.id!, columnName: 'mayorId'))!.value,
        mayor.id,
      );
      final before = await _fieldHlc(town.id!, 'mayorId');

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, mayor, transaction: tx),
      );

      expect((await Town.db.findById(session, town.id!))!.mayorId, mayor.id);
      expect(await attemptedValue(rowId: town.id!, columnName: 'mayorId'), isNull);
      expect(await _fieldHlc(town.id!, 'mayorId'), before);
    },
  );

  test(
    'Given two merged unique children waiting for unavailable parents and a missing fallback, '
    'when the fallback and another claimant are inserted locally, '
    'then one child owns the fallback and every child retains its authored parent.',
    () async {
      const fallbackId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
      final children = [
        for (var i = 0; i < 2; i++)
          UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'orphan-$i',
            parentId: const Uuid().v7obj(),
          ),
      ];
      final hlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
      await session.db.mergeChanges([
        for (final child in children)
          CrdtMergeInsert(
            uuidScopeId: testCrdtUserId,
            tableName: child.table.tableName,
            uuidRowId: child.id!,
            uuidNodeId: hlc.nodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            data: child,
          ),
      ], scopeId: testCrdtUserId);
      expect(
        (await UniqueSetDefaultChild.db.find(session)).map((row) => row.parentId),
        everyElement(isNull),
      );
      final claimant = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'claimant',
        parentId: fallbackId,
      );

      await session.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(
          session,
          Town(id: fallbackId, name: 'fallback'),
          transaction: tx,
        );
        await UniqueSetDefaultChild.db.insertRow(session, claimant, transaction: tx);
      });

      final rows = await UniqueSetDefaultChild.db.find(session);
      expect(rows, hasLength(3));
      expect(rows.where((row) => row.parentId == fallbackId), hasLength(1));
      expect(rows.where((row) => row.parentId == null), hasLength(2));
      final sync = CrdtSync(
        syncTables: testSyncTables,
        serializationManager: testSession.db.serializationManager,
      );
      final facts = await sync
          .collectPendingChanges(
            testSession,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      final authored = {
        for (final fact in facts.whereType<CrdtMergeInsert>())
          if (fact.data case final UniqueSetDefaultChild row) row.id: row.parentId,
      };
      expect(authored, {
        for (final row in [...children, claimant]) row.id: row.parentId,
      });
    },
  );
}

Future<Hlc> _fieldHlc(UuidValue rowId, String column) async {
  final field = await CrdtDataField.db.findFirstRow(
    session,
    where: (t) => t.row.uuidRowId.equals(rowId) & t.column.name.equals(column),
    include: CrdtDataField.include(node: CrdtNode.include()),
  );
  return field!.hlc;
}
