import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// Resolves shared-scope membership from the `crdt_scope_members` table.
///
/// The table is `database: all`, so the same code runs on every node:
/// authoritatively on the server (the source of truth) and against the local
/// read-only cache on a follower. A user's personal scope is implicit — a user
/// always belongs to the scope whose UUID equals their own user UUID — and
/// needs no membership row. Explicit rows grant access to additional shared
/// scopes.
///
/// Queries are raw SQL rather than the generated ORM on purpose: `find<T>`
/// resolves the table through the session's serialization manager keyed by the
/// model [Type], and a server session only registers the server-package model
/// classes — never this client-package [CrdtScopeMember]. Raw SQL is
/// serialization-manager-agnostic and runs identically on both ends, matching
/// the rest of the CRDT engine's cross-node queries.
class CrdtScopeMembership {
  const CrdtScopeMembership._();

  /// Returns the scope UUIDs [userUuid] may sync.
  ///
  /// Includes the implicit personal scope and every explicit shared membership,
  /// de-duplicated and sorted by UUID string so both peers iterate
  /// deterministically.
  static Future<List<UuidValue>> memberScopes(
    DatabaseSession session,
    UuidValue userUuid, {
    Transaction? transaction,
  }) async {
    final scopesByUuid = <String, UuidValue>{userUuid.uuid: userUuid};
    final scopeIds = await _explicitMemberScopeIds(
      session,
      userUuid,
      transaction: transaction,
    );

    if (scopeIds.isNotEmpty) {
      final scopes = await _scopeUuidsForIds(
        session,
        scopeIds,
        transaction: transaction,
      );
      for (final scopeUuid in scopes) {
        scopesByUuid[scopeUuid.uuid] = scopeUuid;
      }
    }

    return scopesByUuid.values.toList()
      ..sort((a, b) => a.uuid.compareTo(b.uuid));
  }

  /// Returns whether [userUuid] may act in [scopeUuid].
  ///
  /// The implicit personal scope is accepted without a membership row.
  static Future<bool> isMember(
    DatabaseSession session, {
    required UuidValue userUuid,
    required UuidValue scopeUuid,
    Transaction? transaction,
  }) async {
    if (userUuid == scopeUuid) return true;

    final scopeId = await _scopeIdForUuid(
      session,
      scopeUuid,
      transaction: transaction,
    );
    if (scopeId == null) return false;

    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final result = await session.db.unsafeQuery(
      'SELECT 1 FROM "${CrdtScopeMember.t.tableName}" '
      'WHERE "${CrdtScopeMember.t.userUuid.columnName}" = $encodedUserUuid '
      'AND "${CrdtScopeMember.t.scopeId.columnName}" = $encodedScopeId '
      'LIMIT 1',
      transaction: transaction,
    );
    return result.isNotEmpty;
  }
}

Future<Set<int>> _explicitMemberScopeIds(
  DatabaseSession session,
  UuidValue userUuid, {
  Transaction? transaction,
}) async {
  final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
  final result = await session.db.unsafeQuery(
    'SELECT "${CrdtScopeMember.t.scopeId.columnName}" '
    'FROM "${CrdtScopeMember.t.tableName}" '
    'WHERE "${CrdtScopeMember.t.userUuid.columnName}" = $encodedUserUuid',
    transaction: transaction,
  );
  return {for (final row in result) row[0] as int};
}

Future<List<UuidValue>> _scopeUuidsForIds(
  DatabaseSession session,
  Set<int> scopeIds, {
  Transaction? transaction,
}) async {
  if (scopeIds.isEmpty) return [];
  final encodedScopeIds = scopeIds.map(ValueEncoder.instance.convert).join(', ');
  final result = await session.db.unsafeQuery(
    'SELECT "${CrdtScope.t.uuidScopeId.columnName}" FROM "${CrdtScope.t.tableName}" '
    'WHERE "${CrdtScope.t.id.columnName}" IN ($encodedScopeIds)',
    transaction: transaction,
  );
  return [for (final row in result) Protocol().deserialize<UuidValue>(row[0])];
}

Future<int?> _scopeIdForUuid(
  DatabaseSession session,
  UuidValue scopeUuid, {
  Transaction? transaction,
}) async {
  final encodedScopeUuid = ValueEncoder.instance.convert(scopeUuid);
  final result = await session.db.unsafeQuery(
    'SELECT "${CrdtScope.t.id.columnName}" FROM "${CrdtScope.t.tableName}" '
    'WHERE "${CrdtScope.t.uuidScopeId.columnName}" = $encodedScopeUuid '
    'LIMIT 1',
    transaction: transaction,
  );
  return result.isEmpty ? null : result.first[0] as int;
}
