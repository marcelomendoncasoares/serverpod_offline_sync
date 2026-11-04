import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given more than one payload batch in each of two spaces and an excluded space,',
    () {
      late SyncNode author;
      late UuidValue first;
      late UuidValue second;
      late Map<UuidValue, (UuidValue, String)> expected;

      setUpAll(() async {
        author = await syncNode(await createAdditionalTestSession(), [
          Person.t,
          City.t,
        ]);
        first = const Uuid().v7obj();
        second = const Uuid().v7obj();
        final excluded = const Uuid().v7obj();
        expected = {};
        for (final space in [first, second, excluded]) {
          final people = [
            for (var index = 0; index < 105; index++)
              Person(id: const Uuid().v7obj(), name: '$space/$index'),
          ];
          if (space != excluded) {
            expected.addEntries([
              for (final row in people) MapEntry(row.id!, (space, row.name)),
            ]);
          }
          await author.offlineSync.db.transactionForUser(space, (tx) async {
            await Person.db.insert(author.offlineSync, people, transaction: tx);
            await City.db.insertRow(
              author.offlineSync,
              City(id: const Uuid().v7obj(), name: '$space/city'),
              transaction: tx,
            );
          });
        }
      });

      group('when the two requested spaces are collected in one snapshot,', () {
        late List<CrdtMergeInsert> inserts;
        late int databaseCalls;

        setUpAll(() async {
          final counting = QueryCountingDatabase(author.raw.db);
          final collector = OfflineSyncDatabaseSession(
            counting,
            syncTables: [Person.t, City.t],
          );
          await collector.db.initialize();
          counting.queryCount = 0;

          final changes = await author.sync
              .collectPendingChanges(
                collector,
                checkpointsBySpaceUuid: {first: 0, second: 0},
              )
              .toList();
          inserts = changes.cast<CrdtMergeInsert>();
          databaseCalls = counting.queryCount;
        });

        test('then every requested person keeps its payload and owning space.', () {
          final actual = {
            for (final insert in inserts)
              if (insert.data case final Person person)
                person.id!: (insert.uuidSpaceId, person.name),
          };
          expect(actual, expected);
          expect(inserts, hasLength(212));
        });

        test('then rows from other tables retain their own payloads.', () {
          expect(
            {
              for (final insert in inserts)
                if (insert.data case final City city) insert.uuidSpaceId: city.name,
            },
            {first: '$first/city', second: '$second/city'},
          );
        });

        test(
          'then collection uses fewer database calls than individual row reads.',
          () {
            expect(databaseCalls, lessThan(20));
          },
        );
      });
    },
  );
}
