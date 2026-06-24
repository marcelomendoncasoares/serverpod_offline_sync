import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart' show CrdtScope, CrdtScopeMember, Protocol;

/// Server-side membership helpers for shared CRDT scopes.
///
/// A user's personal scope is implicit and is always included. Explicit rows in
/// `crdt_scope_members` grant access to additional shared scopes.
class CrdtScopeMembership {
  const CrdtScopeMembership._();
  // TODO: Remove the manual queries from this class once this package uses
  // shared tables instead of mixing client and server tables.

  /// Returns the authoritative scope UUIDs the authenticated [userUuid] may sync.
  ///
  /// The returned set includes the implicit personal scope and explicit shared
  /// memberships, de-duplicated and sorted by UUID string so both peers can
  /// iterate deterministically.
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

    return scopesByUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
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
    'SELECT "${CrdtScopeMember.t.scopeId.columnName}" FROM "${CrdtScopeMember.t.tableName}" '
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
