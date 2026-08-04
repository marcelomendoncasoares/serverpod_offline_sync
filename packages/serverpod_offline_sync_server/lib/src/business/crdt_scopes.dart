import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

/// Server-side service for managing CRDT shared-scope membership.
///
/// This is a data-invariant service, not an authorization policy. Applications
/// call it from their own endpoints after applying their own access checks.
class CrdtScopes {
  /// Creates a session-bound CRDT scope management service.
  CrdtScopes(this._session);

  final Session _session;

  /// Creates a shared scope and returns its UUID.
  ///
  /// [grants], if given, adds each user as a member with its role, applied in
  /// one transaction with the scope insert. With no grants the scope is created
  /// dormant — it exists but no one can sync it until membership is granted.
  Future<UuidValue> create({
    Map<UuidValue, CrdtScopeRole>? grants,
    Transaction? transaction,
  }) async {
    final scope = const Uuid().v7obj();
    await DatabaseUtil.runInTransactionOrSavepoint(
      _session.db,
      transaction,
      (tx) async {
        final insertedScope = await CrdtScope.db.insertRow(
          _session,
          CrdtScope(uuidScopeId: scope),
          transaction: tx,
        );
        await _applyGrants(insertedScope.id!, grants ?? const {}, tx);
      },
    );
    return scope;
  }

  /// Creates a shared scope granting [user] the given [role], in one transaction.
  Future<UuidValue> createFor(
    UuidValue user, {
    CrdtScopeRole role = CrdtScopeRole.readWrite,
    Transaction? transaction,
  }) => create(grants: {user: role}, transaction: transaction);

  /// Grants [user] the given [role] in [scope], upserting an existing membership.
  Future<void> grant({
    required UuidValue scope,
    required UuidValue user,
    required CrdtScopeRole role,
    Transaction? transaction,
  }) => grantAll(scope, {user: role}, transaction: transaction);

  /// Grants several members in one transaction; the bulk twin of [grant].
  Future<void> grantAll(
    UuidValue scope,
    Map<UuidValue, CrdtScopeRole> grants, {
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _session.db,
      transaction,
      (tx) async {
        final scopeRow = await CrdtScope.db.findFirstRow(
          _session,
          where: (t) => t.uuidScopeId.equals(scope),
          transaction: tx,
        );
        final scopeId = scopeRow?.id;
        if (scopeId == null) {
          throw CrdtScopeNotFoundException(scope);
        }
        await _applyGrants(scopeId, grants, tx);
      },
    );
  }

  /// Removes [user]'s membership in [scope]. A no-op if not a member.
  Future<void> revoke({
    required UuidValue scope,
    required UuidValue user,
    Transaction? transaction,
  }) async {
    await CrdtScopeMember.db.deleteWhere(
      _session,
      where: (t) => t.userUuid.equals(user) & t.scope.uuidScopeId.equals(scope),
      transaction: transaction,
      noReturn: true,
    );
  }

  /// The role [user] holds in [scope], or null if not a member.
  Future<CrdtScopeRole?> roleOf({
    required UuidValue user,
    required UuidValue scope,
    Transaction? transaction,
  }) {
    return CrdtScopeMembership.roleOf(
      _session,
      userUuid: user,
      scopeUuid: scope,
      transaction: transaction,
    );
  }

  /// The members of [scope] and their roles.
  Future<Map<UuidValue, CrdtScopeRole>> members(
    UuidValue scope, {
    Transaction? transaction,
  }) async {
    final memberships = await CrdtScopeMember.db.find(
      _session,
      where: (t) => t.scope.uuidScopeId.equals(scope),
      transaction: transaction,
    );

    return {
      for (final membership in memberships) membership.userUuid: membership.role,
    };
  }

  Future<void> _applyGrants(
    int scopeId,
    Map<UuidValue, CrdtScopeRole> grants,
    Transaction transaction,
  ) async {
    if (grants.isEmpty) return;

    await CrdtScopeMember.db.upsert(
      _session,
      [
        for (final grant in grants.entries)
          CrdtScopeMember(
            scopeId: scopeId,
            userUuid: grant.key,
            role: grant.value,
          ),
      ],
      conflictColumns: (t) => [t.userUuid, t.scopeId],
      updateColumns: (t) => [t.role],
      transaction: transaction,
      noReturn: true,
    );
  }
}

/// Thrown when a scope-management operation targets a missing CRDT scope row.
final class CrdtScopeNotFoundException implements Exception {
  /// Creates a [CrdtScopeNotFoundException].
  const CrdtScopeNotFoundException(this.scope);

  /// The scope UUID that could not be found.
  final UuidValue scope;

  @override
  String toString() =>
      'CrdtScopeNotFoundException: no CRDT scope row exists for "$scope".';
}
