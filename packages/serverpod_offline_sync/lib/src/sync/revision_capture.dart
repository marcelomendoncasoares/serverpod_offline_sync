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
          final changes = await _collectRevisionChanges(
            session,
            spaceUuidById,
            revisions,
            peerId,
            transaction,
          );

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

  /// Reads row/tombstone metadata and field/attempted-value metadata together,
  /// then batches insert and update payloads within the same capture snapshot.
  Future<List<CrdtMergeChange>> _collectRevisionChanges(
    DatabaseSession session,
    Map<int, UuidValue> spaceUuidById,
    Map<int, int> revisions,
    int? peerId,
    Transaction transaction,
  ) async {
    final rows = await CrdtDataRow.db.find(
      session,
      transaction: transaction,
      where: (t) => _pendingRevisionRows(t.id, revisions, peerId),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
        deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
        fields: CrdtDataField.includeList(
          where: (t) =>
              _afterSpaceRevisionFilter(
                t.spaceId,
                t.syncRevision,
                t.sourcePeerId,
                revisions,
                peerId,
              ) |
              t.attemptedValue.id.notEquals(null),
          include: CrdtDataField.include(
            column: CrdtSchemaColumn.include(),
            node: CrdtNode.include(),
            attemptedValue: CrdtDataAttemptedValue.include(),
          ),
        ),
      ),
    );

    bool pending(int spaceId, int revision, int? sourcePeerId) =>
        revision > revisions[spaceId]! && (peerId == null || sourcePeerId != peerId);

    final inserts = <CrdtDataRow>[];
    final updates = <CrdtDataField>[];
    final deletes = <CrdtDataDeleted>[];
    for (final row in rows) {
      if (pending(row.spaceId, row.syncRevision, row.sourcePeerId)) {
        inserts.add(row);
      }

      // Children need their owner metadata without retaining a cyclic graph.
      final owner = row.copyWith(fields: null, deleted: null);
      for (final field in row.fields ?? const <CrdtDataField>[]) {
        if (pending(field.spaceId, field.syncRevision, field.sourcePeerId) &&
            field.hlc != row.hlc) {
          updates.add(field.copyWith(row: owner));
        }
      }
      final deleted = row.deleted;
      if (deleted != null &&
          pending(deleted.spaceId, deleted.syncRevision, deleted.sourcePeerId)) {
        deletes.add(deleted.copyWith(row: owner));
      }
    }

    final owners = DomainRowOwnerCache();
    final payloads = await _loadOutboundRows(session, inserts, updates, transaction);
    return [
      ...await _streamInserts(
        session,
        spaceUuidById,
        inserts,
        payloads,
        owners,
        transaction,
      ).toList(),
      ...await _streamUpdates(
        session,
        spaceUuidById,
        updates,
        payloads,
        owners,
        transaction,
      ).toList(),
      ...await _streamDeletes(
        session,
        spaceUuidById,
        deletes,
        owners,
        transaction,
      ).toList(),
    ];
  }
}

/// Each change kind enters through its own indexed space/revision range. A
/// correlated OR over every row in a space would scan already acknowledged data.
Expression _pendingRevisionRows(
  ColumnComparable<int?> rowId,
  Map<int, int> revisions,
  int? peerId,
) {
  final row = CrdtDataRow.t;
  final field = CrdtDataField.t;
  final deleted = CrdtDataDeleted.t;
  final rowFilter = _afterSpaceRevisionFilter(
    row.spaceId,
    row.syncRevision,
    row.sourcePeerId,
    revisions,
    peerId,
  );
  final fieldFilter = _afterSpaceRevisionFilter(
    field.spaceId,
    field.syncRevision,
    field.sourcePeerId,
    revisions,
    peerId,
  );
  final deletedFilter = _afterSpaceRevisionFilter(
    deleted.spaceId,
    deleted.syncRevision,
    deleted.sourcePeerId,
    revisions,
    peerId,
  );
  return Expression('''$rowId IN (
SELECT ${row.id} FROM "crdt_data_rows" WHERE $rowFilter
UNION
SELECT ${field.rowId} FROM "crdt_data_fields" WHERE $fieldFilter
UNION
SELECT ${deleted.rowId} FROM "crdt_data_tombstone" WHERE $deletedFilter
)''');
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
