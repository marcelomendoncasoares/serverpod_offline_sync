import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/merge_inserts_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL merge insert atomicity]',
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
          sessions.build(),
          syncTables: server.syncTables,
        );
        await merging.db.initialize();
      });

      group('Given an uncommitted row owned by another space,', () {
        late OfflineSyncSpace ownerSpace;
        late UuidValue incomingUser;
        late server.Person owned;
        late server.Person earlier;
        late Hlc clock;
        late Completer<void> release;
        late Future<void> ownerWrite;

        setUpAll(() async {
          ownerSpace = await OfflineSyncSpace.db.insertRow(raw, OfflineSyncSpace());
          incomingUser = const Uuid().v7obj();
          owned = server.Person(
            id: const Uuid().v7obj(),
            spaceId: ownerSpace.id,
            name: 'original owner',
          );
          earlier = server.Person(id: const Uuid().v7obj(), name: 'earlier insert');
          clock = Hlc.now(const Uuid().v7obj());
          release = Completer<void>();
          final inserted = Completer<void>();
          final ownerSession = sessions.build();
          ownerWrite = ownerSession.db.transaction((tx) async {
            await server.Person.db.insertRow(ownerSession, owned, transaction: tx);
            inserted.complete();
            await release.future;
          });
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await ownerWrite;
          });
          await inserted.future;
        });

        group('when a merge reaches that row after inserting another row,', () {
          late bool waitedForOwner;
          late Object? error;
          late server.Person? ownerAfter;
          late server.Person? earlierAfter;
          late List<CrdtDataRow> metadata;
          late List<OfflineSyncSpaceNode> received;
          late OfflineSyncIntegrityViolation? violation;

          setUpAll(() async {
            var finished = false;
            final pending = merging.db
                .mergeChanges([
                  _insert(incomingUser, earlier, clock),
                  _insert(
                    incomingUser,
                    server.Person(id: owned.id, name: 'intruder'),
                    Hlc(clock.datetime, 1, clock.nodeId),
                  ),
                ], userId: incomingUser)
                .then<Object?>((_) => null, onError: (Object failure) => failure)
                .whenComplete(() => finished = true);

            try {
              await _observeLockWait(raw);
              waitedForOwner = !finished;
            } finally {
              release.complete();
              await ownerWrite;
              error = await pending;
            }

            ownerAfter = await server.Person.db.findById(raw, owned.id!);
            earlierAfter = await server.Person.db.findById(raw, earlier.id!);
            metadata = await CrdtDataRow.db.find(
              raw,
              where: (t) => t.uuidRowId.inSet(<UuidValue>{owned.id!, earlier.id!}),
            );
            received = await OfflineSyncSpaceNode.db.find(
              raw,
              where: (t) => t.node.uuidNodeId.equals(clock.nodeId),
            );
            violation = await OfflineSyncIntegrityViolation.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(owned.id),
            );
          });

          test('then the primary-key race waits for the owner to commit.', () {
            expect(waitedForOwner, isTrue);
          });

          test('then the collision leaves the owner and its space unchanged.', () {
            expect(error, isA<OfflineSyncIntegrityViolationException>());
            expect(ownerAfter?.name, 'original owner');
            expect(ownerAfter?.spaceId, ownerSpace.id);
          });

          test(
            'then the entire rejected merge and its received progress roll back.',
            () {
              expect(earlierAfter, isNull);
              expect(metadata, isEmpty);
              expect(received, isEmpty);
            },
          );

          test('then the ownership violation survives the rollback.', () {
            expect(violation?.type, OfflineSyncViolationType.ownershipCollision);
            expect(violation?.ownerSpaceUuid, ownerSpace.uuidSpaceId);
            expect(violation?.incomingSpaceUuid, incomingUser);
          });
        });
      });

      group('Given a same-space domain row without CRDT metadata,', () {
        late OfflineSyncSpace space;
        late server.Person existing;
        late Hlc clock;

        setUpAll(() async {
          space = await OfflineSyncSpace.db.insertRow(raw, OfflineSyncSpace());
          existing = await server.Person.db.insertRow(
            raw,
            server.Person(
              id: const Uuid().v7obj(),
              spaceId: space.id,
              name: 'before recovery',
              surname: 'old surname',
            ),
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group('when the row and a following insert arrive in one merge,', () {
          late server.Person? recovered;
          late server.Person? following;
          late List<CrdtDataRow> metadata;
          late Hlc? received;

          setUpAll(() async {
            final next = server.Person(id: const Uuid().v7obj(), name: 'following');
            await merging.db.mergeChanges([
              _insert(
                space.uuidSpaceId,
                server.Person(id: existing.id, name: 'recovered', surname: null),
                clock,
              ),
              _insert(
                space.uuidSpaceId,
                next,
                Hlc(clock.datetime, 1, clock.nodeId),
              ),
            ], userId: space.uuidSpaceId);

            recovered = await server.Person.db.findById(raw, existing.id!);
            following = await server.Person.db.findById(raw, next.id!);
            metadata = await CrdtDataRow.db.find(
              raw,
              where: (t) => t.uuidRowId.inSet(<UuidValue>{existing.id!, next.id!}),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            received = (await OfflineSyncSpaceNode.db.findFirstRow(
              raw,
              where: (t) =>
                  t.spaceId.equals(space.id) & t.node.uuidNodeId.equals(clock.nodeId),
            ))?.lastReceivedHlc;
          });

          test('then recovery preserves ownership and omitted fields.', () {
            expect(recovered?.name, 'recovered');
            expect(recovered?.surname, 'old surname');
            expect(recovered?.spaceId, space.id);
            expect(following?.name, 'following');
            expect(following?.spaceId, space.id);
          });

          test('then both authored rows and the final received clock commit.', () {
            expect(metadata, hasLength(2));
            expect(metadata.every((row) => row.hlc.nodeId == clock.nodeId), isTrue);
            expect(received, Hlc(clock.datetime, 1, clock.nodeId));
          });
        });
      });

      group("Given a nullable-only table containing another space's row,", () {
        late OfflineSyncDatabaseSession nullableSession;
        late server.UniqueNullable incoming;
        late server.UniqueNullable owned;
        late UuidValue user;
        late Hlc clock;

        setUpAll(() async {
          // Reuse the generated nullable model with its unique index removed
          // from both PostgreSQL and the schema supplied to the sync engine.
          await raw.db.unsafeExecute(
            'DROP INDEX "unique_nullable__spaceId__value__unique_idx"',
          );
          addTearDown(
            () => raw.db.unsafeExecute(
              'CREATE UNIQUE INDEX "unique_nullable__spaceId__value__unique_idx" '
              'ON unique_nullable ("spaceId", value)',
            ),
          );
          nullableSession = OfflineSyncDatabaseSession.wraps(
            raw,
            syncTables: server.syncTables,
            context: OfflineSyncDatabaseContext(
              syncTables: server.syncTables,
              serializationManager: _PlainNullableSchema(),
            ),
          );
          incoming = server.UniqueNullable(id: const Uuid().v7obj());
          user = const Uuid().v7obj();
          clock = Hlc.now(const Uuid().v7obj());
          final ownerSpace = await OfflineSyncSpace.db.insertRow(
            raw,
            OfflineSyncSpace(),
          );
          owned = await server.UniqueNullable.db.insertRow(
            raw,
            server.UniqueNullable(
              id: const Uuid().v7obj(),
              spaceId: ownerSpace.id,
              value: 7,
            ),
          );
        });

        group('when a merge omits the only nullable field,', () {
          late server.UniqueNullable? stored;
          late OfflineSyncSpace? space;
          late CrdtDataRow? metadata;
          late Hlc? received;

          setUpAll(() async {
            await nullableSession.db.mergeChanges([
              CrdtMergeInsert(
                uuidSpaceId: user,
                tableName: incoming.table.tableName,
                uuidRowId: incoming.id!,
                uuidNodeId: clock.nodeId,
                hlcDatetime: clock.datetime,
                hlcCounter: clock.counter,
                data: incoming,
              ),
            ], userId: user);

            stored = await server.UniqueNullable.db.findById(raw, incoming.id!);
            space = await OfflineSyncSpace.db.findFirstRow(
              raw,
              where: (t) => t.uuidSpaceId.equals(user),
            );
            metadata = await CrdtDataRow.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(incoming.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            received = (await OfflineSyncSpaceNode.db.findFirstRow(
              raw,
              where: (t) =>
                  t.spaceId.equals(space?.id) & t.node.uuidNodeId.equals(clock.nodeId),
            ))?.lastReceivedHlc;
          });

          test('then the empty payload still creates the owned row.', () {
            expect(stored?.id, incoming.id);
            expect(stored?.value, isNull);
            expect(space, isNotNull);
            expect(stored?.spaceId, space!.id);
          });

          test('then its metadata and received clock commit together.', () {
            expect(metadata?.hlc, clock);
            expect(received, clock);
          });
        });

        group('when an omitted-field insert collides with that row,', () {
          late Object? error;
          late server.UniqueNullable? ownerAfter;
          late CrdtDataRow? metadata;

          setUpAll(() async {
            final intruder = const Uuid().v7obj();
            final collisionClock = Hlc.now(const Uuid().v7obj());
            try {
              await nullableSession.db.mergeChanges([
                CrdtMergeInsert(
                  uuidSpaceId: intruder,
                  tableName: owned.table.tableName,
                  uuidRowId: owned.id!,
                  uuidNodeId: collisionClock.nodeId,
                  hlcDatetime: collisionClock.datetime,
                  hlcCounter: collisionClock.counter,
                  data: server.UniqueNullable(id: owned.id),
                ),
              ], userId: intruder);
              error = null;
            } on Object catch (failure) {
              error = failure;
            }

            ownerAfter = await server.UniqueNullable.db.findById(raw, owned.id!);
            metadata = await CrdtDataRow.db.findFirstRow(
              raw,
              where: (t) => t.uuidRowId.equals(owned.id),
            );
          });

          test('then the empty payload cannot acquire or alter the foreign row.', () {
            expect(error, isA<OfflineSyncIntegrityViolationException>());
            expect(ownerAfter?.spaceId, owned.spaceId);
            expect(ownerAfter?.value, owned.value);
            expect(metadata, isNull);
          });
        });
      });

      group('Given a default parent already claimed by another child,', () {
        const defaultParent = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
        late UuidValue user;
        late UuidValue missingParent;
        late server.UniqueSetDefaultChild fresh;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          missingParent = const Uuid().v7obj();
          final parent = await merging.db.transactionForUser(
            user,
            (tx) => server.Town.db.insertRow(
              merging,
              server.Town(id: defaultParent, name: 'default parent'),
              transaction: tx,
            ),
          );
          await merging.db.transactionForUser(
            user,
            (tx) => server.UniqueSetDefaultChild.db.insertRow(
              merging,
              server.UniqueSetDefaultChild(
                name: 'default claimant',
                parentId: parent.id,
              ),
              transaction: tx,
            ),
          );
          fresh = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'new child',
            parentId: missingParent,
          );
          clock = Hlc.now(const Uuid().v7obj());
        });

        group('when a new child arrives naming a missing parent,', () {
          late server.UniqueSetDefaultChild? child;
          late CrdtDataField? attemptedParent;

          setUpAll(() async {
            await merging.db.mergeChanges([
              CrdtMergeInsert(
                uuidSpaceId: user,
                tableName: 'unique_set_default_child',
                uuidRowId: fresh.id!,
                uuidNodeId: clock.nodeId,
                hlcDatetime: clock.datetime,
                hlcCounter: clock.counter,
                data: fresh,
              ),
            ], userId: user);
            child = await server.UniqueSetDefaultChild.db.findById(raw, fresh.id!);
            attemptedParent = await CrdtDataField.db.findFirstRow(
              raw,
              where: (t) =>
                  t.row.uuidRowId.equals(fresh.id) & t.column.name.equals('parentId'),
              include: CrdtDataField.include(
                attemptedValue: CrdtDataAttemptedValue.include(),
              ),
            );
          });

          test(
            'then the projected null remains null despite the database default.',
            () {
              expect(child, isNotNull);
              expect(child!.parentId, isNull);
            },
          );

          test('then the child retains its authored missing-parent value.', () {
            expect(attemptedParent?.attemptedValue?.value, missingParent);
          });
        });
      });

      group('Given a database constraint rejecting a later incoming row,', () {
        late UuidValue user;
        late server.Person earlier;
        late server.Person rejected;
        late Hlc clock;

        setUpAll(() async {
          user = const Uuid().v7obj();
          earlier = server.Person(id: const Uuid().v7obj(), name: 'accepted');
          rejected = server.Person(id: const Uuid().v7obj(), name: 'rejected');
          clock = Hlc.now(const Uuid().v7obj());
          await raw.db.unsafeExecute('''
ALTER TABLE person ADD CONSTRAINT reject_merge_probe
CHECK (id <> '${rejected.id}')
''');
          addTearDown(
            () => raw.db.unsafeExecute(
              'ALTER TABLE person DROP CONSTRAINT reject_merge_probe',
            ),
          );
        });

        group('when both rows are merged in causal order,', () {
          late Object? error;
          late List<server.Person> rows;
          late List<CrdtDataRow> metadata;
          late List<OfflineSyncSpaceNode> received;

          setUpAll(() async {
            try {
              await merging.db.mergeChanges([
                _insert(user, earlier, clock),
                _insert(user, rejected, Hlc(clock.datetime, 1, clock.nodeId)),
              ], userId: user);
              error = null;
            } on Object catch (failure) {
              error = failure;
            }
            rows = await server.Person.db.find(
              raw,
              where: (t) => t.id.inSet(<UuidValue>{earlier.id!, rejected.id!}),
            );
            metadata = await CrdtDataRow.db.find(
              raw,
              where: (t) => t.uuidRowId.inSet(<UuidValue>{earlier.id!, rejected.id!}),
            );
            received = await OfflineSyncSpaceNode.db.find(
              raw,
              where: (t) => t.node.uuidNodeId.equals(clock.nodeId),
            );
          });

          test('then the unrelated constraint failure is not suppressed.', () {
            expect(error, isA<DatabaseQueryException>());
          });

          test('then neither rows nor metadata nor received progress commit.', () {
            expect(rows, isEmpty);
            expect(metadata, isEmpty);
            expect(received, isEmpty);
          });
        });
      });
    },
  );
}

CrdtMergeInsert _insert(UuidValue space, server.Person row, Hlc clock) =>
    CrdtMergeInsert(
      uuidSpaceId: space,
      tableName: 'person',
      uuidRowId: row.id!,
      uuidNodeId: clock.nodeId,
      hlcDatetime: clock.datetime,
      hlcCounter: clock.counter,
      data: row,
    );

Future<void> _observeLockWait(Session observer) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < const Duration(seconds: 10)) {
    final result = await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE datname = current_database() AND wait_event_type = 'Lock'
  AND cardinality(pg_blocking_pids(pid)) > 0
''');
    if ((result.first.first as int) > 0) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('Expected a database-observed primary-key lock waiter.');
}

class _PlainNullableSchema extends DatabaseSerializationManager {
  @override
  String getModuleName() => server.Protocol().getModuleName();

  @override
  Table? getTableForType(Type type) => server.Protocol().getTableForType(type);

  @override
  List<TableDefinition> getTargetTableDefinitions() => [
    for (final table in server.Protocol().getTargetTableDefinitions())
      if (table.name == 'unique_nullable') table.copyWith(indexes: []) else table,
  ];
}
