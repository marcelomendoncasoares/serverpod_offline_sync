// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs

import 'package:serverpod_database/serverpod_database.dart';

/// City has one persisted domain field and no outgoing foreign keys. Its
/// generated reverse relations do not add columns or referential constraints.
List<Table> benchmarkTables(List<Table> tables, String schema) => switch (schema) {
  'full' => tables,
  'city' => tables.where((table) => table.tableName == 'city').toList(),
  _ => throw ArgumentError.value(schema, 'schema'),
};
