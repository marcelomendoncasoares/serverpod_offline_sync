import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given equivalent schemas with different table and column order when computeSyncTablesHash is called then the hash is stable.',
    () {
      final manager = _FakeSerializationManager([
        _childDefinition(
          onDelete: ForeignKeyAction.cascade,
          uniqueIndexColumns: ['name'],
        ),
        _alphaDefinition(),
      ]);

      final leftTables = [_AlphaTable(), _ChildTable()];
      final rightTables = [
        _ChildTable(reversedColumns: true),
        _AlphaTable(reversedColumns: true),
      ];

      CrdtSync.initialize(syncTables: leftTables, serializationManager: manager);
      final leftHash = CrdtSync.computeSyncTablesHash(leftTables);

      CrdtSync.initialize(syncTables: rightTables, serializationManager: manager);
      final rightHash = CrdtSync.computeSyncTablesHash(rightTables);

      expect(rightHash, leftHash);
    },
  );

  test(
    'Given schemas with different columns when computeSyncTablesHash is called then the hash changes.',
    () {
      final manager = _FakeSerializationManager([
        _alphaDefinition(columns: ['id', 'name']),
      ]);
      final baseTables = [_AlphaTable()];
      final changedTables = [_AlphaTable(includeNote: true)];

      CrdtSync.initialize(syncTables: baseTables, serializationManager: manager);
      final baseHash = CrdtSync.computeSyncTablesHash(baseTables);

      CrdtSync.initialize(syncTables: changedTables, serializationManager: manager);
      final changedHash = CrdtSync.computeSyncTablesHash(changedTables);

      expect(changedHash, isNot(baseHash));
    },
  );

  test(
    'Given schemas with different foreign key definitions when computeSyncTablesHash is called then the hash changes.',
    () {
      final syncTables = [_ParentTable(), _ChildTable()];
      final baseManager = _FakeSerializationManager([
        _parentDefinition(),
        _childDefinition(onDelete: ForeignKeyAction.restrict),
      ]);
      final changedManager = _FakeSerializationManager([
        _parentDefinition(),
        _childDefinition(onDelete: ForeignKeyAction.cascade),
      ]);

      CrdtSync.initialize(syncTables: syncTables, serializationManager: baseManager);
      final baseHash = CrdtSync.computeSyncTablesHash(syncTables);

      CrdtSync.initialize(syncTables: syncTables, serializationManager: changedManager);
      final changedHash = CrdtSync.computeSyncTablesHash(syncTables);

      expect(changedHash, isNot(baseHash));
    },
  );

  test(
    'Given schemas with different unique indexes when computeSyncTablesHash is called then the hash changes.',
    () {
      final syncTables = [_ChildTable()];
      final baseManager = _FakeSerializationManager([
        _childDefinition(
          onDelete: ForeignKeyAction.cascade,
          uniqueIndexColumns: ['name'],
        ),
      ]);
      final changedManager = _FakeSerializationManager([
        _childDefinition(
          onDelete: ForeignKeyAction.cascade,
          uniqueIndexColumns: ['parentId'],
        ),
      ]);

      CrdtSync.initialize(syncTables: syncTables, serializationManager: baseManager);
      final baseHash = CrdtSync.computeSyncTablesHash(syncTables);

      CrdtSync.initialize(syncTables: syncTables, serializationManager: changedManager);
      final changedHash = CrdtSync.computeSyncTablesHash(syncTables);

      expect(changedHash, isNot(baseHash));
    },
  );
}

class _FakeSerializationManager extends DatabaseSerializationManager {
  _FakeSerializationManager(this._definitions);

  final List<TableDefinition> _definitions;

  @override
  T deserialize<T>(dynamic data, [Type? t]) => throw UnimplementedError();

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  String? getClassNameForObject(Object? data) => null;

  @override
  String getModuleName() => 'test';

  @override
  Table? getTableForType(Type t) => null;

  @override
  List<TableDefinition> getTargetTableDefinitions() => _definitions;
}

class _AlphaTable extends Table<UuidValue> {
  _AlphaTable({this.includeNote = false, this.reversedColumns = false})
    : super(tableName: 'alpha');

  final bool includeNote;
  final bool reversedColumns;

  late final ColumnString name = ColumnString('name', this);
  late final ColumnString note = ColumnString('note', this);

  @override
  List<Column> get columns {
    final columns = <Column>[id, name, if (includeNote) note];
    return reversedColumns ? columns.reversed.toList() : columns;
  }
}

class _ParentTable extends Table<UuidValue> {
  _ParentTable() : super(tableName: 'parent');

  late final ColumnString name = ColumnString('name', this);

  @override
  List<Column> get columns => [id, name];
}

class _ChildTable extends Table<UuidValue> {
  _ChildTable({this.reversedColumns = false}) : super(tableName: 'child');

  final bool reversedColumns;

  late final ColumnUuid parentId = ColumnUuid('parentId', this);
  late final ColumnString name = ColumnString('name', this);

  @override
  List<Column> get columns {
    final columns = <Column>[id, parentId, name];
    return reversedColumns ? columns.reversed.toList() : columns;
  }
}

TableDefinition _alphaDefinition({List<String> columns = const ['id', 'name']}) {
  return TableDefinition(
    name: 'alpha',
    dartName: 'Alpha',
    schema: 'public',
    module: 'test',
    columns: [
      for (final column in columns)
        ColumnDefinition(
          name: column,
          columnType: column == 'id' ? ColumnType.uuid : ColumnType.text,
          isNullable: false,
          dartType: column == 'id' ? 'UuidValue?' : 'String',
        ),
    ],
    foreignKeys: const [],
    indexes: const [],
  );
}

TableDefinition _parentDefinition() {
  return TableDefinition(
    name: 'parent',
    dartName: 'Parent',
    schema: 'public',
    module: 'test',
    columns: [
      ColumnDefinition(
        name: 'id',
        columnType: ColumnType.uuid,
        isNullable: false,
        dartType: 'UuidValue?',
      ),
      ColumnDefinition(
        name: 'name',
        columnType: ColumnType.text,
        isNullable: false,
        dartType: 'String',
      ),
    ],
    foreignKeys: const [],
    indexes: const [],
  );
}

TableDefinition _childDefinition({
  required ForeignKeyAction onDelete,
  List<String>? uniqueIndexColumns,
}) {
  return TableDefinition(
    name: 'child',
    dartName: 'Child',
    schema: 'public',
    module: 'test',
    columns: [
      ColumnDefinition(
        name: 'id',
        columnType: ColumnType.uuid,
        isNullable: false,
        dartType: 'UuidValue?',
      ),
      ColumnDefinition(
        name: 'parentId',
        columnType: ColumnType.uuid,
        isNullable: false,
        dartType: 'UuidValue',
      ),
      ColumnDefinition(
        name: 'name',
        columnType: ColumnType.text,
        isNullable: false,
        dartType: 'String',
      ),
    ],
    foreignKeys: [
      ForeignKeyDefinition(
        constraintName: 'child_parent_fk',
        columns: ['parentId'],
        referenceTable: 'parent',
        referenceTableSchema: 'public',
        referenceColumns: ['id'],
        onDelete: onDelete,
      ),
    ],
    indexes: [
      if (uniqueIndexColumns != null)
        IndexDefinition(
          indexName: 'child_unique_idx',
          elements: [
            for (final column in uniqueIndexColumns)
              IndexElementDefinition(
                type: IndexElementDefinitionType.column,
                definition: column,
              ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
    ],
  );
}
