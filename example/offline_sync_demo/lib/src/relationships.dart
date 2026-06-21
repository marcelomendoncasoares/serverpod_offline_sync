import 'package:serverpod_database/serverpod_database.dart'
    show ColumnDefinition, ColumnType, ForeignKeyAction, TableDefinition;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;

import 'models.dart';

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
/// menus, edge badges, and generic row construction stay in sync with the model
/// with zero hand-maintained tables.
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

  TableDefinition? definition(String table) => _byName[table];

  /// Relationships whose parent is [table] — i.e. the kinds of child rows that
  /// can be attached to it. Drives the "+ child" menu.
  List<Relationship> childRelationshipsOf(String table) =>
      _inbound[table] ?? const [];

  /// This table's own foreign keys — the references that can be re-pointed or
  /// detached. Drives the "move" picker and tree nesting.
  List<Relationship> parentRelationshipsOf(String table) =>
      _outbound[table] ?? const [];

  /// Tables that can be created without an existing parent (every required
  /// foreign key has a default, and every required column is fillable).
  List<String> get creatableRootTables {
    final result = <String>[];
    for (final table in _byName.keys) {
      if (buildRowJson(table) != null) result.add(table);
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

  /// A short human label for [json] of [table].
  String displayLabel(String table, Map<String, dynamic> json) {
    final column = displayColumn(table);
    final value = json[column];
    if (value == null) return '(${shortId(_idOf(json))})';
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

  /// Builds a JSON row for [table] ready to insert, filling required columns and
  /// optionally pointing [fkColumn] at [fkValue]. Returns null when the table
  /// cannot be safely constructed generically (e.g. it has a required blob or a
  /// required parent with no default).
  Map<String, dynamic>? buildRowJson(
    String table, {
    String? fkColumn,
    protocol.UuidValue? fkValue,
    String? label,
  }) {
    final definition = _byName[table];
    if (definition == null) return null;

    final fkColumnNames = {
      for (final fk in definition.foreignKeys)
        if (fk.columns.length == 1) fk.columns.single,
    };
    final display = displayColumn(table);
    final rowLabel = label ?? _defaultLabel(table);

    final json = <String, dynamic>{'id': newId().uuid};
    for (final column in definition.columns) {
      if (column.name == 'id' || column.name == 'scopeId') continue;
      if (column.name.startsWith('_')) continue;

      if (column.name == fkColumn) {
        json[column.name] = fkValue?.uuid;
        continue;
      }
      if (column.name == display) {
        json[column.name] = column.columnType == ColumnType.uuid
            ? newId().uuid
            : rowLabel;
        continue;
      }
      if (column.isNullable) continue;

      final isFk = fkColumnNames.contains(column.name);
      if (isFk) {
        final fallback = _cleanDefault(column.columnDefault);
        if (fallback == null) return null;
        json[column.name] = fallback;
        continue;
      }

      final value = _defaultValueFor(column, rowLabel);
      if (value == _unfillable) return null;
      json[column.name] = value;
    }
    return json;
  }

  static const Object _unfillable = Object();

  Object? _defaultValueFor(ColumnDefinition column, String label) {
    final cleaned = _cleanDefault(column.columnDefault);
    if (cleaned != null) return cleaned;
    return switch (column.columnType) {
      ColumnType.text => label,
      ColumnType.uuid => newId().uuid,
      ColumnType.boolean => false,
      ColumnType.integer => 0,
      ColumnType.bigint => (column.dartType ?? '').contains('BigInt') ? '0' : 0,
      ColumnType.doublePrecision => 0,
      ColumnType.timestampWithoutTimeZone =>
        DateTime.now().toUtc().toIso8601String(),
      _ => _unfillable,
    };
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

  static String? _cleanDefault(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    final cast = value.indexOf('::');
    if (cast != -1) value = value.substring(0, cast).trim();
    if (value.length >= 2 && value.startsWith("'") && value.endsWith("'")) {
      value = value.substring(1, value.length - 1);
    }
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'null') return null;
    if (lower.startsWith('gen_random_uuid') || lower.startsWith('nextval')) {
      return null;
    }
    return value;
  }

  static protocol.UuidValue? _idOf(Map<String, dynamic> json) {
    final raw = json['id'];
    if (raw == null) return null;
    return protocol.UuidValue.withValidation('$raw');
  }
}
