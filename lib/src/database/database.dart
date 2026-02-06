import 'package:drift/drift.dart';

import '../utils/sql_builder.dart';
import 'tables/control.dart';
import 'tables/data.dart';
import 'tables/hlc.dart';
import 'tables/merge.dart';

part 'database.g.dart';

/// The main database class for CRDT synchronization.
@DriftDatabase(
  tables: [
    CrdtDataTable,
    CrdtControlTable,
    CrdtHlcStateTable,
    CrdtMergeHlcTable,
  ],
)
class CrdtDatabase extends _$CrdtDatabase {
  /// Creates a new instance of [CrdtDatabase] with the provided [executor].
  CrdtDatabase(
    this.userDatabase, {
    required this.userId,
    required this.nodeId,
    required this.synchronizedTables,
  }) : super(
         userDatabase.executor.interceptWith(
           _EnsureHlcInitialized(userDatabase),
         ),
       );

  /// The user database to synchronize with.
  final GeneratedDatabase userDatabase;

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

class _EnsureHlcInitialized extends QueryInterceptor {
  _EnsureHlcInitialized(this.userDatabase);

  final GeneratedDatabase userDatabase;

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) async {
    return executor.ensureOpen(_EnsureHlcInitializedUser(user, userDatabase));
  }
}

class _EnsureHlcInitializedUser implements QueryExecutorUser {
  _EnsureHlcInitializedUser(this.user, this.userDatabase);

  final QueryExecutorUser user;
  final GeneratedDatabase userDatabase;

  /// This must be set to the [schemaVersion] of the [userDatabase] to ensure
  /// that the `PRAGMA user_version` is correctly updated after migrations are
  /// applied. Otherwise, the saved version will match the CRDT database version.
  @override
  int get schemaVersion => userDatabase.schemaVersion;

  /// If this method is reached, it means that the CRDT database is being opened
  /// before the user database. This method will ensure that the user database is
  /// always opened first. When, on the opposite, the user database is opened before
  /// the CRDT database, this method will never be called.
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {
    final userDetails = OpeningDetails(
      details.versionBefore,
      userDatabase.schemaVersion,
    );
    await userDatabase.beforeOpen(executor, userDetails);

    // This means an explicit opt-out from Drift managed migrations. Since the
    // [userDatabase] will be migrated first, by using its [schemaVersion] on
    // the [crdtDetails], the CRDT database will skip migrations entirely. If
    // migrations are needed for the CRDT database in the future, they should
    // be hooked manually on this method.
    final crdtDetails = OpeningDetails(
      userDatabase.schemaVersion,
      userDatabase.schemaVersion,
    );
    await user.beforeOpen(executor, crdtDetails);
  }
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
