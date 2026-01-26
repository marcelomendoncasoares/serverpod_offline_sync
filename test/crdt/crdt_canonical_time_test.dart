import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_offline_first/src/hlc/stateful.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';

void main() {
  group('Given CRDT for an empty database', () {
    late OfflineSyncCrdt crdt;
    late String nodeId;

    setUp(() async {
      (crdt, _, nodeId) = database.crdtContext;
    });

    test('when getting the canonical time '
        'then it returns Hlc.zero for the nodeId.', () async {
      expect(crdt.canonicalTime, equals(Hlc.zero(nodeId)));
    });
  });

  group('Given CRDT for a database with data', () {
    late OfflineSyncCrdt crdt;
    late CrdtDatabase crdtDb;
    late Hlc createdHlc;

    setUp(() async {
      await database.managers.todosTable.create(
        (t) => t(content: 'test', targetDate: Value(DateTime.now())),
      );

      (crdt, crdtDb, _) = database.crdtContext;

      final allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
      createdHlc = allCrdtDataEntries.first.hlcTimestamp;
    });

    test('when getting the canonical time '
        'then it returns the HLC timestamp of the created data.', () async {
      expect(crdt.canonicalTime, equals(createdHlc));
    });
  });

  group('Given CRDT for a database with data and a new data entry', () {
    late OfflineSyncCrdt crdt;

    setUp(() async {
      await database.managers.todosTable.create(
        (t) => t(content: 'test', targetDate: Value(DateTime.now())),
      );

      (crdt, _, _) = database.crdtContext;

      await database.managers.todosTable.create(
        (t) => t(content: 'test2', targetDate: Value(DateTime.now())),
      );
    });

    test('when getting the canonical time '
        'then the canonical time matches the cached HLC for the nodeId.', () async {
      expect(
        crdt.canonicalTime,
        equals(StatefulHlc.cached(crdt.userId, crdt.nodeId).lastHlc),
      );
    });
  });
}
