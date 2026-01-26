import 'package:drift/drift.dart';

import '../utils/sql_builder.dart';
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
  CrdtDatabase(
    super.e, {
    required this.userId,
    required this.nodeId,
    required this.synchronizedTables,
  });

  /// The user ID for the CRDT system.
  final String userId;

  /// The node ID for the CRDT system.
  final String nodeId;

  /// Tables to be synchronized with CRDT.
  final List<TableInfo> synchronizedTables;

  /// The SQL builder for the CRDT data table.
  late final sqlBuilder = CrdtDataSqlBuilder(this);

  /// Whether the database is using the SQLite or Postgres dialect.
  bool get isPostgres => executor.dialect == SqlDialect.postgres;

  /// Not actually used, but required by the generated code. Will be ignored because
  /// the [CrdtDatabase] always receives an already opened executor. No migrations
  /// should ever be run on this database to avoid messing with the user schema.
  @override
  int schemaVersion = 1;
}

/// Extension methods for the [List<TableInfo>] class to find a synchronized table.
extension FindSynchronizedTable on List<TableInfo> {
  /// Gets the table names of the synchronized tables.
  Iterable<String> get tableNames => map((t) => t.actualTableName);

  /// Gets the synchronized table information for the given table name.
  ///
  /// If the table is not found, an [ArgumentError] is thrown.
  TableInfo find<T extends Insertable>([String? tableName]) {
    if (tableName == null && T == dynamic) {
      throw ArgumentError('Table name is required when T is dynamic.');
    }
    return firstWhere(
      (t) =>
          (tableName == null && t is TableInfo<Table, T>) ||
          t.actualTableName == tableName,
      orElse: () => throw ArgumentError(
        'Table ${tableName != null ? '"$tableName"' : 'for type "$T"'} not '
        'found in synchronized tables.',
      ),
    );
  }
}
