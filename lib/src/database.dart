import 'package:drift/drift.dart';

import 'tables/compensation.dart';
import 'tables/control.dart';
import 'tables/data.dart';
import 'tables/merge.dart';

part 'database.g.dart';

/// The main database class for CRDT synchronization.
@DriftDatabase(
  tables: [
    CrdtDataTable,
    CrdtControlTable,
    CrdtCompensationTable,
    CrdtMergeHlcTable,
  ],
)
class CrdtDatabase extends _$CrdtDatabase {
  /// Creates a new instance of [CrdtDatabase] with the provided [executor].
  CrdtDatabase(super.e, {required this.synchronizedTables});

  /// Tables to be synchronized with CRDT.
  final List<TableInfo> synchronizedTables;

  /// Whether the database is using the SQLite or Postgres dialect.
  bool get isPostgres => executor.dialect == SqlDialect.postgres;

  /// Not actually used, but required by the generated code. Will be ignored because
  /// the [CrdtDatabase] always receives an already opened executor. No migrations
  /// should ever be run on this database to avoid messing with the user schema.
  @override
  int schemaVersion = 1;
}

/// Extensions for [CrdtDatabase] to extract data from the CRDT data table.
extension CrdtDatabaseDataEntryExtensions on CrdtDatabase {
  /// Gets a single data entry from the CRDT data table.
  Future<T?> getSingleFromCrdtData<T extends DataClass>({
    required String tableName,
    required String rowId,
  }) async {
    final data = await getFromCrdtData<T>(tableName: tableName, rowIds: [rowId]);
    return data.firstOrNull;
  }

  /// Gets a list of data entries from the CRDT data table.
  Future<List<T>> getFromCrdtData<T extends DataClass>({
    required String tableName,
    required List<String> rowIds,
  }) async {
    final tableInfo = synchronizedTables.firstWhere(
      (t) => t.actualTableName == tableName,
      orElse: () => throw ArgumentError(
        'Table $tableName not found in synchronized tables.',
      ),
    );

    final crdtDataEntries = await managers.crdtDataTable
        .filter((o) => o.tblName.equals(tableName) & o.rowId.isIn(rowIds))
        .get();

    return crdtDataEntries.convert<T>(tableInfo);
  }
}

extension on List<CrdtDataEntry> {
  Future<List<T>> convert<T extends DataClass>(TableInfo tableInfo) async {
    final foundRowIds = map((e) => e.rowId).toSet();
    return [
      for (final rowId in foundRowIds)
        await tableInfo.map({
          for (final c in tableInfo.$columns)
            c.$name: firstWhere((e) => e.rowId == rowId && e.columnName == c.$name)
                .rawValue
                ?.rawSqlValue,
        }) as T,
    ];
  }
}
