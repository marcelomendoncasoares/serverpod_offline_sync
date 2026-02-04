import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:drift_offline_sync/src/hlc/stateful.dart';
import 'package:test/test.dart';

import 'utils/crdt_context.dart';
import 'utils/database.dart';
import 'utils/executor.dart';
import 'utils/user.dart';

void main() {
  group(
    'Given a database opened with a CRDT control table having initial HLC from same user and node',
    () {
      late Hlc initialHlc;

      setUp(() async {
        initialHlc = Hlc.now(testNodeId);
        await testDatabaseFixture(initialHlc: initialHlc);
      });

      test('when retrieving the cached HLC '
          'then the HLC for the node is the initial HLC.', () async {
        expect(StatefulHlc.cached(testUserId, testNodeId).lastHlc, equals(initialHlc));
      });
    },
  );

  group(
    'Given a database opened with a CRDT control table having initial HLC from same user and different node',
    () {
      late Hlc initialHlc;

      setUp(() async {
        initialHlc = Hlc.now('other_node_id');
        await testDatabaseFixture(initialHlc: initialHlc);
      });

      test(
        'when retrieving the cached HLC '
        'then the HLC for the node is the initial HLC for the requested node.',
        () async {
          final expectedHlc = initialHlc.copyWith(nodeId: testNodeId);
          expect(
            StatefulHlc.cached(testUserId, testNodeId).lastHlc,
            equals(expectedHlc),
          );
        },
      );
    },
  );

  group(
    'Given a database opened with a CRDT control table having initial HLC from different user and node',
    () {
      late Hlc initialHlc;

      setUp(() async {
        initialHlc = Hlc.now('other_node_id');
        await testDatabaseFixture(initialHlc: initialHlc);
      });

      test('when retrieving the cached HLC '
          'then the HLC for the node is zero for the requested node.', () async {
        final expectedHlc = Hlc.zero(testNodeId);
        expect(
          StatefulHlc.cached('other_user_id', testNodeId).lastHlc,
          equals(expectedHlc),
        );
      });
    },
  );
}

Future<TodoDb> testDatabaseFixture({
  required Hlc initialHlc,
  String? userId,
}) async {
  setTestFileExecutor();
  final database = TodoDb(testExecutor);

  final (crdt, crdtDb, nodeId) = database.crdtContext;

  await crdtDb.managers.crdtDataTable.create(
    (t) => t(
      userId: userId ?? crdt.userId,
      tblName: 'todos',
      columnName: 'content',
      rowId: '1',
      hlcTimestamp: initialHlc,
    ),
  );

  await database.close();
  await testExecutor.close();

  setTestFileExecutor();
  return TodoDb(testExecutor);
}
