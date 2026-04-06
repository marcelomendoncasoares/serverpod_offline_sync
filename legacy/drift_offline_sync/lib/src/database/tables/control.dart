import 'package:drift/drift.dart';

import '../../hlc/converter.dart';

// Required for the generated code to know the HLC and converters.
export '../../hlc/converter.dart';

/// CRDT control table.
///
/// This table stores metadata about the CRDT synchronization state for each user.
///
@DataClassName('CrdtControlEntry')
class CrdtControlTable extends Table {
  @override
  String get tableName => '__crdt_control';

  /// Identifier for the user or client.
  late final userId = text()();

  /// Node identifier for the client.
  late final nodeId = text()();

  /// Whether CRDT triggers are currently enabled for this user.
  late final crdtTriggersOn = boolean().withDefault(const Constant(true))();

  /// The schema version of the CRDT data.
  late final schemaVersion = integer()();

  /// The last HLC timestamp when the user synchronized.
  late final lastSyncHlc = text().nullable().map(nullableHlcConverter)();

  /// The last HLC timestamp when merged changes were applied.
  late final lastApplyHlc = text().nullable().map(nullableHlcConverter)();

  @override
  Set<Column> get primaryKey => {userId, nodeId};

  /// Query to insert a new entry into the CRDT control table.
  ///
  /// Declared here to ensure the query is synchronized with the table.
  static String getDefaultUpsertQuery({
    required String userId,
    required String nodeId,
    required int schemaVersion,
  }) {
    return '''
INSERT INTO "__crdt_control" (
  "user_id",
  "node_id",
  "crdt_triggers_on",
  "schema_version"
) VALUES ('$userId', '$nodeId', TRUE, $schemaVersion)
ON CONFLICT ("user_id", "node_id") DO UPDATE SET
  "crdt_triggers_on" = TRUE,
  "schema_version" = $schemaVersion;''';
  }
}
