import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/schema_lifetime_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL shared schema rebuild]',
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

      setUpAll(() async {
        raw = sessions.build();
      });

      group('Given stored people and a registry missing an unused column,', () {
        late List<server.Person> people;
        late OfflineSyncDatabaseContext shared;
        late QueryCountingDatabase firstDatabase;
        late QueryCountingDatabase secondDatabase;
        late OfflineSyncDatabaseSession first;
        late OfflineSyncDatabaseSession second;

        setUpAll(() async {
          final seed = OfflineSyncDatabaseSession.wraps(
            raw,
            syncTables: server.syncTables,
          );
          await seed.db.initialize();
          people = [server.Person(name: 'first'), server.Person(name: 'second')];
          people = await seed.db.transactionForUser(
            const Uuid().v7obj(),
            (tx) => server.Person.db.insert(seed, people, transaction: tx),
          );
          await _removeUnusedCityColumn(raw);
          shared = OfflineSyncDatabaseContext(
            syncTables: server.syncTables,
            serializationManager: raw.db.serializationManager,
          );
          firstDatabase = QueryCountingDatabase(sessions.build().db);
          secondDatabase = QueryCountingDatabase(sessions.build().db);
          first = OfflineSyncDatabaseSession(
            firstDatabase,
            syncTables: server.syncTables,
            context: shared,
          );
          second = OfflineSyncDatabaseSession(
            secondDatabase,
            syncTables: server.syncTables,
            context: shared,
          );
        });

        group('when two sessions initialize together and a later session opens,', () {
          late int initialProjectionRows;
          late int laterProjectionRows;
          late CrdtSchemaColumn? repairedColumn;
          late List<server.Person> stored;

          setUpAll(() async {
            await Future.wait([first.db.initialize(), second.db.initialize()]);
            repairedColumn = await CrdtSchemaColumn.db.findFirstRow(
              raw,
              where: (t) => t.tbl.name.equals('city') & t.name.equals('name'),
            );
            initialProjectionRows =
                _projectionRows(firstDatabase) + _projectionRows(secondDatabase);
            final laterDatabase = QueryCountingDatabase(sessions.build().db);
            final later = OfflineSyncDatabaseSession(
              laterDatabase,
              syncTables: server.syncTables,
              context: shared,
            );
            await later.db.initialize();
            laterProjectionRows = _projectionRows(laterDatabase);
            stored = await server.Person.db.find(
              raw,
              where: (t) => t.id.inSet(people.map((p) => p.id!).toSet()),
            );
          });

          test(
            'then registry repair rebuilds the stored projection once across concurrent sessions.',
            () {
              expect(repairedColumn, isNotNull);
              expect(initialProjectionRows, people.length);
            },
          );

          test('then later sessions do not scan projection rows again.', () {
            expect(laterProjectionRows, 0);
          });

          test('then the stored domain values remain intact.', () {
            expect(
              {for (final row in stored) row.id: row.name},
              {for (final row in people) row.id: row.name},
            );
          });
        });
      });

      group('Given a registry repair whose first projection read fails,', () {
        late OfflineSyncDatabaseContext shared;
        late OfflineSyncDatabaseSession failing;
        late _FailingProjectionDatabase failingDatabase;

        setUpAll(() async {
          final seed = OfflineSyncDatabaseSession.wraps(
            raw,
            syncTables: server.syncTables,
          );
          await seed.db.initialize();
          await seed.db.transactionForUser(
            const Uuid().v7obj(),
            (tx) => server.Person.db.insertRow(
              seed,
              server.Person(name: 'retry survives'),
              transaction: tx,
            ),
          );
          await _removeUnusedCityColumn(raw);
          shared = OfflineSyncDatabaseContext(
            syncTables: server.syncTables,
            serializationManager: raw.db.serializationManager,
          );
          failingDatabase = _FailingProjectionDatabase(sessions.build().db);
          failing = OfflineSyncDatabaseSession(
            failingDatabase,
            syncTables: server.syncTables,
            context: shared,
          );
        });

        group('when initialization fails and a new session retries,', () {
          late Object? firstFailure;
          late int retryProjectionRows;
          late int subsequentProjectionRows;

          setUpAll(() async {
            firstFailure = await failing.db.initialize().then<Object?>(
              (_) => null,
              onError: (Object error) => error,
            );
            final retryDatabase = QueryCountingDatabase(sessions.build().db);
            final retry = OfflineSyncDatabaseSession(
              retryDatabase,
              syncTables: server.syncTables,
              context: shared,
            );
            await retry.db.initialize();
            retryProjectionRows = _projectionRows(retryDatabase);
            final subsequentDatabase = QueryCountingDatabase(sessions.build().db);
            final subsequent = OfflineSyncDatabaseSession(
              subsequentDatabase,
              syncTables: server.syncTables,
              context: shared,
            );
            await subsequent.db.initialize();
            subsequentProjectionRows = _projectionRows(subsequentDatabase);
          });

          test(
            'then the failure is surfaced and the next session completes the rebuild.',
            () {
              expect(
                firstFailure,
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  'injected projection read failure',
                ),
              );
              expect(retryProjectionRows, greaterThan(0));
            },
          );

          test('then successful retry is remembered by subsequent sessions.', () {
            expect(subsequentProjectionRows, 0);
          });
        });
      });
    },
  );
}

int _projectionRows(QueryCountingDatabase database) =>
    database.rowsReadByType['CrdtDataRow'] ?? 0;

Future<void> _removeUnusedCityColumn(Session session) async {
  final column = (await CrdtSchemaColumn.db.findFirstRow(
    session,
    where: (t) => t.tbl.name.equals('city') & t.name.equals('name'),
  ))!;
  await CrdtSchemaColumn.db.deleteRow(session, column);
}

class _FailingProjectionDatabase extends QueryCountingDatabase {
  // The superclass positional parameter is library-private.
  // ignore: matching_super_parameters
  _FailingProjectionDatabase(super.delegate);

  var _failed = false;

  @override
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    if (T == CrdtDataRow && !_failed) {
      _failed = true;
      throw StateError('injected projection read failure');
    }

    return super.find<T>(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }
}
