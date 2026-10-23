import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/merge_domain_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL authored domain values]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: directory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 8,
      ),
    ),
    (sessions, _) {
      late Session raw;
      late OfflineSyncDatabaseSession merging;

      setUpAll(() async {
        raw = sessions.build();
        merging = OfflineSyncDatabaseSession.wraps(raw, syncTables: server.syncTables);
        await merging.db.initialize();
      });

      group('Given 105 people, a city and a person owned by another space,', () {
        late UuidValue user;
        late List<server.Person> people;
        late server.City city;
        late server.Person other;
        late List<CrdtMergeChange> changes;
        late Map<UuidValue, (String, String?)> expected;

        setUpAll(() async {
          user = const Uuid().v7obj();
          people = [
            for (var index = 0; index < 105; index++)
              server.Person(
                id: const Uuid().v7obj(),
                name: 'before $index',
                surname: 'keep $index',
              ),
          ];
          city = server.City(id: const Uuid().v7obj(), name: 'before city');
          other = server.Person(
            id: const Uuid().v7obj(),
            name: 'other space',
            surname: 'untouched',
          );
          await merging.db.transactionForUser(user, (tx) async {
            await server.Person.db.insert(merging, people, transaction: tx);
            await server.City.db.insertRow(merging, city, transaction: tx);
          });
          await merging.db.transactionForUser(const Uuid().v7obj(), (tx) async {
            await server.Person.db.insertRow(merging, other, transaction: tx);
          });
          final clock = await _nextClock(raw, user);
          var counter = clock.counter;
          changes = [];
          expected = {};
          for (final (index, person) in people.indexed) {
            final name = "edited café '$index'";
            changes.add(
              _update(
                user,
                'person',
                person.id!,
                'name',
                name,
                Hlc(clock.datetime, counter++, clock.nodeId),
              ),
            );
            if (index < 103) {
              changes.add(
                _update(
                  user,
                  'person',
                  person.id!,
                  'surname',
                  null,
                  Hlc(clock.datetime, counter++, clock.nodeId),
                ),
              );
            }
            expected[person.id!] = (name, index < 103 ? null : person.surname);
          }
          changes.add(
            _update(
              user,
              'city',
              city.id!,
              'name',
              'edited city',
              Hlc(clock.datetime, counter++, clock.nodeId),
            ),
          );
        });

        group('when distinct values and sparse fields are merged together,', () {
          late Map<UuidValue, (String, String?)> actual;
          late server.Person? otherAfter;
          late server.City? cityAfter;

          setUpAll(() async {
            await merging.db.mergeChanges(changes, userId: user);
            final rows = await server.Person.db.find(
              raw,
              where: (t) => t.id.inSet(people.map((p) => p.id!).toSet()),
            );
            actual = {for (final row in rows) row.id!: (row.name, row.surname)};
            otherAfter = await server.Person.db.findById(raw, other.id!);
            cityAfter = await server.City.db.findById(raw, city.id!);
          });

          test(
            'then every row receives its own values and omitted fields remain unchanged.',
            () {
              expect(actual, expected);
            },
          );

          test('then the other table receives its own update.', () {
            expect(cityAfter?.name, 'edited city');
          });

          test('then the unrelated space remains unchanged.', () {
            expect(otherAfter?.name, other.name);
            expect(otherAfter?.surname, other.surname);
          });
        });
      });

      group('Given two rows with structured, binary, UUID and nullable columns,', () {
        late UuidValue user;
        late List<server.Types> before;
        late List<server.Types> expected;
        late List<CrdtMergeChange> changes;

        setUpAll(() async {
          user = const Uuid().v7obj();
          before = [
            for (var index = 0; index < 2; index++)
              server.Types(
                id: const Uuid().v7obj(),
                aBool: true,
                aDateTime: DateTime.utc(2026, 10, 1),
                aText: 'before $index',
                anInt: index,
                anInt64: BigInt.from(index),
                aReal: 1.25,
                aBlob: Uint8List.fromList([0, index]).buffer.asByteData(),
                optionalText: 'clear me',
              ),
          ];
          before = await merging.db.transactionForUser(
            user,
            (tx) => server.Types.db.insert(merging, before, transaction: tx),
          );
          before = [
            for (final row in before) (await server.Types.db.findById(raw, row.id!))!,
          ];
          expected = [
            for (final (index, row) in before.indexed)
              row.copyWith(
                aBool: index == 0,
                aDateTime: DateTime.utc(2026, 10, 18, 12, index),
                aText: "after 'café' $index",
                anInt: -index - 1,
                anInt64: BigInt.parse('9007199254740993') + BigInt.from(index),
                aReal: -2.5 - index,
                aBlob: Uint8List.fromList([0, 39, 92, 255, index]).buffer.asByteData(),
                optionalText: null,
                optionalUuid: index == 0 ? const Uuid().v7obj() : null,
                anEnum: index == 0 ? server.TypesEnum.values.first : null,
                jsonDocument: index == 0
                    ? server.SyncDocument(
                        title: 'JSON café',
                        enabled: true,
                        numbers: [-1, 2],
                      )
                    : null,
                jsonbDocument: server.SyncDocument(
                  title: 'JSONB $index',
                  enabled: false,
                  numbers: [index, 3],
                ),
                jsonbNumbers: index == 0 ? [1, -2, 3] : [],
              ),
          ];
          final clock = await _nextClock(raw, user);
          var counter = clock.counter;
          changes = [
            for (final row in expected)
              for (final entry in <String, Object?>{
                'aBool': row.aBool,
                'aDateTime': row.aDateTime,
                'aText': row.aText,
                'anInt': row.anInt,
                'anInt64': row.anInt64,
                'aReal': row.aReal,
                'aBlob': row.aBlob,
                'optionalText': row.optionalText,
                'optionalUuid': row.optionalUuid,
                'anEnum': row.anEnum,
                'jsonDocument': row.jsonDocument,
                'jsonbDocument': row.jsonbDocument,
                'jsonbNumbers': row.jsonbNumbers,
              }.entries)
                _update(
                  user,
                  'types',
                  row.id!,
                  entry.key,
                  entry.value,
                  Hlc(clock.datetime, counter++, clock.nodeId),
                ),
          ];
        });

        group('when their new values are merged in the same round,', () {
          late List<server.Types> actual;

          setUpAll(() async {
            await merging.db.mergeChanges(changes, userId: user);
            actual = [
              for (final row in expected)
                (await server.Types.db.findById(raw, row.id!))!,
            ];
          });

          test('then both rows retain every typed value and explicit null.', () {
            expect(
              actual.map((row) => row.toJson()).toList(),
              expected.map((row) => row.toJson()).toList(),
            );
          });
        });
      });

      group(
        'Given 105 edits and a trigger rejecting the last row after earlier writes,',
        () {
          late UuidValue user;
          late List<server.Person> people;
          late List<CrdtMergeChange> changes;
          late OfflineSyncSpace spaceBefore;
          late CrdtNode clockBefore;

          setUpAll(() async {
            user = const Uuid().v7obj();
            people = [
              for (var index = 0; index < 105; index++)
                server.Person(id: const Uuid().v7obj(), name: 'before $index'),
            ];
            await merging.db.transactionForUser(
              user,
              (tx) => server.Person.db.insert(merging, people, transaction: tx),
            );
            spaceBefore = (await OfflineSyncSpace.db.findFirstRow(
              raw,
              where: (t) => t.uuidSpaceId.equals(user),
            ))!;
            clockBefore = (await CrdtNode.db.findFirstRow(
              raw,
              where: (t) => t.localUserUuid.equals(user),
            ))!;
            final clock = await _nextClock(raw, user);
            changes = [
              for (final (index, row) in people.indexed)
                _update(
                  user,
                  'person',
                  row.id!,
                  'name',
                  'after $index',
                  Hlc(clock.datetime, clock.counter + index, clock.nodeId),
                ),
            ];
            await raw.db.unsafeExecute('''
CREATE FUNCTION reject_last_domain_update() RETURNS trigger LANGUAGE plpgsql AS \$\$
BEGIN
  IF NEW."id" = '${people.last.id}' THEN
    IF NOT EXISTS (SELECT 1 FROM "person" WHERE "id" = '${people.first.id}' AND "name" = 'after 0') THEN
      RAISE EXCEPTION 'test did not reach earlier writes';
    END IF;
    RAISE EXCEPTION 'injected last domain update failure';
  END IF;
  RETURN NEW;
END
\$\$;
CREATE TRIGGER reject_last_domain_update BEFORE UPDATE ON "person"
FOR EACH ROW EXECUTE FUNCTION reject_last_domain_update();
''');
            addTearDown(() async {
              await raw.db.unsafeExecute('''
DROP TRIGGER IF EXISTS reject_last_domain_update ON "person";
DROP FUNCTION IF EXISTS reject_last_domain_update();
''');
            });
          });

          group(
            'when the merge fails and is retried after removing the rejection,',
            () {
              late Object? error;
              late List<server.Person> failedRows;
              late List<CrdtDataField> failedFields;
              late OfflineSyncSpace failedSpace;
              late CrdtNode failedClock;
              late List<server.Person> retriedRows;

              setUpAll(() async {
                error = await merging.db
                    .mergeChanges(changes, userId: user)
                    .then<Object?>((_) => null, onError: (Object error) => error);
                final ids = people.map((p) => p.id!).toSet();
                failedRows = await server.Person.db.find(
                  raw,
                  where: (t) => t.id.inSet(ids),
                );
                failedFields = await CrdtDataField.db.find(
                  raw,
                  where: (t) => t.row.uuidRowId.inSet(ids),
                );
                failedSpace = (await OfflineSyncSpace.db.findById(
                  raw,
                  spaceBefore.id!,
                ))!;
                failedClock = (await CrdtNode.db.findById(raw, clockBefore.id!))!;
                await raw.db.unsafeExecute(
                  'DROP TRIGGER reject_last_domain_update ON "person"',
                );
                await merging.db.mergeChanges(changes, userId: user);
                retriedRows = await server.Person.db.find(
                  raw,
                  where: (t) => t.id.inSet(ids),
                );
              });

              test('then earlier domain writes and field metadata roll back.', () {
                expect(
                  error.toString(),
                  contains('injected last domain update failure'),
                );
                expect(
                  {for (final row in failedRows) row.id: row.name},
                  {for (final row in people) row.id: row.name},
                );
                expect(failedFields, isEmpty);
              });

              test('then the applying clock and space revision remain unchanged.', () {
                expect(failedClock.lastHlc, clockBefore.lastHlc);
                expect(failedSpace.syncRevision, spaceBefore.syncRevision);
                expect(failedSpace.lastHlc, spaceBefore.lastHlc);
              });

              test('then retry commits every edited row.', () {
                expect(
                  {for (final row in retriedRows) row.id: row.name},
                  {for (final (index, row) in people.indexed) row.id: 'after $index'},
                );
              });
            },
          );
        },
      );
    },
  );
}

Future<Hlc> _nextClock(Session raw, UuidValue space) async {
  final previous = (await OfflineSyncSpace.db.findFirstRow(
    raw,
    where: (t) => t.uuidSpaceId.equals(space),
  ))!.lastHlc!;
  return Hlc(previous.datetime, previous.counter + 1, const Uuid().v7obj());
}

CrdtMergeUpdate _update(
  UuidValue space,
  String table,
  UuidValue row,
  String column,
  Object? value,
  Hlc clock,
) => CrdtMergeUpdate(
  uuidSpaceId: space,
  tableName: table,
  uuidRowId: row,
  columnName: column,
  value: value,
  uuidNodeId: clock.nodeId,
  hlcDatetime: clock.datetime,
  hlcCounter: clock.counter,
);
