import 'dart:convert';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

const _defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a company insert concurrent with its original town deletion,', () {
    late SyncNode childWriter;
    late SyncNode deleteWriter;
    late SyncNode defaultWriter;
    late Town town;
    late Company company;
    late CrdtMergeSet childFacts;
    late CrdtMergeSet deleteFacts;
    late CrdtMergeSet defaultFacts;

    setUpAll(() async {
      childWriter = await _node();
      deleteWriter = await _node();
      defaultWriter = await _node();

      town = Town(id: const Uuid().v7obj(), name: 'original');
      company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
      });
      await _merge(deleteWriter, await _collect(childWriter));
      await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
      });
      await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
      });
      childFacts = await _collect(childWriter);
      deleteFacts = await _collect(deleteWriter);

      await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(
          defaultWriter.offlineSync,
          Town(id: _defaultTownId, name: 'default'),
          transaction: tx,
        );
      });
      defaultFacts = await _collect(defaultWriter);
    });

    group(
      'when merging the default insert before the company and original deletion,',
      () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, defaultFacts);
          await _merge(observer, childFacts);
          await _merge(observer, deleteFacts);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town is hidden.', () {
          expect(visibleOriginal, isNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the default town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, _defaultTownId);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultFacts,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      },
    );

    group(
      'when merging the default insert after the company and original deletion,',
      () {
        late Town? beforeOriginal;
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, childFacts);
          await _merge(observer, deleteFacts);
          beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          await _merge(observer, defaultFacts);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town was visible before the default arrived.', () {
          expect(beforeOriginal, isNotNull);
        });

        test('then the original town is hidden.', () {
          expect(visibleOriginal, isNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the default town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, _defaultTownId);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultFacts,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      },
    );

    group('when merging all three authored histories in one batch,', () {
      late Town? visibleOriginal;
      late Town? visibleDefault;
      late Company? visibleCompany;
      late CrdtMergeSet exportedFacts;
      late CrdtMergeSet comparisonFacts;
      late Town? comparisonOriginal;
      late Town? comparisonDefault;
      late Company? comparisonCompany;

      setUpAll(() async {
        final observer = await _node();
        await _merge(observer, [...childFacts, ...deleteFacts, ...defaultFacts]);
        visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
        visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
        visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
        exportedFacts = await _collect(observer);
        final comparison = await _node();
        await _merge(comparison, defaultFacts);
        await _merge(comparison, childFacts);
        await _merge(comparison, deleteFacts);
        comparisonFacts = await _collect(comparison);
        comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
        comparisonDefault = await Town.db.findById(
          comparison.offlineSync,
          _defaultTownId,
        );
        comparisonCompany = await Company.db.findById(
          comparison.offlineSync,
          company.id!,
        );
      });

      test('then the original town is hidden.', () {
        expect(visibleOriginal, isNull);
      });

      test('then the default town is visible.', () {
        expect(visibleDefault, isNotNull);
      });

      test('then the company references the default town.', () {
        expect(visibleCompany, isNotNull);
        expect(visibleCompany!.townId, _defaultTownId);
      });

      test(
        'then town visibility and the company reference match separate deliveries.',
        () {
          expect(comparisonOriginal?.id, visibleOriginal?.id);
          expect(comparisonDefault?.id, visibleDefault?.id);
          expect(comparisonCompany?.id, visibleCompany?.id);
          expect(comparisonCompany?.townId, visibleCompany?.townId);
        },
      );

      test('then exported facts match separate deliveries.', () {
        expect(_payloads(exportedFacts), _payloads(comparisonFacts));
      });

      test('then every exported payload and HLC comes from an author.', () {
        final authoredPayloads = _payloads([
          ...childFacts,
          ...deleteFacts,
          ...defaultFacts,
        ]);
        for (final entry in _payloads(exportedFacts).entries) {
          expect(entry.value, authoredPayloads[entry.key]);
        }
      });

      test('then the exported child retains its original authored parent.', () {
        final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
          (fact) => fact.uuidRowId == company.id,
        );
        expect((childInsert.data as Company).townId, town.id);
      });
    });
  });

  group(
    'Given a company insert concurrent with deletions of its original town and the existing default town,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late Town town;
      late Town defaultTown;
      late Company company;
      late CrdtMergeSet initial;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late List<CrdtMergeDelete> defaultDelete;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();

        town = Town(id: const Uuid().v7obj(), name: 'original');
        defaultTown = Town(id: _defaultTownId, name: 'default');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
          await Town.db.insertRow(
            childWriter.offlineSync,
            defaultTown,
            transaction: tx,
          );
        });
        initial = await _collect(childWriter);
        await _merge(deleteWriter, initial);
        await _merge(defaultWriter, initial);
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
        });
        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(
            defaultWriter.offlineSync,
            defaultTown,
            transaction: tx,
          );
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        defaultDelete = (await _collect(
          defaultWriter,
        )).whereType<CrdtMergeDelete>().toList();
      });

      group('when merging the default deletion before the original deletion,', () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, childFacts);
          await _merge(observer, defaultDelete);
          await _merge(observer, deleteFacts);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultDelete]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town is visible.', () {
          expect(visibleOriginal, isNotNull);
        });

        test('then the default town is hidden.', () {
          expect(visibleDefault, isNull);
        });

        test('then the company references the original town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, town.id);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then the default town deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == _defaultTownId,
            ),
            hasLength(1),
          );
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultDelete,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });

      group('when merging only the default tombstone after the original deletion,', () {
        late UuidValue? beforeReference;
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, childFacts);
          await _merge(observer, deleteFacts);
          beforeReference = (await Company.db.findById(
            observer.offlineSync,
            company.id!,
          ))!.townId;
          await _merge(observer, defaultDelete);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultDelete]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test(
          'then the company referenced the default before its deletion arrived.',
          () {
            expect(beforeReference, _defaultTownId);
          },
        );
        test('then the original town is visible.', () {
          expect(visibleOriginal, isNotNull);
        });

        test('then the default town is hidden.', () {
          expect(visibleDefault, isNull);
        });

        test('then the company references the original town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, town.id);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then the default town deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == _defaultTownId,
            ),
            hasLength(1),
          );
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultDelete,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });
    },
  );

  group(
    'Given an authored restoration of a deleted default town and a company insert concurrent with its original town deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late Town town;
      late Town defaultTown;
      late Company company;
      late CrdtMergeSet deletedDefaultFacts;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet restoredDefaultFacts;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();

        town = Town(id: const Uuid().v7obj(), name: 'original');
        defaultTown = Town(id: _defaultTownId, name: 'default');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
        });
        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.insertRow(
            defaultWriter.offlineSync,
            defaultTown,
            transaction: tx,
          );
        });
        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(
            defaultWriter.offlineSync,
            defaultTown,
            transaction: tx,
          );
        });
        deletedDefaultFacts = await _collect(defaultWriter);
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);

        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.insertRow(
            defaultWriter.offlineSync,
            defaultTown,
            transaction: tx,
          );
        });
        restoredDefaultFacts = await _collect(defaultWriter);
      });

      group(
        'when merging the default restoration before the company and original deletion,',
        () {
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, deletedDefaultFacts);
            await _merge(observer, restoredDefaultFacts);
            await _merge(observer, childFacts);
            await _merge(observer, deleteFacts);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, deletedDefaultFacts);
            await _merge(comparison, [
              ...childFacts,
              ...deleteFacts,
              ...deletedDefaultFacts,
              ...restoredDefaultFacts,
            ]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the original town is hidden.', () {
            expect(visibleOriginal, isNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the default town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, _defaultTownId);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...deletedDefaultFacts,
              ...restoredDefaultFacts,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group(
        'when merging the default restoration after the company and original deletion,',
        () {
          late Town? beforeOriginal;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, deletedDefaultFacts);
            await _merge(observer, childFacts);
            await _merge(observer, deleteFacts);
            beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            await _merge(observer, restoredDefaultFacts);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, deletedDefaultFacts);
            await _merge(comparison, [
              ...childFacts,
              ...deleteFacts,
              ...deletedDefaultFacts,
              ...restoredDefaultFacts,
            ]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test(
            'then the original town was visible before the default restoration.',
            () {
              expect(beforeOriginal, isNotNull);
            },
          );
          test('then the original town is hidden.', () {
            expect(visibleOriginal, isNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the default town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, _defaultTownId);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...deletedDefaultFacts,
              ...restoredDefaultFacts,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );
    },
  );

  group(
    'Given a default town attached to a city and a company insert concurrent with deletion of that city and the original town,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late List<CrdtMergeDelete> deletions;
      late List<CrdtMergeDelete> cityDelete;
      late List<CrdtMergeDelete> townDelete;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();

        city = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.offlineSync, city, transaction: tx);
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        // Neither the default town nor the company exists on this author, so
        // these deletes author no child tombstones or FK rewrites.
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
          await City.db.deleteRow(deleteWriter.offlineSync, city, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deletions = (await _collect(
          deleteWriter,
        )).whereType<CrdtMergeDelete>().toList();
        cityDelete = deletions.where((fact) => fact.uuidRowId == city.id).toList();
        townDelete = deletions.where((fact) => fact.uuidRowId == town.id).toList();
      });

      group(
        'when merging the default city deletion before the original town deletion,',
        () {
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, cityDelete);
            await _merge(observer, townDelete);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deletions]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is hidden.', () {
            expect(visibleDefault, isNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then the default city is hidden.', () {
            expect(visibleCity, isNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == city.id,
              ),
              hasLength(1),
            );
          });

          test('then the original town deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == town.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([...childFacts, ...deletions]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group(
        'when merging only the default city deletion after the original town deletion,',
        () {
          late UuidValue? beforeReference;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, townDelete);
            beforeReference = (await Company.db.findById(
              observer.offlineSync,
              company.id!,
            ))!.townId;
            await _merge(observer, cityDelete);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deletions]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the company referenced the default before the city deletion.', () {
            expect(beforeReference, _defaultTownId);
          });

          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is hidden.', () {
            expect(visibleDefault, isNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then the default city is hidden.', () {
            expect(visibleCity, isNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == city.id,
              ),
              hasLength(1),
            );
          });

          test('then the original town deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == town.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([...childFacts, ...deletions]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );
    },
  );

  group(
    'Given concurrent deletions of the original town and default city followed by an authored city restoration,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet cityRestoration;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();

        city = City(id: const Uuid().v7obj(), name: 'default city');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.offlineSync, city, transaction: tx);
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
          await City.db.deleteRow(deleteWriter.offlineSync, city, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);

        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await City.db.insertRow(deleteWriter.offlineSync, city, transaction: tx);
        });
        cityRestoration = (await _collect(
          deleteWriter,
        )).where((fact) => fact.tableName == City.t.tableName).toList();
      });

      group(
        'when merging the default city restoration before the company and default town,',
        () {
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, deleteFacts);
            await _merge(observer, cityRestoration);
            await _merge(observer, childFacts);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, deleteFacts);
            await _merge(comparison, [
              ...childFacts,
              ...deleteFacts,
              ...cityRestoration,
            ]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the original town is hidden.', () {
            expect(visibleOriginal, isNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the default town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, _defaultTownId);
          });

          test('then the default city is visible.', () {
            expect(visibleCity, isNotNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...cityRestoration,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group(
        'when merging only the default city restoration after the company and deletions,',
        () {
          late Town? beforeDefault;
          late Town? beforeOriginal;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, deleteFacts);
            beforeDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            await _merge(observer, cityRestoration);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, deleteFacts);
            await _merge(comparison, [
              ...childFacts,
              ...deleteFacts,
              ...cityRestoration,
            ]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the default town was hidden before the city restoration.', () {
            expect(beforeDefault, isNull);
          });

          test('then the original town was visible before the city restoration.', () {
            expect(beforeOriginal, isNotNull);
          });

          test('then the original town is hidden.', () {
            expect(visibleOriginal, isNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the default town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, _defaultTownId);
          });

          test('then the default city is visible.', () {
            expect(visibleCity, isNotNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...cityRestoration,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );
    },
  );

  group(
    'Given two city deletions whose cascades hide the original and default towns and a restrict blocker hidden by the original city cascade,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
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

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();

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
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(
            childWriter.offlineSync,
            originalCity,
            transaction: tx,
          );
          await City.db.insertRow(
            childWriter.offlineSync,
            defaultCity,
            transaction: tx,
          );
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
          await Town.db.insertRow(
            childWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default', cityId: defaultCity.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
          await Organization.db.insertRow(
            childWriter.offlineSync,
            organization,
            transaction: tx,
          );
          await Person.db.insertRow(childWriter.offlineSync, blocker, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await City.db.deleteRow(
            deleteWriter.offlineSync,
            originalCity,
            transaction: tx,
          );
          await City.db.deleteRow(
            deleteWriter.offlineSync,
            defaultCity,
            transaction: tx,
          );
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

      group(
        'when merging the original city deletion before the default city deletion,',
        () {
          late City? beforeCity;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleOriginalCity;
          late City? visibleDefaultCity;
          late Organization? visibleOrganization;
          late Person? visibleBlocker;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, originalDelete);
            beforeCity = await City.db.findById(observer.offlineSync, originalCity.id!);
            await _merge(observer, defaultDelete);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleOriginalCity = await City.db.findById(
              observer.offlineSync,
              originalCity.id!,
            );
            visibleDefaultCity = await City.db.findById(
              observer.offlineSync,
              defaultCity.id!,
            );
            visibleOrganization = await Organization.db.findById(
              observer.offlineSync,
              organization.id!,
            );
            visibleBlocker = await Person.db.findById(
              observer.offlineSync,
              blocker.id!,
            );
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deletions]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test(
            'then the original city was hidden before the default city deletion.',
            () {
              expect(beforeCity, isNull);
            },
          );
          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then both city deletions are withdrawn.', () {
            expect(visibleOriginalCity, isNotNull);
            expect(visibleDefaultCity, isNotNull);
          });

          test('then the organization remains visible.', () {
            expect(visibleOrganization, isNotNull);
          });

          test('then the blocker retains its authored organization and city.', () {
            expect(visibleBlocker, isNotNull);
            expect(visibleBlocker!.organizationId, organization.id);
            expect(visibleBlocker!.cityId, defaultCity.id);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the original city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == originalCity.id,
              ),
              hasLength(1),
            );
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == defaultCity.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([...childFacts, ...deletions]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group(
        'when merging the default city deletion before the original city deletion,',
        () {
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleOriginalCity;
          late City? visibleDefaultCity;
          late Organization? visibleOrganization;
          late Person? visibleBlocker;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, defaultDelete);
            await _merge(observer, originalDelete);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleOriginalCity = await City.db.findById(
              observer.offlineSync,
              originalCity.id!,
            );
            visibleDefaultCity = await City.db.findById(
              observer.offlineSync,
              defaultCity.id!,
            );
            visibleOrganization = await Organization.db.findById(
              observer.offlineSync,
              organization.id!,
            );
            visibleBlocker = await Person.db.findById(
              observer.offlineSync,
              blocker.id!,
            );
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deletions]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then both city deletions are withdrawn.', () {
            expect(visibleOriginalCity, isNotNull);
            expect(visibleDefaultCity, isNotNull);
          });

          test('then the organization remains visible.', () {
            expect(visibleOrganization, isNotNull);
          });

          test('then the blocker retains its authored organization and city.', () {
            expect(visibleBlocker, isNotNull);
            expect(visibleBlocker!.organizationId, organization.id);
            expect(visibleBlocker!.cityId, defaultCity.id);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the original city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == originalCity.id,
              ),
              hasLength(1),
            );
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == defaultCity.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([...childFacts, ...deletions]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group('when merging both city deletions with the child facts in one batch,', () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late City? visibleOriginalCity;
        late City? visibleDefaultCity;
        late Organization? visibleOrganization;
        late Person? visibleBlocker;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, [...childFacts, ...deletions]);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          visibleOriginalCity = await City.db.findById(
            observer.offlineSync,
            originalCity.id!,
          );
          visibleDefaultCity = await City.db.findById(
            observer.offlineSync,
            defaultCity.id!,
          );
          visibleOrganization = await Organization.db.findById(
            observer.offlineSync,
            organization.id!,
          );
          visibleBlocker = await Person.db.findById(observer.offlineSync, blocker.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, childFacts);
          await _merge(comparison, originalDelete);
          await _merge(comparison, defaultDelete);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town is visible.', () {
          expect(visibleOriginal, isNotNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the original town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, town.id);
        });

        test('then both city deletions are withdrawn.', () {
          expect(visibleOriginalCity, isNotNull);
          expect(visibleDefaultCity, isNotNull);
        });

        test('then the organization remains visible.', () {
          expect(visibleOrganization, isNotNull);
        });

        test('then the blocker retains its authored organization and city.', () {
          expect(visibleBlocker, isNotNull);
          expect(visibleBlocker!.organizationId, organization.id);
          expect(visibleBlocker!.cityId, defaultCity.id);
        });

        test(
          'then town visibility and the company reference match separate deliveries.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match separate deliveries.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then the original city deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == originalCity.id,
            ),
            hasLength(1),
          );
        });

        test('then the default city deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == defaultCity.id,
            ),
            hasLength(1),
          );
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([...childFacts, ...deletions]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });
    },
  );

  group(
    'Given a nullable set-default child whose authored town has never arrived,',
    () {
      late SyncNode defaultWriter;
      late Town missingTown;
      late UniqueSetDefaultChild child;
      late Hlc childHlc;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet defaultFacts;

      setUpAll(() async {
        defaultWriter = await _node();

        missingTown = Town(id: const Uuid().v7obj(), name: 'missing');
        child = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'child',
          parentId: missingTown.id,
        );
        childHlc = Hlc.now(const Uuid().v7obj());
        childFacts = <CrdtMergeChange>[
          CrdtMergeInsert(
            uuidSpaceId: testCrdtUserId,
            tableName: UniqueSetDefaultChild.t.tableName,
            uuidRowId: child.id!,
            uuidNodeId: childHlc.nodeId,
            hlcDatetime: childHlc.datetime,
            hlcCounter: 0,
            data: child,
          ),
        ];
        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.insertRow(
            defaultWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default'),
            transaction: tx,
          );
        });
        defaultFacts = await _collect(defaultWriter);
      });

      group('when merging the default town before the child,', () {
        late UniqueSetDefaultChild? visibleChild;
        late Town? missingParent;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late UniqueSetDefaultChild? comparisonChild;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, defaultFacts);
          await _merge(observer, childFacts);
          visibleChild = await UniqueSetDefaultChild.db.findById(
            observer.offlineSync,
            child.id!,
          );
          missingParent = await Town.db.findById(observer.offlineSync, missingTown.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...defaultFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(
            comparison.offlineSync,
            missingTown.id!,
          );
          comparisonChild = await UniqueSetDefaultChild.db.findById(
            comparison.offlineSync,
            child.id!,
          );
        });

        test('then the child is visible on the default town.', () {
          expect(visibleChild, isNotNull);
          expect(visibleChild!.parentId, _defaultTownId);
        });

        test('then the authored parent is still missing.', () {
          expect(missingParent, isNull);
        });

        test('then the visible child and missing parent match batched delivery.', () {
          expect(comparisonOriginal?.id, missingParent?.id);
          expect(comparisonChild?.id, visibleChild?.id);
          expect(comparisonChild?.parentId, visibleChild?.parentId);
        });

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([...childFacts, ...defaultFacts]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == child.id,
          );
          expect((childInsert.data as UniqueSetDefaultChild).parentId, missingTown.id);
        });

        test('then both authored inserts are exported intact.', () {
          expect(_payloads(exportedFacts), _payloads([...childFacts, ...defaultFacts]));
        });
      });

      group('when merging only the default town after the child,', () {
        late UniqueSetDefaultChild? beforeChild;
        late UniqueSetDefaultChild? visibleChild;
        late Town? missingParent;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late UniqueSetDefaultChild? comparisonChild;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, childFacts);
          beforeChild = await UniqueSetDefaultChild.db.findById(
            observer.offlineSync,
            child.id!,
          );
          await _merge(observer, defaultFacts);
          visibleChild = await UniqueSetDefaultChild.db.findById(
            observer.offlineSync,
            child.id!,
          );
          missingParent = await Town.db.findById(observer.offlineSync, missingTown.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...defaultFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(
            comparison.offlineSync,
            missingTown.id!,
          );
          comparisonChild = await UniqueSetDefaultChild.db.findById(
            comparison.offlineSync,
            child.id!,
          );
        });

        test('then the child was hidden before the default arrived.', () {
          expect(beforeChild, isNull);
        });

        test('then the child is visible on the default town.', () {
          expect(visibleChild, isNotNull);
          expect(visibleChild!.parentId, _defaultTownId);
        });

        test('then the authored parent is still missing.', () {
          expect(missingParent, isNull);
        });

        test('then the visible child and missing parent match batched delivery.', () {
          expect(comparisonOriginal?.id, missingParent?.id);
          expect(comparisonChild?.id, visibleChild?.id);
          expect(comparisonChild?.parentId, visibleChild?.parentId);
        });

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([...childFacts, ...defaultFacts]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == child.id,
          );
          expect((childInsert.data as UniqueSetDefaultChild).parentId, missingTown.id);
        });

        test('then both authored inserts are exported intact.', () {
          expect(_payloads(exportedFacts), _payloads([...childFacts, ...defaultFacts]));
        });
      });
    },
  );

  group(
    'Given an observer retaining the original town after a concurrent company insert and town deletion without a default,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late Town? originalBeforeLocalDefault;
      late SyncNode observer;
      late CrdtMergeSet defaultFacts;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        observer = await _node();

        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        await _merge(observer, childFacts);
        await _merge(observer, deleteFacts);
        originalBeforeLocalDefault = await Town.db.findById(
          observer.offlineSync,
          town.id!,
        );
      });

      group('when inserting the default town locally on the observer,', () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          await observer.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Town.db.insertRow(
              observer.offlineSync,
              Town(id: _defaultTownId, name: 'default'),
              transaction: tx,
            );
          });
          defaultFacts = (await _collect(
            observer,
          )).where((fact) => fact.uuidRowId == _defaultTownId).toList();
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, defaultFacts);
          await _merge(comparison, childFacts);
          await _merge(comparison, deleteFacts);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town was visible before the local insert.', () {
          expect(originalBeforeLocalDefault, isNotNull);
        });

        test('then the original town is hidden.', () {
          expect(visibleOriginal, isNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the default town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, _defaultTownId);
        });

        test(
          'then town visibility and the company reference match default-first delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match default-first delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultFacts,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });
    },
  );

  group(
    'Given deletions of the original town and the default city with a concurrent person blocking that city deletion,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode blockerWriter;
      late City city;
      late Town town;
      late Company company;
      late Person blocker;
      late CrdtMergeSet initial;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet blockerFacts;
      late List<CrdtMergeDelete> cityDelete;
      late List<CrdtMergeDelete> originalDelete;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        blockerWriter = await _node();

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
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.offlineSync, city, transaction: tx);
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
        });
        initial = await _collect(childWriter);
        await _merge(deleteWriter, initial);
        await _merge(blockerWriter, initial);
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(
            childWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default', cityId: city.id),
            transaction: tx,
          );
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await City.db.deleteRow(deleteWriter.offlineSync, city, transaction: tx);
          await Town.db.deleteRow(deleteWriter.offlineSync, town, transaction: tx);
        });
        await blockerWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Person.db.insertRow(
            blockerWriter.offlineSync,
            blocker,
            transaction: tx,
          );
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        blockerFacts = (await _collect(
          blockerWriter,
        )).where((fact) => fact.uuidRowId == blocker.id).toList();
        originalDelete = deleteFacts
            .whereType<CrdtMergeDelete>()
            .where((fact) => fact.uuidRowId == town.id)
            .toList();
        cityDelete = deleteFacts
            .whereType<CrdtMergeDelete>()
            .where((fact) => fact.uuidRowId == city.id)
            .toList();
      });

      group('when merging the restrict blocker before the company and deletions,', () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late City? visibleCity;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, initial);
          await _merge(observer, blockerFacts);
          await _merge(observer, childFacts);
          await _merge(observer, deleteFacts);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          visibleCity = await City.db.findById(observer.offlineSync, city.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...blockerFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town is visible.', () {
          expect(visibleOriginal, isNotNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the original town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, town.id);
        });

        test('then the default city is visible.', () {
          expect(visibleCity, isNotNull);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then the original town deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == town.id,
            ),
            hasLength(1),
          );
        });

        test('then the default city deletion remains authored in the export.', () {
          expect(
            exportedFacts.whereType<CrdtMergeDelete>().where(
              (fact) => fact.uuidRowId == city.id,
            ),
            hasLength(1),
          );
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...blockerFacts,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });

      group(
        'when merging only the restrict blocker after the company and deletions,',
        () {
          late Town? beforeDefault;
          late Town? beforeOriginal;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, deleteFacts);
            beforeDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            await _merge(observer, blockerFacts);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deleteFacts, ...blockerFacts]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the default town was hidden before the blocker arrived.', () {
            expect(beforeDefault, isNull);
          });

          test('then the original town was visible before the blocker arrived.', () {
            expect(beforeOriginal, isNotNull);
          });

          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then the default city is visible.', () {
            expect(visibleCity, isNotNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the original town deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == town.id,
              ),
              hasLength(1),
            );
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == city.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...blockerFacts,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );

      group(
        'when merging the default city deletion and blocker together after the original deletion,',
        () {
          late Town? beforeOriginal;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, originalDelete);
            beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            await _merge(observer, [...cityDelete, ...blockerFacts]);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deleteFacts, ...blockerFacts]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test(
            'then the original town was hidden before the blocked city deletion.',
            () {
              expect(beforeOriginal, isNull);
            },
          );
          test('then the original town is visible.', () {
            expect(visibleOriginal, isNotNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the original town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, town.id);
          });

          test('then the default city is visible.', () {
            expect(visibleCity, isNotNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then the original town deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == town.id,
              ),
              hasLength(1),
            );
          });

          test('then the default city deletion remains authored in the export.', () {
            expect(
              exportedFacts.whereType<CrdtMergeDelete>().where(
                (fact) => fact.uuidRowId == city.id,
              ),
              hasLength(1),
            );
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...blockerFacts,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );
    },
  );

  group(
    'Given a city deletion blocked by a concurrent town and its company without a default,',
    () {
      late SyncNode childWriter;
      late SyncNode deleteWriter;
      late SyncNode defaultWriter;
      late City city;
      late Town town;
      late Company company;
      late CrdtMergeSet childFacts;
      late CrdtMergeSet deleteFacts;
      late CrdtMergeSet defaultFacts;

      setUpAll(() async {
        childWriter = await _node();
        deleteWriter = await _node();
        defaultWriter = await _node();

        city = City(id: const Uuid().v7obj(), name: 'original city');
        town = Town(id: const Uuid().v7obj(), name: 'original', cityId: city.id);
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(childWriter.offlineSync, city, transaction: tx);
        });
        await _merge(deleteWriter, await _collect(childWriter));
        await childWriter.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(childWriter.offlineSync, town, transaction: tx);
          await Company.db.insertRow(childWriter.offlineSync, company, transaction: tx);
        });
        await deleteWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await City.db.deleteRow(deleteWriter.offlineSync, city, transaction: tx);
        });
        await defaultWriter.offlineSync.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          await Town.db.insertRow(
            defaultWriter.offlineSync,
            Town(id: _defaultTownId, name: 'default'),
            transaction: tx,
          );
        });
        childFacts = await _collect(childWriter);
        deleteFacts = await _collect(deleteWriter);
        defaultFacts = await _collect(defaultWriter);
      });

      group('when merging the default town before the company and city deletion,', () {
        late Town? visibleOriginal;
        late Town? visibleDefault;
        late Company? visibleCompany;
        late City? visibleCity;
        late CrdtMergeSet exportedFacts;
        late CrdtMergeSet comparisonFacts;
        late Town? comparisonOriginal;
        late Town? comparisonDefault;
        late Company? comparisonCompany;

        setUpAll(() async {
          final observer = await _node();
          await _merge(observer, defaultFacts);
          await _merge(observer, childFacts);
          await _merge(observer, deleteFacts);
          visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
          visibleDefault = await Town.db.findById(observer.offlineSync, _defaultTownId);
          visibleCompany = await Company.db.findById(observer.offlineSync, company.id!);
          visibleCity = await City.db.findById(observer.offlineSync, city.id!);
          exportedFacts = await _collect(observer);
          final comparison = await _node();
          await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultFacts]);
          comparisonFacts = await _collect(comparison);
          comparisonOriginal = await Town.db.findById(comparison.offlineSync, town.id!);
          comparisonDefault = await Town.db.findById(
            comparison.offlineSync,
            _defaultTownId,
          );
          comparisonCompany = await Company.db.findById(
            comparison.offlineSync,
            company.id!,
          );
        });

        test('then the original town is hidden.', () {
          expect(visibleOriginal, isNull);
        });

        test('then the default town is visible.', () {
          expect(visibleDefault, isNotNull);
        });

        test('then the company references the default town.', () {
          expect(visibleCompany, isNotNull);
          expect(visibleCompany!.townId, _defaultTownId);
        });

        test('then the original city is hidden.', () {
          expect(visibleCity, isNull);
        });

        test(
          'then town visibility and the company reference match batched delivery.',
          () {
            expect(comparisonOriginal?.id, visibleOriginal?.id);
            expect(comparisonDefault?.id, visibleDefault?.id);
            expect(comparisonCompany?.id, visibleCompany?.id);
            expect(comparisonCompany?.townId, visibleCompany?.townId);
          },
        );

        test('then exported facts match batched delivery.', () {
          expect(_payloads(exportedFacts), _payloads(comparisonFacts));
        });

        test('then every exported payload and HLC comes from an author.', () {
          final authoredPayloads = _payloads([
            ...childFacts,
            ...deleteFacts,
            ...defaultFacts,
          ]);
          for (final entry in _payloads(exportedFacts).entries) {
            expect(entry.value, authoredPayloads[entry.key]);
          }
        });

        test('then the exported child retains its original authored parent.', () {
          final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
            (fact) => fact.uuidRowId == company.id,
          );
          expect((childInsert.data as Company).townId, town.id);
        });
      });

      group(
        'when merging only the default town after the company and city deletion,',
        () {
          late City? beforeCity;
          late Town? beforeOriginal;
          late Town? visibleOriginal;
          late Town? visibleDefault;
          late Company? visibleCompany;
          late City? visibleCity;
          late CrdtMergeSet exportedFacts;
          late CrdtMergeSet comparisonFacts;
          late Town? comparisonOriginal;
          late Town? comparisonDefault;
          late Company? comparisonCompany;

          setUpAll(() async {
            final observer = await _node();
            await _merge(observer, childFacts);
            await _merge(observer, deleteFacts);
            beforeCity = await City.db.findById(observer.offlineSync, city.id!);
            beforeOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            await _merge(observer, defaultFacts);
            visibleOriginal = await Town.db.findById(observer.offlineSync, town.id!);
            visibleDefault = await Town.db.findById(
              observer.offlineSync,
              _defaultTownId,
            );
            visibleCompany = await Company.db.findById(
              observer.offlineSync,
              company.id!,
            );
            visibleCity = await City.db.findById(observer.offlineSync, city.id!);
            exportedFacts = await _collect(observer);
            final comparison = await _node();
            await _merge(comparison, [...childFacts, ...deleteFacts, ...defaultFacts]);
            comparisonFacts = await _collect(comparison);
            comparisonOriginal = await Town.db.findById(
              comparison.offlineSync,
              town.id!,
            );
            comparisonDefault = await Town.db.findById(
              comparison.offlineSync,
              _defaultTownId,
            );
            comparisonCompany = await Company.db.findById(
              comparison.offlineSync,
              company.id!,
            );
          });

          test('then the city was visible before the default arrived.', () {
            expect(beforeCity, isNotNull);
          });

          test('then the original town was visible before the default arrived.', () {
            expect(beforeOriginal, isNotNull);
          });

          test('then the original town is hidden.', () {
            expect(visibleOriginal, isNull);
          });

          test('then the default town is visible.', () {
            expect(visibleDefault, isNotNull);
          });

          test('then the company references the default town.', () {
            expect(visibleCompany, isNotNull);
            expect(visibleCompany!.townId, _defaultTownId);
          });

          test('then the original city is hidden.', () {
            expect(visibleCity, isNull);
          });

          test(
            'then town visibility and the company reference match batched delivery.',
            () {
              expect(comparisonOriginal?.id, visibleOriginal?.id);
              expect(comparisonDefault?.id, visibleDefault?.id);
              expect(comparisonCompany?.id, visibleCompany?.id);
              expect(comparisonCompany?.townId, visibleCompany?.townId);
            },
          );

          test('then exported facts match batched delivery.', () {
            expect(_payloads(exportedFacts), _payloads(comparisonFacts));
          });

          test('then every exported payload and HLC comes from an author.', () {
            final authoredPayloads = _payloads([
              ...childFacts,
              ...deleteFacts,
              ...defaultFacts,
            ]);
            for (final entry in _payloads(exportedFacts).entries) {
              expect(entry.value, authoredPayloads[entry.key]);
            }
          });

          test('then the exported child retains its original authored parent.', () {
            final childInsert = exportedFacts.whereType<CrdtMergeInsert>().singleWhere(
              (fact) => fact.uuidRowId == company.id,
            );
            expect((childInsert.data as Company).townId, town.id);
          });
        },
      );
    },
  );
}

Future<SyncNode> _node() async => syncNode(
  await createAdditionalTestSession(),
  testSyncTables,
);

Future<CrdtMergeSet> _collect(SyncNode node) => node.sync
    .collectPendingChanges(
      node.raw,
      checkpointsBySpaceUuid: {testCrdtUserId: const []},
    )
    .toList();

Future<void> _merge(SyncNode node, CrdtMergeSet facts) =>
    node.offlineSync.db.mergeChanges(facts, spaceId: testCrdtUserId);

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
