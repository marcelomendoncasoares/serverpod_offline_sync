import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// Copies an include graph before adding query-owned visibility predicates.
///
/// Generated include classes only expose their fields through these base
/// interfaces. Keeping a separate graph also isolates concurrent subscriptions
/// and reads that reuse the caller's include objects.
@internal
Include? copyInclude(Include? include) {
  if (include == null) return null;
  if (include is IncludeList) return _IncludeListCopy(include);
  return _IncludeObjectCopy(include);
}

class _IncludeObjectCopy extends IncludeObject {
  _IncludeObjectCopy(Include source)
    : table = source.table,
      includes = source.includes.map(
        (key, value) => MapEntry(key, copyInclude(value)),
      );

  @override
  final Table table;

  @override
  final Map<String, Include?> includes;
}

// Mirrors the Serverpod 4.1 IncludeList API. When upgrading Serverpod, keep all
// query options in this snapshot in sync with that interface.
class _IncludeListCopy extends IncludeList {
  _IncludeListCopy(IncludeList source)
    : table = source.table,
      super(
        where: source.where,
        limit: source.limit,
        offset: source.offset,
        orderBy: source.orderBy,
        orderByList: source.orderByList?.toList(),
        include: source.include == null ? null : _IncludeObjectCopy(source.include!),
      );

  @override
  final Table table;

  @override
  Map<String, Include?> get includes => include?.includes ?? {};
}
