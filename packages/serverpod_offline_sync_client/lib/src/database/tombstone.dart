import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../protocol/protocol.dart';

/// Merges [where] with CRDT tombstone predicates and mutates [include] in place.
///
/// This method ensures that no rows marked as deleted on the tombstone are
/// returned for queries with [where] clauses or [include] graphs. If [include]
/// is null, only the root table and [where] are merged.
///
/// We do **not** add a root predicate for keys whose nested include is an
/// [IncludeList] - tombstone filtering for that path is already handled via the
/// list subquery [where] (and many-relations are not the same join shape as a
/// single [IncludeObject]).
@internal
Expression? mergeWhereWithTombstone<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
  Expression? where,
  Include? include,
) {
  final includeObjectPredicates = _walkIncludeGraphForTombstone(include, null);

  final rootTable = serializationManager.getTableForType(T)!;
  var merged = _mergeWhereOptional(
    where,
    rootTable.whereNotDeletedOnTombstone,
  );
  merged = _mergeWhereOptional(merged, includeObjectPredicates);
  return merged;
}

/// Walks [inc], mutating each [IncludeList.where] and returning predicates to
/// `AND` into the main query for [IncludeObject] joins.
Expression? _walkIncludeGraphForTombstone(
  Include? inc,
  Expression? includeObjectPredicates,
) {
  if (inc == null) return includeObjectPredicates;
  if (inc is IncludeList) {
    // List relation: filter inside the list subquery only.
    inc.where = _mergeWhereOptional(
      inc.where,
      inc.table.whereNotDeletedOnTombstone,
    );
    return _walkIncludeGraphForTombstone(inc.include, includeObjectPredicates);
  }
  var acc = includeObjectPredicates;
  final obj = inc;
  final selfTable = obj.table;
  for (final entry in obj.includes.entries) {
    final nested = entry.value;
    if (nested is IncludeList) {
      // e.g. one-to-many: tombstone applies via IncludeList.where, not the main WHERE.
      acc = _walkIncludeGraphForTombstone(nested, acc);
      continue;
    }
    if (nested is IncludeObject) {
      // one-to-one / optional object: joined on the main SELECT, constrain via root WHERE.
      final childTable = selfTable.getRelationTable(entry.key);
      if (childTable != null) {
        acc = _mergeWhereOptional(
          acc,
          childTable.whereNotDeletedOnTombstone,
        );
      }
      acc = _walkIncludeGraphForTombstone(nested, acc);
    }
  }
  return acc;
}

Expression? _mergeWhereOptional(Expression? where, Expression? addition) {
  if (addition == null) return where;
  if (where == null) return addition;
  return where & addition;
}

extension on Table {
  /// Creates a predicate that filters out tombstone rows for the given [Table]
  /// similarly to the generated field [CrdtDataRow.deleted].
  ///
  /// Join path:
  ///   - UserModel.[id] = [CrdtDataRow.uuidRowId],
  ///   - [CrdtDataRow.id] = [CrdtDataDeleted.rowId].
  ///
  /// Returns null when [Table] does not use a UUID primary key. Keeps rows
  /// when there is no tombstone row or [CrdtDataDeleted.isDeleted] is false
  /// (LEFT JOIN null-safe).
  Expression? get whereNotDeletedOnTombstone {
    if (id is! ColumnUuid) return null;
    final crdtRowTable = createRelationTable<CrdtDataRowTable>(
      relationFieldName: '${tableName}_crdt_row',
      field: id,
      foreignField: CrdtDataRow.t.uuidRowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    final tomb = crdtRowTable.deleted;
    return (tomb.id.equals(null)) | (tomb.isDeleted.equals(false));
  }
}
