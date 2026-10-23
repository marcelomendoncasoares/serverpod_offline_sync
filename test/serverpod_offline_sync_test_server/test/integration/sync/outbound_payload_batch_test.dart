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

  group('Given pending edits and inserts across two spaces and an excluded space,', () {
    late SyncNode author;
    late UuidValue first;
    late UuidValue second;
    late Map<UuidValue, int> checkpoints;
    late Map<(UuidValue, String, UuidValue, String), Object?> expected;
    late Map<UuidValue, UuidValue> inserted;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t, City.t]);
      first = const Uuid().v7obj();
      second = const Uuid().v7obj();
      final excluded = const Uuid().v7obj();
      checkpoints = {};
      expected = {};
      inserted = {};
      for (final space in [first, second, excluded]) {
        final city = City(id: const Uuid().v7obj(), name: 'before');
        final people = [
          for (var index = 0; index < 105; index++)
            Person(id: const Uuid().v7obj(), name: 'before', surname: 'before'),
        ];
        await author.offlineSync.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(author.offlineSync, city, transaction: tx);
          await Person.db.insert(author.offlineSync, people, transaction: tx);
        });
        final initial = await author.sync.captureChanges(
          author.raw,
          checkpointsBySpaceUuid: {space: 0},
        );
        if (space != excluded) {
          checkpoints[space] = initial.checkpoints.single.revision;
        }

        final newPerson = Person(
          id: const Uuid().v7obj(),
          name: '$space/new',
          cityId: city.id,
        );
        final edits = [
          for (final (index, row) in people.indexed)
            row.copyWith(name: '$space/edited/$index', surname: null, cityId: city.id),
        ];
        await author.offlineSync.db.transactionForUser(space, (tx) async {
          await Person.db.update(
            author.offlineSync,
            edits,
            columns: (t) => [t.name, t.surname, t.cityId],
            transaction: tx,
          );
          await City.db.updateRow(
            author.offlineSync,
            city.copyWith(name: '$space/edited city'),
            columns: (t) => [t.name],
            transaction: tx,
          );
          await Person.db.insertRow(author.offlineSync, newPerson, transaction: tx);
        });
        if (space != excluded) {
          for (final person in edits) {
            expected[(space, 'person', person.id!, 'name')] = person.name;
            expected[(space, 'person', person.id!, 'surname')] = null;
            expected[(space, 'person', person.id!, 'cityId')] = city.id;
          }
          expected[(space, 'city', city.id!, 'name')] = '$space/edited city';
          inserted[newPerson.id!] = space;
        }
      }
    });

    group('when both requested deltas are captured,', () {
      late List<CrdtMergeChange> changes;
      late int databaseCalls;

      setUpAll(() async {
        final counting = QueryCountingDatabase(author.raw.db);
        final collector = OfflineSyncDatabaseSession(
          counting,
          syncTables: [Person.t, City.t],
        );
        await collector.db.initialize();
        counting.queryCount = 0;
        changes = await author.sync
            .collectPendingChanges(
              collector,
              checkpointsBySpaceUuid: checkpoints,
            )
            .toList();
        databaseCalls = counting.queryCount;
      });

      test('then each updated field keeps its exact value, row and space.', () {
        expect({
          for (final change in changes.whereType<CrdtMergeUpdate>())
            (change.uuidSpaceId, change.tableName, change.uuidRowId, change.columnName):
                change.value,
        }, expected);
        expect(changes.whereType<CrdtMergeUpdate>(), hasLength(expected.length));
      });

      test('then inserts sharing the payload batches retain their full rows.', () {
        final inserts = changes.whereType<CrdtMergeInsert>().toList();
        expect({
          for (final insert in inserts) insert.uuidRowId: insert.uuidSpaceId,
        }, inserted);
        for (final insert in inserts) {
          final person = insert.data as Person;
          expect(person.name, '${insert.uuidSpaceId}/new');
          expect(person.cityId, isNotNull);
        }
      });

      test('then payload collection does not query once per changed field.', () {
        expect(databaseCalls, lessThan(25));
      });
    });
  });
}
