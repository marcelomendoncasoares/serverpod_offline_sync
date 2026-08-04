import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../crdt/extensions.dart';
import '../generated/protocol.dart';

/// Resolves the local [CrdtSchemaTable] id for a domain table name. Returns
/// null when the table is not registered for CRDT synchronization.
typedef CrdtTableIdResolver = int? Function(String tableName);

/// Resolves the [CrdtScope] ids scoping the current query. Returns null when no
/// scope is available (e.g. server-side reads outside `transactionForUser`
/// without a persistent user), in which case the query is an admin read: rows
/// are not isolated and a row is hidden only when its owning scope hides it.
typedef CrdtScopeIdsResolver = List<int>? Function();

/// Private sentinel class used to signal that the CRDT visibility filter
/// should be bypassed. Detected via `is` type check instead of string
/// comparison.
///
/// It renders as the inert SQL literal `TRUE`, so it is always valid wherever
/// it appears in a `where` clause and never needs to be stripped out before the
/// query reaches the database.
final class _IncludeHiddenSentinel extends Expression<String> {
  const _IncludeHiddenSentinel() : super('TRUE');
}

/// Extension on [Table] that exposes [includeHiddenRows] for use in `where`
/// clauses to bypass the CRDT tombstone/visibility filter.
extension IncludeTombstonedRows on Table {
  /// Expression that bypasses the CRDT tombstone/visibility filter.
  ///
  /// When included in a `where` clause, all rows are returned — including those
  /// that are tombstoned (soft-deleted) — instead of being hidden.
  ///
  /// Example:
  /// ```dart
  /// // Returns all persons, including tombstoned ones.
  /// final allPersons = await Person.db.find(
  ///   session,
  ///   where: (t) => t.includeHiddenRows,
  /// );
  ///
  /// // Returns all persons named 'Alice', including tombstoned ones.
  /// final alicePersons = await Person.db.find(
  ///   session,
  ///   where: (t) => t.name.equals('Alice') & t.includeHiddenRows,
  /// );
  /// ```
  Expression get includeHiddenRows => const _IncludeHiddenSentinel();
}

/// Merges [where] with CRDT visibility predicates and mutates [include] in place.
///
/// This method ensures that no rows with a hidden [CrdtDataRow.visibility] are
/// returned for queries with [where] clauses or [include] graphs. If [include]
/// is null, only the root table and [where] are merged.
///
/// Each predicate only considers [CrdtDataRow]s recorded for the queried table
/// ([tableIdForName]) and, when scopes are available ([scopeIds]), isolates the
/// query to those scopes' rows. This prevents a tombstone recorded for another
/// table or scope from masking an unrelated row that reuses the same UUID.
/// Without a scope (admin reads), rows are not isolated and a row stays
/// visible as long as its owning scope still sees it.
///
/// Both resolvers are only invoked when a predicate is actually built (i.e.
/// for synced tables with UUID primary keys), so queries on CRDT-internal
/// tables never touch the recorder state.
///
/// We do **not** add a root predicate for keys whose nested include is an
/// [IncludeList] - visibility filtering for that path is already handled via the
/// list subquery [where] (and many-relations are not the same join shape as a
/// single [IncludeObject]).
///
/// If [where] contains the [IncludeTombstonedRows.includeHiddenRows] sentinel
/// anywhere in the expression tree, the visibility filter is skipped for the
/// root table. The sentinel itself renders as the inert SQL literal `TRUE`, so
/// it is left in place without producing invalid SQL.
@internal
Expression? mergeWhereWithTombstone<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
  Expression? where,
  Include? include, {
  required CrdtTableIdResolver tableIdForName,
  required CrdtScopeIdsResolver scopeIds,
}) {
  final includeObjectPredicates = _walkIncludeGraphForTombstone(
    include,
    null,
    tableIdForName: tableIdForName,
    scopeIds: scopeIds,
  );

  final rootTable = serializationManager.getTableForType(T);
  var merged = _includesHiddenSentinel(where)
      ? where
      : _mergeWhereOptional(
          where,
          rootTable?.whereVisibleOnCrdtRow(tableIdForName, scopeIds),
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
  required CrdtScopeIdsResolver scopeIds,
}) {
  if (inc == null) return includeObjectPredicates;
  if (inc is IncludeList) {
    // List relation: filter inside the list subquery only.
    if (!_includesHiddenSentinel(inc.where)) {
      inc.where = _mergeWhereOptional(
        inc.where,
        inc.table.whereVisibleOnCrdtRow(tableIdForName, scopeIds),
      );
    }
    return _walkIncludeGraphForTombstone(
      inc.include,
      includeObjectPredicates,
      tableIdForName: tableIdForName,
      scopeIds: scopeIds,
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
        scopeIds: scopeIds,
      );
      continue;
    }
    if (nested is IncludeObject) {
      // one-to-one / optional object: joined on the main SELECT, constrain via root WHERE.
      final childTable = selfTable.getRelationTable(entry.key);
      if (childTable != null) {
        acc = _mergeWhereOptional(
          acc,
          childTable.whereVisibleOnCrdtRow(tableIdForName, scopeIds),
        );
      }
      acc = _walkIncludeGraphForTombstone(
        nested,
        acc,
        tableIdForName: tableIdForName,
        scopeIds: scopeIds,
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

/// Returns `true` when [where] contains the [_IncludeHiddenSentinel] anywhere
/// in its expression tree.
///
/// Walks the tree via [Expression.depthFirst], which every expression type
/// implements, so the sentinel is detected regardless of how deeply it is
/// nested or which operators (`AND`, `OR`, `NOT`) combine it. The sentinel
/// renders as inert SQL (`TRUE`), so no rewriting of [where] is needed.
bool _includesHiddenSentinel(Expression? where) {
  if (where == null) return false;
  return where.depthFirst.any((e) => e is _IncludeHiddenSentinel);
}

extension on Table {
  /// Creates a predicate that filters out hidden rows for the given [Table]
  /// using materialized [CrdtDataRow.visibility] metadata.
  ///
  /// Returns null when [Table] does not use a UUID primary key or is not
  /// registered for CRDT synchronization. Keeps rows when the id is null
  /// (unmatched [IncludeObject] joins) or no hidden CRDT row matches.
  ///
  /// With scopes, rows are isolated to them (`scopeId IN (<scopes>)`) and
  /// checked against those scopes' tombstones with a correlated `NOT EXISTS`
  /// probe covered by the (scopeId, tblId, uuidRowId) unique index. Without a
  /// scope (admin reads), there is no isolation filter and the probe is
  /// keyed by the row's own `scopeId` column instead — covered by the same
  /// index — so a row stays visible while its owning scope sees it.
  Expression? whereVisibleOnCrdtRow(
    CrdtTableIdResolver tableIdForName,
    CrdtScopeIdsResolver scopeIds,
  ) {
    if (id is! ColumnUuid) return null;
    final tableId = tableIdForName(tableName);
    if (tableId == null) return null;

    // Synced tables are validated to carry the column at initialize(); a
    // missing column here must fail closed, never skip the predicate.
    final scopeColumn =
        scopeIdColumn ??
        (throw StateError(
          'Synced table "$tableName" has no int scopeId column; '
          'CrdtSchemaRegistry validation should have rejected it.',
        ));

    final crdtRow = CrdtDataRow.t;
    final effectiveScopeIds = scopeIds();
    if (effectiveScopeIds != null && effectiveScopeIds.isEmpty) {
      return id.equals(null) | const Expression('FALSE');
    }

    final scopeFilter = effectiveScopeIds == null
        ? '${crdtRow.scopeId} = $scopeColumn'
        : '${crdtRow.scopeId} IN (${_sqlIntList(effectiveScopeIds)})';
    final notExistsExpr = Expression(
      'NOT EXISTS '
      '(SELECT 1 FROM "${crdtRow.tableName}" '
      'WHERE $scopeFilter '
      'AND ${crdtRow.tblId} = $tableId '
      'AND ${crdtRow.uuidRowId} = $id '
      'AND ${crdtRow.visibility} > $crdtRowLastVisibleVisibilityIndex)',
    );

    return id.equals(null) |
        ((effectiveScopeIds != null)
            ? (scopeColumn.inSet(effectiveScopeIds.toSet()) & notExistsExpr)
            : notExistsExpr);
  }

  ColumnInt? get scopeIdColumn {
    for (final column in columns) {
      if (column.columnName == 'scopeId' && column is ColumnInt) {
        return column;
      }
    }
    return null;
  }
}

String _sqlIntList(Iterable<int> values) {
  return values.map(ValueEncoder.instance.convert).join(', ');
}
