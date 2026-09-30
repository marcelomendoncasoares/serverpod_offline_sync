import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a town and organization sharing a UUID with their missing parents,',
    () {
      late SyncNode author;
      late SyncNode observer;
      late UuidValue sharedId;
      late Town town;
      late Organization organization;
      late Hlc authored;
      late Map<(String, String), Hlc> originalClocks;

      setUpAll(() async {
        author = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        observer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        sharedId = const Uuid().v7obj();
        town = Town(
          id: sharedId,
          name: 'town',
          cityId: sharedId,
          mayorId: sharedId,
        );
        organization = Organization(
          id: sharedId,
          name: 'organization',
          cityId: sharedId,
        );
        authored = Hlc(DateTime.utc(2026, 9, 1), 0, const Uuid().v7obj());
        await author.offlineSync.db.mergeChanges([
          CrdtMergeInsert(
            uuidSpaceId: testCrdtUserId,
            tableName: Town.t.tableName,
            uuidRowId: sharedId,
            uuidNodeId: authored.nodeId,
            hlcDatetime: authored.datetime,
            hlcCounter: authored.counter,
            data: town,
          ),
          CrdtMergeInsert(
            uuidSpaceId: testCrdtUserId,
            tableName: Organization.t.tableName,
            uuidRowId: sharedId,
            uuidNodeId: authored.nodeId,
            hlcDatetime: authored.datetime,
            hlcCounter: authored.counter + 1,
            data: organization,
          ),
        ], spaceId: testCrdtUserId);
        originalClocks = await _dependentClocks(author, sharedId);
      });

      group('when the city and mayor arrive together and synchronize,', () {
        late Town? authorTown;
        late Town? observerTown;
        late Organization? authorOrganization;
        late Organization? observerOrganization;
        late Person? authorMayor;
        late Person? observerMayor;
        late Map<(String, String), Hlc> authorClocks;
        late Map<(String, String), Hlc> observerClocks;
        late int authorAttempts;
        late int observerAttempts;

        setUpAll(() async {
          final city = City(id: sharedId, name: 'city');
          final mayor = Person(
            id: sharedId,
            name: 'mayor',
            cityId: sharedId,
            organizationId: sharedId,
          );
          await author.offlineSync.db.mergeChanges([
            CrdtMergeInsert(
              uuidSpaceId: testCrdtUserId,
              tableName: City.t.tableName,
              uuidRowId: sharedId,
              uuidNodeId: authored.nodeId,
              hlcDatetime: authored.datetime,
              hlcCounter: authored.counter + 2,
              data: city,
            ),
            CrdtMergeInsert(
              uuidSpaceId: testCrdtUserId,
              tableName: Person.t.tableName,
              uuidRowId: sharedId,
              uuidNodeId: authored.nodeId,
              hlcDatetime: authored.datetime,
              hlcCounter: authored.counter + 3,
              data: mayor,
            ),
          ], spaceId: testCrdtUserId);
          await syncWithServer(author, observer);

          authorTown = await Town.db.findById(author.offlineSync, sharedId);
          observerTown = await Town.db.findById(observer.offlineSync, sharedId);
          authorOrganization = await Organization.db.findById(
            author.offlineSync,
            sharedId,
          );
          observerOrganization = await Organization.db.findById(
            observer.offlineSync,
            sharedId,
          );
          authorMayor = await Person.db.findById(author.offlineSync, sharedId);
          observerMayor = await Person.db.findById(
            observer.offlineSync,
            sharedId,
          );
          authorClocks = await _dependentClocks(author, sharedId);
          observerClocks = await _dependentClocks(observer, sharedId);
          authorAttempts = await CrdtDataAttemptedValue.db.count(
            author.offlineSync,
          );
          observerAttempts = await CrdtDataAttemptedValue.db.count(
            observer.offlineSync,
          );
        });

        test(
          'then both replicas restore each reference to its own parent table.',
          () {
            for (final value in [authorTown, observerTown]) {
              expect(value, isNotNull);
              expect(
                (value!.name, value.cityId, value.mayorId),
                ('town', sharedId, sharedId),
              );
            }
            for (final value in [authorOrganization, observerOrganization]) {
              expect(value, isNotNull);
              expect((value!.name, value.cityId), ('organization', sharedId));
            }
            for (final value in [authorMayor, observerMayor]) {
              expect(value, isNotNull);
              expect(
                (value!.name, value.cityId, value.organizationId),
                ('mayor', sharedId, sharedId),
              );
            }
          },
        );

        test(
          'then restoring each dependency preserves its authored field clocks.',
          () {
            expect(originalClocks.keys.toSet(), {
              ('town', 'cityId'),
              ('town', 'mayorId'),
              ('organization', 'cityId'),
            });
            expect(authorClocks, originalClocks);
            expect(observerClocks, originalClocks);
          },
        );

        test(
          'then neither replica retains a repaired-away parent reference.',
          () {
            expect(authorAttempts, 0);
            expect(observerAttempts, 0);
          },
        );
      });
    },
  );
}

Future<Map<(String, String), Hlc>> _dependentClocks(
  SyncNode node,
  UuidValue id,
) async {
  final fields = await CrdtDataField.db.find(
    node.offlineSync,
    where: (t) =>
        t.row.uuidRowId.equals(id) &
        t.row.tbl.name.inSet({'town', 'organization'}) &
        t.column.name.inSet({'cityId', 'mayorId'}),
    include: CrdtDataField.include(
      row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
      column: CrdtSchemaColumn.include(),
      node: CrdtNode.include(),
    ),
  );
  return {
    for (final field in fields) (field.row!.tbl!.name, field.column!.name): field.hlc,
  };
}
