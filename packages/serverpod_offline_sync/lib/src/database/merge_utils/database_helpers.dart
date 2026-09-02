import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

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
    if (value is UuidValue) return value;
    if (value is String) return UuidValue.withValidation(value);
    if (value is Uint8List) return UuidValue.fromByteList(value);
    if (value is List && value.length == 16) {
      return UuidValue.fromByteList(Uint8List.fromList(List<int>.from(value)));
    }
    return UuidValueJsonExtension.fromJson(value);
  }
}

/// Canonicalizes a domain/attempted value so UUID blobs round-trip as
/// [UuidValue] rather than as SQLite byte lists.
@internal
Object? canonicalDomainValue(Object? value) {
  try {
    return value.toUuidValue() ?? value;
  } on Object {
    return value;
  }
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
  /// Returns a copy of this row with [scopeId] set.
  /// Must use dynamic cast because the copyWith method is generated only.
  T copyWithScopeId(int scopeId) => (this as dynamic).copyWith(scopeId: scopeId) as T;
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
  /// The scope ownership column managed by the CRDT layer, if present.
  ColumnInt? get crdtScopeIdColumn {
    for (final column in columns) {
      if (column.columnName == 'scopeId' && column is ColumnInt) {
        return column;
      }
    }
    return null;
  }

  /// The columns that are part of CRDT sync, excluding the primary key and the
  /// CRDT-managed scopeId column.
  Iterable<Column> get crdtSyncableColumns => managedColumns.crdtSyncableColumns;
}

/// Extensions on iterables of [Column] used by the CRDT recorder.
@internal
extension CrdtColumnIterableExtension on Iterable<Column> {
  /// The columns that are part of CRDT sync, excluding the primary key and the
  /// CRDT-managed scopeId column.
  Iterable<Column> get crdtSyncableColumns => where(
    (column) => column.columnName != 'id' && column.columnName != 'scopeId',
  );
}
