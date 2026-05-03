import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
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

      test(
        'then the columns are registered with the correct names and IDs.',
        () async {
          expect(columnRows, hasLength(table.columns.length));
          expect(
            columnRows.map((c) => c.name).toSet(),
            table.columns.map((c) => c.columnName).toSet(),
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

          expect(secondColumnRows, hasLength(table.columns.length));
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
        hasLength(tables.fold<int>(0, (sum, t) => sum + t.columns.length)),
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
}

class _UuidPkTable extends Table<UuidValue> {
  _UuidPkTable({String? name}) : super(tableName: name ?? 'uuid_pk_table');

  @override
  List<Column> get columns => [
    id,
    ColumnString('name', this),
    ColumnBool('is_active', this),
  ];
}
