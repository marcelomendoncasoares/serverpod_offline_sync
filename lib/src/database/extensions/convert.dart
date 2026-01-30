import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import '../../hlc/normalized.dart';
import '../database.dart';

/// Extensions for [CrdtDatabase] to convert data to [CrdtDataEntry].
extension CrdtDatabaseConvertExtensions on CrdtDatabase {
  /// Converts the [Insertable] object to a list of [CrdtDataEntry].
  ///
  /// Note that the generated entries will have the same HLC timestamp for all
  /// columns and will overwrite individual column updates if newer.
  ///
  /// Returns a list of [CrdtDataEntry].
  Iterable<CrdtDataEntry> convertToCrdtDataEntry<T extends Insertable>(
    T data,
    Hlc hlcTimestamp,
  ) {
    final json = data.toJsonForDatabase(_generationContext);
    final tableInfo = synchronizedTables.whereType<TableInfo<dynamic, T>>().single;
    final rowIdValues = [for (final c in tableInfo.$primaryKey) json[c.$name]];

    // Get normalized IDs from schema cache
    final tableId = schemaCache.getTableId(tableInfo.actualTableName);
    final currentNodeId = schemaCache.currentNodeId;

    // Extract HLC components
    final hlcDatetime = NormalizedHlc.extractDatetime(hlcTimestamp);
    final hlcCounter = NormalizedHlc.extractCounter(hlcTimestamp);

    return tableInfo.$columns.map(
      (c) {
        final columnId = schemaCache.getColumnId(tableId, c.$name);
        return CrdtDataEntry(
          userId: userId,
          tableId: tableId,
          columnId: columnId,
          rowId: rowIdValues.join(sqlBuilder.rowIdSeparator),
          hlcDatetime: hlcDatetime,
          hlcCounter: hlcCounter,
          hlcNodeId: currentNodeId,
          rawValue: json[c.$name]?.toDriftAny(),
        );
      },
    );
  }

  /// Gets a [GenerationContext] for the database.
  GenerationContext get _generationContext => GenerationContext.fromDb(this);
}

extension on Insertable {
  Map<String, Object?> toJsonForDatabase(GenerationContext context) {
    final expressions = toColumns(false);
    return {
      for (final e in expressions.entries) e.key: e.value.extractValue(context),
    };
  }
}

extension on Expression {
  Object? extractValue(GenerationContext context) {
    final exp = this;
    if (exp is! Variable) {
      throw ArgumentError.value(exp, 'exp', 'Expected a Variable');
    }
    return exp.mapToSimpleValue(context);
  }
}

extension on Object {
  DriftAny? toDriftAny() => DriftAny(this);
}
