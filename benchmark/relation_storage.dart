import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'utils/benchmark.dart';
import 'utils/tables.dart';

const _measuredObjects = <String>[
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx',
];

const _fieldObjects = <String>{
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
};

const _foreignKeyObjects = <String>{
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx',
};

const _domainObjects = <String>{'person', 'sqlite_autoindex_person_1'};

Future<void> main(List<String> args) async {
  final rowCount = _readRowCount(args);
  final benchmark = RelationStorageBenchmark(rowCount: rowCount);
  final result = await benchmark.measure();
  _printReport(result);
}

int _readRowCount(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--rows=')) {
      final value = int.tryParse(arg.substring('--rows='.length));
      if (value == null || value <= 0) {
        throw ArgumentError.value(arg, '--rows', 'Must be a positive integer.');
      }
      return value;
    }
  }
  return 10000;
}

class RelationStorageBenchmark {
  RelationStorageBenchmark({required this.rowCount});

  static const _clientUrl = 'http://localhost:8081/';

  final int rowCount;
  final UuidValue _userId = const Uuid().v7obj();

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  late final CrdtDatabaseSession _crdtSession;
  var _hasOpenSession = false;

  Future<RelationStorageResult> measure() async {
    await _setup();
    try {
      final targets = await _insertRelationTargets();
      var rows = await _insertPeople();
      final snapshots = <StorageSnapshot>[await _snapshot(0)];

      rows = await _setRelation(
        rows,
        column: Person.t.organizationId,
        update: (row) => row.copyWith(organizationId: targets.organizationId),
      );
      snapshots.add(await _snapshot(1));

      rows = await _setRelation(
        rows,
        column: Person.t.oldCompanyId,
        update: (row) => row.copyWith(oldCompanyId: targets.companyId),
      );
      snapshots.add(await _snapshot(2));

      await _setRelation(
        rows,
        column: Person.t.cityId,
        update: (row) => row.copyWith(cityId: targets.cityId),
      );
      snapshots.add(await _snapshot(3));

      return RelationStorageResult(rowCount: rowCount, snapshots: snapshots);
    } finally {
      await _teardown();
    }
  }

  Future<void> _setup() async {
    final dbPath = p.join(
      Directory.systemTemp.path,
      'offline_sync_relation_storage_$rowCount.db',
    );
    _dbFile = File(dbPath);
    deleteDatabaseFiles(_dbFile);

    _plainSession = await Client(_clientUrl).createSession(
      _dbFile.path,
      isDebugMode: true,
    );
    _hasOpenSession = true;
    await clearUserTables(_plainSession);

    _crdtSession = CrdtDatabaseSession.wraps(
      _plainSession,
      syncTables: benchmarkSyncTables,
      persistentUserId: _userId,
    );
    await _crdtSession.db.initialize();
  }

  Future<({UuidValue cityId, UuidValue companyId, UuidValue organizationId})>
  _insertRelationTargets() async {
    final city = await City.db.insertRow(
      _crdtSession,
      City(id: const Uuid().v7obj(), name: 'target city'),
    );
    final organization = await Organization.db.insertRow(
      _crdtSession,
      Organization(
        id: const Uuid().v7obj(),
        name: 'target organization',
      ),
    );
    final town = await Town.db.insertRow(
      _crdtSession,
      Town(id: const Uuid().v7obj(), name: 'target town'),
    );
    final company = await Company.db.insertRow(
      _crdtSession,
      Company(
        id: const Uuid().v7obj(),
        name: 'target company',
        townId: town.id,
      ),
    );

    return (
      cityId: city.id!,
      companyId: company.id!,
      organizationId: organization.id!,
    );
  }

  Future<List<Person>> _insertPeople() {
    final rows = [
      for (var i = 0; i < rowCount; i++)
        Person(id: const Uuid().v7obj(), name: 'person'),
    ];
    return Person.db.insert(_crdtSession, rows);
  }

  Future<List<Person>> _setRelation(
    List<Person> rows, {
    required Column<UuidValue?> column,
    required Person Function(Person row) update,
  }) {
    return Person.db.update(
      _crdtSession,
      rows.map(update).toList(),
      columns: (_) => [column],
    );
  }

  Future<StorageSnapshot> _snapshot(int populatedRelationsPerRow) async {
    await _plainSession.db.unsafeExecute('PRAGMA wal_checkpoint(TRUNCATE)');
    await _plainSession.db.unsafeExecute('VACUUM');
    await _plainSession.db.unsafeExecute('PRAGMA wal_checkpoint(TRUNCATE)');

    final pageSize =
        (await _plainSession.db.unsafeQuery('PRAGMA page_size')).first.first as int;
    final pageCount =
        (await _plainSession.db.unsafeQuery('PRAGMA page_count')).first.first as int;
    final rows = await _plainSession.db.unsafeQuery('''
SELECT name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (${_measuredObjects.map((name) => "'$name'").join(', ')})
GROUP BY name
ORDER BY name
''');
    final objects = <String, StorageObject>{
      for (final row in rows)
        row[0] as String: StorageObject(
          allocatedBytes: row[1] as int,
          payloadBytes: row[2] as int,
        ),
    };

    final countRows = await _plainSession.db.unsafeQuery('''
SELECT
  (SELECT COUNT(*) FROM "person"),
  (SELECT COUNT(*) FROM "crdt_data_rows" r
     JOIN "crdt_schema_tables" t ON t."id" = r."tblId"
    WHERE t."name" = 'person'),
  (SELECT COUNT(*) FROM "crdt_data_fields" f
     JOIN "crdt_data_rows" r ON r."id" = f."rowId"
     JOIN "crdt_schema_tables" t ON t."id" = r."tblId"
    WHERE t."name" = 'person'),
  (SELECT COUNT(*) FROM "crdt_data_foreign_key" fk
     JOIN "crdt_data_fields" f ON f."id" = fk."fieldId"
     JOIN "crdt_data_rows" r ON r."id" = f."rowId"
     JOIN "crdt_schema_tables" t ON t."id" = r."tblId"
    WHERE t."name" = 'person')
''');
    final counts = countRows.single;
    final expectedRelationRows = rowCount * populatedRelationsPerRow;
    if (counts[0] != rowCount ||
        counts[1] != rowCount ||
        counts[2] != expectedRelationRows ||
        counts[3] != 0) {
      throw StateError(
        'Unexpected row counts at $populatedRelationsPerRow relations: '
        'person=${counts[0]}, crdt rows=${counts[1]}, fields=${counts[2]}, '
        'foreign keys=${counts[3]}.',
      );
    }

    return StorageSnapshot(
      populatedRelationsPerRow: populatedRelationsPerRow,
      pageSize: pageSize,
      databaseBytes: pageSize * pageCount,
      objects: objects,
      fieldRows: counts[2] as int,
      foreignKeyRows: counts[3] as int,
    );
  }

  Future<void> _teardown() async {
    if (!_hasOpenSession) return;
    await _plainSession.close();
    _hasOpenSession = false;
    deleteDatabaseFiles(_dbFile);
  }
}

class RelationStorageResult {
  const RelationStorageResult({required this.rowCount, required this.snapshots});

  final int rowCount;
  final List<StorageSnapshot> snapshots;
}

class StorageSnapshot {
  const StorageSnapshot({
    required this.populatedRelationsPerRow,
    required this.pageSize,
    required this.databaseBytes,
    required this.objects,
    required this.fieldRows,
    required this.foreignKeyRows,
  });

  final int populatedRelationsPerRow;
  final int pageSize;
  final int databaseBytes;
  final Map<String, StorageObject> objects;
  final int fieldRows;
  final int foreignKeyRows;

  int allocatedFor(Set<String> names) => names.fold(
    0,
    (total, name) => total + (objects[name]?.allocatedBytes ?? 0),
  );

  int payloadFor(Set<String> names) => names.fold(
    0,
    (total, name) => total + (objects[name]?.payloadBytes ?? 0),
  );
}

class StorageObject {
  const StorageObject({
    required this.allocatedBytes,
    required this.payloadBytes,
  });

  final int allocatedBytes;
  final int payloadBytes;
}

void _printReport(RelationStorageResult result) {
  final snapshots = result.snapshots;
  final rowCount = result.rowCount;
  print('# Relation storage benchmark\n');
  print(
    'SQLite, ${snapshots.first.pageSize}-byte pages, $rowCount `person` rows. '
    'Each stage populates one additional UUID foreign key through the real CRDT '
    'update path; `VACUUM` compacts the database before every measurement.\n',
  );
  print('| Relations / row | CRDT field rows | CRDT FK rows | Database size |');
  print('| ---: | ---: | ---: | ---: |');
  for (final snapshot in snapshots) {
    print(
      '| ${snapshot.populatedRelationsPerRow} '
      '| ${snapshot.fieldRows} '
      '| ${snapshot.foreignKeyRows} '
      '| ${snapshot.databaseBytes} B |',
    );
  }

  print(
    '\n| Added relation | Domain | Field table + index | FK table + index | CRDT metadata | Focused total |',
  );
  print('| ---: | ---: | ---: | ---: | ---: | ---: |');
  for (var i = 1; i < snapshots.length; i++) {
    final before = snapshots[i - 1];
    final after = snapshots[i];
    final domain = _perRowDelta(before, after, _domainObjects, rowCount);
    final field = _perRowDelta(before, after, _fieldObjects, rowCount);
    final foreignKey = _perRowDelta(before, after, _foreignKeyObjects, rowCount);
    print(
      '| $i '
      '| ${_bytes(domain)} '
      '| ${_bytes(field)} '
      '| ${_bytes(foreignKey)} '
      '| ${_bytes(field + foreignKey)} '
      '| ${_bytes(domain + field + foreignKey)} |',
    );
  }

  final first = snapshots.first;
  final last = snapshots.last;
  final relationCount = rowCount * (snapshots.length - 1);
  final domain = _perUnitDelta(first, last, _domainObjects, relationCount);
  final field = _perUnitDelta(first, last, _fieldObjects, relationCount);
  final foreignKey = _perUnitDelta(first, last, _foreignKeyObjects, relationCount);
  final metadataPayload =
      (last.payloadFor({..._fieldObjects, ..._foreignKeyObjects}) -
          first.payloadFor({..._fieldObjects, ..._foreignKeyObjects})) /
      relationCount;
  print('\nMean per populated relation:');
  print('- Domain UUID storage: ${_bytes(domain)}');
  print('- CRDT field table and index: ${_bytes(field)}');
  print('- CRDT foreign-key table and index: ${_bytes(foreignKey)}');
  print('- CRDT metadata allocated: ${_bytes(field + foreignKey)}');
  print('- CRDT metadata logical payload: ${_bytes(metadataPayload)}');
  print('- Focused physical total: ${_bytes(domain + field + foreignKey)}');
}

double _perRowDelta(
  StorageSnapshot before,
  StorageSnapshot after,
  Set<String> objects,
  int rowCount,
) => (after.allocatedFor(objects) - before.allocatedFor(objects)) / rowCount;

double _perUnitDelta(
  StorageSnapshot before,
  StorageSnapshot after,
  Set<String> objects,
  int unitCount,
) => (after.allocatedFor(objects) - before.allocatedFor(objects)) / unitCount;

String _bytes(double value) => '${value.toStringAsFixed(2)} B';
