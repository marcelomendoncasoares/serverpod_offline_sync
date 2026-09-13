import 'dart:typed_data';

import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a SQLite child row with JSON and JSONB documents, a JSONB list, and binary data,',
    () {
      late SyncNode source;
      late SyncNode target;
      late Types inserted;

      setUpAll(() async {
        source = await syncNode(await createAdditionalTestSession(), [Types.t]);
        target = await syncNode(await createAdditionalTestSession(), [Types.t]);

        await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          final parent = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: null,
              jsonbDocument: null,
              jsonbNumbers: null,
            ),
            transaction: tx,
          );

          inserted = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: SyncDocument(
                title: 'JSON café',
                enabled: true,
                numbers: [1, 2],
              ),
              jsonbDocument: SyncDocument(
                title: 'JSONB ☕',
                enabled: false,
                numbers: [-3, 4],
              ),
              jsonbNumbers: [0, 5, 100],
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });
      });

      group(
        'when its pending changes are collected and merged into another SQLite database,',
        () {
          late Types collected;
          late Types merged;

          setUpAll(() async {
            final changes = await source.sync
                .collectPendingChanges(
                  source.raw,
                  checkpointsBySpaceUuid: {testCrdtUserId: const []},
                )
                .toList();

            collected =
                changes.inserts
                        .singleWhere((change) => change.uuidRowId == inserted.id)
                        .data
                    as Types;

            final protocol = source.raw.db.serializationManager;
            await target.offlineSync.db.mergeChanges(
              [
                for (final change in changes)
                  protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
                      as CrdtMergeChange,
              ],
              spaceId: testCrdtUserId,
            );

            merged = (await Types.db.findById(target.offlineSync, inserted.id!))!;
          });

          test('then both document encodings retain their typed fields.', () {
            expect(collected.jsonDocument!.toJson(), inserted.jsonDocument!.toJson());
            expect(collected.jsonbDocument!.toJson(), inserted.jsonbDocument!.toJson());
            expect(merged.jsonDocument!.toJson(), inserted.jsonDocument!.toJson());
            expect(merged.jsonbDocument!.toJson(), inserted.jsonbDocument!.toJson());
          });

          test('then the structured list retains every integer.', () {
            expect(collected.jsonbNumbers, [0, 5, 100]);
            expect(merged.jsonbNumbers, [0, 5, 100]);
          });

          test('then binary data remains binary instead of being decoded as JSON.', () {
            expect(
              collected.aBlob.buffer.asUint8List(
                collected.aBlob.offsetInBytes,
                collected.aBlob.lengthInBytes,
              ),
              [0, 123, 255],
            );
            expect(
              merged.aBlob.buffer.asUint8List(
                merged.aBlob.offsetInBytes,
                merged.aBlob.lengthInBytes,
              ),
              [0, 123, 255],
            );
          });
        },
      );
    },
  );

  group(
    'Given a synchronized child row with JSON and JSONB documents and a JSONB list,',
    () {
      late SyncNode source;
      late SyncNode target;
      late Types inserted;

      setUpAll(() async {
        source = await syncNode(await createAdditionalTestSession(), [Types.t]);
        target = await syncNode(await createAdditionalTestSession(), [Types.t]);

        await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          final parent = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: null,
              jsonbDocument: null,
              jsonbNumbers: null,
            ),
            transaction: tx,
          );

          inserted = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: SyncDocument(
                title: 'Original JSON',
                enabled: true,
                numbers: [1],
              ),
              jsonbDocument: SyncDocument(
                title: 'Original JSONB',
                enabled: false,
                numbers: [2],
              ),
              jsonbNumbers: [3],
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });

        final changes = await source.sync
            .collectPendingChanges(
              source.raw,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final protocol = source.raw.db.serializationManager;
        await target.offlineSync.db.mergeChanges(
          [
            for (final change in changes)
              protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
                  as CrdtMergeChange,
          ],
          spaceId: testCrdtUserId,
        );
      });

      group('when the documents and list are edited and synchronized,', () {
        late Types merged;
        late Map<String, dynamic> updates;

        setUpAll(() async {
          await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Types.db.updateRow(
              source.offlineSync,
              inserted.copyWith(
                jsonDocument: SyncDocument(
                  title: 'Edited JSON',
                  enabled: false,
                  numbers: [4, 5],
                ),
                jsonbDocument: SyncDocument(
                  title: 'Edited JSONB',
                  enabled: true,
                  numbers: [6, 7],
                ),
                jsonbNumbers: [8, 9],
              ),
              columns: (t) => [t.jsonDocument, t.jsonbDocument, t.jsonbNumbers],
              transaction: tx,
            );
          });

          final changes = await source.sync
              .collectPendingChanges(
                source.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();

          updates = {
            for (final change in changes.updates) change.columnName: change.value,
          };

          final protocol = source.raw.db.serializationManager;
          await target.offlineSync.db.mergeChanges(
            [
              for (final change in changes)
                protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
                    as CrdtMergeChange,
            ],
            spaceId: testCrdtUserId,
          );

          merged = (await Types.db.findById(target.offlineSync, inserted.id!))!;
        });

        test('then document updates use their generated model type.', () {
          expect(updates['jsonDocument'], isA<SyncDocument>());
          expect(updates['jsonbDocument'], isA<SyncDocument>());
          expect(
            merged.jsonDocument!.toJson(),
            SyncDocument(
              title: 'Edited JSON',
              enabled: false,
              numbers: [4, 5],
            ).toJson(),
          );
          expect(
            merged.jsonbDocument!.toJson(),
            SyncDocument(
              title: 'Edited JSONB',
              enabled: true,
              numbers: [6, 7],
            ).toJson(),
          );
        });

        test('then a generic list update retains its typed values.', () {
          expect(updates['jsonbNumbers'], [8, 9]);
          expect(merged.jsonbNumbers, [8, 9]);
        });
      });
    },
  );

  group(
    'Given a synchronized child row with populated JSON and JSONB documents and a JSONB list,',
    () {
      late SyncNode source;
      late SyncNode target;
      late Types inserted;

      setUpAll(() async {
        source = await syncNode(await createAdditionalTestSession(), [Types.t]);
        target = await syncNode(await createAdditionalTestSession(), [Types.t]);

        await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          final parent = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: null,
              jsonbDocument: null,
              jsonbNumbers: null,
            ),
            transaction: tx,
          );

          inserted = await Types.db.insertRow(
            source.offlineSync,
            Types(
              aBool: true,
              aDateTime: DateTime.utc(2026, 9, 13),
              aText: 'Structured row',
              anInt: 7,
              anInt64: BigInt.from(8),
              aReal: 1.25,
              aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
              jsonDocument: SyncDocument(title: 'JSON', enabled: true, numbers: [1]),
              jsonbDocument: SyncDocument(title: 'JSONB', enabled: false, numbers: [2]),
              jsonbNumbers: [3],
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });

        final changes = await source.sync
            .collectPendingChanges(
              source.raw,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final protocol = source.raw.db.serializationManager;
        await target.offlineSync.db.mergeChanges(
          [
            for (final change in changes)
              protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
                  as CrdtMergeChange,
          ],
          spaceId: testCrdtUserId,
        );
      });

      group('when all structured values are cleared and synchronized,', () {
        late Types merged;
        late Map<String, dynamic> updates;

        setUpAll(() async {
          await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Types.db.updateRow(
              source.offlineSync,
              inserted.copyWith(
                jsonDocument: null,
                jsonbDocument: null,
                jsonbNumbers: null,
              ),
              columns: (t) => [t.jsonDocument, t.jsonbDocument, t.jsonbNumbers],
              transaction: tx,
            );
          });

          final changes = await source.sync
              .collectPendingChanges(
                source.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();

          updates = {
            for (final update in changes.updates) update.columnName: update.value,
          };

          final protocol = source.raw.db.serializationManager;
          await target.offlineSync.db.mergeChanges(
            [
              for (final change in changes)
                protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
                    as CrdtMergeChange,
            ],
            spaceId: testCrdtUserId,
          );

          merged = (await Types.db.findById(target.offlineSync, inserted.id!))!;
        });

        test('then each clear is transmitted as an explicit null.', () {
          expect(updates, {
            'jsonDocument': null,
            'jsonbDocument': null,
            'jsonbNumbers': null,
          });
        });

        test('then the receiving row no longer contains any structured value.', () {
          expect(merged.jsonDocument, isNull);
          expect(merged.jsonbDocument, isNull);
          expect(merged.jsonbNumbers, isNull);
        });
      });
    },
  );

  group('Given a SQLite row with absent structured values,', () {
    late SyncNode source;

    setUpAll(() async {
      source = await syncNode(await createAdditionalTestSession(), [Types.t]);

      await source.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Types.db.insertRow(
          source.offlineSync,
          Types(
            aBool: true,
            aDateTime: DateTime.utc(2026, 9, 13),
            aText: 'Structured row',
            anInt: 7,
            anInt64: BigInt.from(8),
            aReal: 1.25,
            aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
            jsonDocument: null,
            jsonbDocument: null,
            jsonbNumbers: null,
          ),
          transaction: tx,
        );
      });
    });

    group('when its pending insert is collected,', () {
      late Types collected;

      setUpAll(() async {
        final changes = await source.sync
            .collectPendingChanges(
              source.raw,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        collected = changes.inserts.single.data as Types;
      });

      test('then null remains absent for every structured encoding.', () {
        expect(collected.jsonDocument, isNull);
        expect(collected.jsonbDocument, isNull);
        expect(collected.jsonbNumbers, isNull);
      });
    });
  });
}
