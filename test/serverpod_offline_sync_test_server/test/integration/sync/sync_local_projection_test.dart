import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given people sharing an organization and an address attached to an unassigned person,',
    () {
      late SyncNode author;
      late SyncNode observer;
      late Organization organization;
      late List<Person> siblings;
      late Person newcomer;
      late Address address;
      late Map<UuidValue, Hlc> siblingHlcs;

      setUpAll(() async {
        author = await syncNode(await createAdditionalTestSession(), testSyncTables);
        observer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        organization = Organization(id: const Uuid().v7obj(), name: 'organization');
        siblings = [
          for (var i = 0; i < 24; i++)
            Person(
              id: const Uuid().v7obj(),
              name: 'person-$i',
              organizationId: organization.id,
            ),
        ];
        newcomer = Person(id: const Uuid().v7obj(), name: 'newcomer');
        address = Address(
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
        siblingHlcs = {
          for (final person in siblings)
            person.id!: await rowHlc(person.id!, databaseSession: author.crdt),
        };
      });

      group(
        'when more people are inserted and the unassigned person joins the organization offline,',
        () {
          late List<Person> added;
          late List<Person> authorPeople;
          late List<Person> observerPeople;
          late Address? authorAddress;
          late Address? observerAddress;
          late int authorAttemptedCount;
          late int observerAttemptedCount;
          late Map<UuidValue, Hlc> authorSiblingHlcs;
          late Map<UuidValue, Hlc> observerSiblingHlcs;

          setUpAll(() async {
            added = [
              for (var i = 24; i < 48; i++)
                Person(
                  id: const Uuid().v7obj(),
                  name: 'person-$i',
                  organizationId: organization.id,
                ),
            ];

            await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
              await Person.db.insert(
                author.crdt,
                added,
                transaction: tx,
                noReturn: true,
              );
              await Person.db.updateRow(
                author.crdt,
                newcomer.copyWith(organizationId: organization.id),
                columns: (t) => [t.organizationId],
                transaction: tx,
              );
            });
            await syncWithServer(author, observer);

            authorPeople = await Person.db.find(author.crdt);
            observerPeople = await Person.db.find(observer.crdt);
            authorAddress = await Address.db.findById(author.crdt, address.id!);
            observerAddress = await Address.db.findById(observer.crdt, address.id!);
            authorAttemptedCount = await CrdtDataAttemptedValue.db.count(author.crdt);
            observerAttemptedCount = await CrdtDataAttemptedValue.db.count(
              observer.crdt,
            );
            authorSiblingHlcs = {
              for (final person in siblings)
                person.id!: await rowHlc(person.id!, databaseSession: author.crdt),
            };
            observerSiblingHlcs = {
              for (final person in siblings)
                person.id!: await rowHlc(person.id!, databaseSession: observer.crdt),
            };
          });

          test('then both replicas see every person.', () {
            final expectedIds = {
              for (final person in [...siblings, ...added, newcomer]) person.id,
            };
            expect({for (final person in authorPeople) person.id}, expectedIds);
            expect({for (final person in observerPeople) person.id}, expectedIds);
          });

          test('then every person on both replicas belongs to the organization.', () {
            expect(
              authorPeople.map((person) => person.organizationId),
              everyElement(organization.id),
            );
            expect(
              observerPeople.map((person) => person.organizationId),
              everyElement(organization.id),
            );
          });

          test(
            'then the address on both replicas remains attached to the newcomer.',
            () {
              expect(authorAddress!.inhabitantId, newcomer.id);
              expect(observerAddress!.inhabitantId, newcomer.id);
            },
          );

          test('then neither replica holds a withheld authored value.', () {
            expect(authorAttemptedCount, 0);
            expect(observerAttemptedCount, 0);
          });

          test(
            'then the original siblings keep their row clocks on both replicas.',
            () {
              expect(authorSiblingHlcs, siblingHlcs);
              expect(observerSiblingHlcs, siblingHlcs);
            },
          );
        },
      );
    },
  );

  group(
    'Given two people in the same organization with an address attached to the first,',
    () {
      late SyncNode author;
      late SyncNode observer;
      late Organization organization;
      late List<Person> people;
      late Address address;
      late Map<UuidValue, Hlc> originalClocks;

      setUpAll(() async {
        author = await syncNode(await createAdditionalTestSession(), testSyncTables);
        observer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        organization = Organization(id: const Uuid().v7obj(), name: 'organization');
        people = [
          for (final name in ['first', 'second'])
            Person(
              id: const Uuid().v7obj(),
              name: name,
              organizationId: organization.id,
            ),
        ];
        address = Address(
          id: const Uuid().v7obj(),
          street: 'street',
          inhabitantId: people.first.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Organization.db.insertRow(author.crdt, organization, transaction: tx);
          await Person.db.insert(author.crdt, people, transaction: tx);
          await Address.db.insertRow(author.crdt, address, transaction: tx);
        });
        originalClocks = {
          for (final person in people)
            person.id!: await rowHlc(person.id!, databaseSession: author.crdt),
        };
      });

      group(
        'when a primary-key upsert changes names only for the person matching its filter,',
        () {
          late List<Person> updated;
          late List<Person> authorPeople;
          late List<Person> observerPeople;
          late Address? authorAddress;
          late Address? observerAddress;
          late Map<UuidValue, Hlc> authorClocks;
          late Map<UuidValue, Hlc> observerClocks;
          late List<CrdtDataField> authorFields;
          late List<CrdtDataField> observerFields;
          late int authorAttemptedCount;
          late int observerAttemptedCount;

          setUpAll(() async {
            updated = await author.crdt.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.upsert(
                author.crdt,
                [for (final person in people) person.copyWith(name: 'updated')],
                conflictColumns: (t) => [t.id],
                updateColumns: (t) => [t.name],
                updateWhere: (t) => t.name.equals('first'),
                transaction: tx,
              ),
            );
            await syncWithServer(author, observer);

            authorPeople = await Person.db.find(author.crdt);
            observerPeople = await Person.db.find(observer.crdt);
            authorAddress = await Address.db.findById(author.crdt, address.id!);
            observerAddress = await Address.db.findById(observer.crdt, address.id!);
            authorClocks = {
              for (final person in people)
                person.id!: await rowHlc(person.id!, databaseSession: author.crdt),
            };
            observerClocks = {
              for (final person in people)
                person.id!: await rowHlc(person.id!, databaseSession: observer.crdt),
            };
            authorFields = await CrdtDataField.db.find(
              author.crdt,
              where: (t) =>
                  t.row.uuidRowId.inSet({for (final person in people) person.id!}),
              include: CrdtDataField.include(
                row: CrdtDataRow.include(),
                column: CrdtSchemaColumn.include(),
                node: CrdtNode.include(),
              ),
            );
            observerFields = await CrdtDataField.db.find(
              observer.crdt,
              where: (t) =>
                  t.row.uuidRowId.inSet({for (final person in people) person.id!}),
              include: CrdtDataField.include(
                row: CrdtDataRow.include(),
                column: CrdtSchemaColumn.include(),
                node: CrdtNode.include(),
              ),
            );
            authorAttemptedCount = await CrdtDataAttemptedValue.db.count(author.crdt);
            observerAttemptedCount = await CrdtDataAttemptedValue.db.count(
              observer.crdt,
            );
          });

          test('then the upsert reports only the filtered person.', () {
            expect(updated.map((person) => person.id).toSet(), {people.first.id});
          });

          test(
            'then both replicas show the updated name only on the filtered person.',
            () {
              final expectedNames = {
                people.first.id: 'updated',
                people.last.id: 'second',
              };
              expect(
                {for (final person in authorPeople) person.id: person.name},
                expectedNames,
              );
              expect(
                {for (final person in observerPeople) person.id: person.name},
                expectedNames,
              );
            },
          );

          test(
            'then every person on both replicas still belongs to the organization.',
            () {
              expect(
                authorPeople.map((person) => person.organizationId),
                everyElement(organization.id),
              );
              expect(
                observerPeople.map((person) => person.organizationId),
                everyElement(organization.id),
              );
            },
          );

          test(
            'then the address on both replicas remains attached to the first person.',
            () {
              expect(authorAddress!.inhabitantId, people.first.id);
              expect(observerAddress!.inhabitantId, people.first.id);
            },
          );

          test('then both replicas keep the original row clocks.', () {
            expect(authorClocks, originalClocks);
            expect(observerClocks, originalClocks);
          });

          test(
            'then both replicas author an organization for every person and a name only for the filtered person.',
            () {
              final expectedFields = {
                for (final person in people) (person.id, 'organizationId'),
                (people.first.id, 'name'),
              };
              expect(
                {
                  for (final field in authorFields)
                    (field.row!.uuidRowId, field.column!.name),
                },
                expectedFields,
              );
              expect(
                {
                  for (final field in observerFields)
                    (field.row!.uuidRowId, field.column!.name),
                },
                expectedFields,
              );
            },
          );

          test(
            'then organization field clocks stay at the original row clocks on both replicas.',
            () {
              for (final fields in [authorFields, observerFields]) {
                for (final field in fields.where(
                  (field) => field.column!.name == 'organizationId',
                )) {
                  expect(field.hlc, originalClocks[field.row!.uuidRowId]);
                }
              }
            },
          );

          test('then neither replica holds a withheld authored value.', () {
            expect(authorAttemptedCount, 0);
            expect(observerAttemptedCount, 0);
          });
        },
      );
    },
  );

  group('Given a merged town waiting for a missing mayor,', () {
    late SyncNode node;
    late Person mayor;
    late Town town;
    late Hlc mayorFieldHlc;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
      town = Town(id: const Uuid().v7obj(), name: 'town', mayorId: mayor.id);
      final hlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
      await node.crdt.db.mergeChanges([
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
      expect((await Town.db.findById(node.crdt, town.id!))!.mayorId, isNull);
      expect(
        (await attemptedValue(
          rowId: town.id!,
          columnName: 'mayorId',
          databaseSession: node.crdt,
        ))!.value,
        mayor.id,
      );
      mayorFieldHlc = await _fieldHlc(
        town.id!,
        'mayorId',
        databaseSession: node.crdt,
      );
    });

    group('when that person is inserted locally,', () {
      late Town? recoveredTown;
      late CrdtDataAttemptedValue? withheldMayor;
      late Hlc recoveredMayorFieldHlc;

      setUpAll(() async {
        await node.crdt.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(node.crdt, mayor, transaction: tx),
        );

        recoveredTown = await Town.db.findById(node.crdt, town.id!);
        withheldMayor = await attemptedValue(
          rowId: town.id!,
          columnName: 'mayorId',
          databaseSession: node.crdt,
        );
        recoveredMayorFieldHlc = await _fieldHlc(
          town.id!,
          'mayorId',
          databaseSession: node.crdt,
        );
      });

      test('then the town recovers its authored mayor.', () {
        expect(recoveredTown!.mayorId, mayor.id);
      });

      test('then the town no longer holds a withheld mayor.', () {
        expect(withheldMayor, isNull);
      });

      test('then the mayor field clock is unchanged.', () {
        expect(recoveredMayorFieldHlc, mayorFieldHlc);
      });
    });
  });

  group(
    'Given two merged unique children waiting for unavailable parents and a missing fallback,',
    () {
      const fallbackId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
      late SyncNode node;
      late List<UniqueSetDefaultChild> children;

      setUpAll(() async {
        node = await syncNode(await createAdditionalTestSession(), testSyncTables);
        children = [
          for (var i = 0; i < 2; i++)
            UniqueSetDefaultChild(
              id: const Uuid().v7obj(),
              name: 'orphan-$i',
              parentId: const Uuid().v7obj(),
            ),
        ];
        final hlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
        await node.crdt.db.mergeChanges([
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
          (await UniqueSetDefaultChild.db.find(node.crdt)).map((row) => row.parentId),
          everyElement(isNull),
        );
      });

      group('when the fallback and another claimant are inserted locally,', () {
        late UniqueSetDefaultChild claimant;
        late List<UniqueSetDefaultChild> rows;
        late Map<UuidValue?, UuidValue?> authoredParents;

        setUpAll(() async {
          claimant = UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'claimant',
            parentId: fallbackId,
          );
          await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await Town.db.insertRow(
              node.crdt,
              Town(id: fallbackId, name: 'fallback'),
              transaction: tx,
            );
            await UniqueSetDefaultChild.db.insertRow(
              node.crdt,
              claimant,
              transaction: tx,
            );
          });

          rows = await UniqueSetDefaultChild.db.find(node.crdt);
          final facts = await node.sync
              .collectPendingChanges(
                node.raw,
                checkpointsByScopeUuid: {testCrdtUserId: const []},
              )
              .toList();
          authoredParents = {
            for (final fact in facts.whereType<CrdtMergeInsert>())
              if (fact.data case final UniqueSetDefaultChild row) row.id: row.parentId,
          };
        });

        test('then three unique children are visible.', () {
          expect(rows, hasLength(3));
        });

        test('then exactly one child owns the fallback.', () {
          expect(rows.where((row) => row.parentId == fallbackId), hasLength(1));
        });

        test('then the other children have no visible parent.', () {
          expect(rows.where((row) => row.parentId == null), hasLength(2));
        });

        test('then every exported insert retains its authored parent.', () {
          expect(authoredParents, {
            for (final row in [...children, claimant]) row.id: row.parentId,
          });
        });
      });
    },
  );
}

Future<Hlc> _fieldHlc(
  UuidValue rowId,
  String column, {
  required CrdtDatabaseSession databaseSession,
}) async {
  final field = await CrdtDataField.db.findFirstRow(
    databaseSession,
    where: (t) => t.row.uuidRowId.equals(rowId) & t.column.name.equals(column),
    include: CrdtDataField.include(node: CrdtNode.include()),
  );
  return field!.hlc;
}
