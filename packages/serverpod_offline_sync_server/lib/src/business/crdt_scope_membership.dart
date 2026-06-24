import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show CrdtScope;

/// Server-side membership helpers for shared CRDT scopes.
///
/// A user's personal scope is implicit and is always included. Explicit rows in
/// `crdt_scope_members` grant access to additional shared scopes.
class CrdtScopeMembership {
  const CrdtScopeMembership._();

  /// Returns the authoritative scope UUIDs the authenticated [userUuid] may sync.
  ///
  /// The returned set includes the implicit personal scope and explicit shared
  /// memberships, de-duplicated and sorted by UUID string so both peers can
  /// iterate deterministically.
  static Future<List<UuidValue>> memberScopes(
    Session session,
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
      final scopes = await CrdtScope.db.find(
        session,
        where: (t) => t.id.inSet(scopeIds),
        transaction: transaction,
      );
      for (final scope in scopes) {
        scopesByUuid[scope.uuidScopeId.uuid] = scope.uuidScopeId;
      }
    }

    return scopesByUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
  }

  /// Returns whether [userUuid] may act in [scopeUuid].
  ///
  /// The implicit personal scope is accepted without a membership row.
  static Future<bool> isMember(
    Session session, {
    required UuidValue userUuid,
    required UuidValue scopeUuid,
    Transaction? transaction,
  }) async {
    if (userUuid == scopeUuid) return true;

    final scope = await CrdtScope.db.findFirstRow(
      session,
      where: (t) => t.uuidScopeId.equals(scopeUuid),
      transaction: transaction,
    );
    final scopeId = scope?.id;
    if (scopeId == null) return false;

    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final result = await session.db.unsafeQuery(
      'SELECT 1 FROM "crdt_scope_members" '
      'WHERE "userUuid" = $encodedUserUuid '
      'AND "scopeId" = $encodedScopeId '
      'LIMIT 1',
      transaction: transaction,
    );
    return result.isNotEmpty;
  }
}

Future<Set<int>> _explicitMemberScopeIds(
  Session session,
  UuidValue userUuid, {
  Transaction? transaction,
}) async {
  final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
  final result = await session.db.unsafeQuery(
    'SELECT "scopeId" FROM "crdt_scope_members" '
    'WHERE "userUuid" = $encodedUserUuid',
    transaction: transaction,
  );
  return {
    for (final row in result) row[0] as int,
  };
}
