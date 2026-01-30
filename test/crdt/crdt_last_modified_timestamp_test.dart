import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:drift_offline_sync/src/hlc/normalized.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/crdt_test_helper.dart';
import '../utils/database.dart';

void main() {
  group('Given CRDT for an empty database', () {
    late OfflineSyncCrdt crdt;

    setUp(() async {
      (crdt, _, _) = database.crdtContext;
    });

    test('when getting the last modified timestamp '
        'then it returns null since the database is empty.', () async {
      final lastModified = await crdt.getLastModified();
      expect(lastModified, isNull);
    });
  });

  group('Given CRDT for a database with data', () {
    late OfflineSyncCrdt crdt;
    late CrdtDatabase crdtDb;
    late String nodeId;
    late Hlc createdHlc;

    setUp(() async {
      await database.managers.todosTable.create(
        (t) => t(content: 'test', targetDate: Value(DateTime.now())),
      );

      (crdt, crdtDb, nodeId) = database.crdtContext;

      final allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
      createdHlc = await CrdtTestHelper.getHlc(crdtDb, allCrdtDataEntries.first);
    });

    group('when getting the last modified timestamp', () {
      test('without any filters '
          'then it returns the HLC timestamp of the created data.', () async {
        final lastModified = await crdt.getLastModified();
        expect(lastModified, equals(createdHlc));
      });

      test('with onlyNodeId set to the nodeId '
          'then it returns the HLC timestamp of the created data.', () async {
        final lastModified = await crdt.getLastModified(onlyNodeId: nodeId);
        expect(lastModified, equals(createdHlc));
      });

      test('with onlyNodeId set to a different nodeId '
          'then it returns null.', () async {
        final lastModified = await crdt.getLastModified(onlyNodeId: 'other-node');
        expect(lastModified, isNull);
      });

      test('with exceptNodeId set to the nodeId '
          'then it returns null.', () async {
        final lastModified = await crdt.getLastModified(exceptNodeId: nodeId);
        expect(lastModified, isNull);
      });

      test('with exceptNodeId set to a different nodeId '
          'then it returns the HLC timestamp of the created data.', () async {
        final lastModified = await crdt.getLastModified(exceptNodeId: 'other-node');
        expect(lastModified, equals(createdHlc));
      });
    });
  });
}
