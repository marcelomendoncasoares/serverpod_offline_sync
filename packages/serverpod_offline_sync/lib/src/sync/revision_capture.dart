part of 'engine.dart';

/// A complete range of this replica's committed state, detached from its snapshot.
typedef OfflineSyncCapture = ({
  List<CrdtMergeChange> changes,
  List<OfflineSyncSpaceCheckpoint> checkpoints,
});

/// Durable replica-local checkpoint capture and receiver receipts.
extension OfflineSyncRevisionCapture on OfflineSyncEngine {
  /// Resolves one authenticated connection identity, shared by all its spaces.
  Future<OfflineSyncPeer> resolvePeer(
    DatabaseSession session,
    UuidValue userId,
    UuidValue peerUuid,
  ) async {
    Future<OfflineSyncPeer?> find() => OfflineSyncPeer.db.findFirstRow(
      session,
      where: (t) => t.userUuid.equals(userId) & t.peerUuid.equals(peerUuid),
    );

    final existing = await find();
    if (existing != null) return existing;

    final inserted = await OfflineSyncPeer.db.insert(
      session,
      [OfflineSyncPeer(userUuid: userId, peerUuid: peerUuid)],
      ignoreConflicts: true,
    );
    return inserted.firstOrNull ??
        (await find() ?? (throw StateError('The authenticated peer is missing.')));
  }

  /// Reports committed incoming revisions for the authenticated user and space.
  Future<OfflineSyncSinceRevision> createSyncSinceRevision(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue spaceId,
  }) async {
    final space = await OfflineSyncSpaceManager(session).getOrCreate(spaceId);
    final progress = await OfflineSyncPeerCheckpoint.db.find(
      session,
      where: (t) => t.spaceId.equals(space.id) & t.peer.userUuid.equals(userId),
      include: OfflineSyncPeerCheckpoint.include(peer: OfflineSyncPeer.include()),
    );
    return OfflineSyncSinceRevision(
      uuidSpaceId: spaceId,
      nodeCheckpoints: [
        for (final cursor in progress)
          OfflineSyncNodeCheckpoint(
            uuidNodeId: cursor.peer!.peerUuid,
            revision: cursor.revision,
          ),
      ],
    );
  }

  /// The bound and every selected metadata/value read share one snapshot.
  Future<OfflineSyncCapture> captureChanges(
    DatabaseSession session, {
    required Map<UuidValue, int> checkpointsBySpaceUuid,
    int? peerId,
  }) async {
    if (checkpointsBySpaceUuid.isEmpty) {
      return (
        changes: const <CrdtMergeChange>[],
        checkpoints: const <OfflineSyncSpaceCheckpoint>[],
      );
    }

    // Wrapped databases may initialize the registry in a write transaction.
    // Do that before opening the consistent capture snapshot.
    if (session.db case final OfflineSyncDatabase database) {
      await database.ensureInitialized();
    }

    try {
      return await session.db.transaction(
        (transaction) async {
          final spaces = await OfflineSyncSpace.db.find(
            session,
            where: (t) => t.uuidSpaceId.inSet(checkpointsBySpaceUuid.keys.toSet()),
            transaction: transaction,
          );
          for (final space in spaces) {
            if (checkpointsBySpaceUuid[space.uuidSpaceId]! > space.syncRevision) {
              throw StateError('The peer checkpoint exceeds this replica epoch.');
            }
          }

          final spaceUuidById = {
            for (final space in spaces) space.id!: space.uuidSpaceId,
          };
          final revisions = {
            for (final space in spaces)
              space.id!: checkpointsBySpaceUuid[space.uuidSpaceId]!,
          };
          final owners = DomainRowOwnerCache();
          final changes = <CrdtMergeChange>[
            ...await _streamInserts(
              session,
              spaceUuidById,
              owners,
              transaction,
              filter: (t) => _afterSpaceRevisionFilter(
                t.spaceId,
                t.syncRevision,
                t.sourcePeerId,
                revisions,
                peerId,
              ),
            ).toList(),
            ...await _streamUpdates(
              session,
              spaceUuidById,
              owners,
              transaction,
              filter: (t) => _afterSpaceRevisionFilter(
                t.spaceId,
                t.syncRevision,
                t.sourcePeerId,
                revisions,
                peerId,
              ),
            ).toList(),
            ...await _streamDeletes(
              session,
              spaceUuidById,
              owners,
              transaction,
              filter: (t) => _afterSpaceRevisionFilter(
                t.spaceId,
                t.syncRevision,
                t.sourcePeerId,
                revisions,
                peerId,
              ),
            ).toList(),
          ];

          return (
            changes: changes,
            checkpoints: [
              for (final space in spaces)
                OfflineSyncSpaceCheckpoint(
                  uuidSpaceId: space.uuidSpaceId,
                  revision: space.syncRevision,
                ),
            ],
          );
        },
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );
    } on PendingOutboundIntegrityViolation catch (violation) {
      await _recordAndThrowIntegrityViolation(session, violation);
    }
  }
}

Expression _afterSpaceRevisionFilter(
  ColumnInt spaceId,
  ColumnInt revision,
  ColumnInt sourcePeerId,
  Map<int, int> checkpoints,
  int? knownByPeerId,
) {
  Expression afterRevision = Constant.bool(false);
  for (final entry in checkpoints.entries) {
    afterRevision =
        afterRevision | (spaceId.equals(entry.key) & (revision > entry.value));
  }
  return knownByPeerId == null
      ? afterRevision
      : afterRevision &
            (sourcePeerId.equals(null) | sourcePeerId.notEquals(knownByPeerId));
}
