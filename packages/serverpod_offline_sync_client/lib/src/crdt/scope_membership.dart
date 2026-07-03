import 'package:meta/meta.dart';
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
    final grants = await memberGrants(
      session,
      userUuid,
      transaction: transaction,
    );
    return [for (final grant in grants) grant.uuidScopeId];
  }

  /// Returns the authoritative scope grants for [userUuid].
  ///
  /// Like [memberScopes] but carries each scope's `role`. The implicit
  /// personal scope is included with [CrdtScopeRole.readWrite]. Used to build the
  /// authoritative [CrdtSyncScopeSet] announcement so a follower can project
  /// roles into its local cache.
  static Future<List<CrdtScopeGrant>> memberGrants(
    DatabaseSession session,
    UuidValue userUuid, {
    Transaction? transaction,
  }) async {
    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final result = await session.db.unsafeQuery(
      'SELECT s."${CrdtScope.t.uuidScopeId.columnName}", '
      'm."${CrdtScopeMember.t.role.columnName}" '
      'FROM "${CrdtScopeMember.t.tableName}" m '
      'JOIN "${CrdtScope.t.tableName}" s '
      'ON s."${CrdtScope.t.id.columnName}" = m."${CrdtScopeMember.t.scopeId.columnName}" '
      'WHERE m."${CrdtScopeMember.t.userUuid.columnName}" = $encodedUserUuid',
      transaction: transaction,
    );

    final grantsByUuid = <String, CrdtScopeGrant>{};
    for (final row in result) {
      final scopeUuid = Protocol().deserialize<UuidValue>(row[0]);
      grantsByUuid[scopeUuid.uuid] = CrdtScopeGrant(
        uuidScopeId: scopeUuid,
        role: _roleFromDatabase(row[1]),
      );
    }
    // Assigned after the shared rows so the personal grant stays readWrite
    // even if a stray membership row exists for it, matching [roleOf].
    grantsByUuid[userUuid.uuid] = CrdtScopeGrant(
      uuidScopeId: userUuid,
      role: CrdtScopeRole.readWrite,
    );

    return grantsByUuid.values.toList()
      ..sort((a, b) => a.uuidScopeId.uuid.compareTo(b.uuidScopeId.uuid));
  }

  /// The role [userUuid] holds in [scopeUuid], or null if none is recorded.
  ///
  /// The implicit personal scope resolves to [CrdtScopeRole.readWrite]. On the
  /// server this reads authoritative membership; on a client it reads the
  /// projected membership cache.
  static Future<CrdtScopeRole?> roleOf(
    DatabaseSession session, {
    required UuidValue userUuid,
    required UuidValue scopeUuid,
    Transaction? transaction,
  }) async {
    if (userUuid == scopeUuid) return CrdtScopeRole.readWrite;

    final scopeId = await _scopeIdForUuid(
      session,
      scopeUuid,
      transaction: transaction,
    );
    if (scopeId == null) return null;

    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final result = await session.db.unsafeQuery(
      'SELECT "${CrdtScopeMember.t.role.columnName}" '
      'FROM "${CrdtScopeMember.t.tableName}" '
      'WHERE "${CrdtScopeMember.t.userUuid.columnName}" = $encodedUserUuid '
      'AND "${CrdtScopeMember.t.scopeId.columnName}" = $encodedScopeId '
      'LIMIT 1',
      transaction: transaction,
    );
    return result.isEmpty ? null : _roleFromDatabase(result.first[0]);
  }

  /// Reconciles the local `crdt_scope_members` cache from an authoritative
  /// [grants] announcement — a follower's read-only projection of its own
  /// memberships.
  ///
  /// Upserts a row per shared grant (the implicit personal scope is skipped)
  /// and deletes rows for [userUuid] whose scope is no longer granted, so a
  /// revoked or demoted membership does not linger offline. Scopes must already
  /// be materialized locally; a grant whose scope is unknown is skipped.
  @internal
  static Future<void> projectFollowerMembership(
    DatabaseSession session, {
    required UuidValue userUuid,
    required List<CrdtScopeGrant> grants,
  }) async {
    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final keptScopeIds = <int>[];

    for (final grant in grants) {
      if (grant.uuidScopeId == userUuid) continue; // personal scope is implicit
      final scopeId = await _scopeIdForUuid(session, grant.uuidScopeId);
      if (scopeId == null) continue; // not materialized locally yet

      keptScopeIds.add(scopeId);
      final encodedScopeId = ValueEncoder.instance.convert(scopeId);
      final encodedRole = ValueEncoder.instance.convert(grant.role.toJson());
      await session.db.unsafeExecute(
        'INSERT INTO "${CrdtScopeMember.t.tableName}" '
        '("${CrdtScopeMember.t.scopeId.columnName}", '
        '"${CrdtScopeMember.t.userUuid.columnName}", '
        '"${CrdtScopeMember.t.role.columnName}") '
        'VALUES ($encodedScopeId, $encodedUserUuid, $encodedRole) '
        'ON CONFLICT ("${CrdtScopeMember.t.userUuid.columnName}", '
        '"${CrdtScopeMember.t.scopeId.columnName}") '
        'DO UPDATE SET "${CrdtScopeMember.t.role.columnName}" = $encodedRole',
      );
    }

    final notInClause = keptScopeIds.isEmpty
        ? ''
        : 'AND "${CrdtScopeMember.t.scopeId.columnName}" NOT IN '
              '(${keptScopeIds.map(ValueEncoder.instance.convert).join(', ')})';
    await session.db.unsafeExecute(
      'DELETE FROM "${CrdtScopeMember.t.tableName}" '
      'WHERE "${CrdtScopeMember.t.userUuid.columnName}" = $encodedUserUuid '
      '$notInClause',
    );
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
    final role = await roleOf(
      session,
      userUuid: userUuid,
      scopeUuid: scopeUuid,
      transaction: transaction,
    );
    return role != null;
  }
}

CrdtScopeRole _roleFromDatabase(Object? value) {
  if (value == null) {
    throw StateError('crdt_scope_members.role must not be null.');
  }
  return CrdtScopeRole.fromJson(value as String);
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
