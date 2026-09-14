import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

/// Server-side service for managing CRDT shared-space membership.
///
/// This is a data-invariant service, not an authorization policy. Applications
/// call it from their own endpoints after applying their own access checks.
class OfflineSyncSpaces {
  /// Creates a session-bound CRDT space management service.
  OfflineSyncSpaces(this._session);

  final Session _session;

  /// Creates a shared space and returns its UUID.
  ///
  /// [grants], if given, adds each user as a member with its role, applied in
  /// one transaction with the space insert. With no grants the space is created
  /// dormant — it exists but no one can sync it until membership is granted.
  Future<UuidValue> create({
    Map<UuidValue, OfflineSyncSpaceRole>? grants,
    Transaction? transaction,
  }) async {
    final space = const Uuid().v7obj();
    await DatabaseUtil.runInTransactionOrSavepoint(
      _session.db,
      transaction,
      (tx) async {
        final insertedSpace = await OfflineSyncSpace.db.insertRow(
          _session,
          OfflineSyncSpace(uuidSpaceId: space),
          transaction: tx,
        );
        await _applyGrants(insertedSpace.id!, grants ?? const {}, tx);
      },
    );
    return space;
  }

  /// Creates a shared space granting [user] the given [role], in one transaction.
  Future<UuidValue> createFor(
    UuidValue user, {
    OfflineSyncSpaceRole role = OfflineSyncSpaceRole.readWrite,
    Transaction? transaction,
  }) => create(grants: {user: role}, transaction: transaction);

  /// Grants [user] the given [role] in [space], upserting an existing membership.
  Future<void> grant({
    required UuidValue space,
    required UuidValue user,
    required OfflineSyncSpaceRole role,
    Transaction? transaction,
  }) => grantAll(space, {user: role}, transaction: transaction);

  /// Grants several members in one transaction; the bulk twin of [grant].
  Future<void> grantAll(
    UuidValue space,
    Map<UuidValue, OfflineSyncSpaceRole> grants, {
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _session.db,
      transaction,
      (tx) async {
        final spaceRow = await OfflineSyncSpace.db.findFirstRow(
          _session,
          where: (t) => t.uuidSpaceId.equals(space),
          transaction: tx,
        );
        final spaceId = spaceRow?.id;
        if (spaceId == null) {
          throw OfflineSyncSpaceNotFoundException(space);
        }
        await _applyGrants(spaceId, grants, tx);
      },
    );
  }

  /// Removes [user]'s membership in [space]. A no-op if not a member.
  Future<void> revoke({
    required UuidValue space,
    required UuidValue user,
    Transaction? transaction,
  }) async {
    await OfflineSyncSpaceMember.db.deleteWhere(
      _session,
      where: (t) => t.userUuid.equals(user) & t.space.uuidSpaceId.equals(space),
      transaction: transaction,
      noReturn: true,
    );
  }

  /// The role [user] holds in [space], or null if not a member.
  Future<OfflineSyncSpaceRole?> roleOf({
    required UuidValue user,
    required UuidValue space,
    Transaction? transaction,
  }) {
    return OfflineSyncSpaceMembership.roleOf(
      _session,
      userUuid: user,
      spaceUuid: space,
      transaction: transaction,
    );
  }

  /// The members of [space] and their roles.
  Future<Map<UuidValue, OfflineSyncSpaceRole>> members(
    UuidValue space, {
    Transaction? transaction,
  }) async {
    final memberships = await OfflineSyncSpaceMember.db.find(
      _session,
      where: (t) => t.space.uuidSpaceId.equals(space),
      transaction: transaction,
    );

    return {
      for (final membership in memberships) membership.userUuid: membership.role,
    };
  }

  Future<void> _applyGrants(
    int spaceId,
    Map<UuidValue, OfflineSyncSpaceRole> grants,
    Transaction transaction,
  ) async {
    if (grants.isEmpty) return;

    await OfflineSyncSpaceMember.db.upsert(
      _session,
      [
        for (final grant in grants.entries)
          OfflineSyncSpaceMember(
            spaceId: spaceId,
            userUuid: grant.key,
            role: grant.value,
          ),
      ],
      conflictColumns: (t) => [t.userUuid, t.spaceId],
      updateColumns: (t) => [t.role],
      transaction: transaction,
      noReturn: true,
    );
  }
}

/// Thrown when a space-management operation targets a missing CRDT space row.
final class OfflineSyncSpaceNotFoundException implements Exception {
  /// Creates a [OfflineSyncSpaceNotFoundException].
  const OfflineSyncSpaceNotFoundException(this.space);

  /// The space UUID that could not be found.
  final UuidValue space;

  @override
  String toString() =>
      'OfflineSyncSpaceNotFoundException: no CRDT space row exists for "$space".';
}
