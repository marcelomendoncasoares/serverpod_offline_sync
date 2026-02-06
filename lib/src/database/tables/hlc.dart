import 'package:drift/drift.dart';

/// HLC state table.
///
/// Stores per-user last timestamp and counter for Hybrid Logical Clock state.
///
@DataClassName('CrdtHlcEntry')
class CrdtHlcStateTable extends Table {
  @override
  String get tableName => '__hlc_state';

  /// Identifier for the user or client.
  late final userId = text()();

  /// Last HLC timestamp in milliseconds since epoch (logical time component).
  late final lastTimestamp = integer()();

  /// Counter for events at the same logical time (count component).
  late final counter = integer()();

  @override
  Set<Column> get primaryKey => {userId};
}
