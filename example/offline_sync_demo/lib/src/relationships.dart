import 'package:serverpod_database/serverpod_database.dart'
    show ColumnType, ForeignKeyAction, TableDefinition, TableRow;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;

import 'models.dart';
import 'table_ops.dart';

/// The referential action a foreign key takes when its parent is deleted.
///
/// This is the whole point of the FK-conflict demo, so it is surfaced directly
/// on every relationship edge.
enum FkAction {
  restrict('Restrict', 'blocks the delete'),
  cascade('Cascade', 'deletes children'),
  setNull('SetNull', 'nulls the reference'),
  setDefault('SetDefault', 'resets to default'),
  noAction('NoAction', 'no enforced action');

  const FkAction(this.label, this.summary);

  final String label;
  final String summary;

  static FkAction from(ForeignKeyAction? action) => switch (action) {
    ForeignKeyAction.cascade => FkAction.cascade,
    ForeignKeyAction.restrict => FkAction.restrict,
    ForeignKeyAction.setNull => FkAction.setNull,
    ForeignKeyAction.setDefault => FkAction.setDefault,
    _ => FkAction.noAction,
  };
}

/// A single foreign-key edge: [childTable].[fkColumn] → [parentTable], with the
/// [onDelete] action that fires when the parent row is removed.
class Relationship {
  Relationship({
    required this.childTable,
    required this.fkColumn,
    required this.parentTable,
    required this.onDelete,
  });

  final String childTable;
  final String fkColumn;
  final String parentTable;
  final FkAction onDelete;
}

/// Metadata-driven view of the synced schema.
///
/// Everything here is computed once from [protocol.Protocol.targetTableDefinitions]
/// (the same table definitions the client already ships), so the relationship
/// menus and edge badges stay in sync with the generated model.
class RelationshipCatalog {
  RelationshipCatalog._(this._byName, this._inbound, this._outbound);

  final Map<String, TableDefinition> _byName;
  final Map<String, List<Relationship>> _inbound;
  final Map<String, List<Relationship>> _outbound;

  static RelationshipCatalog build(Set<String> syncedTables) {
    final byName = <String, TableDefinition>{
      for (final table in protocol.Protocol.targetTableDefinitions)
        if (syncedTables.contains(table.name)) table.name: table,
    };

    final outbound = <String, List<Relationship>>{};
    final inbound = <String, List<Relationship>>{};
    for (final table in byName.values) {
      outbound[table.name] = [];
      inbound.putIfAbsent(table.name, () => []);
    }

    for (final table in byName.values) {
      for (final fk in table.foreignKeys) {
        // Only simple, user-visible relationships: single column, not one of
        // the generated `_relationBackref` columns, and pointing at a table we
        // actually render.
        if (fk.columns.length != 1) continue;
        final column = fk.columns.single;
        if (column.startsWith('_')) continue;
        if (!byName.containsKey(fk.referenceTable)) continue;

        final relationship = Relationship(
          childTable: table.name,
          fkColumn: column,
          parentTable: fk.referenceTable,
          onDelete: FkAction.from(fk.onDelete),
        );
        outbound[table.name]!.add(relationship);
        inbound[fk.referenceTable]!.add(relationship);
      }
    }

    return RelationshipCatalog._(byName, inbound, outbound);
  }

  Iterable<String> get tables => _byName.keys;

  /// Relationships whose parent is [table] — i.e. the kinds of child rows that
  /// can be attached to it. Drives the "+ child" menu.
  List<Relationship> childRelationshipsOf(String table) =>
      _inbound[table] ?? const [];

  /// This table's own foreign keys — the references that can be re-pointed or
  /// detached. Drives the "move" picker and tree nesting.
  List<Relationship> parentRelationshipsOf(String table) =>
      _outbound[table] ?? const [];

  /// Tables listed in the "+ New row" menu, as declared by
  /// [demoTableOps.canCreateRoot].
  List<String> get creatableRootTables {
    final result = <String>[];
    for (final table in _byName.keys) {
      if (demoTableOps[table]?.canCreateRoot ?? false) result.add(table);
    }
    result.sort();
    return result;
  }

  /// The column used as a row's human label (e.g. `name`, `street`, `value`).
  String displayColumn(String table) {
    final definition = _byName[table];
    if (definition == null) return 'id';
    const preferred = ['name', 'street', 'aText', 'value', 'title', 'label'];
    for (final candidate in preferred) {
      if (definition.columns.any((c) => c.name == candidate)) return candidate;
    }
    for (final column in definition.columns) {
      if (_isSystemColumn(column.name)) continue;
      if (column.columnType == ColumnType.text) return column.name;
    }
    for (final column in definition.columns) {
      if (_isSystemColumn(column.name)) continue;
      if (column.columnType == ColumnType.uuid) return column.name;
    }
    return 'id';
  }

  /// A short human label for [row].
  String displayLabel(TableRow<protocol.UuidValue?> row) {
    final table = row.table.tableName;
    final json = row.toJson() as Map<String, dynamic>;
    final column = displayColumn(table);
    final value = json[column];
    if (value == null) return '(${shortId(row.id)})';
    final definition = _byName[table];
    final isUuid =
        definition?.columns
            .firstWhere(
              (c) => c.name == column,
              orElse: () => definition.columns.first,
            )
            .columnType ==
        ColumnType.uuid;
    final text = '$value';
    if (isUuid && text.length >= 8) return text.substring(0, 8);
    return text;
  }

  /// Builds a generated row for [table], optionally assigning one foreign key.
  /// Required fields and defaults remain owned by the generated constructors.
  TableRow<protocol.UuidValue?>? buildRow(
    String table, {
    String? fkColumn,
    protocol.UuidValue? fkValue,
    String? label,
  }) {
    final create = demoTableOps[table]?.create;
    if (create == null) return null;
    return create(newId(), label ?? _defaultLabel(table), {
      if (fkColumn != null && fkValue != null) fkColumn: fkValue,
    });
  }

  String _defaultLabel(String table) {
    final words = table.split('_').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    });
    return words.join(' ');
  }

  static bool _isSystemColumn(String name) =>
      name == 'id' || name == 'scopeId' || name.startsWith('_');
}
