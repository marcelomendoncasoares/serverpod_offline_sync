import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a parent row with a visible restrict child and a concurrent child update, ',
    () {
      late Person parent;
      late Address child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'restricted parent'),
            transaction: tx,
          );
          child = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'original street',
              inhabitantId: parent.id,
            ),
            transaction: tx,
          );
          child = await Address.db.updateRow(
            session,
            child.copyWith(street: 'updated street'),
            columns: (t) => [t.street],
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(parent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: parent.id!,
          after: parentHlc,
        );
      });

      group('when the remote parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the parent remains visible and no visible restrict child references a hidden parent.',
          () async {
            final visibleParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await Address.db.findById(session, child.id!);

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.inhabitantId, parent.id);
            expect(visibleChild.street, 'updated street');
          },
        );
      });
    },
  );

  group(
    'Given a blocked restrict parent delete was restored by projection, ',
    () {
      late Person parent;
      late Address child;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'blocked parent'),
            transaction: tx,
          );
          child = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'blocking child',
              inhabitantId: parent.id,
            ),
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(parent.id!);
        await session.db.mergeChanges(
          [
            _deleteChange(
              tableName: Person.t.tableName,
              rowId: parent.id!,
              after: parentHlc,
            ),
          ],
          userId: testCrdtUserId,
        );
      });

      group('when the restrict child is detached, ', () {
        setUp(() async {
          final visibleChild = await Address.db.findById(session, child.id!);
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Address.db.updateRow(
              session,
              visibleChild!.copyWith(inhabitantId: null),
              columns: (t) => [t.inhabitantId],
              transaction: tx,
            );
          });
        });

        test(
          'then the parent is hidden by the preserved base delete fact.',
          () async {
            final hiddenParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await Address.db.findById(session, child.id!);

            expect(hiddenParent, isNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.inhabitantId, isNull);
          },
        );
      });
    },
  );

  group(
    'Given a company with a visible no-action child and a concurrent child update, ',
    () {
      late Town town;
      late Company company;
      late Person child;
      late CrdtMergeDelete remoteCompanyDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          town = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'company town'),
            transaction: tx,
          );
          company = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'no action company',
              townId: town.id,
            ),
            transaction: tx,
          );
          child = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'no action child',
              oldCompanyId: company.id,
            ),
            transaction: tx,
          );
          child = await Person.db.updateRow(
            session,
            child.copyWith(surname: 'updated child'),
            columns: (t) => [t.surname],
            transaction: tx,
          );
        });

        final companyHlc = await _rowHlc(company.id!);
        remoteCompanyDelete = _deleteChange(
          tableName: Company.t.tableName,
          rowId: company.id!,
          after: companyHlc,
        );
      });

      group('when the remote company delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCompanyDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the company remains visible and no visible no-action child references a hidden company.',
          () async {
            final visibleCompany = await Company.db.findById(
              session,
              company.id!,
            );
            final visibleChild = await Person.db.findById(session, child.id!);

            expect(visibleCompany, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.oldCompanyId, company.id);
            expect(visibleChild.surname, 'updated child');
          },
        );
      });
    },
  );

  group(
    'Given a nullable foreign key with set-null and a stored attempted parent value, ',
    () {
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'attempted mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
          child = await Town.db.updateRow(
            session,
            child.copyWith(mayorId: attemptedParent.id),
            columns: (t) => [t.mayorId],
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child remains visible with a materialized null foreign key.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
          },
        );

        test(
          'then the attempted foreign key value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-null projection has materialized a null foreign key, ',
    () {
      late Person attemptedParent;
      late Person newParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'deleted mayor'),
            transaction: tx,
          );
          newParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'new mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
          child = await Town.db.updateRow(
            session,
            child.copyWith(mayorId: attemptedParent.id),
            columns: (t) => [t.mayorId],
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );

        await session.db.mergeChanges(
          [remoteParentDelete],
          userId: testCrdtUserId,
        );
      });

      group('when the user changes the foreign key to a visible parent, ', () {
        setUp(() async {
          final visibleChild = await Town.db.findById(session, child.id!);
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Town.db.updateRow(
              session,
              visibleChild!.copyWith(mayorId: newParent.id),
              columns: (t) => [t.mayorId],
              transaction: tx,
            );
          });
        });

        test(
          'then the projection override becomes inactive and the new user value is visible.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, newParent.id);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, newParent.id!.uuid);
            expect(projection.visibleValue, newParent.id!.uuid);
            expect(projection.hasOverride, isFalse);
          },
        );
      });
    },
  );

  group(
    'Given a nullable foreign key with set-null whose attempted value only exists on insert, ',
    () {
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'insert attempted mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'insert set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the inserted attempted value is preserved in projection metadata.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key with a visible default target and a stored attempted parent value, ',
    () {
      late Town defaultTown;
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        defaultTown = Town(
          id: _defaultTownId,
          name: 'default town',
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          defaultTown = await Town.db.insertRow(
            session,
            defaultTown,
            transaction: tx,
          );
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'set default company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child remains visible with the default foreign key materialized.',
          () async {
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, defaultTown.id);
          },
        );

        test(
          'then the attempted set-default foreign key value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Company.t.townId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedTown.id!.uuid);
            expect(projection.visibleValue, defaultTown.id!.uuid);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key whose default target is missing, ',
    () {
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'set default company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the attempted parent remains visible because the default cannot repair the child.',
          () async {
            final visibleParent = await Town.db.findById(
              session,
              attemptedTown.id!,
            );
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, attemptedTown.id);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key whose default target is cascade-hidden by another root delete, ',
    () {
      late City city;
      late Town defaultTown;
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteCityDelete;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        defaultTown = Town(
          id: _defaultTownId,
          name: 'cascade-hidden default town',
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'default target city'),
            transaction: tx,
          );
          defaultTown = await Town.db.insertRow(
            session,
            defaultTown.copyWith(cityId: city.id),
            transaction: tx,
          );
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'fixed point company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
        );
        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc.maxBetween(remoteCityDelete.hlc),
        );
      });

      group('when both root deletes are merged in the same batch, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete, remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the attempted parent remains visible because the full hidden fixed point hides the default target.',
          () async {
            final hiddenCity = await City.db.findById(session, city.id!);
            final hiddenDefaultTown = await Town.db.findById(
              session,
              defaultTown.id!,
            );
            final visibleAttemptedTown = await Town.db.findById(
              session,
              attemptedTown.id!,
            );
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(hiddenCity, isNull);
            expect(hiddenDefaultTown, isNull);
            expect(visibleAttemptedTown, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, attemptedTown.id);
          },
        );
      });
    },
  );

  group(
    'Given a valid cascade closure from city to organization to person, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late CrdtMergeDelete remoteCityDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'cascade city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'cascade organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'cascade person',
              organizationId: organization.id,
            ),
            transaction: tx,
          );
        });

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
        );
      });

      group('when the root delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then all cascade descendants are hidden and no visible descendant references a hidden ancestor.',
          () async {
            expect(await City.db.findById(session, city.id!), isNull);
            expect(
              await Organization.db.findById(session, organization.id!),
              isNull,
            );
            expect(await Person.db.findById(session, person.id!), isNull);
          },
        );

        test(
          'then replaying the same delete facts does not change cascade metadata.',
          () async {
            final tombstonesBeforeReplay = await _tombstoneSnapshot();
            expect(tombstonesBeforeReplay, hasLength(3));

            await session.db.mergeChanges(
              [remoteCityDelete],
              userId: testCrdtUserId,
            );

            final tombstonesAfterReplay = await _tombstoneSnapshot();
            expect(tombstonesAfterReplay, tombstonesBeforeReplay);
          },
        );
      });
    },
  );

  group(
    'Given a cascade projection hid descendants after a remote root delete, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late CrdtMergeDelete remoteCityDelete;
      late CrdtMergeDelete remoteCityRestore;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'restored cascade city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'restored cascade organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'restored cascade person',
              organizationId: organization.id,
            ),
            transaction: tx,
          );
        });

        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: await _rowHlc(city.id!),
        );
        remoteCityRestore = _restoreChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: remoteCityDelete.hlc,
        );

        await session.db.mergeChanges(
          [remoteCityDelete],
          userId: testCrdtUserId,
        );
      });

      group('when the root restore is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityRestore],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the cascade-derived descendant tombstones are restored.',
          () async {
            final visibleCity = await City.db.findById(session, city.id!);
            final visibleOrganization = await Organization.db.findById(
              session,
              organization.id!,
            );
            final visiblePerson = await Person.db.findById(session, person.id!);

            expect(visibleCity, isNotNull);
            expect(visibleOrganization, isNotNull);
            expect(visibleOrganization!.cityId, city.id);
            expect(visiblePerson, isNotNull);
            expect(visiblePerson!.organizationId, organization.id);
          },
        );
      });
    },
  );

  group(
    'Given a cascade chain that has a restrict descendant, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late Address restrictChild;
      late CrdtMergeDelete remoteCityDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'blocked city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'blocked organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'blocked person',
              organizationId: organization.id,
            ),
            transaction: tx,
          );
          restrictChild = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'restrict street',
              inhabitantId: person.id,
            ),
            transaction: tx,
          );
          restrictChild = await Address.db.updateRow(
            session,
            restrictChild.copyWith(street: 'updated restrict street'),
            columns: (t) => [t.street],
            transaction: tx,
          );
        });

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
        );
      });

      group('when the root delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the cascade is blocked and every row in the mixed chain remains visible.',
          () async {
            final visibleCity = await City.db.findById(session, city.id!);
            final visibleOrganization = await Organization.db.findById(
              session,
              organization.id!,
            );
            final visiblePerson = await Person.db.findById(session, person.id!);
            final visibleRestrictChild = await Address.db.findById(
              session,
              restrictChild.id!,
            );

            expect(visibleCity, isNotNull);
            expect(visibleOrganization, isNotNull);
            expect(visibleOrganization!.cityId, city.id);
            expect(visiblePerson, isNotNull);
            expect(visiblePerson!.organizationId, organization.id);
            expect(visibleRestrictChild, isNotNull);
            expect(visibleRestrictChild!.inhabitantId, person.id);
          },
        );
      });
    },
  );

  group(
    'Given two databases with the same set-null graph and the same remote operations, ',
    () {
      late CrdtDatabaseSession singleBatchSession;
      late CrdtDatabaseSession splitBatchSession;
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;
      late CrdtMergeUpdate remoteChildUpdate;

      setUp(() async {
        singleBatchSession = session;
        splitBatchSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: [
            Person.t,
            Town.t,
          ],
        );
        await splitBatchSession.db.initialize();

        attemptedParent = Person(
          id: const Uuid().v7obj(),
          name: 'batching parent',
        );
        child = Town(
          id: const Uuid().v7obj(),
          name: 'batching town',
          mayorId: attemptedParent.id,
        );

        for (final databaseSession in [singleBatchSession, splitBatchSession]) {
          await databaseSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(
              databaseSession,
              attemptedParent,
              transaction: tx,
            );
            await Town.db.insertRow(
              databaseSession,
              child,
              transaction: tx,
            );
            await Town.db.updateRow(
              databaseSession,
              child,
              columns: (t) => [t.mayorId],
              transaction: tx,
            );
          });
        }

        final singleBatchParentHlc = await _rowHlc(
          attemptedParent.id!,
          databaseSession: singleBatchSession,
        );
        final splitBatchParentHlc = await _rowHlc(
          attemptedParent.id!,
          databaseSession: splitBatchSession,
        );
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: singleBatchParentHlc.maxBetween(splitBatchParentHlc),
        );
        final singleBatchChildHlc = await _rowHlc(
          child.id!,
          databaseSession: singleBatchSession,
        );
        final splitBatchChildHlc = await _rowHlc(
          child.id!,
          databaseSession: splitBatchSession,
        );
        final childUpdateBaseHlc = remoteParentDelete.hlc
            .maxBetween(singleBatchChildHlc)
            .maxBetween(splitBatchChildHlc);
        remoteChildUpdate = CrdtMergeUpdate(
          tableName: Town.t.tableName,
          uuidRowId: child.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: childUpdateBaseHlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Town.t.name.columnName,
          value: 'updated batching town',
        );
      });

      group(
        'when one database merges one batch and the other merges split batches, ',
        () {
          setUp(() async {
            await singleBatchSession.db.mergeChanges(
              [remoteParentDelete, remoteChildUpdate],
              userId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [remoteParentDelete],
              userId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [remoteChildUpdate],
              userId: testCrdtUserId,
            );
          });

          test(
            'then both databases converge to the same repaired visible rows and foreign key projection.',
            () async {
              final singleBatchSnapshot = await _setNullBatchingSnapshot(
                singleBatchSession,
                child.id!,
              );
              final splitBatchSnapshot = await _setNullBatchingSnapshot(
                splitBatchSession,
                child.id!,
              );

              expect(singleBatchSnapshot, splitBatchSnapshot);
              expect(singleBatchSnapshot.childName, 'updated batching town');
              expect(singleBatchSnapshot.visibleMayorId, isNull);
              expect(singleBatchSnapshot.attemptedMayorId, attemptedParent.id!.uuid);
              expect(singleBatchSnapshot.hasOverride, isTrue);
            },
          );
        },
      );
    },
  );
}

final _defaultTownId = UuidValue.withValidation(
  '550e8400-e29b-41d4-a716-446655440000',
);

CrdtMergeDelete _deleteChange({
  required String tableName,
  required UuidValue rowId,
  required Hlc after,
}) {
  return CrdtMergeDelete(
    tableName: tableName,
    uuidRowId: rowId,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: after.datetime.advance(),
    hlcCounter: 0,
    clFlag: 2,
    reason: CrdtDataDeletedReason.userDelete,
  );
}

CrdtMergeDelete _restoreChange({
  required String tableName,
  required UuidValue rowId,
  required Hlc after,
}) {
  return CrdtMergeDelete(
    tableName: tableName,
    uuidRowId: rowId,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: after.datetime.advance(),
    hlcCounter: 0,
    clFlag: 3,
    reason: CrdtDataDeletedReason.userReinsert,
  );
}

Future<Hlc> _rowHlc(
  UuidValue rowId, {
  CrdtDatabaseSession? databaseSession,
}) async {
  final crdtRow = await CrdtDataRow.db.findFirstRow(
    databaseSession ?? session,
    where: (t) => t.uuidRowId.equals(rowId),
    include: CrdtDataRow.include(node: CrdtNode.include()),
  );

  return crdtRow!.hlc;
}

Future<_ForeignKeyProjection?> _findForeignKeyProjection({
  required UuidValue rowId,
  required String columnName,
  CrdtDatabaseSession? databaseSession,
}) async {
  final result = await (databaseSession ?? session).db.unsafeQuery(
    '''
SELECT fk."attemptedValue", fk."visibleValue", fk."hasOverride"
FROM "crdt_data_foreign_key" fk
JOIN "crdt_data_fields" f ON f."id" = fk."fieldId"
JOIN "crdt_data_rows" r ON r."id" = f."rowId"
JOIN "crdt_schema_columns" c ON c."id" = f."columnId"
WHERE lower(hex(r."uuidRowId")) = '${rowId.uuid.replaceAll('-', '')}'
  AND c."name" = '$columnName'
''',
  );

  if (result.isEmpty) return null;
  final row = result.single;
  return (
    attemptedValue: _uuidStringFromDatabase(row[0]),
    visibleValue: _uuidStringFromDatabase(row[1]),
    hasOverride: row[2] == true || row[2] == 1,
  );
}

String? _uuidStringFromDatabase(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return UuidValueJsonExtension.fromJson(value).uuid;
}

Future<List<String>> _tombstoneSnapshot() async {
  final rows = await session.db.unsafeQuery(
    '''
SELECT r."uuidRowId", tomb."clFlag", tomb."reason", tomb."hlcDatetime",
       tomb."hlcCounter", n."uuidNodeId"
FROM "crdt_data_tombstone" tomb
JOIN "crdt_data_rows" r ON r."id" = tomb."rowId"
JOIN "crdt_nodes" n ON n."id" = tomb."nodeId"
ORDER BY r."uuidRowId"
''',
  );

  return [
    for (final row in rows)
      '${row[0]}|${row[1]}|${row[2]}|${row[3]}|${row[4]}|${row[5]}',
  ];
}

Future<_SetNullBatchingSnapshot> _setNullBatchingSnapshot(
  CrdtDatabaseSession databaseSession,
  UuidValue childId,
) async {
  final child = await Town.db.findById(databaseSession, childId);
  final projection = await _findForeignKeyProjection(
    rowId: childId,
    columnName: Town.t.mayorId.columnName,
    databaseSession: databaseSession,
  );

  return (
    childName: child?.name,
    visibleMayorId: child?.mayorId?.uuid,
    attemptedMayorId: projection?.attemptedValue,
    hasOverride: projection?.hasOverride,
  );
}

typedef _ForeignKeyProjection = ({
  String? attemptedValue,
  String? visibleValue,
  bool hasOverride,
});

typedef _SetNullBatchingSnapshot = ({
  String? childName,
  String? visibleMayorId,
  String? attemptedMayorId,
  bool? hasOverride,
});

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
}
