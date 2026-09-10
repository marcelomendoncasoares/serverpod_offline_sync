import 'dart:convert';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

const _defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

void main() {
  initTestClientSession();

  group(
    'Given a company insert concurrent with its original town deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late SyncNode defaultFirst;
      late SyncNode defaultLast;
      late SyncNode batched;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet defaultFacts;
      late List<_ObserverSnapshot> snapshots;
      late Town? originalBeforeDefault;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();
        defaultFirst = await _node();
        defaultLast = await _node();
        batched = await _node();
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);

        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            defaultWriter.crdt,
            Town(id: _defaultTownId, name: 'default'),
            transaction: tx,
          );
        });
        defaultFacts = await _collect(defaultWriter);
      });

      group('when a default town insert arrives first, last, or in the same batch,', () {
        setUp(() async {
          await _merge(defaultFirst, defaultFacts);
          await _merge(defaultFirst, childFacts);
          await _merge(defaultFirst, deleteFacts);
          await _merge(defaultLast, childFacts);
          await _merge(defaultLast, deleteFacts);
          // This observer has already rejected the original town's deletion.
          originalBeforeDefault = await Town.db.findById(
            defaultLast.crdt,
            town.id!,
          );
          await _merge(defaultLast, defaultFacts);
          await _merge(batched, [...childFacts, ...deleteFacts, ...defaultFacts]);

          snapshots = await _captureConvergence(
            [defaultFirst, defaultLast, batched],
            town: town,
            company: company,
          );
        });

        test(
          'then every observer hides the original town and repairs the same authored reference.',
          () {
            _expectConvergence(
              snapshots,
              authoredFacts: [...childFacts, ...deleteFacts, ...defaultFacts],
              originalVisible: false,
              defaultVisible: true,
              companyTownId: _defaultTownId,
            );
            expect(originalBeforeDefault, isNotNull);
          },
        );
      });
    },
  );

  group(
    'Given a company insert concurrent with deletions of its original town and the existing default town,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late SyncNode defaultFirst;
      late SyncNode defaultLast;
      late Town town;
      late Town defaultTown;
      late Company company;
      late CrdtMergeSet initial;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late List<CrdtMergeDelete> defaultDelete;
      late List<_ObserverSnapshot> snapshots;
      late UuidValue? referenceBeforeDefaultDeletion;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();
        defaultFirst = await _node();
        defaultLast = await _node();
        town = Town(id: const Uuid().v7obj(), name: 'original');
        defaultTown = Town(id: _defaultTownId, name: 'default');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
          await Town.db.insertRow(childWriter.crdt, defaultTown, transaction: tx);
        });
        initial = await _collect(childWriter);
        await _merge(deleteWriter, initial);
        await _merge(defaultWriter, initial);
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
        });
        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(defaultWriter.crdt, defaultTown, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        defaultDelete = (await _collect(
          defaultWriter,
        )).whereType<CrdtMergeDelete>().toList();
      });

      group(
        'when the default deletion arrives before or after the original deletion,',
        () {
          setUp(() async {
            await _merge(defaultFirst, childFacts);
            await _merge(defaultFirst, defaultDelete);
            await _merge(defaultFirst, deleteFacts);
            await _merge(defaultLast, childFacts);
            await _merge(defaultLast, deleteFacts);
            referenceBeforeDefaultDeletion = (await Company.db.findById(
              defaultLast.crdt,
              company.id!,
            ))!.townId;
            // Only the default tombstone is delivered: no original town or company
            // facts are replayed to accidentally trigger their recomputation.
            await _merge(defaultLast, defaultDelete);

            snapshots = await _captureConvergence(
              [defaultFirst, defaultLast],
              town: town,
              company: company,
            );
          });

          test(
            'then every observer hides the default and restores the original town and reference.',
            () {
              _expectConvergence(
                snapshots,
                authoredFacts: [...childFacts, ...deleteFacts, ...defaultDelete],
                originalVisible: true,
                defaultVisible: false,
                companyTownId: town.id!,
              );
              expect(defaultDelete, hasLength(1));
              expect(referenceBeforeDefaultDeletion, _defaultTownId);
            },
          );
        },
      );
    },
  );

  group(
    'Given a deleted default town and a company insert concurrent with its original town deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late SyncNode defaultFirst;
      late SyncNode defaultLast;
      late Town town;
      late Town defaultTown;
      late Company company;
      late CrdtMergeSet deletedDefaultFacts;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late List<_ObserverSnapshot> snapshots;
      late Town? originalBeforeDefault;
      late CrdtMergeSet restoredDefaultFacts;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();
        defaultFirst = await _node();
        defaultLast = await _node();
        town = Town(id: const Uuid().v7obj(), name: 'original');
        defaultTown = Town(id: _defaultTownId, name: 'default');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
        });
        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(defaultWriter.crdt, defaultTown, transaction: tx);
        });
        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(defaultWriter.crdt, defaultTown, transaction: tx);
        });
        deletedDefaultFacts = await _collect(defaultWriter);
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        await _merge(defaultFirst, deletedDefaultFacts);
        await _merge(defaultLast, deletedDefaultFacts);
      });

      group(
        'when the default restoration arrives before or after the original deletion,',
        () {
          setUp(() async {
            await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
              await Town.db.insertRow(defaultWriter.crdt, defaultTown, transaction: tx);
            });
            restoredDefaultFacts = await _collect(defaultWriter);
            await _merge(defaultFirst, restoredDefaultFacts);
            await _merge(defaultFirst, childFacts);
            await _merge(defaultFirst, deleteFacts);
            await _merge(defaultLast, childFacts);
            await _merge(defaultLast, deleteFacts);
            originalBeforeDefault = await Town.db.findById(
              defaultLast.crdt,
              town.id!,
            );
            await _merge(defaultLast, restoredDefaultFacts);

            snapshots = await _captureConvergence(
              [defaultFirst, defaultLast],
              town: town,
              company: company,
            );
          });

          test(
            'then every observer accepts the original deletion and repairs onto the restored default.',
            () {
              _expectConvergence(
                snapshots,
                authoredFacts: [
                  ...childFacts,
                  ...deleteFacts,
                  ...deletedDefaultFacts,
                  ...restoredDefaultFacts,
                ],
                originalVisible: false,
                defaultVisible: true,
                companyTownId: _defaultTownId,
              );
              expect(originalBeforeDefault, isNotNull);
            },
          );
        },
      );
    },
  );

  group(
    'Given a default town attached to a city and a company insert concurrent with deletion of that city and the original town,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode cityFirst;
      late SyncNode cityLast;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late List<CrdtMergeDelete> deletions;
      late List<CrdtMergeDelete> cityDelete;
      late List<CrdtMergeDelete> townDelete;
      late List<_ObserverSnapshot> snapshots;
      late UuidValue? referenceBeforeCityDeletion;
      late City? cityFirstFinalCity;
      late City? cityLastFinalCity;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        cityFirst = await _node();
        cityLast = await _node();
        city = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.crdt, city, transaction: tx);
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.crdt,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        // Neither the default town nor the company exists on this author, so
        // these deletes author no child tombstones or FK rewrites.
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
          await City.db.deleteRow(deleteWriter.crdt, city, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deletions = (await _collect(
          deleteWriter,
        )).whereType<CrdtMergeDelete>().toList();
        cityDelete = deletions.where((fact) => fact.uuidRowId == city.id).toList();
        townDelete = deletions.where((fact) => fact.uuidRowId == town.id).toList();
      });

      group(
        'when the city deletion arrives before or after the original town deletion,',
        () {
          setUp(() async {
            await _merge(cityFirst, childFacts);
            await _merge(cityFirst, cityDelete);
            await _merge(cityFirst, townDelete);
            await _merge(cityLast, childFacts);
            await _merge(cityLast, townDelete);
            referenceBeforeCityDeletion = (await Company.db.findById(
              cityLast.crdt,
              company.id!,
            ))!.townId;
            await _merge(cityLast, cityDelete);

            snapshots = await _captureConvergence(
              [cityFirst, cityLast],
              town: town,
              company: company,
            );
            cityFirstFinalCity = await City.db.findById(
              cityFirst.crdt,
              city.id!,
            );
            cityLastFinalCity = await City.db.findById(cityLast.crdt, city.id!);
          });

          test(
            'then every observer hides the default by cascade and retains the original town and reference.',
            () {
              _expectConvergence(
                snapshots,
                authoredFacts: [...childFacts, ...deletions],
                originalVisible: true,
                defaultVisible: false,
                companyTownId: town.id!,
              );
              expect(cityDelete, hasLength(1));
              expect(townDelete, hasLength(1));
              expect(referenceBeforeCityDeletion, _defaultTownId);
              expect(cityFirstFinalCity, isNull);
              expect(cityLastFinalCity, isNull);
            },
          );
        },
      );
    },
  );

  group(
    'Given a cascade-hidden default town and a company insert concurrent with its original town deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode cityFirst;
      late SyncNode cityLast;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late List<_ObserverSnapshot> snapshots;
      late Town? defaultBeforeCityRestoration;
      late Town? originalBeforeCityRestoration;
      late City? cityFirstFinalCity;
      late City? cityLastFinalCity;
      late CrdtMergeSet cityRestoration;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        cityFirst = await _node();
        cityLast = await _node();
        city = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.crdt, city, transaction: tx);
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.crdt,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
          await City.db.deleteRow(deleteWriter.crdt, city, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        await _merge(cityFirst, deleteFacts);
        await _merge(cityLast, childFacts);
        await _merge(cityLast, deleteFacts);
        defaultBeforeCityRestoration = await Town.db.findById(
          cityLast.crdt,
          _defaultTownId,
        );
        originalBeforeCityRestoration = await Town.db.findById(cityLast.crdt, town.id!);
      });

      group(
        'when only the default city restoration arrives before or after those company and town facts,',
        () {
          setUp(() async {
            await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
              await City.db.insertRow(deleteWriter.crdt, city, transaction: tx);
            });
            cityRestoration = (await _collect(
              deleteWriter,
            )).where((fact) => fact.tableName == City.t.tableName).toList();
            await _merge(cityFirst, cityRestoration);
            await _merge(cityFirst, childFacts);
            // The late observer receives no default-town or company facts here.
            await _merge(cityLast, cityRestoration);

            snapshots = await _captureConvergence(
              [cityFirst, cityLast],
              town: town,
              company: company,
            );
            cityFirstFinalCity = await City.db.findById(
              cityFirst.crdt,
              city.id!,
            );
            cityLastFinalCity = await City.db.findById(cityLast.crdt, city.id!);
          });

          test(
            'then every observer restores the default and accepts the original town deletion.',
            () {
              _expectConvergence(
                snapshots,
                authoredFacts: [...childFacts, ...deleteFacts, ...cityRestoration],
                originalVisible: false,
                defaultVisible: true,
                companyTownId: _defaultTownId,
              );
              expect(defaultBeforeCityRestoration, isNull);
              expect(originalBeforeCityRestoration, isNotNull);
              expect(cityFirstFinalCity, isNotNull);
              expect(cityLastFinalCity, isNotNull);
            },
          );
        },
      );
    },
  );

  group(
    'Given two city deletions whose cascades hide the original and default towns and a restrict blocker hidden by the original city cascade,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode originalFirst;
      late SyncNode defaultFirst;
      late SyncNode batched;
      late City originalCity;
      late City defaultCity;
      late Town town;
      late Company company;
      late Organization organization;
      late Person blocker;
      late CrdtMergeSet childFacts;
      late List<CrdtMergeDelete> deletions;
      late List<CrdtMergeDelete> originalDelete;
      late List<CrdtMergeDelete> defaultDelete;
      late List<
        ({
          City? originalCity,
          City? defaultCity,
          Organization? organization,
          Person? blocker,
        })
      >
      relatedRows;
      late List<_ObserverSnapshot> snapshots;
      late City? originalCityBeforeDefaultDeletion;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        originalFirst = await _node();
        defaultFirst = await _node();
        batched = await _node();
        originalCity = City(id: const Uuid().v7obj(), name: 'original city');
        defaultCity = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(
          id: const Uuid().v7obj(),
          name: 'original',
          cityId: originalCity.id,
        );
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        organization = Organization(
          id: const Uuid().v7obj(),
          name: 'organization',
          cityId: originalCity.id,
        );
        blocker = Person(
          id: const Uuid().v7obj(),
          name: 'default city blocker',
          organizationId: organization.id,
          cityId: defaultCity.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.crdt, originalCity, transaction: tx);
          await City.db.insertRow(childWriter.crdt, defaultCity, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
          await Town.db.insertRow(
            childWriter.crdt,
            Town(id: _defaultTownId, name: 'default', cityId: defaultCity.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
          await Organization.db.insertRow(
            childWriter.crdt,
            organization,
            transaction: tx,
          );
          await Person.db.insertRow(childWriter.crdt, blocker, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.deleteRow(deleteWriter.crdt, originalCity, transaction: tx);
          await City.db.deleteRow(deleteWriter.crdt, defaultCity, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deletions = (await _collect(
          deleteWriter,
        )).whereType<CrdtMergeDelete>().toList();
        originalDelete = deletions
            .where((fact) => fact.uuidRowId == originalCity.id)
            .toList();
        defaultDelete = deletions
            .where((fact) => fact.uuidRowId == defaultCity.id)
            .toList();
      });

      group('when observers receive the deletions in opposite orders or together,', () {
        setUp(() async {
          await _merge(originalFirst, childFacts);
          await _merge(originalFirst, originalDelete);
          originalCityBeforeDefaultDeletion = await City.db.findById(
            originalFirst.crdt,
            originalCity.id!,
          );
          await _merge(originalFirst, defaultDelete);
          await _merge(defaultFirst, childFacts);
          await _merge(defaultFirst, defaultDelete);
          await _merge(defaultFirst, originalDelete);
          await _merge(batched, [...childFacts, ...deletions]);

          snapshots = await _captureConvergence(
            [originalFirst, defaultFirst, batched],
            town: town,
            company: company,
          );
          relatedRows = [
            for (final observer in [originalFirst, defaultFirst, batched])
              (
                originalCity: await City.db.findById(observer.crdt, originalCity.id!),
                defaultCity: await City.db.findById(observer.crdt, defaultCity.id!),
                organization: await Organization.db.findById(
                  observer.crdt,
                  organization.id!,
                ),
                blocker: await Person.db.findById(observer.crdt, blocker.id!),
              ),
          ];
        });

        test(
          'then every observer withdraws both deletions and preserves the authored relationships.',
          () {
            _expectConvergence(
              snapshots,
              authoredFacts: [...childFacts, ...deletions],
              originalVisible: true,
              defaultVisible: true,
              companyTownId: town.id!,
            );
            for (final rows in relatedRows) {
              expect(rows.originalCity, isNotNull);
              expect(rows.defaultCity, isNotNull);
              expect(rows.organization, isNotNull);
              expect(rows.blocker, isNotNull);
              expect(rows.blocker!.organizationId, organization.id);
              expect(rows.blocker!.cityId, defaultCity.id);
            }
            expect(originalDelete, hasLength(1));
            expect(defaultDelete, hasLength(1));
            expect(originalCityBeforeDefaultDeletion, isNull);
          },
        );
      });
    },
  );

  group(
    'Given a nullable set-default child whose authored town has never arrived,',
    () {
      late SyncNode defaultWriter;
      late SyncNode defaultFirst;
      late SyncNode defaultLast;
      late Town missingTown;
      late UniqueSetDefaultChild child;
      late Hlc childHlc;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet defaultFacts;
      late List<
        ({UniqueSetDefaultChild? child, Town? original, Map<String, dynamic> facts})
      >
      snapshots;
      late UniqueSetDefaultChild? childBeforeDefault;

      setUp(() async {
        defaultWriter = await _node();
        defaultFirst = await _node();
        defaultLast = await _node();
        missingTown = Town(id: const Uuid().v7obj(), name: 'missing');
        child = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'child',
          parentId: missingTown.id,
        );
        childHlc = Hlc.now(const Uuid().v7obj());
        childFacts = <CrdtMergeChange>[
          CrdtMergeInsert(
            uuidScopeId: testCrdtUserId,
            tableName: UniqueSetDefaultChild.t.tableName,
            uuidRowId: child.id!,
            uuidNodeId: childHlc.nodeId,
            hlcDatetime: childHlc.datetime,
            hlcCounter: 0,
            data: child,
          ),
        ];
        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            defaultWriter.crdt,
            Town(id: _defaultTownId, name: 'default'),
            transaction: tx,
          );
        });
        defaultFacts = await _collect(defaultWriter);
      });

      group('when the default town arrives before or after that child,', () {
        setUp(() async {
          await _merge(defaultFirst, defaultFacts);
          await _merge(defaultFirst, childFacts);
          await _merge(defaultLast, childFacts);
          childBeforeDefault = await UniqueSetDefaultChild.db.findById(
            defaultLast.crdt,
            child.id!,
          );
          await _merge(defaultLast, defaultFacts);

          snapshots = [
            for (final observer in [defaultFirst, defaultLast])
              (
                child: await UniqueSetDefaultChild.db.findById(
                  observer.crdt,
                  child.id!,
                ),
                original: await Town.db.findById(observer.crdt, missingTown.id!),
                facts: _payloads(await _collect(observer)),
              ),
          ];
        });

        test(
          'then both observers show the child on the default and preserve its missing authored parent.',
          () {
            for (final snapshot in snapshots) {
              expect(snapshot.child, isNotNull);
              expect(snapshot.child!.parentId, _defaultTownId);
              expect(snapshot.original, isNull);
              expect(snapshot.facts, _payloads([...childFacts, ...defaultFacts]));
            }
            expect(childBeforeDefault, isNull);
          },
        );
      });
    },
  );

  group(
    'Given an observer retaining the original town after a concurrent company insert and town deletion without a default,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode localDefault;
      late SyncNode defaultFirst;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late List<_ObserverSnapshot> snapshots;
      late Town? originalBeforeLocalDefault;
      late CrdtMergeSet defaultFacts;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        localDefault = await _node();
        defaultFirst = await _node();
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        await _merge(localDefault, childFacts);
        await _merge(localDefault, deleteFacts);
        originalBeforeLocalDefault = await Town.db.findById(
          localDefault.crdt,
          town.id!,
        );
      });

      group(
        'when that observer inserts the default locally and another receives it before the earlier facts,',
        () {
          setUp(() async {
            await localDefault.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
              await Town.db.insertRow(
                localDefault.crdt,
                Town(id: _defaultTownId, name: 'default'),
                transaction: tx,
              );
            });
            defaultFacts = (await _collect(
              localDefault,
            )).where((fact) => fact.uuidRowId == _defaultTownId).toList();
            await _merge(defaultFirst, defaultFacts);
            await _merge(defaultFirst, childFacts);
            await _merge(defaultFirst, deleteFacts);

            snapshots = await _captureConvergence(
              [localDefault, defaultFirst],
              town: town,
              company: company,
            );
          });

          test(
            'then both accept the original deletion and preserve the authored company reference.',
            () {
              _expectConvergence(
                snapshots,
                authoredFacts: [...childFacts, ...deleteFacts, ...defaultFacts],
                originalVisible: false,
                defaultVisible: true,
                companyTownId: _defaultTownId,
              );
              expect(originalBeforeLocalDefault, isNotNull);
            },
          );
        },
      );
    },
  );

  group(
    'Given deletions of the original town and the default city with a concurrent person blocking that city deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode blockerWriter;
      late SyncNode blockerFirst;
      late SyncNode blockerLast;
      late SyncNode originalFirst;
      late City city;
      late Town town;
      late Company company;
      late Person blocker;
      late CrdtMergeSet initial;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet blockerFacts;
      late List<_ObserverSnapshot> snapshots;
      late Town? defaultBeforeBlocker;
      late Town? originalBeforeBlocker;
      late Town? originalBeforeCityDeletion;
      late City? blockerFirstFinalCity;
      late City? blockerLastFinalCity;
      late List<CrdtMergeDelete> cityDelete;
      late List<CrdtMergeDelete> originalDelete;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        blockerWriter = await _node();
        blockerFirst = await _node();
        blockerLast = await _node();
        originalFirst = await _node();
        city = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        blocker = Person(
          id: const Uuid().v7obj(),
          name: 'blocker',
          cityId: city.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.crdt, city, transaction: tx);
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
        });
        initial = await _collect(childWriter);
        await _merge(deleteWriter, initial);
        await _merge(blockerWriter, initial);
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.crdt,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.deleteRow(deleteWriter.crdt, city, transaction: tx);
          await Town.db.deleteRow(deleteWriter.crdt, town, transaction: tx);
        });
        await blockerWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(blockerWriter.crdt, blocker, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        blockerFacts = (await _collect(
          blockerWriter,
        )).where((fact) => fact.uuidRowId == blocker.id).toList();
      });

      group('when observers receive the blocker and deletions in different orders,', () {
        setUp(() async {
          await _merge(blockerFirst, initial);
          await _merge(blockerFirst, blockerFacts);
          await _merge(blockerFirst, childFacts);
          await _merge(blockerFirst, deleteFacts);
          await _merge(blockerLast, childFacts);
          await _merge(blockerLast, deleteFacts);
          defaultBeforeBlocker = await Town.db.findById(
            blockerLast.crdt,
            _defaultTownId,
          );
          originalBeforeBlocker = await Town.db.findById(
            blockerLast.crdt,
            town.id!,
          );
          await _merge(blockerLast, blockerFacts);

          originalDelete = deleteFacts
              .whereType<CrdtMergeDelete>()
              .where((fact) => fact.uuidRowId == town.id)
              .toList();
          cityDelete = deleteFacts
              .whereType<CrdtMergeDelete>()
              .where((fact) => fact.uuidRowId == city.id)
              .toList();

          await _merge(originalFirst, childFacts);
          await _merge(originalFirst, originalDelete);
          originalBeforeCityDeletion = await Town.db.findById(
            originalFirst.crdt,
            town.id!,
          );
          // The default's final visibility does not change here. Its candidate
          // cascade deletion must still invalidate the company's earlier repair.
          await _merge(originalFirst, [...cityDelete, ...blockerFacts]);

          snapshots = await _captureConvergence(
            [blockerFirst, blockerLast, originalFirst],
            town: town,
            company: company,
          );
          blockerFirstFinalCity = await City.db.findById(
            blockerFirst.crdt,
            city.id!,
          );
          blockerLastFinalCity = await City.db.findById(
            blockerLast.crdt,
            city.id!,
          );
        });

        test(
          'then all observers withdraw both deletions and preserve the original reference.',
          () {
            _expectConvergence(
              snapshots,
              authoredFacts: [...childFacts, ...deleteFacts, ...blockerFacts],
              originalVisible: true,
              defaultVisible: true,
              companyTownId: town.id!,
            );
            expect(defaultBeforeBlocker, isNull);
            expect(originalBeforeBlocker, isNotNull);
            expect(originalDelete, hasLength(1));
            expect(cityDelete, hasLength(1));
            expect(originalBeforeCityDeletion, isNull);
            expect(blockerFirstFinalCity, isNotNull);
            expect(blockerLastFinalCity, isNotNull);
          },
        );
      });
    },
  );

  group(
    'Given a city deletion blocked by a concurrent town and its company without a default,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late SyncNode defaultFirst;
      late SyncNode defaultLast;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet defaultFacts;
      late List<_ObserverSnapshot> snapshots;
      late City? cityBeforeDefault;
      late Town? originalBeforeDefault;
      late City? defaultFirstFinalCity;
      late City? defaultLastFinalCity;

      setUp(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();
        defaultFirst = await _node();
        defaultLast = await _node();
        city = City(id: const Uuid().v7obj(), name: 'original city');
        town = Town(id: const Uuid().v7obj(), name: 'original', cityId: city.id);
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.crdt, city, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.crdt, town, transaction: tx);
          await Company.db.insertRow(childWriter.crdt, company, transaction: tx);
        });
        await deleteWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.deleteRow(deleteWriter.crdt, city, transaction: tx);
        });
        await defaultWriter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            defaultWriter.crdt,
            Town(id: _defaultTownId, name: 'default'),
            transaction: tx,
          );
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        defaultFacts = await _collect(defaultWriter);
      });

      group('when a default town arrives before or after those facts,', () {
        setUp(() async {
          await _merge(defaultFirst, defaultFacts);
          await _merge(defaultFirst, childFacts);
          await _merge(defaultFirst, deleteFacts);
          await _merge(defaultLast, childFacts);
          await _merge(defaultLast, deleteFacts);
          cityBeforeDefault = await City.db.findById(
            defaultLast.crdt,
            city.id!,
          );
          originalBeforeDefault = await Town.db.findById(
            defaultLast.crdt,
            town.id!,
          );
          await _merge(defaultLast, defaultFacts);

          snapshots = await _captureConvergence(
            [defaultFirst, defaultLast],
            town: town,
            company: company,
          );
          defaultFirstFinalCity = await City.db.findById(
            defaultFirst.crdt,
            city.id!,
          );
          defaultLastFinalCity = await City.db.findById(
            defaultLast.crdt,
            city.id!,
          );
        });

        test(
          'then both observers accept the city cascade and repair the company onto the default.',
          () {
            _expectConvergence(
              snapshots,
              authoredFacts: [...childFacts, ...deleteFacts, ...defaultFacts],
              originalVisible: false,
              defaultVisible: true,
              companyTownId: _defaultTownId,
            );
            expect(cityBeforeDefault, isNotNull);
            expect(originalBeforeDefault, isNotNull);
            expect(defaultFirstFinalCity, isNull);
            expect(defaultLastFinalCity, isNull);
          },
        );
      });
    },
  );
}

Future<SyncNode> _node() async =>
    syncNode(await createAdditionalTestSession(), testSyncTables);

Future<CrdtMergeSet> _collect(SyncNode node) => node.sync
    .collectPendingChanges(
      node.raw,
      checkpointsByScopeUuid: {testCrdtUserId: const []},
    )
    .toList();

Future<void> _merge(SyncNode node, CrdtMergeSet facts) =>
    node.crdt.db.mergeChanges(facts, scopeId: testCrdtUserId);

// Compare full payloads, including HLCs, independently of collection order.
// A row/column can appear at several HLCs in the supplied author histories;
// collection exports only its winning fact, so compare observers directly
// and verify that every exported fact came from an author.
Map<String, dynamic> _payloads(CrdtMergeSet facts) => {
  for (final fact in facts)
    '${fact.tableName}|${fact.uuidRowId}|${fact.hlc}|${switch (fact) {
      CrdtMergeUpdate(:final columnName) => columnName,
      CrdtMergeDelete() => 'delete',
      CrdtMergeInsert() => 'insert',
    }}': jsonDecode(
      jsonEncode(fact.toJson()),
    ),
};

typedef _ObserverSnapshot = ({
  Town? original,
  Town? defaultTown,
  Company? company,
  Map<String, dynamic> facts,
});

Future<List<_ObserverSnapshot>> _captureConvergence(
  List<SyncNode> observers, {
  required Town town,
  required Company company,
}) async => [
  for (final observer in observers)
    (
      original: await Town.db.findById(observer.crdt, town.id!),
      defaultTown: await Town.db.findById(observer.crdt, _defaultTownId),
      company: await Company.db.findById(observer.crdt, company.id!),
      facts: _payloads(await _collect(observer)),
    ),
];

void _expectConvergence(
  List<_ObserverSnapshot> snapshots, {
  required CrdtMergeSet authoredFacts,
  required bool originalVisible,
  required bool defaultVisible,
  required UuidValue companyTownId,
}) {
  final authors = _payloads(authoredFacts);
  for (final snapshot in snapshots) {
    expect(snapshot.original, originalVisible ? isNotNull : isNull);
    expect(snapshot.defaultTown, defaultVisible ? isNotNull : isNull);
    expect(snapshot.company, isNotNull);
    expect(snapshot.company!.townId, companyTownId);
    expect(snapshot.facts, snapshots.first.facts);
    for (final entry in snapshot.facts.entries) {
      expect(
        entry.value,
        authors[entry.key],
        reason: 'Projection must preserve authored values and HLCs.',
      );
    }
  }
}
