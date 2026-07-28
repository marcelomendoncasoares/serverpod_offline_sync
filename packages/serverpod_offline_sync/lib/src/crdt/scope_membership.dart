import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';

/// Resolves shared-scope membership from the `crdt_scope_members` table.
///
/// The table is `database: all`, so the same code runs on every node:
/// authoritatively on the server (the source of truth) and against the local
/// read-only cache on a follower. A user's personal scope is implicit — a user
/// always belongs to the scope whose UUID equals their own user UUID — and
/// needs no membership row. Explicit rows grant access to additional shared
/// scopes.
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
    final memberships = await CrdtScopeMember.db.find(
      session,
      where: (t) => t.userUuid.equals(userUuid),
      transaction: transaction,
      include: CrdtScopeMember.include(scope: CrdtScope.include()),
    );

    final grantsByUuid = <String, CrdtScopeGrant>{};
    for (final membership in memberships) {
      final scopeUuid = membership.scope!.uuidScopeId;
      grantsByUuid[scopeUuid.uuid] = CrdtScopeGrant(
        uuidScopeId: scopeUuid,
        role: membership.role,
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

    final membership = await CrdtScopeMember.db.findFirstRow(
      session,
      where: (t) => t.userUuid.equals(userUuid) & t.scopeId.equals(scopeId),
      transaction: transaction,
    );
    return membership?.role;
  }

  /// Reconciles the local `crdt_scope_members` cache from an authoritative
  /// [grants] announcement — a follower's read-only projection of its own
  /// memberships.
  ///
  /// Upserts the materialized shared grants (the implicit personal scope is
  /// skipped) and deletes rows for [userUuid] whose scope is no longer granted,
  /// so a revoked or demoted membership does not linger offline. Scopes must
  /// already be materialized locally; a grant whose scope is unknown is skipped.
  @internal
  static Future<void> projectFollowerMembership(
    DatabaseSession session, {
    required UuidValue userUuid,
    required List<CrdtScopeGrant> grants,
  }) async {
    final keptScopeIds = <int>[];
    final memberships = <CrdtScopeMember>[];

    for (final grant in grants) {
      if (grant.uuidScopeId == userUuid) continue; // personal scope is implicit
      final scopeId = await _scopeIdForUuid(session, grant.uuidScopeId);
      if (scopeId == null) continue; // not materialized locally yet

      keptScopeIds.add(scopeId);
      memberships.add(
        CrdtScopeMember(
          scopeId: scopeId,
          userUuid: userUuid,
          role: grant.role,
        ),
      );
    }

    if (memberships.isNotEmpty) {
      await CrdtScopeMember.db.upsert(
        session,
        memberships,
        conflictColumns: (t) => [t.userUuid, t.scopeId],
        updateColumns: (t) => [t.role],
        noReturn: true,
      );
    }

    await CrdtScopeMember.db.deleteWhere(
      session,
      where: (t) =>
          t.userUuid.equals(userUuid) &
          (keptScopeIds.isEmpty
              ? Constant.bool(true)
              : t.scopeId.notInSet(keptScopeIds.toSet())),
      noReturn: true,
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

Future<int?> _scopeIdForUuid(
  DatabaseSession session,
  UuidValue scopeUuid, {
  Transaction? transaction,
}) async {
  final scope = await CrdtScope.db.findFirstRow(
    session,
    where: (t) => t.uuidScopeId.equals(scopeUuid),
    transaction: transaction,
  );
  return scope?.id;
}
