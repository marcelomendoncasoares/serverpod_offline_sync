import 'package:drift/drift.dart';

import '/src/database.dart';
import 'crdt.dart';
import 'triggers.dart';

/// Runs migrations declared by a [MigrationStrategy].
class OfflineSyncMigrator extends Migrator {
  /// Used internally by drift when opening the database.
  OfflineSyncMigrator(
    super.database, {
    required this.userId,
    required this.nodeId,

    /// Restrict tables to synchronize. If not provided, all tables will be considered.
    List<TableInfo>? synchronizedTables,

    /// Optionally specify tables to exclude from synchronization.
    List<TableInfo>? excludeTables,
  }) : synchronizedTables = synchronizedTables ?? database.allTables.toList() {
    if (excludeTables != null) {
      this.synchronizedTables.removeWhere(excludeTables.contains);
    }
    _validateSynchronizedTables();
  }

  /// The user ID for the CRDT system.
  ///
  /// Note that this is the user ID, not the node ID. A user can have multiple nodes,
  /// all sharing the same user ID so that they can synchronize with each other.
  final String userId;

  /// The node ID for the CRDT system.
  ///
  /// A node is a unique identifier for a device or application instance.
  final String nodeId;

  /// Tables to be synchronized with CRDT.
  final List<TableInfo> synchronizedTables;

  /// The database instance to apply the CRDT schema to.
  late final crdtDb = CrdtDatabase(
    database.executor,
    userId: userId,
    nodeId: nodeId,
    synchronizedTables: synchronizedTables,
  );

  /// The CRDT execution instance.
  late final crdt = OfflineSyncCrdt(crdtDb, userId: userId, nodeId: nodeId);

  /// Migrations for tables that are part of the CRDT system.
  final pendingMigrations = <String, CrdtTableMigration>{};

  /// Eagerly validates that all synchronized tables are supported.
  ///
  /// This prevents errors at runtime later if tables do not meet the requirements.
  void _validateSynchronizedTables() {
    for (final table in synchronizedTables) {
      if (table.$primaryKey.isEmpty) {
        throw ArgumentError(
          'Table "${table.actualTableName}" has no primary key and is therefore not '
          'supported to track changes to it. Either add a primary key to the table '
          'or remove it from the synchronized tables list.',
        );
      }
    }
  }

  /// Gets the migration for a table that is part of the CRDT system.
  ///
  /// If the table is not in the list of synchronized tables, a new migration
  /// will be created.
  CrdtTableMigration _register(String tableName) {
    return pendingMigrations.putIfAbsent(
      tableName,
      () => CrdtTableMigration(tableName),
    );
  }

  /// Creates the CRDT-related entities in the database.
  Future<void> createCrdtControl() async {
    for (final table in crdtDb.allTables) {
      await createTable(table);
    }

    if (crdtDb.isPostgres) {
      final crdtTable = crdtDb.crdtDataTable;
      await database.customStatement(
        'ALTER TABLE ${crdtTable.actualTableName} '
        // TODO: Fix this partitioning, since RANGE can not be used for discrete values.
        'PARTITION BY RANGE (${crdtTable.userId.name}, ${crdtTable.tblName.name});',
      );

      // TODO: Alter all ON DELETE FK constraints from RESTRICT to NO ACTION.
      // TODO: Alter all FK constraints to be deferrable initially deferred.
    }

    for (final table in synchronizedTables) {
      await _createTriggers(table);
    }
  }

  Future<void> _createTriggers(TableInfo table) async {
    final triggerCreator = switch (database.executor.dialect) {
      SqlDialect.sqlite => Sqlite3OfflineSyncTriggers(crdtDb),
      // TODO: Implement the triggers for the Postgres dialect.
      _ => throw UnsupportedError('Unsupported dialect: ${database.executor.dialect}'),
    };
    final triggers = triggerCreator.generateCreateTriggerStatements(table);
    for (final trigger in triggers) {
      await database.customStatement(trigger);
    }
  }

  @override
  Future<void> createAll() async {
    await super.createAll();
    await createCrdtControl();
  }

  @override
  Future<void> createTable(TableInfo table) async {
    // Tables that start with 'tmp_for_copy_' are used in alter table operations.
    // We do not want to register them as created tables.
    if (!table.actualTableName.startsWith('tmp_for_copy_')) {
      _register(table.actualTableName).created = true;
    }
    await super.createTable(table);
    if (synchronizedTables.contains(table)) {
      await _createTriggers(table);
    }
  }

  @override
  Future<void> alterTable(TableMigration migration) async {
    final table = migration.affectedTable;
    pendingMigrations.putIfAbsent(
      table.actualTableName,
      () => CrdtTableMigration.from(migration),
    );

    final existingTriggers = await database.getCrdtTriggers();
    for (final trigger in existingTriggers) {
      await database.customStatement('DROP TRIGGER IF EXISTS $trigger;');
    }

    await super.alterTable(migration);
    await _createTriggers(table);
  }

  @override
  Future<void> drop(DatabaseSchemaEntity entity) async {
    if (entity is TableInfo) {
      _register(entity.actualTableName).dropped = true;
    }
    return super.drop(entity);
  }

  @override
  Future<void> deleteTable(String name) async {
    _register(name).dropped = true;
    return super.deleteTable(name);
  }

  @override
  Future<void> addColumn(TableInfo table, GeneratedColumn column) async {
    _register(table.actualTableName).onColumn(column.$name).added = true;
    return super.addColumn(table, column);
  }

  @override
  Future<void> dropColumn(TableInfo table, String column) async {
    _register(table.actualTableName).onColumn(column).dropped = true;
    return super.dropColumn(table, column);
  }

  @override
  Future<void> renameColumn(
    TableInfo table,
    String oldName,
    GeneratedColumn column,
  ) async {
    _register(table.actualTableName).onColumn(column.$name).oldName = oldName;
    return super.renameColumn(table, oldName, column);
  }

  @override
  Future<void> renameTable(TableInfo table, String oldName) async {
    _register(table.actualTableName).oldName = oldName;
    return super.renameTable(table, oldName);
  }
}

/// A migration for a table that is part of the CRDT system.
class CrdtTableMigration {
  /// Creates a new instance of [CrdtTableMigration].
  CrdtTableMigration(this.tableName);

  /// The table that is being migrated.
  final String tableName;

  /// Whether the table was created.
  bool created = false;

  /// Whether the table was dropped.
  bool dropped = false;

  /// The old name of the table, if the table was renamed.
  String? oldName;

  /// The columns that were added.
  final columns = <String, CrdtColumnMigration>{};

  /// Whether the table was modified.
  bool get modified => oldName != null || columns.isNotEmpty;

  /// Gets the migration for a column that is part of the CRDT system.
  ///
  /// If the column is not in the list of synchronized columns, a new migration
  /// will be created.
  CrdtColumnMigration onColumn(String columnName) {
    return columns.putIfAbsent(columnName, () => CrdtColumnMigration(columnName));
  }

  /// Creates a new instance of [CrdtTableMigration] from a [TableMigration].
  static CrdtTableMigration from(TableMigration migration) {
    final table = migration.affectedTable;
    final tableMigration = CrdtTableMigration(table.actualTableName);
    for (final column in migration.newColumns) {
      // TODO: Handle the column transformer.
      tableMigration.onColumn(column.name);
    }
    return tableMigration;
  }
}

/// A migration for a table that is part of the CRDT system.
class CrdtColumnMigration {
  /// Creates a new instance of [CrdtColumnMigration].
  CrdtColumnMigration(this.columnName);

  /// The column that is being migrated.
  final String columnName;

  /// Whether the column was added.
  bool added = false;

  /// Whether the column was dropped.
  bool dropped = false;

  /// The old name of the column, if the column was renamed.
  String? oldName;

  /// Whether the column type was modified.
  bool changedType = false;
}
