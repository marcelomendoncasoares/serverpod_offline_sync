import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

/// Escapes a SQL identifier so it can be safely wrapped in double quotes.
@internal
String escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

/// Encodes [value] as a SQL literal.
@internal
String sqlLiteral(Object? value) => ValueEncoder.instance.convert(value);

/// Encodes [values] as a comma-separated list of SQL literals.
@internal
String sqlLiteralList(Iterable<Object?> values) =>
    values.map(ValueEncoder.instance.convert).join(', ');

/// SQL predicate matching rows where [columnName] equals [value].
@internal
String domainColumnPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${escapeIdentifier(columnName)}" = ${sqlLiteral(value)}';

/// SQL predicate matching rows where [columnName] differs from [value].
@internal
String domainColumnNotPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${escapeIdentifier(columnName)}" <> ${sqlLiteral(value)}';

/// Converts a raw database [value] into a [UuidValue], when present.
@internal
UuidValue? uuidValueFromDatabase(Object? value) {
  if (value == null) return null;
  if (value is UuidValue) return value;
  if (value is String) return UuidValue.withValidation(value);
  return UuidValueJsonExtension.fromJson(value);
}

/// Whether [left] and [right] represent the same UUID (or are both null).
@internal
bool sameUuidValue(UuidValue? left, UuidValue? right) {
  return left?.uuid == right?.uuid;
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
