import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

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
    await _runInTransaction(transaction, (tx) async {
      final scopeId = await _insertScope(scope, tx);
      await _applyGrants(scopeId, grants ?? const {}, tx);
    });
    return scope;
  }

  /// Creates a shared scope granting [user] the given [role], in one transaction.
  Future<UuidValue> createFor(
    UuidValue user, {
    CrdtScopeRole role = CrdtScopeRole.readWrite,
    Transaction? transaction,
  }) {
    return create(grants: {user: role}, transaction: transaction);
  }

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
    return _runInTransaction(transaction, (tx) async {
      final scopeId = await _scopeIdForUuid(scope, transaction: tx);
      if (scopeId == null) {
        throw ArgumentError.value(
          scope,
          'scope',
          'No CRDT scope row exists for the scope UUID.',
        );
      }
      await _applyGrants(scopeId, grants, tx);
    });
  }

  /// Removes [user]'s membership in [scope]. A no-op if not a member.
  Future<void> revoke({
    required UuidValue scope,
    required UuidValue user,
    Transaction? transaction,
  }) async {
    final encodedUser = ValueEncoder.instance.convert(user);
    final encodedScope = ValueEncoder.instance.convert(scope);
    await _session.db.unsafeExecute(
      'DELETE FROM "${CrdtScopeMember.t.tableName}" '
      'WHERE "${CrdtScopeMember.t.userUuid.columnName}" = $encodedUser '
      'AND "${CrdtScopeMember.t.scopeId.columnName}" IN ( '
      'SELECT "${CrdtScope.t.id.columnName}" '
      'FROM "${CrdtScope.t.tableName}" '
      'WHERE "${CrdtScope.t.uuidScopeId.columnName}" = $encodedScope '
      ')',
      transaction: transaction,
    );
  }

  /// The role [user] holds in [scope], or null if not a member. The read an app
  /// wraps with its own admin policy before calling [grant] / [revoke].
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
    final encodedScope = ValueEncoder.instance.convert(scope);
    final result = await _session.db.unsafeQuery(
      'SELECT m."${CrdtScopeMember.t.userUuid.columnName}", '
      'm."${CrdtScopeMember.t.role.columnName}" '
      'FROM "${CrdtScopeMember.t.tableName}" m '
      'JOIN "${CrdtScope.t.tableName}" s '
      'ON s."${CrdtScope.t.id.columnName}" = '
      'm."${CrdtScopeMember.t.scopeId.columnName}" '
      'WHERE s."${CrdtScope.t.uuidScopeId.columnName}" = $encodedScope',
      transaction: transaction,
    );

    return {
      for (final row in result)
        Protocol().deserialize<UuidValue>(row[0]): _roleFromDatabase(row[1]),
    };
  }

  Future<T> _runInTransaction<T>(
    Transaction? transaction,
    Future<T> Function(Transaction transaction) fn,
  ) {
    if (transaction != null) return fn(transaction);
    return _session.db.transaction(fn);
  }

  Future<int> _insertScope(UuidValue scope, Transaction transaction) async {
    final encodedScope = ValueEncoder.instance.convert(scope);
    final result = await _session.db.unsafeQuery(
      'INSERT INTO "${CrdtScope.t.tableName}" '
      '("${CrdtScope.t.uuidScopeId.columnName}") '
      'VALUES ($encodedScope) '
      'RETURNING "${CrdtScope.t.id.columnName}"',
      transaction: transaction,
    );
    return result.single[0] as int;
  }

  Future<void> _applyGrants(
    int scopeId,
    Map<UuidValue, CrdtScopeRole> grants,
    Transaction transaction,
  ) async {
    if (grants.isEmpty) return;

    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    for (final grant in grants.entries) {
      final encodedUser = ValueEncoder.instance.convert(grant.key);
      final encodedRole = ValueEncoder.instance.convert(grant.value.toJson());
      await _session.db.unsafeExecute(
        'INSERT INTO "${CrdtScopeMember.t.tableName}" '
        '("${CrdtScopeMember.t.scopeId.columnName}", '
        '"${CrdtScopeMember.t.userUuid.columnName}", '
        '"${CrdtScopeMember.t.role.columnName}") '
        'VALUES ($encodedScopeId, $encodedUser, $encodedRole) '
        'ON CONFLICT ("${CrdtScopeMember.t.userUuid.columnName}", '
        '"${CrdtScopeMember.t.scopeId.columnName}") '
        'DO UPDATE SET "${CrdtScopeMember.t.role.columnName}" = $encodedRole',
        transaction: transaction,
      );
    }
  }

  Future<int?> _scopeIdForUuid(
    UuidValue scope, {
    required Transaction transaction,
  }) async {
    final encodedScope = ValueEncoder.instance.convert(scope);
    final result = await _session.db.unsafeQuery(
      'SELECT "${CrdtScope.t.id.columnName}" '
      'FROM "${CrdtScope.t.tableName}" '
      'WHERE "${CrdtScope.t.uuidScopeId.columnName}" = $encodedScope '
      'LIMIT 1',
      transaction: transaction,
    );
    return result.isEmpty ? null : result.single[0] as int;
  }
}

CrdtScopeRole _roleFromDatabase(Object? value) {
  if (value == null) {
    throw StateError('crdt_scope_members.role must not be null.');
  }
  return CrdtScopeRole.fromJson(value as String);
}
