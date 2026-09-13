import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late Client client;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('structured_sync_');
    client = Client('http://localhost:8081/');
  });
  tearDownAll(() async {
    await directory.delete(recursive: true);
  });

  Future<({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync})>
  node() async {
    final raw = await client.createSession('${directory.path}/${const Uuid().v7()}.db');
    addTearDown(raw.close);
    final crdt = CrdtDatabaseSession.wraps(raw, syncTables: [Types.t]);
    await crdt.db.initialize();
    return (
      raw: raw,
      crdt: crdt,
      sync: CrdtSync(
        syncTables: [Types.t],
        serializationManager: raw.db.serializationManager,
      ),
    );
  }

  Types row({
    required SyncDocument? json,
    required SyncDocument? jsonb,
    required List<int>? numbers,
  }) => Types(
    aBool: true,
    aDateTime: DateTime.utc(2026, 9, 13),
    aText: 'Structured row',
    anInt: 7,
    anInt64: BigInt.from(8),
    aReal: 1.25,
    aBlob: Uint8List.fromList([0, 123, 255]).buffer.asByteData(),
    jsonDocument: json,
    jsonbDocument: jsonb,
    jsonbNumbers: numbers,
  );

  List<CrdtMergeChange> throughWire(
    List<CrdtMergeChange> changes,
    SerializationManager protocol,
  ) => [
    for (final change in changes)
      protocol.decodeWithType(protocol.encodeWithTypeForProtocol(change))!
          as CrdtMergeChange,
  ];

  group(
    'Given a SQLite row with JSON and JSONB documents, a JSONB list, and binary data,',
    () {
      late UuidValue actor;
      late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync})
      source;
      late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync})
      target;
      late Types inserted;
      setUpAll(() async {
        actor = const Uuid().v7obj();
        source = await node();
        target = await node();
        inserted = row(
          json: SyncDocument(title: 'JSON café', enabled: true, numbers: [1, 2]),
          jsonb: SyncDocument(title: 'JSONB ☕', enabled: false, numbers: [-3, 4]),
          numbers: [0, 5, 100],
        );
        await source.crdt.db.transactionForUser(actor, (tx) async {
          inserted = await Types.db.insertRow(source.crdt, inserted, transaction: tx);
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
                  checkpointsByScopeUuid: {actor: const []},
                )
                .toList();
            collected = changes.inserts.single.data as Types;
            await target.crdt.db.mergeChanges(
              throughWire(changes, client.serializationManager),
              scopeId: actor,
            );
            merged = (await Types.db.findById(target.crdt, inserted.id!))!;
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

  group('Given a previously synchronized row with JSON and JSONB documents,', () {
    late UuidValue actor;
    late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync}) source;
    late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync}) target;
    late Types inserted;
    setUpAll(() async {
      actor = const Uuid().v7obj();
      source = await node();
      target = await node();
      inserted = row(
        json: SyncDocument(title: 'Original JSON', enabled: true, numbers: [1]),
        jsonb: SyncDocument(title: 'Original JSONB', enabled: false, numbers: [2]),
        numbers: [3],
      );
      await source.crdt.db.transactionForUser(actor, (tx) async {
        inserted = await Types.db.insertRow(source.crdt, inserted, transaction: tx);
      });
      final changes = await source.sync
          .collectPendingChanges(source.raw, checkpointsByScopeUuid: {actor: const []})
          .toList();
      await target.crdt.db.mergeChanges(
        throughWire(changes, client.serializationManager),
        scopeId: actor,
      );
    });
    group('when the documents and list are edited and synchronized,', () {
      late Types merged;
      late Map<String, dynamic> updates;
      setUpAll(() async {
        await source.crdt.db.transactionForUser(actor, (tx) async {
          await Types.db.updateRow(
            source.crdt,
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
              checkpointsByScopeUuid: {actor: const []},
            )
            .toList();
        updates = {
          for (final change in changes.updates) change.columnName: change.value,
        };
        await target.crdt.db.mergeChanges(
          throughWire(changes, client.serializationManager),
          scopeId: actor,
        );
        merged = (await Types.db.findById(target.crdt, inserted.id!))!;
      });
      test('then document updates use their generated model type.', () {
        expect(updates['jsonDocument'], isA<SyncDocument>());
        expect(updates['jsonbDocument'], isA<SyncDocument>());
        expect(
          merged.jsonDocument!.toJson(),
          SyncDocument(title: 'Edited JSON', enabled: false, numbers: [4, 5]).toJson(),
        );
        expect(
          merged.jsonbDocument!.toJson(),
          SyncDocument(title: 'Edited JSONB', enabled: true, numbers: [6, 7]).toJson(),
        );
      });
      test('then a generic list update retains its typed values.', () {
        expect(updates['jsonbNumbers'], [8, 9]);
        expect(merged.jsonbNumbers, [8, 9]);
      });
    });
  });

  group('Given synchronized JSON and JSONB documents and a structured list,', () {
    late UuidValue actor;
    late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync}) source;
    late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync}) target;
    late Types inserted;
    setUpAll(() async {
      actor = const Uuid().v7obj();
      source = await node();
      target = await node();
      await source.crdt.db.transactionForUser(actor, (tx) async {
        inserted = await Types.db.insertRow(
          source.crdt,
          row(
            json: SyncDocument(title: 'JSON', enabled: true, numbers: [1]),
            jsonb: SyncDocument(title: 'JSONB', enabled: false, numbers: [2]),
            numbers: [3],
          ),
          transaction: tx,
        );
      });
      final changes = await source.sync
          .collectPendingChanges(
            source.raw,
            checkpointsByScopeUuid: {actor: const []},
          )
          .toList();
      await target.crdt.db.mergeChanges(
        throughWire(changes, client.serializationManager),
        scopeId: actor,
      );
    });
    group('when all structured values are cleared and synchronized,', () {
      late Types merged;
      late Map<String, dynamic> updates;
      setUpAll(() async {
        await source.crdt.db.transactionForUser(actor, (tx) async {
          await Types.db.updateRow(
            source.crdt,
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
              checkpointsByScopeUuid: {actor: const []},
            )
            .toList();
        updates = {
          for (final update in changes.updates) update.columnName: update.value,
        };
        await target.crdt.db.mergeChanges(
          throughWire(changes, client.serializationManager),
          scopeId: actor,
        );
        merged = (await Types.db.findById(target.crdt, inserted.id!))!;
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
  });

  group('Given a SQLite row with absent structured values,', () {
    late UuidValue actor;
    late ({ClientDatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync}) source;
    setUpAll(() async {
      actor = const Uuid().v7obj();
      source = await node();
      await source.crdt.db.transactionForUser(actor, (tx) async {
        await Types.db.insertRow(
          source.crdt,
          row(json: null, jsonb: null, numbers: null),
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
              checkpointsByScopeUuid: {actor: const []},
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
