import 'package:drift/drift.dart';

import '../hlc/converter.dart';

// Required for the generated code to know the HLC and converters.
export '../hlc/converter.dart';

/// CRDT merge HLC table.
///
/// This table stores the last HLC timestamp received from each node when merging
/// changes, so that the next merges can be performed incrementally.
///
@TableIndex(
  name: 'idx_crdt_merge_hlc_timestamp',
  columns: {#userId, #hlcTimestamp},
)
@DataClassName('CrdtMergeHlcEntry')
class CrdtMergeHlcTable extends Table {
  @override
  String get tableName => '__crdt_merge_hlc';

  /// Identifier for the user or client.
  late final userId = text()();

  /// Node identifier for the client.
  late final nodeId = text()();

  /// The last HLC timestamp received from this node when merging changes.
  late final lastReceivedHlc = text().map(hlcConverter)();

  @override
  Set<Column> get primaryKey => {userId, nodeId};
}
