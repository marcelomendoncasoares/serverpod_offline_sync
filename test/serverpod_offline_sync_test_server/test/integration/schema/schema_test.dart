import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  tearDown(() async {
    await CrdtSchemaColumn.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await CrdtSchemaTable.db.deleteWhere(session, where: (t) => Constant.bool(true));
  });

  test(
    'Given a CRDT schema registry with an empty sync table list, '
    'when syncAndGetSchema is called, '
    'then no tables or columns are created.',
    () async {
      final (tableRows, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: [],
      ).syncAndGetSchema();

      expect(tableRows, isEmpty);
      expect(columnRows, isEmpty);
    },
  );

  group(
    'Given a CRDT schema registry with only one table with UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called,',
    () {
      final table = _UuidPkTable();
      late List<CrdtSchemaTable> tableRows;
      late List<CrdtSchemaColumn> columnRows;

      setUp(() async {
        (tableRows, columnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
        ).syncAndGetSchema();
      });

      test(
        'then the table is registered with the correct name and ID.',
        () async {
          expect(tableRows, hasLength(1));
          expect(tableRows.single.name, table.tableName);
          expect(tableRows.single.id, isNotNull);
        },
      );

      final expectedColumnNames = _syncedColumnNames(table);

      test(
        'then the columns are registered with the correct names and IDs.',
        () async {
          expect(columnRows, hasLength(expectedColumnNames.length));
          expect(
            columnRows.map((c) => c.name).toSet(),
            expectedColumnNames,
          );
          expect(columnRows.map((c) => c.tblId).toSet(), {tableRows.single.id!});
        },
      );
    },
  );

  group(
    'Given a CRDT schema registry with tables already registered,',
    () {
      final table = _UuidPkTable();
      late List<CrdtSchemaTable> firstTableRows;
      late List<CrdtSchemaColumn> firstColumnRows;

      setUp(() async {
        (firstTableRows, firstColumnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
        ).syncAndGetSchema();
      });

      test(
        'when syncAndGetSchema is called again with the same tables as the sync list, '
        'then the table and columns are not duplicated.',
        () async {
          final (secondTableRows, secondColumnRows) = await CrdtSchemaRegistry(
            session,
            syncTables: [table],
          ).syncAndGetSchema();

          expect(secondTableRows, hasLength(1));
          expect(secondTableRows.single.name, table.tableName);
          expect(secondTableRows.single.id, firstTableRows.single.id);

          expect(secondColumnRows, hasLength(_syncedColumnNames(table).length));
          expect(
            secondColumnRows.map((c) => c.id).toSet(),
            firstColumnRows.map((c) => c.id).toSet(),
          );
        },
      );
    },
  );

  test(
    'Given a CRDT schema registry with several tables with UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called, '
    'then the tables are registered with the correct names and IDs.',
    () async {
      final tables = [
        _UuidPkTable(name: 'table1'),
        _UuidPkTable(name: 'table2'),
        _UuidPkTable(name: 'table3'),
      ];

      final (tableRows, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: tables,
      ).syncAndGetSchema();

      expect(tableRows, hasLength(tables.length));
      expect(
        tableRows.map((t) => t.name).toSet(),
        tables.map((t) => t.tableName).toSet(),
      );
      expect(
        columnRows,
        hasLength(
          tables.fold<int>(0, (sum, t) => sum + _syncedColumnNames(t).length),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a table with non-UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called, '
    'then an error is thrown.',
    () async {
      const tableName = 'int_pk_table';
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Table<int>(tableName: tableName)],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CRDT can only synchronize tables with a UUID primary key, but '
                '1 table(s) do not have a UUID primary key: "$tableName"',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with a global unique index, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final uniqueDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Unique.t.tableName);
      final scopedUniqueIndex = uniqueDefinition.indexes.singleWhere(
        (index) => index.isUnique && !index.isPrimary,
      );
      final globalUniqueDefinition = uniqueDefinition.copyWith(
        indexes: [
          scopedUniqueIndex.copyWith(
            elements: [
              for (final element in scopedUniqueIndex.elements)
                if (element.definition != 'scopeId') element,
            ],
          ),
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
          tableDefinitions: [globalUniqueDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT can only synchronize tables with per-scope unique indexes',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced one-to-one foreign key unique index, '
    'when syncAndGetSchema is called, '
    'then the index is accepted.',
    () async {
      final (tableRows, _) = await CrdtSchemaRegistry(
        session,
        syncTables: [Address.t, Person.t],
      ).syncAndGetSchema();

      expect(tableRows.map((table) => table.name).toSet(), {
        Address.t.tableName,
        Person.t.tableName,
      });
    },
  );
}

class _UuidPkTable extends Table<UuidValue> {
  _UuidPkTable({String? name}) : super(tableName: name ?? 'uuid_pk_table');

  @override
  List<Column> get columns => [
    id,
    ColumnInt('scopeId', this),
    ColumnString('name', this),
    ColumnBool('is_active', this),
  ];
}

Set<String> _syncedColumnNames(Table table) => {
  for (final column in table.columns)
    if (column.columnName != 'scopeId') column.columnName,
};
