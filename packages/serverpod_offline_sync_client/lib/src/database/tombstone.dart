import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../crdt/extensions.dart';
import '../protocol/protocol.dart';

/// Resolves the local [CrdtSchemaTable] id for a domain table name. Returns
/// null when the table is not registered for CRDT synchronization.
typedef CrdtTableIdResolver = int? Function(String tableName);

/// Resolves the [CrdtScope] id scoping the current query. Returns null when
/// no scope is available (e.g. server-side reads outside `transactionForUser`
/// without a persistent user), in which case the query is an admin read: rows
/// are not isolated and a row is hidden only when its owning scope hides it.
typedef CrdtScopeIdResolver = int? Function();

/// Private sentinel class used to signal that the CRDT visibility filter
/// should be bypassed. Detected via `is` type check instead of string comparison.
final class _IncludeHiddenSentinel extends Expression<String> {
  const _IncludeHiddenSentinel() : super('__include_hidden__');
}

/// Extension on [Table] that exposes [includeHiddenRows] for use in `where`
/// clauses to bypass the CRDT tombstone/visibility filter.
///
/// When included in a `where` clause, all rows are returned — including those
/// that are tombstoned (soft-deleted) — instead of being hidden. The placeholder
/// is stripped before the query reaches the database, so no invalid SQL is
/// generated.
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
extension IncludeTombstonedRows on Table {
  /// Placeholder expression that signals the CRDT visibility filter should be
  /// skipped, returning tombstoned rows alongside live rows.
  Expression get includeHiddenRows => const _IncludeHiddenSentinel();
}

/// Merges [where] with CRDT visibility predicates and mutates [include] in place.
///
/// This method ensures that no rows with a hidden [CrdtDataRow.visibility] are
/// returned for queries with [where] clauses or [include] graphs. If [include]
/// is null, only the root table and [where] are merged.
///
/// Each predicate only considers [CrdtDataRow]s recorded for the queried table
/// ([tableIdForName]) and, when a scope is available ([scopeId]), isolates the
/// query to that scope's rows. This prevents a tombstone recorded for another
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
/// If [where] contains the [IncludeTombstonedRows.includeHiddenRows] sentinel,
/// the visibility filter is skipped for the root table and the sentinel is
/// stripped from the final expression so no invalid SQL is generated.
@internal
Expression? mergeWhereWithTombstone<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
  Expression? where,
  Include? include, {
  required CrdtTableIdResolver tableIdForName,
  required CrdtScopeIdResolver scopeId,
}) {
  final includeObjectPredicates = _walkIncludeGraphForTombstone(
    include,
    null,
    tableIdForName: tableIdForName,
    scopeId: scopeId,
  );

  final rootTable = serializationManager.getTableForType(T);
  final (cleanWhere, skipRootVisibility) = _stripIncludeHidden(where);
  var merged = skipRootVisibility
      ? cleanWhere
      : _mergeWhereOptional(
          cleanWhere,
          rootTable?.whereVisibleOnCrdtRow(tableIdForName, scopeId),
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
  required CrdtScopeIdResolver scopeId,
}) {
  if (inc == null) return includeObjectPredicates;
  if (inc is IncludeList) {
    // List relation: filter inside the list subquery only.
    final (cleanWhere, skipVisibility) = _stripIncludeHidden(inc.where);
    inc.where = skipVisibility
        ? cleanWhere
        : _mergeWhereOptional(
            cleanWhere,
            inc.table.whereVisibleOnCrdtRow(tableIdForName, scopeId),
          );
    return _walkIncludeGraphForTombstone(
      inc.include,
      includeObjectPredicates,
      tableIdForName: tableIdForName,
      scopeId: scopeId,
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
        scopeId: scopeId,
      );
      continue;
    }
    if (nested is IncludeObject) {
      // one-to-one / optional object: joined on the main SELECT, constrain via root WHERE.
      final childTable = selfTable.getRelationTable(entry.key);
      if (childTable != null) {
        acc = _mergeWhereOptional(
          acc,
          childTable.whereVisibleOnCrdtRow(tableIdForName, scopeId),
        );
      }
      acc = _walkIncludeGraphForTombstone(
        nested,
        acc,
        tableIdForName: tableIdForName,
        scopeId: scopeId,
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

/// Strips the [_IncludeHiddenSentinel] from [where], returning the cleaned
/// expression and a flag indicating whether the sentinel was found.
///
/// Recursively walks [TwoPartExpression] nodes to remove the sentinel wherever
/// it appears, rebuilding the tree without it. The returned [bool] is `true`
/// when the sentinel was found at any depth.
(Expression?, bool) _stripIncludeHidden(Expression? where) {
  if (where == null) return (null, false);
  if (where is _IncludeHiddenSentinel) return (null, true);
  if (where is TwoPartExpression) {
    final subs = where.subExpressions;
    final (cleanLeft, foundLeft) = _stripIncludeHidden(subs[0]);
    final (cleanRight, foundRight) = _stripIncludeHidden(subs[1]);
    if (!foundLeft && !foundRight) return (where, false);
    final Expression? cleaned;
    if (cleanLeft == null && cleanRight == null) {
      cleaned = null;
    } else if (cleanLeft == null) {
      cleaned = cleanRight;
    } else if (cleanRight == null) {
      cleaned = cleanLeft;
    } else if (where.operator == 'AND') {
      cleaned = cleanLeft & cleanRight;
    } else if (where.operator == 'OR') {
      cleaned = cleanLeft | cleanRight;
    } else {
      throw StateError(
        'Unsupported TwoPartExpression operator "${where.operator}" '
        'when stripping includeHiddenRows sentinel. '
        'Only AND and OR operators are supported.',
      );
    }
    return (cleaned, true);
  }
  return (where, false);
}

extension on Table {
  /// Creates a predicate that filters out hidden rows for the given [Table]
  /// using materialized [CrdtDataRow.visibility] metadata.
  ///
  /// Returns null when [Table] does not use a UUID primary key or is not
  /// registered for CRDT synchronization. Keeps rows when the id is null
  /// (unmatched [IncludeObject] joins) or no hidden CRDT row matches.
  ///
  /// With a scope, rows are isolated to it (`scopeId = <scope>`) and checked
  /// against the scope's tombstones with a correlated `NOT EXISTS` probe
  /// covered by the (scopeId, tblId, uuidRowId) unique index. Without a
  /// scope (admin reads), there is no isolation filter and the probe is
  /// keyed by the row's own `scopeId` column instead — covered by the same
  /// index — so a row stays visible while its owning scope sees it.
  Expression? whereVisibleOnCrdtRow(
    CrdtTableIdResolver tableIdForName,
    CrdtScopeIdResolver scopeId,
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
    final effectiveScopeId = scopeId();
    final notExistsExpr = Expression(
      'NOT EXISTS '
      '(SELECT 1 FROM "${crdtRow.tableName}" '
      'WHERE ${crdtRow.scopeId} = ${effectiveScopeId ?? scopeColumn} '
      'AND ${crdtRow.tblId} = $tableId '
      'AND ${crdtRow.uuidRowId} = $id '
      'AND ${crdtRow.visibility} > $crdtRowLastVisibleVisibilityIndex)',
    );

    return id.equals(null) |
        ((effectiveScopeId != null)
            ? (scopeColumn.equals(effectiveScopeId) & notExistsExpr)
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
