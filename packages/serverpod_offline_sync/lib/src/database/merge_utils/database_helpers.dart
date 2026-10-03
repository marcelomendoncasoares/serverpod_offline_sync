import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import 'types.dart';

/// Extensions on [String] used for SQL construction.
@internal
extension SqlStringExtension on String {
  /// Escapes this SQL identifier so it can be safely wrapped in double quotes.
  String escapeIdentifier() => replaceAll('"', '""');
}

/// Extensions on [Object?] used for SQL construction.
@internal
extension SqlObjectExtension on Object? {
  /// Encodes this value as a SQL literal.
  String sqlLiteral() => ValueEncoder.instance.convert(this);
}

/// Extensions on [Iterable] used for SQL construction.
@internal
extension SqlIterableExtension on Iterable<Object?> {
  /// Encodes these values as a comma-separated list of SQL literals.
  String sqlLiteralList() => map((value) => value.sqlLiteral()).join(', ');
}

/// SQL predicate matching rows where [columnName] equals [value].
@internal
String domainColumnPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${columnName.escapeIdentifier()}" = ${value.sqlLiteral()}';

/// SQL predicate matching rows where [columnName] differs from [value].
@internal
String domainColumnNotPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${columnName.escapeIdentifier()}" <> ${value.sqlLiteral()}';

/// Extensions on [Object?] used for UUID conversion.
@internal
extension UuidValueExtension on Object? {
  /// Converts this raw database value into a [UuidValue], when present.
  UuidValue? toUuidValue() {
    final value = this;
    if (value == null) return null;
    return UuidValueJsonExtension.fromJson(value);
  }
}

/// Orders row keys by table name, then row id, for deterministic planning.
@internal
int compareMergeRowKeys(MergeRowKey left, MergeRowKey right) {
  final tableComparison = left.$1.compareTo(right.$1);
  if (tableComparison != 0) return tableComparison;
  return left.$2.uuid.compareTo(right.$2.uuid);
}

/// Decodes UUID columns using their schema, preserving text and binary values
/// even when their contents could also represent a UUID.
@internal
Object? canonicalDomainValue(Object? value, ColumnDefinition? column) {
  if (column?.columnType == ColumnType.uuid) return value.toUuidValue();
  return value;
}

/// Extensions on [UuidValue?] used for UUID comparison.
@internal
extension UuidValueComparisonExtension on UuidValue? {
  /// Whether this UUID and [other] represent the same UUID (or are both null).
  bool sameUuidValue(UuidValue? other) => this?.uuid == other?.uuid;
}

/// Extensions on domain [TableRow]s used by the CRDT recorder.
@internal
extension CrdtTableRowExtension<T extends TableRow> on T {
  /// Returns a copy of this row with [spaceId] set.
  /// Must use dynamic cast because the copyWith method is generated only.
  T copyWithSpaceId(int spaceId) => (this as dynamic).copyWith(spaceId: spaceId) as T;
}

/// Adapts a materialized domain row for an ORM insert. A null chosen by
/// projection is a stored value, even when the column has a database default.
/// Serverpod otherwise treats null insert values as requests for that default.
@internal
TableRow<UuidValue?> withExplicitInsertNulls(
  TableRow row,
  Set<String> columns,
) => columns.isEmpty ? row as TableRow<UuidValue?> : _ExplicitNullRow(row, columns);

/// Keeps per-row default semantics when a batch contains projected nulls.
/// PostgreSQL builds a batch using the first row's table, so rows with different
/// null overrides use separate consecutive batches in the caller's transaction.
@internal
Future<List<T>> insertWithExplicitNulls<T extends TableRow>(
  Database database,
  List<T> rows, {
  required Map<UuidValue, Set<String>> explicitNulls,
  required Transaction transaction,
  bool ignoreConflicts = false,
  bool noReturn = false,
}) async {
  if (explicitNulls.isEmpty) {
    return database.insert<T>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }
  final inserted = <T>[];
  var start = 0;
  while (start < rows.length) {
    final columns = explicitNulls[rows[start].id] ?? const <String>{};
    var end = start + 1;
    while (end < rows.length) {
      final next = explicitNulls[rows[end].id] ?? const <String>{};
      if (columns.length != next.length || !columns.containsAll(next)) break;
      end++;
    }

    final result = await database.insert<TableRow<UuidValue?>>(
      [
        for (var index = start; index < end; index++)
          withExplicitInsertNulls(rows[index], columns),
      ],
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
    inserted.addAll(result.cast<T>());
    start = end;
  }
  return inserted;
}

class _ExplicitNullRow implements TableRow<UuidValue?> {
  _ExplicitNullRow(this.row, Set<String> columns)
    : table = _ExplicitNullTable(row.table, columns);

  final TableRow row;

  @override
  UuidValue? get id => row.id as UuidValue?;

  @override
  final Table<UuidValue?> table;

  @override
  dynamic toJson() => row.toJson();
}

class _ExplicitNullTable extends Table<UuidValue?> {
  _ExplicitNullTable(Table source, Set<String> explicitNulls)
    : super(tableName: source.tableName) {
    columns = [
      for (final column in source.columns)
        if (explicitNulls.contains(column.columnName))
          _ExplicitNullColumn(column)
        else
          column,
    ];
  }

  @override
  late final List<Column> columns;
}

class _ExplicitNullColumn extends Column<Object?> {
  _ExplicitNullColumn(Column source)
    : super(source.columnName, source.table, fieldName: source.fieldName);
}

/// Helpers over lists of domain [TableRow]s used by the CRDT recorder.
@internal
extension TableRowListExtension on List<TableRow> {
  /// The UUID primary keys of all rows in the list.
  Set<UuidValue> get uuidRowIds {
    if (isEmpty) return {};
    if (first.id == null) throw StateError('Row IDs must be non-null.');
    if (first.id is! UuidValue) throw StateError('Row IDs must be UuidValue.');
    return {for (final row in this) row.id as UuidValue};
  }
}

/// Extensions on [Table] used by the CRDT recorder.
@internal
extension CrdtTableExtension on Table {
  /// The space ownership column managed by the CRDT layer, if present.
  ColumnInt? get offlineSyncSpaceIdColumn {
    for (final column in columns) {
      if (column.columnName == 'spaceId' && column is ColumnInt) {
        return column;
      }
    }
    return null;
  }

  /// The columns that are part of CRDT sync, excluding the primary key and the
  /// CRDT-managed spaceId column.
  Iterable<Column> get crdtSyncableColumns => managedColumns.crdtSyncableColumns;
}

/// Extensions on iterables of [Column] used by the CRDT recorder.
@internal
extension CrdtColumnIterableExtension on Iterable<Column> {
  /// The columns that are part of CRDT sync, excluding the primary key and the
  /// CRDT-managed spaceId column.
  Iterable<Column> get crdtSyncableColumns => where(
    (column) => column.columnName != 'id' && column.columnName != 'spaceId',
  );
}
