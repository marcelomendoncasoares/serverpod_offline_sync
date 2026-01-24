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
