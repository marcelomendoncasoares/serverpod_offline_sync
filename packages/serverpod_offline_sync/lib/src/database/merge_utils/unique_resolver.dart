import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart' show ColumnType;
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/extensions.dart';
import '../../generated/protocol.dart';
import '../../hlc/hlc.dart';
import '../exceptions.dart';
import '../unique_index_utils.dart';
import 'database_helpers.dart';
import 'recorder_context.dart';
import 'types.dart';

/// Unique-index stage of the fact-plus-projection planner.
///
/// Groups by authored / FK-safe claim values rather than previously released
/// domain values. Hidden rows are released unconditionally and never join
/// winner selection.
@internal
class CrdtUniqueConflictResolver {
  /// Creates a resolver over the given recorder context.
  CrdtUniqueConflictResolver(this._context);

  final CrdtRecorderContext _context;

  static final _reservedTextSuffix = RegExp(
    '__(?:conflict|hidden|park)__[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  final _uniqueTextColumns = <String, Set<String>>{};
  final _syntheticUuidColumns = <String, Set<String>>{};

  Set<String> _textColumnsFor(String tableName) => _uniqueTextColumns.putIfAbsent(
    tableName,
    () => {
      for (final column in uniqueColumnNamesFor(tableName))
        if (_context.columnsByTableAndName[tableName]?[column]?.columnType ==
            ColumnType.text)
          column,
    },
  );

  Set<String> _uuidColumnsFor(String tableName) => _syntheticUuidColumns.putIfAbsent(
    tableName,
    () => {
      for (final index in uniqueIndexesFor(tableName))
        for (final column in index.releaseColumns)
          if (column.kind == CrdtUniqueConflictReleaseKind.syntheticUuid)
            column.columnName,
    },
  );

  /// Whether authored values need a generated-namespace check.
  bool hasReservedUniqueColumns(String tableName) =>
      _textColumnsFor(tableName).isNotEmpty || _uuidColumnsFor(tableName).isNotEmpty;

  /// Rejects authored values in the namespace owned by deterministic projection.
  /// This checks the schema and input only, never the currently occupied names.
  void validateAuthoredValue(String tableName, String columnName, Object? value) {
    if (!isReservedValue(tableName, columnName, value)) return;
    throw OfflineSyncReservedValueException(
      tableName: tableName,
      columnName: columnName,
      value: value.toString(),
    );
  }

  /// Generated text suffixes and version-8 UUIDs belong only to projection.
  /// UUID checks apply only where the schema uses synthetic UUID release,
  /// leaving primary keys, foreign keys, and nullable UUID columns unrestricted.
  bool isReservedValue(String tableName, String columnName, Object? value) {
    if (value is String &&
        value.contains('__') &&
        _textColumnsFor(tableName).contains(columnName) &&
        _reservedTextSuffix.hasMatch(value)) {
      return true;
    }
    if ((value is UuidValue || value is String) &&
        _uuidColumnsFor(tableName).contains(columnName)) {
      final uuid = value.toString();
      return uuid.length == 36 && uuid[14] == '8';
    }
    return false;
  }

  /// Validates a group of newly authored field facts.
  void validateAuthoredFields(Map<MergeFieldKey, Object?> values) {
    for (final MapEntry(key: key, value: value) in values.entries) {
      validateAuthoredValue(key.$1, key.$3, value);
    }
  }

  /// Whether [tableName] has any synchronized unique index.
  bool tableHasUniqueIndexes(String tableName) =>
      uniqueIndexesFor(tableName).isNotEmpty;

  /// Unique indexes declared for [tableName].
  List<UniqueIndexConflictRelease> uniqueIndexesFor(String tableName) {
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return const [];
    return _context.uniqueIndexesForTable(tableDefinition);
  }

  /// Unique-indexed column names for [tableName], excluding `spaceId`.
  Set<String> uniqueColumnNamesFor(String tableName) {
    return {
      for (final uniqueIndex in uniqueIndexesFor(tableName))
        ...uniqueIndex.indexedColumns,
    };
  }

  /// Whether [columnName] participates in any unique index of [tableName].
  bool isUniqueIndexedColumn(String tableName, String columnName) {
    return uniqueColumnNamesFor(tableName).contains(columnName);
  }

  /// Releasable columns of indexes affected by [changedColumns], used by
  /// two-phase parking even when only a fixed discriminator changes.
  ///
  /// A column can be indexed more than once, and releasing it is one act, so
  /// the columns are deduplicated by name.
  List<UniqueColumnConflictRelease> uniqueReleaseColumnsFor(
    String tableName,
    Set<String> changedColumns,
  ) {
    final byName = <String, UniqueColumnConflictRelease>{};
    for (final uniqueIndex in uniqueIndexesFor(tableName)) {
      if (!uniqueIndex.indexedColumns.any(changedColumns.contains)) continue;
      for (final column in uniqueIndex.releaseColumns) {
        byName[column.columnName] = column;
      }
    }
    return byName.values.toList();
  }

  /// Mutates [valuesByRow] to unique-final domain values and returns the
  /// terminal unique reasons for fields this stage changed.
  ///
  /// [claimByField] is the unique grouping key: FK-safe candidate for FK
  /// fields, otherwise the authored value. Grouping never uses a previously
  /// released materialized value.
  Map<MergeFieldKey, CrdtProjectionReason> planUniqueProjection({
    required Map<MergeRowKey, Map<String, Object?>> valuesByRow,
    required Map<MergeRowKey, CrdtDataRow> crdtRows,
    required Set<MergeRowKey> hidden,
    required Map<MergeFieldKey, Object?> authoredByField,
    required Map<MergeFieldKey, Object?> claimByField,
    required Map<MergeFieldKey, Hlc> fieldHlcs,
    bool resolveVisibleConflicts = true,
  }) {
    final reasons = <MergeFieldKey, CrdtProjectionReason>{};
    final tableNames = {for (final rowKey in valuesByRow.keys) rowKey.$1};

    for (final tableName in tableNames) {
      final tableDefinition = _context.tableDefinitionsByName[tableName];
      if (tableDefinition == null) continue;
      final uniqueIndexes = _context.uniqueIndexesForTable(tableDefinition);
      if (uniqueIndexes.isEmpty) continue;

      final tableRowKeys = [
        for (final rowKey in valuesByRow.keys)
          if (rowKey.$1 == tableName) rowKey,
      ]..sort(compareMergeRowKeys);

      // A null tuple makes no unique claim, but still needs to shed any old
      // release. Restore candidates first; per-index winners then retain their
      // canonical tuples so they remain identifiable through those indexes.
      for (final rowKey in tableRowKeys) {
        if (!resolveVisibleConflicts && !hidden.contains(rowKey)) continue;
        for (final uniqueIndex in uniqueIndexes) {
          _materializeCanonicalClaim(
            rowKey: rowKey,
            uniqueIndex: uniqueIndex,
            claimByField: claimByField,
            valuesByRow: valuesByRow,
          );
        }
      }

      for (final uniqueIndex in uniqueIndexes) {
        for (final rowKey in tableRowKeys) {
          if (!hidden.contains(rowKey)) continue;
          if (_claimTuple(rowKey, uniqueIndex, claimByField) == null) continue;
          _releaseRow(
            rowKey: rowKey,
            uniqueIndex: uniqueIndex,
            authoredByField: authoredByField,
            valuesByRow: valuesByRow,
            reasons: reasons,
            releaseSuffix: 'hidden',
            reason: CrdtProjectionReason.hiddenUniqueRelease,
          );
        }

        // Local writes retain their proposed unique values so the database
        // enforces uniqueness. Hidden rows still release their old values.
        if (!resolveVisibleConflicts) continue;
        final groups = <String, List<MergeRowKey>>{};
        for (final rowKey in tableRowKeys) {
          if (hidden.contains(rowKey)) continue;
          final claim = _claimTuple(rowKey, uniqueIndex, claimByField);
          if (claim == null) continue;
          groups.putIfAbsent(claim, () => []).add(rowKey);
        }

        for (final group in groups.values) {
          group.sort(
            (left, right) => _compareUniqueClaims(
              left: left,
              right: right,
              uniqueIndex: uniqueIndex,
              crdtRows: crdtRows,
              fieldHlcs: fieldHlcs,
            ),
          );
          final winner = group.first;
          _materializeCanonicalClaim(
            rowKey: winner,
            uniqueIndex: uniqueIndex,
            claimByField: claimByField,
            valuesByRow: valuesByRow,
          );
          for (final loser in group.skip(1)) {
            _releaseRow(
              rowKey: loser,
              uniqueIndex: uniqueIndex,
              authoredByField: authoredByField,
              valuesByRow: valuesByRow,
              reasons: reasons,
              releaseSuffix: 'conflict',
              reason: CrdtProjectionReason.uniqueConflict,
            );
          }
        }
      }
    }

    return reasons;
  }

  String? _claimTuple(
    MergeRowKey rowKey,
    UniqueIndexConflictRelease uniqueIndex,
    Map<MergeFieldKey, Object?> claimByField,
  ) {
    final parts = <String>[];
    for (final columnName in uniqueIndex.indexedColumns) {
      final value = claimByField[(rowKey.$1, rowKey.$2, columnName)];
      if (value == null) return null;
      parts.add(canonicalProjectionValue(value));
    }
    return parts.join('\x1f');
  }

  void _materializeCanonicalClaim({
    required MergeRowKey rowKey,
    required UniqueIndexConflictRelease uniqueIndex,
    required Map<MergeFieldKey, Object?> claimByField,
    required Map<MergeRowKey, Map<String, Object?>> valuesByRow,
  }) {
    final values = valuesByRow[rowKey];
    if (values == null) return;
    for (final columnName in uniqueIndex.indexedColumns) {
      values[columnName] = claimByField[(rowKey.$1, rowKey.$2, columnName)];
    }
  }

  void _releaseRow({
    required MergeRowKey rowKey,
    required UniqueIndexConflictRelease uniqueIndex,
    required Map<MergeFieldKey, Object?> authoredByField,
    required Map<MergeRowKey, Map<String, Object?>> valuesByRow,
    required Map<MergeFieldKey, CrdtProjectionReason> reasons,
    required String releaseSuffix,
    required CrdtProjectionReason reason,
  }) {
    final values = valuesByRow[rowKey];
    if (values == null) return;

    for (final column in uniqueIndex.releaseColumns) {
      final authored = authoredByField[(rowKey.$1, rowKey.$2, column.columnName)];
      final released = _context.conflictFreeValue(
        column,
        authored ?? values[column.columnName],
        rowKey.$1,
        rowKey.$2,
        releaseSuffix,
      );
      values[column.columnName] = released;
      if (!projectionValuesEqual(released, authored)) {
        reasons[(rowKey.$1, rowKey.$2, column.columnName)] = reason;
      }
    }
  }

  int _compareUniqueClaims({
    required MergeRowKey left,
    required MergeRowKey right,
    required UniqueIndexConflictRelease uniqueIndex,
    required Map<MergeRowKey, CrdtDataRow> crdtRows,
    required Map<MergeFieldKey, Hlc> fieldHlcs,
  }) {
    final leftHlc = _uniqueIndexHlc(
      rowKey: left,
      uniqueIndex: uniqueIndex,
      crdtRows: crdtRows,
      fieldHlcs: fieldHlcs,
    );
    final rightHlc = _uniqueIndexHlc(
      rowKey: right,
      uniqueIndex: uniqueIndex,
      crdtRows: crdtRows,
      fieldHlcs: fieldHlcs,
    );
    final comparison = leftHlc.compareTo(rightHlc);
    if (comparison != 0) return comparison;
    return left.$2.uuid.compareTo(right.$2.uuid);
  }

  Hlc _uniqueIndexHlc({
    required MergeRowKey rowKey,
    required UniqueIndexConflictRelease uniqueIndex,
    required Map<MergeRowKey, CrdtDataRow> crdtRows,
    required Map<MergeFieldKey, Hlc> fieldHlcs,
  }) {
    final fieldClaimHlcs = [
      for (final columnName in uniqueIndex.indexedColumns)
        ?fieldHlcs[(rowKey.$1, rowKey.$2, columnName)],
    ];
    if (fieldClaimHlcs.isNotEmpty) {
      return fieldClaimHlcs.reduce((left, right) => left.maxBetween(right));
    }
    return crdtRows[rowKey]!.hlc;
  }
}

/// Canonical token for unique-claim grouping and equality.
@internal
String canonicalProjectionValue(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  final uuid = tryUuidValue(value);
  if (uuid != null) return uuid.uuid;
  return value.toString();
}

/// Whether two projection values represent the same domain/authored fact.
@internal
bool projectionValuesEqual(Object? left, Object? right) {
  if (left == null || right == null) return left == right;
  if (left is String && right is String) return left == right;
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.entries.every(
          (entry) =>
              right.containsKey(entry.key) &&
              projectionValuesEqual(entry.value, right[entry.key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!projectionValuesEqual(left[index], right[index])) return false;
    }
    return true;
  }
  final leftUuid = tryUuidValue(left);
  final rightUuid = tryUuidValue(right);
  if (leftUuid != null && rightUuid != null) {
    return leftUuid.sameUuidValue(rightUuid);
  }
  return left == right;
}

/// Parses [value] as a UUID when it is one, otherwise null.
@internal
UuidValue? tryUuidValue(Object? value) {
  try {
    return value.toUuidValue();
  } on Object {
    return null;
  }
}
