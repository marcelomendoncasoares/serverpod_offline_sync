import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../protocol/protocol.dart';

/// Merges [where] with CRDT visibility predicates and mutates [include] in place.
///
/// This method ensures that no rows marked as hidden on their CRDT row metadata
/// are returned for queries with [where] clauses or [include] graphs. If
/// [include] is null, only the root table and [where] are merged.
///
/// We do **not** add a root predicate for keys whose nested include is an
/// [IncludeList] - visibility filtering for that path is already handled via the
/// list subquery [where] (and many-relations are not the same join shape as a
/// single [IncludeObject]).
@internal
Expression? mergeWhereWithTombstone<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
  Expression? where,
  Include? include,
) {
  final includeObjectPredicates = _walkIncludeGraphForTombstone(include, null);

  final rootTable = serializationManager.getTableForType(T);
  var merged = _mergeWhereOptional(
    where,
    rootTable?.whereNotHiddenOnCrdtRow,
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
      inc.table.whereNotHiddenOnCrdtRow,
    );
    return _walkIncludeGraphForTombstone(inc.include, includeObjectPredicates);
  }
  var acc = includeObjectPredicates;
  final obj = inc;
  final selfTable = obj.table;
  for (final entry in obj.includes.entries) {
    final nested = entry.value;
    if (nested is IncludeList) {
      // e.g. one-to-many: visibility applies via IncludeList.where, not the main WHERE.
      acc = _walkIncludeGraphForTombstone(nested, acc);
      continue;
    }
    if (nested is IncludeObject) {
      // one-to-one / optional object: joined on the main SELECT, constrain via root WHERE.
      final childTable = selfTable.getRelationTable(entry.key);
      if (childTable != null) {
        acc = _mergeWhereOptional(
          acc,
          childTable.whereNotHiddenOnCrdtRow,
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
  /// Creates a predicate that filters out hidden rows for the given [Table]
  /// using materialized [CrdtDataRow.isHidden] metadata.
  ///
  /// Join path:
  ///   - UserModel.[id] = [CrdtDataRow.uuidRowId].
  ///
  /// Returns null when [Table] does not use a UUID primary key. Keeps rows when
  /// there is no CRDT row or [CrdtDataRow.isHidden] is false (LEFT JOIN
  /// null-safe).
  Expression? get whereNotHiddenOnCrdtRow {
    if (id is! ColumnUuid) return null;
    final crdtRowTable = createRelationTable<CrdtDataRowTable>(
      relationFieldName: '${tableName}_crdt_row',
      field: id,
      foreignField: CrdtDataRow.t.uuidRowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return (crdtRowTable.id.equals(null)) | crdtRowTable.isHidden.equals(false);
  }
}
