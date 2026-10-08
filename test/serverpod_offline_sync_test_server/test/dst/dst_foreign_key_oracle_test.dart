import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a unique nullable set-default child referencing its default town,', () {
    late DstReplica replica;
    late UuidValue space;
    late Town parent;
    late UniqueSetDefaultChild child;

    setUpAll(() async {
      final ids = DstIds(DstRandom(118));
      space = ids.next();
      replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      parent = Town(id: dstDefaultTownId, name: 'default');
      child = UniqueSetDefaultChild(
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
    });

    group('when the child is deleted and its released field is read back,', () {
      late DstSnapshot snapshot;

      setUpAll(() async {
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(space, (tx) async {
            await UniqueSetDefaultChild.db.deleteRow(
              replica.session,
              child,
              transaction: tx,
            );
          }),
        );
        snapshot = await DstSnapshot.capture(replica);
      });

      test('then the hidden row retains a null reference.', () {
        final hidden = snapshot.rows['unique_set_default_child']![child.id]!;
        expect(hidden.visible, isFalse);
        expect(hidden.columns['parentId'], isNull);
      });

      test('then the schema retains its non-null default.', () {
        expect(
          dstForeignKeys
              .singleWhere((edge) => edge.child == DstTable.uniqueSetDefaultChild)
              .defaultValue,
          parent.id,
        );
      });

      test('then the snapshot satisfies the oracle invariants.', () {
        expect(DstOracle.invariants(snapshot), isEmpty);
      });
    });
  });

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

  group(
    'Given a person and visible city, organization, company, and town parents,',
    () {
      late DstReplica replica;
      late UuidValue space;
      late City city;
      late Organization organization;
      late Town town;
      late Company company;
      late Person person;
      late DstOperations operations;

      setUpAll(() async {
        final random = DstRandom(300);
        final ids = DstIds(random);
        space = ids.next();
        replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        city = City(id: ids.next(), name: 'city');
        organization = Organization(
          id: ids.next(),
          name: 'organization',
          cityId: city.id,
        );
        town = Town(id: ids.next(), name: 'town', cityId: city.id);
        company = Company(id: ids.next(), name: 'company', townId: town.id);
        person = Person(id: ids.next(), name: 'person');
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
        operations = DstOperations(random, ids);
      });

      group('when the DST repeatedly retargets the person and town,', () {
        late Set<String> references;
        late bool cycleAuthored;

        setUpAll(() async {
          references = <String>{};
          cycleAuthored = false;

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
            final actualPerson = (await Person.db.findById(
              replica.session,
              person.id!,
            ))!;
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
        });

        test('then every person reference can be authored.', () {
          expect(references, {'organization', 'company', 'city'});
        });

        test('then the company-town-person cycle can be authored.', () {
          expect(cycleAuthored, isTrue);
        });
      });
    },
  );

  group(
    'Given visible person and town parents for required cascade, required no-action, unique set-default, and unique cascade children,',
    () {
      late DstReplica replica;
      late UuidValue space;
      late DstOperations operations;

      setUpAll(() async {
        final random = DstRandom(301);
        final ids = DstIds(random);
        space = ids.next();
        replica = await DstReplica.create(
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
        operations = DstOperations(random, ids);
      });

      group('when the DST inserts the children,', () {
        late DstOperationOutcome requiredCascade;
        late DstOperationOutcome requiredNoAction;
        late DstOperationOutcome uniqueDefault;
        late DstOperationOutcome uniqueCascade;
        late DstSnapshot snapshot;

        setUpAll(() async {
          requiredCascade = await operations.apply(
            replica,
            space,
            table: DstTable.requiredCascadeChild,
            action: DstAction.insert,
          );
          requiredNoAction = await operations.apply(
            replica,
            space,
            table: DstTable.requiredNoActionChild,
            action: DstAction.insert,
          );
          uniqueDefault = await operations.apply(
            replica,
            space,
            table: DstTable.uniqueSetDefaultChild,
            action: DstAction.insert,
          );
          uniqueCascade = await operations.apply(
            replica,
            space,
            table: DstTable.uniqueCascadeReference,
            action: DstAction.insert,
          );
          snapshot = await DstSnapshot.capture(replica);
        });

        test('then the required cascade child is authored and captured.', () {
          expect(requiredCascade, DstOperationOutcome.applied);
          expect(snapshot.rows['required_cascade_child'], hasLength(1));
        });

        test('then the required no-action child is authored and captured.', () {
          expect(requiredNoAction, DstOperationOutcome.applied);
          expect(snapshot.rows['required_no_action_child'], hasLength(1));
        });

        test('then the unique set-default child is authored and captured.', () {
          expect(uniqueDefault, DstOperationOutcome.applied);
          expect(snapshot.rows['unique_set_default_child'], hasLength(1));
        });

        test('then the unique cascade child is authored and captured.', () {
          expect(uniqueCascade, DstOperationOutcome.applied);
          expect(snapshot.rows['unique_cascade_reference'], hasLength(1));
        });

        test('then every child reference satisfies the oracle invariants.', () {
          expect(DstOracle.invariants(snapshot), isEmpty);
        });
      });
    },
  );
}
