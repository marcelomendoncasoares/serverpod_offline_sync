import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../crdt/extensions.dart';
import '../protocol/protocol.dart';

/// Resolves the local [CrdtSchemaTable] id for a domain table name. Returns
/// null when the table is not registered for CRDT synchronization.
typedef CrdtTableIdResolver = int? Function(String tableName);

/// Resolves the [CrdtScope] id scoping the current query. Returns null when no
/// user scope is available (e.g. server-side reads outside
/// `transactionForUser` without a persistent user), in which case a row is
/// only hidden when every user tracking it has it hidden.
typedef CrdtScopeUserIdResolver = int? Function();

/// Merges [where] with CRDT visibility predicates and mutates [include] in place.
///
/// This method ensures that no rows with a hidden [CrdtDataRow.visibility] are
/// returned for queries with [where] clauses or [include] graphs. If [include]
/// is null, only the root table and [where] are merged.
///
/// Each predicate only considers [CrdtDataRow]s recorded for the queried table
/// ([tableIdForName]) and, when a user scope is available ([scopeUserId]), for
/// the scoped user. This prevents a tombstone recorded for another table or
/// user from masking an unrelated row that reuses the same UUID. Without a
/// user scope (admin reads on multi-user databases), a row stays visible as
/// long as at least one user tracking it still sees it.
///
/// Both resolvers are only invoked when a predicate is actually built (i.e.
/// for synced tables with UUID primary keys), so queries on CRDT-internal
/// tables never touch the recorder state.
///
/// We do **not** add a root predicate for keys whose nested include is an
/// [IncludeList] - visibility filtering for that path is already handled via the
/// list subquery [where] (and many-relations are not the same join shape as a
/// single [IncludeObject]).
@internal
Expression? mergeWhereWithTombstone<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
  Expression? where,
  Include? include, {
  required CrdtTableIdResolver tableIdForName,
  required CrdtScopeUserIdResolver scopeUserId,
}) {
  final includeObjectPredicates = _walkIncludeGraphForTombstone(
    include,
    null,
    tableIdForName: tableIdForName,
    scopeUserId: scopeUserId,
  );

  final rootTable = serializationManager.getTableForType(T);
  var merged = _mergeWhereOptional(
    where,
    rootTable?.whereVisibleOnCrdtRow(tableIdForName, scopeUserId),
  );
  merged = _mergeWhereOptional(merged, includeObjectPredicates);
  return merged;
}

/// Walks [inc], mutating each [IncludeList.where] and returning predicates to
/// `AND` into the main query for [IncludeObject] joins.
Expression? _walkIncludeGraphForTombstone(
  Include? inc,
  Expression? includeObjectPredicates, {
  required CrdtTableIdResolver tableIdForName,
  required CrdtScopeUserIdResolver scopeUserId,
}) {
  if (inc == null) return includeObjectPredicates;
  if (inc is IncludeList) {
    // List relation: filter inside the list subquery only.
    inc.where = _mergeWhereOptional(
      inc.where,
      inc.table.whereVisibleOnCrdtRow(tableIdForName, scopeUserId),
    );
    return _walkIncludeGraphForTombstone(
      inc.include,
      includeObjectPredicates,
      tableIdForName: tableIdForName,
      scopeUserId: scopeUserId,
    );
  }
  var acc = includeObjectPredicates;
  final obj = inc;
  final selfTable = obj.table;
  for (final entry in obj.includes.entries) {
    final nested = entry.value;
    if (nested is IncludeList) {
      // e.g. one-to-many: visibility applies via IncludeList.where, not the main WHERE.
      acc = _walkIncludeGraphForTombstone(
        nested,
        acc,
        tableIdForName: tableIdForName,
        scopeUserId: scopeUserId,
      );
      continue;
    }
    if (nested is IncludeObject) {
      // one-to-one / optional object: joined on the main SELECT, constrain via root WHERE.
      final childTable = selfTable.getRelationTable(entry.key);
      if (childTable != null) {
        acc = _mergeWhereOptional(
          acc,
          childTable.whereVisibleOnCrdtRow(tableIdForName, scopeUserId),
        );
      }
      acc = _walkIncludeGraphForTombstone(
        nested,
        acc,
        tableIdForName: tableIdForName,
        scopeUserId: scopeUserId,
      );
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
  /// using materialized [CrdtDataRow.visibility] metadata.
  ///
  /// The row id is matched against a subquery of hidden [CrdtDataRow]s scoped
  /// to this table's [CrdtSchemaTable] id and, when available, the scoped
  /// user. The uncorrelated subquery avoids joining [CrdtDataRow] directly,
  /// which would duplicate result rows when multiple users track the same row.
  ///
  /// Returns null when [Table] does not use a UUID primary key or is not
  /// registered for CRDT synchronization. Keeps rows when the id is null
  /// (unmatched [IncludeObject] joins) or no hidden CRDT row matches.
  ///
  /// Without a user scope, a row is only hidden when every user tracking it
  /// has it hidden (the minimum visibility across users is hidden), so admin
  /// reads keep rows that are still visible to some user.
  ///
  /// The scoped form is a correlated `NOT EXISTS` probe covered by the
  /// (scopeId, tblId, uuidRowId) unique index, so point lookups stay
  /// index-bound and planners can flatten it into an anti-join for scans.
  /// The unscoped form deliberately stays uncorrelated (one scan and
  /// aggregate per query): without a (tblId, uuidRowId) index, correlated
  /// probes would scan [CrdtDataRow] per outer row.
  Expression? whereVisibleOnCrdtRow(
    CrdtTableIdResolver tableIdForName,
    CrdtScopeUserIdResolver scopeUserId,
  ) {
    if (id is! ColumnUuid) return null;
    final tableId = tableIdForName(tableName);
    if (tableId == null) return null;

    final crdtRow = CrdtDataRow.t;
    final userId = scopeUserId();
    if (userId != null) {
      final scopeColumn = scopeIdColumn;
      if (scopeColumn == null) return null;

      return id.equals(null) |
          (Expression('$scopeColumn = $userId') &
              Expression(
                'NOT EXISTS '
                '(SELECT 1 FROM "${crdtRow.tableName}" '
                'WHERE ${crdtRow.scopeId} = $userId '
                'AND ${crdtRow.tblId} = $tableId '
                'AND ${crdtRow.uuidRowId} = $id '
                'AND ${crdtRow.visibility} > $crdtRowLastVisibleVisibilityIndex)',
              ));
    }

    final scopeColumn = scopeIdColumn;
    if (scopeColumn == null) return null;

    return id.equals(null) |
        Expression(
          'NOT EXISTS '
          '(SELECT 1 FROM "${crdtRow.tableName}" '
          'WHERE ${crdtRow.scopeId} = $scopeColumn '
          'AND ${crdtRow.tblId} = $tableId '
          'AND ${crdtRow.uuidRowId} = $id '
          'AND ${crdtRow.visibility} > $crdtRowLastVisibleVisibilityIndex)',
        );
  }

  Column<int>? get scopeIdColumn {
    for (final column in columns) {
      if (column.columnName == 'scopeId' && column is Column<int>) {
        return column;
      }
    }
    return null;
  }
}
