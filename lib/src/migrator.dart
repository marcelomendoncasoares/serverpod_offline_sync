import 'package:drift/drift.dart';

import 'crdt/crdt.dart';
import 'database/database.dart';
import 'database/triggers.dart';
import 'hlc/stateful.dart';

/// The bias to use when conflicting operations are detected.
enum ConflictingBias {
  /// Newer updates are overridden by deletes.
  deleteWins,

  /// Deletes are undone by newer conflicting updates.
  updateWins,
}

/// Runs migrations declared by a [MigrationStrategy].
class OfflineSyncMigrator extends Migrator {
  /// Used internally by drift when opening the database.
  OfflineSyncMigrator(
    super.database, {
    required this.userId,
    required this.nodeId,
    this.conflictingBias = ConflictingBias.deleteWins,

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

  /// The bias to use when conflicting operations are detected.
  ///
  /// The default is [ConflictingBias.deleteWins], which is the most common case.
  final ConflictingBias conflictingBias;

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

    // Populate the schema tables and node table
    await _populateSchemaAndNodes();

    if (crdtDb.isPostgres) {
      final crdtTable = crdtDb.crdtDataTable;
      await database.customStatement(
        'ALTER TABLE ${crdtTable.actualTableName} '
        // TODO: Fix this partitioning, since RANGE can not be used for discrete values.
        'PARTITION BY RANGE (${crdtTable.userId.name}, ${crdtTable.tableId.name});',
      );

      // TODO: Alter all ON DELETE FK constraints from RESTRICT to NO ACTION.
      // TODO: Alter all FK constraints to be deferrable initially deferred.
    }

    for (final table in synchronizedTables) {
      await _createTriggers(table);
    }
  }

  /// Populates the schema tables and nodes table.
  ///
  /// This method must be called after creating the CRDT control tables but before
  /// creating triggers, as triggers depend on the schema being populated.
  Future<void> _populateSchemaAndNodes() async {
    // First, ensure the current node exists and has ID 1
    await _ensureCurrentNodeIsFirst();

    // Register the normalized node ID for StatefulHlc
    StatefulHlc.registerNormalizedNodeId(nodeId, 1);

    // Initialize a StatefulHlc instance for this user/node to ensure it's cached
    StatefulHlc.cached(userId, nodeId);

    // Then populate schema tables for all synchronized tables
    for (final table in synchronizedTables) {
      await _populateSchemaForTable(table);
    }

    // Clear the cache after population to ensure fresh data on next access
    crdtDb.clearSchemaCache();
  }

  /// Ensures the current node is registered with ID 1.
  ///
  /// If the node already exists, it will not be re-inserted. If it exists
  /// with a different ID, an error is thrown as the schema is inconsistent.
  Future<void> _ensureCurrentNodeIsFirst() async {
    // Check if current node exists
    final existing = await (crdtDb.select(crdtDb.crdtNodesTable)
          ..where((t) => t.nodeId.equals(nodeId)))
        .getSingleOrNull();

    if (existing != null) {
      if (existing.id != 1) {
        throw StateError(
          'Current node "$nodeId" exists with ID ${existing.id} but must have ID 1. '
          'This indicates a corrupted schema. Please reset the database.',
        );
      }
      // Node already exists with correct ID
      return;
    }

    // Check if ID 1 is already taken by another node
    final nodeWithId1 = await (crdtDb.select(crdtDb.crdtNodesTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    if (nodeWithId1 != null) {
      throw StateError(
        'Node ID 1 is already taken by "${nodeWithId1.nodeId}" but current node is "$nodeId". '
        'The current node must always be registered with ID 1. Please reset the database.',
      );
    }

    // Insert current node with explicit ID 1
    // Note: This assumes the database supports explicit ID insertion for autoincrement fields
    await crdtDb.into(crdtDb.crdtNodesTable).insert(
          CrdtNodesTableCompanion.insert(
            id: const Value(1),
            nodeId: nodeId,
          ),
        );
  }

  /// Populates the schema tables for a given table.
  ///
  /// This registers the table name and all its column names in the normalized
  /// schema tables. If entries already exist, they will not be re-inserted.
  Future<void> _populateSchemaForTable(TableInfo table) async {
    final tableName = table.actualTableName;

    // Insert or get existing table ID
    await crdtDb.into(crdtDb.crdtSchemaTablesTable).insert(
          CrdtSchemaTablesTableCompanion.insert(tableName: tableName),
          mode: InsertMode.insertOrIgnore,
        );

    final tableId = await crdtDb.getTableId(tableName);

    // Insert all columns for this table
    final columns = table.$columns.map((c) => c.$name).toSet();
    // Also include the special "__crdt_is_deleted" column
    columns.add(crdtDb.sqlBuilder.isDeletedColumnName);

    for (final columnName in columns) {
      await crdtDb.into(crdtDb.crdtSchemaColumnsTable).insert(
            CrdtSchemaColumnsTableCompanion.insert(
              tableId: tableId,
              columnName: columnName,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _createTriggers(TableInfo table) async {
    final triggerCreator = switch (database.executor.dialect) {
      SqlDialect.sqlite => Sqlite3OfflineSyncTriggers(crdtDb, conflictingBias),
      // TODO: Implement the triggers for the Postgres dialect.
      _ => throw UnsupportedError('Unsupported dialect: ${database.executor.dialect}'),
    };
    final triggers = await triggerCreator.generateCreateTriggerStatements(table);
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
      // Populate schema for the new table
      await _populateSchemaForTable(table);
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
    
    // Refresh schema after migration
    if (synchronizedTables.contains(table)) {
      await _populateSchemaForTable(table);
      crdtDb.clearSchemaCache();
    }
    
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
