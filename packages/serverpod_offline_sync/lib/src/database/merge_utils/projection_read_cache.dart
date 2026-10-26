part of 'foreign_key_projector.dart';

/// Read snapshots shared only by the two projection passes of one locked merge.
///
/// Projection mutates its working maps, so readers copy snapshots before using
/// them. Physical writes invalidate their rows and every claim lookup on those
/// tables. The next pass still walks the closure and resolves all conflicts.
@internal
class CrdtProjectionReadCache {
  CrdtProjectionReadCache._(this._context, this._transaction)
    : _spaceId = _context.spaceIdFor(_transaction);

  final CrdtRecorderContext _context;
  final Transaction _transaction;
  final int _spaceId;
  final _rows = <MergeRowKey, _ProjectionReadSnapshot?>{};
  final _claims = <(String, bool, String), Set<UuidValue>>{};

  void _checkScope(CrdtRecorderContext context, Transaction transaction) {
    if (!identical(context, _context) ||
        !identical(transaction, _transaction) ||
        context.spaceIdFor(transaction) != _spaceId) {
      throw StateError('Projection reads cannot cross transactions or spaces.');
    }
  }

  /// Forgets both row snapshots and lookups that might gain or lose a claimant.
  void invalidateRows(Iterable<MergeRowKey> rows) {
    final tables = <String>{};
    for (final row in rows) {
      _rows.remove(row);
      tables.add(row.$1);
    }
    _claims.removeWhere((key, _) => tables.contains(key.$1));
  }

  (String, bool, String) _claimKey(
    String table,
    List<Map<String, Set<Object?>>> claims, {
    required bool attempted,
  }) {
    // Preserve each composite claim; only the order of OR alternatives,
    // columns, and IN values is immaterial. Encoding boundaries prevents
    // names or string values from aliasing another claim's signature.
    final alternatives = <String>[];
    for (final claim in claims) {
      final columns = claim.keys.toList()..sort();
      alternatives.add(
        jsonEncode([
          for (final column in columns)
            [
              column,
              (claim[column]!
                  .map(
                    (value) =>
                        jsonEncode([value.runtimeType.toString(), value.sqlLiteral()]),
                  )
                  .toList()
                ..sort()),
            ],
        ]),
      );
    }
    alternatives.sort();
    return (table, attempted, jsonEncode(alternatives));
  }
}

typedef _ProjectionReadSnapshot = ({
  _ProjectedForeignKeyRow row,
  Set<String> columns,
  Map<MergeFieldKey, int> fieldIds,
  Map<MergeFieldKey, Hlc> fieldHlcs,
  Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
});

_ProjectedForeignKeyRow _copyProjectionRow(_ProjectedForeignKeyRow row) => (
  key: row.key,
  crdtRow: row.crdtRow.copyWith(),
  values: Map<String, Object?>.from(row.values),
);
