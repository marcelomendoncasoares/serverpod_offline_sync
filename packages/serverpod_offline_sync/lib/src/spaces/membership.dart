import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';

/// Resolves shared-space membership from the `offline_sync_space_members` table.
///
/// The table is `database: all`, so the same code runs on every node:
/// authoritatively on the server (the source of truth) and against the local
/// read-only cache on a follower. A user's personal space is implicit — a user
/// always belongs to the space whose UUID equals their own user UUID — and
/// needs no membership row. Explicit rows grant access to additional shared
/// spaces.
class OfflineSyncSpaceMembership {
  const OfflineSyncSpaceMembership._();

  /// Returns the space UUIDs [userUuid] may sync.
  ///
  /// Includes the implicit personal space and every explicit shared membership,
  /// de-duplicated and sorted by UUID string so both peers iterate
  /// deterministically.
  static Future<List<UuidValue>> memberSpaces(
    DatabaseSession session,
    UuidValue userUuid, {
    Transaction? transaction,
  }) async {
    final grants = await memberGrants(
      session,
      userUuid,
      transaction: transaction,
    );
    return [for (final grant in grants) grant.uuidSpaceId];
  }

  /// Returns the authoritative space grants for [userUuid].
  ///
  /// Like [memberSpaces] but carries each space's `role`. The implicit
  /// personal space is included with [OfflineSyncSpaceRole.readWrite]. Used to build the
  /// authoritative [OfflineSyncSpaceSet] announcement so a follower can project
  /// roles into its local cache.
  static Future<List<OfflineSyncSpaceGrant>> memberGrants(
    DatabaseSession session,
    UuidValue userUuid, {
    Transaction? transaction,
  }) async {
    final memberships = await OfflineSyncSpaceMember.db.find(
      session,
      where: (t) => t.userUuid.equals(userUuid),
      transaction: transaction,
      include: OfflineSyncSpaceMember.include(space: OfflineSyncSpace.include()),
    );

    final grantsByUuid = <String, OfflineSyncSpaceGrant>{};
    for (final membership in memberships) {
      final spaceUuid = membership.space!.uuidSpaceId;
      grantsByUuid[spaceUuid.uuid] = OfflineSyncSpaceGrant(
        uuidSpaceId: spaceUuid,
        role: membership.role,
      );
    }
    // Assigned after the shared rows so the personal grant stays readWrite
    // even if a stray membership row exists for it, matching [roleOf].
    grantsByUuid[userUuid.uuid] = OfflineSyncSpaceGrant(
      uuidSpaceId: userUuid,
      role: OfflineSyncSpaceRole.readWrite,
    );

    return grantsByUuid.values.toList()
      ..sort((a, b) => a.uuidSpaceId.uuid.compareTo(b.uuidSpaceId.uuid));
  }

  /// The role [userUuid] holds in [spaceUuid], or null if none is recorded.
  ///
  /// The implicit personal space resolves to [OfflineSyncSpaceRole.readWrite]. On the
  /// server this reads authoritative membership; on a client it reads the
  /// projected membership cache.
  static Future<OfflineSyncSpaceRole?> roleOf(
    DatabaseSession session, {
    required UuidValue userUuid,
    required UuidValue spaceUuid,
    Transaction? transaction,
  }) async {
    if (userUuid == spaceUuid) return OfflineSyncSpaceRole.readWrite;

    final spaceId = await _spaceIdForUuid(
      session,
      spaceUuid,
      transaction: transaction,
    );
    if (spaceId == null) return null;

    final membership = await OfflineSyncSpaceMember.db.findFirstRow(
      session,
      where: (t) => t.userUuid.equals(userUuid) & t.spaceId.equals(spaceId),
      transaction: transaction,
    );
    return membership?.role;
  }

  /// Reconciles the local `offline_sync_space_members` cache from an authoritative
  /// [grants] announcement — a follower's read-only projection of its own
  /// memberships.
  ///
  /// Upserts the materialized shared grants (the implicit personal space is
  /// skipped) and deletes rows for [userUuid] whose space is no longer granted,
  /// so a revoked or demoted membership does not linger offline. Spaces must
  /// already be materialized locally; a grant whose space is unknown is skipped.
  @internal
  static Future<void> projectFollowerMembership(
    DatabaseSession session, {
    required UuidValue userUuid,
    required List<OfflineSyncSpaceGrant> grants,
  }) async {
    final keptSpaceIds = <int>[];
    final memberships = <OfflineSyncSpaceMember>[];

    for (final grant in grants) {
      if (grant.uuidSpaceId == userUuid) continue; // personal space is implicit
      final spaceId = await _spaceIdForUuid(session, grant.uuidSpaceId);
      if (spaceId == null) continue; // not materialized locally yet

      keptSpaceIds.add(spaceId);
      memberships.add(
        OfflineSyncSpaceMember(
          spaceId: spaceId,
          userUuid: userUuid,
          role: grant.role,
        ),
      );
    }

    if (memberships.isNotEmpty) {
      await OfflineSyncSpaceMember.db.upsert(
        session,
        memberships,
        conflictColumns: (t) => [t.userUuid, t.spaceId],
        updateColumns: (t) => [t.role],
        noReturn: true,
      );
    }

    await OfflineSyncSpaceMember.db.deleteWhere(
      session,
      where: (t) =>
          t.userUuid.equals(userUuid) &
          (keptSpaceIds.isEmpty
              ? Constant.bool(true)
              : t.spaceId.notInSet(keptSpaceIds.toSet())),
      noReturn: true,
    );
  }

  /// Returns whether [userUuid] may act in [spaceUuid].
  ///
  /// The implicit personal space is accepted without a membership row.
  static Future<bool> isMember(
    DatabaseSession session, {
    required UuidValue userUuid,
    required UuidValue spaceUuid,
    Transaction? transaction,
  }) async {
    final role = await roleOf(
      session,
      userUuid: userUuid,
      spaceUuid: spaceUuid,
      transaction: transaction,
    );
    return role != null;
  }
}

Future<int?> _spaceIdForUuid(
  DatabaseSession session,
  UuidValue spaceUuid, {
  Transaction? transaction,
}) async {
  final space = await OfflineSyncSpace.db.findFirstRow(
    session,
    where: (t) => t.uuidSpaceId.equals(spaceUuid),
    transaction: transaction,
  );
  return space?.id;
}
