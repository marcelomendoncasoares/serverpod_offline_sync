import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

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
    final memberships = await CrdtScopeMember.db.find(
      session,
      where: (t) => t.userUuid.equals(userUuid),
      include: CrdtScopeMember.include(scope: CrdtScope.include()),
      transaction: transaction,
    );

    final scopesByUuid = <String, UuidValue>{userUuid.uuid: userUuid};
    for (final membership in memberships) {
      final scopeUuid = membership.scope?.uuidScopeId;
      if (scopeUuid != null) {
        scopesByUuid[scopeUuid.uuid] = scopeUuid;
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

    final membership = await CrdtScopeMember.db.findFirstRow(
      session,
      where: (t) => t.userUuid.equals(userUuid) & t.scope.uuidScopeId.equals(scopeUuid),
      transaction: transaction,
    );
    return membership != null;
  }
}
