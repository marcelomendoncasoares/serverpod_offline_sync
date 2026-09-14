import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession();

  test(
    'Given a unique nullable set-default child referencing its default town, '
    'when the child is deleted and its released field is read back, '
    'then the hidden row retains null while the schema retains its non-null default.',
    () async {
      final ids = DstIds(DstRandom(118));
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final parent = Town(id: dstDefaultTownId, name: 'default');
      final child = UniqueSetDefaultChild(
        id: ids.next(),
        name: 'child',
        parentId: parent.id,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Town.db.insertRow(replica.session, parent, transaction: tx);
          await UniqueSetDefaultChild.db.insertRow(
            replica.session,
            child,
            transaction: tx,
          );
        }),
      );

      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await UniqueSetDefaultChild.db.deleteRow(
            replica.session,
            child,
            transaction: tx,
          );
        }),
      );
      final snapshot = await DstSnapshot.capture(replica);

      final hidden = snapshot.rows['unique_set_default_child']![child.id]!;
      expect(hidden.visible, isFalse);
      expect(hidden.columns['parentId'], isNull);
      expect(
        dstForeignKeys
            .singleWhere((edge) => edge.child == DstTable.uniqueSetDefaultChild)
            .defaultValue,
        parent.id,
      );
      expect(DstOracle.invariants(snapshot), isEmpty);
    },
  );

  test(
    'Given a visible person referencing a hidden company, '
    'when its snapshot is checked, '
    'then the oracle rejects the unrepaired reference.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'company': {parentId: (spaceUuid: space, columns: {}, visible: false)},
          'person': {
            childId: (
              spaceUuid: space,
              columns: {'oldCompanyId': parentId},
              visible: true,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.foreignKeyClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given a visible required set-null child referencing a hidden person, '
    'when its snapshot is checked, '
    'then the oracle rejects the unrepaired reference.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'person': {parentId: (spaceUuid: space, columns: {}, visible: false)},
          'required_set_null_child': {
            childId: (spaceUuid: space, columns: {'parentId': parentId}, visible: true),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.foreignKeyClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given a hidden nullable set-default child whose null repair was skipped, '
    'when its snapshot is checked, '
    'then the oracle rejects the unrepaired reference.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'person': {parentId: (spaceUuid: space, columns: {}, visible: false)},
          'nullable_set_default_child': {
            childId: (
              spaceUuid: space,
              columns: {'parentId': parentId},
              visible: false,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.projectionPurity(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given a visible no-action descendant of a hidden cascade middle, '
    'when its snapshot is checked, '
    'then the oracle rejects the unrepaired reference.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'fk_chain_cascade_middle': {
            parentId: (spaceUuid: space, columns: {}, visible: false),
          },
          'fk_chain_restrict_blocker': {
            childId: (
              spaceUuid: space,
              columns: {'cascadeMiddleId': parentId},
              visible: true,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.foreignKeyClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given a nullable set-default child repaired to its null default, '
    'when its snapshot is checked, '
    'then the oracle accepts its set-default projection.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'person': {parentId: (spaceUuid: space, columns: {}, visible: false)},
          'nullable_set_default_child': {
            childId: (spaceUuid: space, columns: {'parentId': null}, visible: true),
          },
        },
        projections: {
          ('nullable_set_default_child', childId, 'parentId'): (
            attemptedValue: parentId,
            projectionReason: CrdtProjectionReason.foreignKeySetDefault,
          ),
        },
        causalLengths: {},
      );

      final violations = DstOracle.projectionPurity(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given a hidden required set-null child and its hidden parent, '
    'when its snapshot is checked, '
    'then the oracle accepts the unchanged non-null reference.',
    () {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final parentId = ids.next();
      final childId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'person': {parentId: (spaceUuid: space, columns: {}, visible: false)},
          'required_set_null_child': {
            childId: (
              spaceUuid: space,
              columns: {'parentId': parentId},
              visible: false,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.projectionPurity(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given a replica holding a required set-null child, '
    'when its snapshot is captured, '
    'then the child and its reference are available to the oracle.',
    () async {
      final ids = DstIds(DstRandom(3));
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final parent = Person(id: ids.next(), name: 'parent');
      final child = RequiredSetNullChild(
        id: ids.next(),
        name: 'child',
        parentId: parent.id!,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Person.db.insertRow(replica.session, parent, transaction: tx);
          await RequiredSetNullChild.db.insertRow(
            replica.session,
            child,
            transaction: tx,
          );
        }),
      );

      final snapshot = await DstSnapshot.capture(replica);

      expect(
        snapshot.rows['required_set_null_child']?[child.id]?.columns['parentId'],
        parent.id.toString(),
      );
    },
  );
  test(
    'Given a person and visible city, organization, company, and town parents, '
    'when the DST repeatedly retargets the person and town, '
    'then every person reference and the company-town-person cycle can be authored.',
    () async {
      final random = DstRandom(300);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final city = City(id: ids.next(), name: 'city');
      final organization = Organization(
        id: ids.next(),
        name: 'organization',
        cityId: city.id,
      );
      final town = Town(id: ids.next(), name: 'town', cityId: city.id);
      final company = Company(id: ids.next(), name: 'company', townId: town.id);
      final person = Person(id: ids.next(), name: 'person');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(replica.session, city, transaction: tx);
          await Organization.db.insertRow(
            replica.session,
            organization,
            transaction: tx,
          );
          await Town.db.insertRow(replica.session, town, transaction: tx);
          await Company.db.insertRow(replica.session, company, transaction: tx);
          await Person.db.insertRow(replica.session, person, transaction: tx);
        }),
      );
      final operations = DstOperations(random, ids);
      final references = <String>{};
      var cycleAuthored = false;

      for (var index = 0; index < 60; index++) {
        await operations.apply(
          replica,
          space,
          table: DstTable.person,
          action: DstAction.update,
        );
        await operations.apply(
          replica,
          space,
          table: DstTable.town,
          action: DstAction.update,
        );
        final actualPerson = (await Person.db.findById(replica.session, person.id!))!;
        final actualTown = (await Town.db.findById(replica.session, town.id!))!;
        if (actualPerson.organizationId == organization.id) {
          references.add('organization');
        }
        if (actualPerson.oldCompanyId == company.id) references.add('company');
        if (actualPerson.cityId == city.id) references.add('city');
        if (actualPerson.oldCompanyId == company.id &&
            actualTown.mayorId == person.id) {
          cycleAuthored = true;
        }
      }

      expect(references, {'organization', 'company', 'city'});
      expect(cycleAuthored, isTrue);
    },
  );

  test(
    'Given visible person and town parents in one space, '
    'when the DST inserts children of every required and nullable FK shape, '
    'then each shape is authored and captured with valid references.',
    () async {
      final random = DstRandom(301);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Person.db.insertRow(
            replica.session,
            Person(id: ids.next(), name: 'parent'),
            transaction: tx,
          );
          await Town.db.insertRow(
            replica.session,
            Town(id: dstDefaultTownId, name: 'default'),
            transaction: tx,
          );
        }),
      );
      final operations = DstOperations(random, ids);

      final requiredNull = await operations.apply(
        replica,
        space,
        table: DstTable.requiredSetNullChild,
        action: DstAction.insert,
      );
      final requiredCascade = await operations.apply(
        replica,
        space,
        table: DstTable.requiredCascadeChild,
        action: DstAction.insert,
      );
      final requiredNoAction = await operations.apply(
        replica,
        space,
        table: DstTable.requiredNoActionChild,
        action: DstAction.insert,
      );
      final nullableDefault = await operations.apply(
        replica,
        space,
        table: DstTable.nullableSetDefaultChild,
        action: DstAction.insert,
      );
      final uniqueDefault = await operations.apply(
        replica,
        space,
        table: DstTable.uniqueSetDefaultChild,
        action: DstAction.insert,
      );
      final uniqueCascade = await operations.apply(
        replica,
        space,
        table: DstTable.uniqueCascadeReference,
        action: DstAction.insert,
      );
      final snapshot = await DstSnapshot.capture(replica);

      expect([
        requiredNull,
        requiredCascade,
        requiredNoAction,
        nullableDefault,
        uniqueDefault,
        uniqueCascade,
      ], everyElement(DstOperationOutcome.applied));
      expect(snapshot.rows['required_set_null_child'], hasLength(1));
      expect(snapshot.rows['required_cascade_child'], hasLength(1));
      expect(snapshot.rows['required_no_action_child'], hasLength(1));
      expect(snapshot.rows['nullable_set_default_child'], hasLength(1));
      expect(snapshot.rows['unique_set_default_child'], hasLength(1));
      expect(snapshot.rows['unique_cascade_reference'], hasLength(1));
      expect(DstOracle.invariants(snapshot), isEmpty);
    },
  );
}
