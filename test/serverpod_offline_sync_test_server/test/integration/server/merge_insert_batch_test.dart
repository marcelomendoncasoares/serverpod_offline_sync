import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/merge_batch_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL merged insert batches]',
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
        merging = OfflineSyncDatabaseSession.wraps(
          raw,
          syncTables: server.syncTables,
        );
        await merging.db.initialize();
      });

      group(
        'Given an established source and a space that rejects its next revision,',
        () {
          late UuidValue spaceId;
          late OfflineSyncSpace spaceBefore;
          late CrdtNode clockBefore;
          late List<OfflineSyncSpaceNode> progressBefore;
          late server.City incoming;
          late Hlc incomingHlc;

          setUpAll(() async {
            spaceId = const Uuid().v7obj();
            final first = Hlc.now(const Uuid().v7obj());
            await merging.db.mergeChanges([
              _insert(
                spaceId,
                server.City(id: const Uuid().v7obj(), name: 'seed'),
                first,
              ),
            ], userId: spaceId);
            spaceBefore = (await OfflineSyncSpace.db.findFirstRow(
              raw,
              where: (t) => t.uuidSpaceId.equals(spaceId),
            ))!;
            clockBefore = (await CrdtNode.db.findFirstRow(
              raw,
              where: (t) => t.localUserUuid.equals(spaceId),
            ))!;
            progressBefore = await OfflineSyncSpaceNode.db.find(
              raw,
              where: (t) => t.spaceId.equals(spaceBefore.id),
            );
            incoming = server.City(id: const Uuid().v7obj(), name: 'retry me');
            incomingHlc = Hlc(first.datetime, 1, first.nodeId);
            await raw.db.unsafeExecute('''
CREATE FUNCTION reject_merge_revision() RETURNS trigger LANGUAGE plpgsql AS \$\$
BEGIN
  IF NEW."id" = ${spaceBefore.id} AND NEW."revision" <> OLD."revision" THEN
    IF NOT EXISTS (SELECT 1 FROM "city" WHERE "id" = '${incoming.id}') THEN
      RAISE EXCEPTION 'test did not reach the completed domain write';
    END IF;
    RAISE EXCEPTION 'injected merge revision failure';
  END IF;
  RETURN NEW;
END
\$\$;
CREATE TRIGGER reject_merge_revision BEFORE UPDATE ON "offline_sync_spaces"
FOR EACH ROW EXECUTE FUNCTION reject_merge_revision();
''');
            addTearDown(() async {
              await raw.db.unsafeExecute('''
DROP TRIGGER IF EXISTS reject_merge_revision ON "offline_sync_spaces";
DROP FUNCTION IF EXISTS reject_merge_revision();
''');
            });
          });

          group(
            'when persistence fails and the same merge is retried without the trigger,',
            () {
              late Object? error;
              late server.City? afterFailure;
              late List<CrdtDataRow> metadataAfterFailure;
              late OfflineSyncSpace spaceAfterFailure;
              late CrdtNode clockAfterFailure;
              late List<OfflineSyncSpaceNode> progressAfterFailure;
              late server.City? afterRetry;
              late Hlc? receivedAfterRetry;
              late OfflineSyncSpace spaceAfterRetry;

              setUpAll(() async {
                final changes = [_insert(spaceId, incoming, incomingHlc)];
                error = await merging.db
                    .mergeChanges(changes, userId: spaceId)
                    .then<Object?>((_) => null, onError: (Object error) => error);
                afterFailure = await server.City.db.findById(raw, incoming.id!);
                metadataAfterFailure = await CrdtDataRow.db.find(
                  raw,
                  where: (t) => t.uuidRowId.equals(incoming.id),
                );
                spaceAfterFailure = (await OfflineSyncSpace.db.findById(
                  raw,
                  spaceBefore.id!,
                ))!;
                clockAfterFailure = (await CrdtNode.db.findById(raw, clockBefore.id!))!;
                progressAfterFailure = await OfflineSyncSpaceNode.db.find(
                  raw,
                  where: (t) => t.spaceId.equals(spaceBefore.id),
                );

                await raw.db.unsafeExecute(
                  'DROP TRIGGER reject_merge_revision ON "offline_sync_spaces"',
                );
                await merging.db.mergeChanges(changes, userId: spaceId);
                afterRetry = await server.City.db.findById(raw, incoming.id!);
                receivedAfterRetry = (await OfflineSyncSpaceNode.db.findFirstRow(
                  raw,
                  where: (t) =>
                      t.spaceId.equals(spaceBefore.id) &
                      t.node.uuidNodeId.equals(incomingHlc.nodeId),
                ))!.lastReceivedHlc;
                spaceAfterRetry = (await OfflineSyncSpace.db.findById(
                  raw,
                  spaceBefore.id!,
                ))!;
              });

              test('then the failed persistence leaves no domain or CRDT write.', () {
                expect(error.toString(), contains('injected merge revision failure'));
                expect(afterFailure, isNull);
                expect(metadataAfterFailure, isEmpty);
              });

              test(
                'then received progress, the clock and the revision all roll back.',
                () {
                  expect(clockAfterFailure.lastHlc, clockBefore.lastHlc);
                  expect(spaceAfterFailure.lastHlc, spaceBefore.lastHlc);
                  expect(spaceAfterFailure.revision, spaceBefore.revision);
                  expect(
                    {
                      for (final node in progressAfterFailure)
                        node.id: node.lastReceivedHlc,
                    },
                    {for (final node in progressBefore) node.id: node.lastReceivedHlc},
                  );
                },
              );

              test(
                'then retry commits the row, progress and a fresh revision together.',
                () {
                  expect(afterRetry?.name, incoming.name);
                  expect(receivedAfterRetry, incomingHlc);
                  expect(spaceAfterRetry.revision, isNot(spaceBefore.revision));
                  expect(
                    spaceAfterRetry.lastHlc!.compareTo(incomingHlc),
                    greaterThanOrEqualTo(0),
                  );
                },
              );
            },
          );
        },
      );

      group(
        'Given an established author advanced by another session and an author known only in another space,',
        () {
          late UuidValue space;
          late UuidValue otherSpace;
          late Hlc first;
          late Hlc second;
          late Hlc third;
          late List<server.City> rows;

          setUpAll(() async {
            space = const Uuid().v7obj();
            otherSpace = const Uuid().v7obj();
            first = Hlc.now(const Uuid().v7obj());
            second = Hlc(first.datetime, 2, const Uuid().v7obj());
            third = Hlc(first.datetime, 4, const Uuid().v7obj());
            rows = [
              server.City(id: const Uuid().v7obj(), name: 'older unseen fact'),
              server.City(id: const Uuid().v7obj(), name: 'new space association'),
              server.City(id: const Uuid().v7obj(), name: 'new author'),
            ];
            await merging.db.mergeChanges([
              _insert(
                space,
                server.City(id: const Uuid().v7obj(), name: 'establish author'),
                first,
              ),
            ], userId: space);
            await merging.db.mergeChanges([
              _insert(
                otherSpace,
                server.City(id: const Uuid().v7obj(), name: 'other first'),
                Hlc(first.datetime, 50, first.nodeId),
              ),
              _insert(
                otherSpace,
                server.City(id: const Uuid().v7obj(), name: 'other second'),
                Hlc(first.datetime, 50, second.nodeId),
              ),
            ], userId: otherSpace);

            final independent = OfflineSyncDatabaseSession.wraps(
              sessions.build(),
              syncTables: server.syncTables,
            );
            await independent.db.mergeChanges([
              _insert(
                space,
                server.City(id: const Uuid().v7obj(), name: 'newer received fact'),
                Hlc(first.datetime, 9, first.nodeId),
              ),
            ], userId: space);
          });

          group('when one batch mixes their older facts with a new author,', () {
            late Map<(UuidValue, UuidValue), Hlc?> progress;
            late Map<UuidValue, UuidValue> authors;

            setUpAll(() async {
              await merging.db.mergeChanges([
                _insert(space, rows[0], Hlc(first.datetime, 3, first.nodeId)),
                _insert(space, rows[1], second),
                _insert(space, rows[2], third),
              ], userId: space);

              final sources = await OfflineSyncSpaceNode.db.find(
                raw,
                where: (t) => t.node.uuidNodeId.inSet({
                  first.nodeId,
                  second.nodeId,
                  third.nodeId,
                }),
                include: OfflineSyncSpaceNode.include(
                  node: CrdtNode.include(),
                  space: OfflineSyncSpace.include(),
                ),
              );
              progress = {
                for (final source in sources)
                  (source.space!.uuidSpaceId, source.node!.uuidNodeId):
                      source.lastReceivedHlc,
              };
              final stored = await CrdtDataRow.db.find(
                raw,
                where: (t) => t.uuidRowId.inSet({for (final row in rows) row.id!}),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              );
              authors = {
                for (final row in stored) row.uuidRowId: row.node!.uuidNodeId,
              };
            });

            test('then progress stays monotonic and scoped to each space.', () {
              expect(progress, {
                (space, first.nodeId): Hlc(first.datetime, 9, first.nodeId),
                (space, second.nodeId): second,
                (space, third.nodeId): third,
                (otherSpace, first.nodeId): Hlc(first.datetime, 50, first.nodeId),
                (otherSpace, second.nodeId): Hlc(first.datetime, 50, second.nodeId),
              });
            });

            test('then every fact retains its original author.', () {
              expect(authors, {
                rows[0].id!: first.nodeId,
                rows[1].id!: second.nodeId,
                rows[2].id!: third.nodeId,
              });
            });
          });
        },
      );

      group('Given related new rows authored by two devices,', () {
        late UuidValue user;
        late server.City city;
        late server.Person first;
        late server.Person second;
        late server.Town town;
        late Hlc firstClock;
        late Hlc secondClock;
        late Hlc reinsertClock;
        late CrdtMergeSet changes;

        setUpAll(() {
          user = const Uuid().v7obj();
          city = server.City(id: const Uuid().v7obj(), name: 'parent city');
          first = server.Person(
            id: const Uuid().v7obj(),
            name: 'first',
            cityId: city.id,
          );
          second = server.Person(
            id: const Uuid().v7obj(),
            name: 'second',
            cityId: city.id,
          );
          town = server.Town(
            id: const Uuid().v7obj(),
            name: 'child town',
            cityId: city.id,
            mayorId: first.id,
          );
          final clock = Hlc.now(const Uuid().v7obj());
          firstClock = Hlc(clock.datetime, 1, clock.nodeId);
          secondClock = Hlc(clock.datetime, 2, const Uuid().v7obj());
          reinsertClock = Hlc(clock.datetime, 5, secondClock.nodeId);
          changes = [
            _insert(user, city, clock),
            _insert(user, first, firstClock),
            _insert(user, second, secondClock),
            _insert(user, town, Hlc(clock.datetime, 3, clock.nodeId)),
            CrdtMergeUpdate(
              uuidSpaceId: user,
              tableName: 'person',
              uuidRowId: first.id!,
              uuidNodeId: clock.nodeId,
              hlcDatetime: clock.datetime,
              hlcCounter: 4,
              columnName: 'name',
              value: 'intermediate',
            ),
            _insert(user, first.copyWith(name: 'reinserted'), reinsertClock),
            CrdtMergeDelete(
              uuidSpaceId: user,
              tableName: 'person',
              uuidRowId: second.id!,
              uuidNodeId: clock.nodeId,
              hlcDatetime: clock.datetime,
              hlcCounter: 6,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ];
        });

        group('when one merge inserts, edits, reinserts and deletes them,', () {
          late server.Person? mergedFirst;
          late server.Person? mergedSecond;
          late server.Town? mergedTown;
          late Map<UuidValue, Hlc> rowClocks;
          late Hlc? nameClock;

          setUpAll(() async {
            await merging.db.mergeChanges(changes, userId: user);

            mergedFirst = await server.Person.db.findById(merging, first.id!);
            mergedSecond = await server.Person.db.findById(merging, second.id!);
            mergedTown = await server.Town.db.findById(merging, town.id!);
            final rows = await CrdtDataRow.db.find(
              raw,
              where: (t) => t.uuidRowId.inSet({first.id!, second.id!}),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            rowClocks = {for (final row in rows) row.uuidRowId: row.hlc};
            nameClock = (await CrdtDataField.db.findFirstRow(
              raw,
              where: (t) =>
                  t.row.uuidRowId.equals(first.id) & t.column.name.equals('name'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            ))?.hlc;
          });

          test('then dependent rows retain their newly inserted parents.', () {
            expect(mergedTown?.cityId, city.id);
            expect(mergedTown?.mayorId, first.id);
            expect(mergedFirst?.cityId, city.id);
          });

          test('then each row tracker retains its own author and insert clock.', () {
            expect(rowClocks, {first.id!: firstClock, second.id!: secondClock});
          });

          test(
            'then later operations see their trackers and retain the newest state.',
            () {
              expect(mergedFirst?.name, 'reinserted');
              expect(nameClock, reinsertClock);
              expect(mergedSecond, isNull);
            },
          );
        });
      });

      group('Given interleaved new parents and children with overlapping row ids,', () {
        late UuidValue user;
        late server.Person earlyParent;
        late server.Person lateParent;
        late server.Town earlyChild;
        late server.Town lateChild;
        late Hlc clock;

        setUpAll(() {
          user = const Uuid().v7obj();
          earlyParent = server.Person(id: const Uuid().v7obj(), name: 'early parent');
          lateParent = server.Person(id: const Uuid().v7obj(), name: 'late parent');
          earlyChild = server.Town(
            id: earlyParent.id,
            name: 'early child',
            mayorId: earlyParent.id,
          );
          lateChild = server.Town(
            id: const Uuid().v7obj(),
            name: 'child before parent',
            mayorId: lateParent.id,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group('when their inserts arrive on both sides of their parent inserts,', () {
          late List<server.Person> people;
          late List<server.Town> towns;
          late Map<UuidValue, Hlc> childClocks;

          setUpAll(() async {
            await merging.db.mergeChanges([
              _insert(user, earlyParent, clock),
              _insert(user, earlyChild, Hlc(clock.datetime, 1, clock.nodeId)),
              _insert(user, lateChild, Hlc(clock.datetime, 2, clock.nodeId)),
              _insert(user, lateParent, Hlc(clock.datetime, 3, clock.nodeId)),
            ], userId: user);

            people = await server.Person.db.find(
              merging,
              where: (t) => t.id.inSet(<UuidValue>{earlyParent.id!, lateParent.id!}),
            );
            towns = await server.Town.db.find(
              merging,
              where: (t) => t.id.inSet(<UuidValue>{earlyChild.id!, lateChild.id!}),
            );
            final trackers = await CrdtDataRow.db.find(
              raw,
              where: (t) =>
                  t.tbl.name.equals('town') &
                  t.uuidRowId.inSet({earlyChild.id!, lateChild.id!}),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            childClocks = {for (final row in trackers) row.uuidRowId: row.hlc};
          });

          test(
            'then both children resolve their parents without losing either table.',
            () {
              expect(people.map((person) => person.id).toSet(), {
                earlyParent.id,
                lateParent.id,
              });
              expect(
                {for (final town in towns) town.id: town.mayorId},
                {
                  earlyChild.id: earlyParent.id,
                  lateChild.id: lateParent.id,
                },
              );
            },
          );

          test('then regrouping writes preserves each child insert clock.', () {
            expect(childClocks, {
              earlyChild.id!: Hlc(clock.datetime, 1, clock.nodeId),
              lateChild.id!: Hlc(clock.datetime, 2, clock.nodeId),
            });
          });
        });
      });

      group('Given fresh inserts interleaved with edits to a stored parent,', () {
        late UuidValue user;
        late server.City city;
        late server.Person first;
        late server.Person second;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          city = await merging.db.transactionForUser(
            user,
            (tx) => server.City.db.insertRow(
              merging,
              server.City(name: 'stored parent'),
              transaction: tx,
            ),
          );
          first = server.Person(
            id: const Uuid().v7obj(),
            name: 'first',
            cityId: city.id,
          );
          second = server.Person(
            id: const Uuid().v7obj(),
            name: 'second',
            cityId: city.id,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group(
          'when the merge also edits an inserted row and reinserts the parent,',
          () {
            late server.City? mergedCity;
            late server.Person? mergedFirst;
            late server.Person? mergedSecond;
            late Hlc? cityNameClock;
            late Hlc? personNameClock;

            setUpAll(() async {
              CrdtMergeUpdate rename(TableRow row, int counter, String value) =>
                  CrdtMergeUpdate(
                    uuidSpaceId: user,
                    tableName: row.table.tableName,
                    uuidRowId: row.id as UuidValue,
                    uuidNodeId: clock.nodeId,
                    hlcDatetime: clock.datetime,
                    hlcCounter: counter,
                    columnName: 'name',
                    value: value,
                  );

              await merging.db.mergeChanges([
                _insert(user, first, clock),
                rename(city, 1, 'intermediate parent'),
                _insert(user, second, Hlc(clock.datetime, 2, clock.nodeId)),
                rename(city, 3, 'newer parent'),
                rename(first, 4, 'edited first'),
                _insert(
                  user,
                  city.copyWith(name: 'reinserted parent'),
                  Hlc(clock.datetime, 5, clock.nodeId),
                ),
              ], userId: user);
              await merging.db.mergeChanges([
                rename(city, 4, 'late older parent edit'),
              ], userId: user);

              mergedCity = await server.City.db.findById(merging, city.id!);
              mergedFirst = await server.Person.db.findById(merging, first.id!);
              mergedSecond = await server.Person.db.findById(merging, second.id!);
              final fields = await CrdtDataField.db.find(
                raw,
                where: (t) =>
                    t.row.uuidRowId.inSet({city.id!, first.id!}) &
                    t.column.name.equals('name'),
                include: CrdtDataField.include(
                  row: CrdtDataRow.include(),
                  node: CrdtNode.include(),
                ),
              );
              cityNameClock = fields
                  .singleWhere((f) => f.row!.uuidRowId == city.id)
                  .hlc;
              personNameClock = fields
                  .singleWhere((f) => f.row!.uuidRowId == first.id)
                  .hlc;
            });

            test('then the inserted rows retain their references and later edits.', () {
              expect(mergedFirst?.name, 'edited first');
              expect(mergedFirst?.cityId, city.id);
              expect(mergedSecond?.name, 'second');
              expect(mergedSecond?.cityId, city.id);
              expect(personNameClock, Hlc(clock.datetime, 4, clock.nodeId));
            });

            test('then queued edits cannot overwrite the newer reinsertion clock.', () {
              expect(mergedCity?.name, 'reinserted parent');
              expect(cityNameClock, Hlc(clock.datetime, 5, clock.nodeId));
            });
          },
        );
      });

      group('Given independent new rows referencing a stored parent,', () {
        late UuidValue user;
        late server.City city;
        late server.Person person;
        late server.Town town;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          city = await merging.db.transactionForUser(
            user,
            (tx) => server.City.db.insertRow(
              merging,
              server.City(name: 'stored city'),
              transaction: tx,
            ),
          );
          person = server.Person(
            id: const Uuid().v7obj(),
            name: 'new person',
            cityId: city.id,
          );
          town = server.Town(
            id: const Uuid().v7obj(),
            name: 'new town',
            cityId: city.id,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group('when a merge inserts them and renames the parent,', () {
          late server.City? mergedCity;
          late server.Person? mergedPerson;
          late server.Town? mergedTown;
          late Map<UuidValue, Hlc> insertClocks;
          late Hlc? renameClock;

          setUpAll(() async {
            await merging.db.mergeChanges([
              _insert(user, person, clock),
              CrdtMergeUpdate(
                uuidSpaceId: user,
                tableName: 'city',
                uuidRowId: city.id!,
                uuidNodeId: clock.nodeId,
                hlcDatetime: clock.datetime,
                hlcCounter: 1,
                columnName: 'name',
                value: 'renamed city',
              ),
              _insert(user, town, Hlc(clock.datetime, 2, clock.nodeId)),
            ], userId: user);

            mergedCity = await server.City.db.findById(merging, city.id!);
            mergedPerson = await server.Person.db.findById(merging, person.id!);
            mergedTown = await server.Town.db.findById(merging, town.id!);
            final rows = await CrdtDataRow.db.find(
              raw,
              where: (t) => t.uuidRowId.inSet({person.id!, town.id!}),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            insertClocks = {for (final row in rows) row.uuidRowId: row.hlc};
            renameClock = (await CrdtDataField.db.findFirstRow(
              raw,
              where: (t) =>
                  t.row.uuidRowId.equals(city.id) & t.column.name.equals('name'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            ))?.hlc;
          });

          test('then both references and the independent edit are visible.', () {
            expect(mergedPerson?.cityId, city.id);
            expect(mergedTown?.cityId, city.id);
            expect(mergedCity?.name, 'renamed city');
          });

          test('then skipping projection retains the authored clocks.', () {
            expect(insertClocks, {
              person.id!: clock,
              town.id!: Hlc(clock.datetime, 2, clock.nodeId),
            });
            expect(renameClock, Hlc(clock.datetime, 1, clock.nodeId));
          });
        });
      });

      group('Given a stored child waiting for a missing parent,', () {
        late UuidValue user;
        late server.Person person;
        late server.Town town;
        late Hlc clock;
        late Object? attemptedBefore;

        setUpAll(() async {
          user = const Uuid().v7obj();
          person = server.Person(id: const Uuid().v7obj(), name: 'missing mayor');
          town = server.Town(
            id: const Uuid().v7obj(),
            name: 'waiting town',
            mayorId: person.id,
          );
          clock = Hlc.now(const Uuid().v7obj());
          await merging.db.mergeChanges([_insert(user, town, clock)], userId: user);
          attemptedBefore = (await CrdtDataField.db.findFirstRow(
            raw,
            where: (t) =>
                t.row.uuidRowId.equals(town.id) & t.column.name.equals('mayorId'),
            include: CrdtDataField.include(
              attemptedValue: CrdtDataAttemptedValue.include(),
            ),
          ))?.attemptedValue?.value;
        });

        group('when a later merge supplies that parent,', () {
          late server.Town? repairedTown;
          late Object? attemptedAfter;
          late Hlc? childClock;

          setUpAll(() async {
            await merging.db.mergeChanges([
              _insert(user, person, Hlc(clock.datetime, 1, clock.nodeId)),
            ], userId: user);

            repairedTown = await server.Town.db.findById(merging, town.id!);
            attemptedAfter = (await CrdtDataField.db.findFirstRow(
              raw,
              where: (t) =>
                  t.row.uuidRowId.equals(town.id) & t.column.name.equals('mayorId'),
              include: CrdtDataField.include(
                attemptedValue: CrdtDataAttemptedValue.include(),
              ),
            ))?.attemptedValue?.value;
            childClock = (await CrdtDataRow.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(town.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            ))?.hlc;
          });

          test('then projection repairs the previously missing reference.', () {
            expect(attemptedBefore, person.id);
            expect(repairedTown?.mayorId, person.id);
            expect(attemptedAfter, isNull);
          });

          test('then repairing the reference preserves its original author clock.', () {
            expect(childClock, clock);
          });
        });
      });

      group('Given new rows whose table relationships form a cycle,', () {
        late UuidValue user;
        late server.Town storedTown;
        late server.Person person;
        late server.Company company;
        late server.Town newTown;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          storedTown = await merging.db.transactionForUser(
            user,
            (tx) => server.Town.db.insertRow(
              merging,
              server.Town(name: 'stored town'),
              transaction: tx,
            ),
          );
          company = server.Company(
            id: const Uuid().v7obj(),
            name: 'new company',
            townId: storedTown.id,
          );
          person = server.Person(
            id: const Uuid().v7obj(),
            name: 'new person',
            oldCompanyId: company.id,
          );
          newTown = server.Town(
            id: const Uuid().v7obj(),
            name: 'new town',
            mayorId: person.id,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        test(
          'when a merge inserts the related rows, '
          'then all authored references survive the causal fallback.',
          () async {
            await merging.db.mergeChanges([
              _insert(user, person, clock),
              _insert(user, company, Hlc(clock.datetime, 1, clock.nodeId)),
              _insert(user, newTown, Hlc(clock.datetime, 2, clock.nodeId)),
            ], userId: user);
            final mergedPerson = await server.Person.db.findById(merging, person.id!);
            final mergedCompany = await server.Company.db.findById(
              merging,
              company.id!,
            );
            final mergedTown = await server.Town.db.findById(merging, newTown.id!);

            expect(mergedPerson?.oldCompanyId, company.id);
            expect(mergedCompany?.townId, storedTown.id);
            expect(mergedTown?.mayorId, person.id);
          },
        );
      });

      group('Given a claimed default parent and another available parent,', () {
        const defaultId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
        late UuidValue user;
        late server.Town available;
        late server.UniqueSetDefaultChild valid;
        late server.UniqueSetDefaultChild projected;
        late UuidValue missingParent;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          available = server.Town(id: const Uuid().v7obj(), name: 'available');
          await merging.db.transactionForUser(user, (tx) async {
            await server.Town.db.insert(merging, [
              server.Town(id: defaultId, name: 'default'),
              available,
            ], transaction: tx);
            await server.UniqueSetDefaultChild.db.insertRow(
              merging,
              server.UniqueSetDefaultChild(name: 'claimant', parentId: defaultId),
              transaction: tx,
            );
          });
          missingParent = const Uuid().v7obj();
          valid = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'valid',
            parentId: available.id,
          );
          projected = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'projected',
            parentId: missingParent,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group(
          'when a valid reference is followed by a projected null in one merge,',
          () {
            late server.UniqueSetDefaultChild? validAfter;
            late server.UniqueSetDefaultChild? projectedAfter;
            late Object? attemptedValue;

            setUpAll(() async {
              await merging.db.mergeChanges([
                _insert(user, valid, clock),
                _insert(user, projected, Hlc(clock.datetime, 1, clock.nodeId)),
              ], userId: user);

              validAfter = await server.UniqueSetDefaultChild.db.findById(
                raw,
                valid.id!,
              );
              projectedAfter = await server.UniqueSetDefaultChild.db.findById(
                raw,
                projected.id!,
              );
              attemptedValue = (await CrdtDataField.db.findFirstRow(
                raw,
                where: (t) =>
                    t.row.uuidRowId.equals(projected.id) &
                    t.column.name.equals('parentId'),
                include: CrdtDataField.include(
                  attemptedValue: CrdtDataAttemptedValue.include(),
                ),
              ))?.attemptedValue?.value;
            });

            test('then each row keeps its own reference and default behavior.', () {
              expect(validAfter?.parentId, available.id);
              expect(projectedAfter, isNotNull);
              expect(projectedAfter!.parentId, isNull);
            });

            test('then projection preserves the missing authored reference.', () {
              expect(attemptedValue, missingParent);
            });
          },
        );
      });
    },
  );
}

CrdtMergeInsert _insert(UuidValue user, TableRow row, Hlc clock) => CrdtMergeInsert(
  uuidSpaceId: user,
  tableName: row.table.tableName,
  uuidRowId: row.id as UuidValue,
  uuidNodeId: clock.nodeId,
  hlcDatetime: clock.datetime,
  hlcCounter: clock.counter,
  data: row as SerializableModel,
);
