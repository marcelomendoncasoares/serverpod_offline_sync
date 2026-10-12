import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import '../hlc/hlc.dart';

/// A manager for [OfflineSyncSpace] rows and the local user clocks acting in them.
///
/// A space is the data scope of a write. The clock that timestamps the write is
/// owned by the acting user, so the two are resolved separately: a shared space
/// has no clock of its own, and one user's clock is shared by every space they
/// act in.
class OfflineSyncSpaceManager {
  /// Creates a [OfflineSyncSpaceManager] bound to a database session.
  OfflineSyncSpaceManager(this._session);

  final DatabaseSession _session;

  final Map<UuidValue, OfflineSyncSpace> _instances = {};

  final Map<UuidValue, CrdtNode> _userNodes = {};

  final Set<(int, int)> _participations = {};

  /// Returns the cached [OfflineSyncSpace] for the given space ID.
  OfflineSyncSpace getCached(UuidValue uuidSpaceId) =>
      _instances[uuidSpaceId] ??
      (throw StateError(
        'Space $uuidSpaceId not found in cache. '
        'Ensure OfflineSyncSpaceManager.getOrCreate() is called before getCached().',
      ));

  /// Returns the cached local clock node of [userId].
  CrdtNode getCachedUserNode(UuidValue userId) =>
      _userNodes[userId] ??
      (throw StateError(
        'Local clock of user $userId not found in cache. Ensure '
        'OfflineSyncSpaceManager.getOrCreateUserNode() is called before '
        'getCachedUserNode().',
      ));

  /// Clears the in-memory cache so state is reloaded from the store.
  void clearCache() {
    _instances.clear();
    _userNodes.clear();
    _participations.clear();
  }

  /// Returns the [OfflineSyncSpace] for the given space ID.
  ///
  /// Will create a new [OfflineSyncSpace] if no space is found. Creation commits
  /// on its own, and concurrent first uses resolve the same row.
  Future<OfflineSyncSpace> getOrCreate(UuidValue uuidSpaceId) async {
    return _instances[uuidSpaceId] ??= await _findOrInsert(
      find: () => OfflineSyncSpace.db.findFirstRow(
        _session,
        where: (t) => t.uuidSpaceId.equals(uuidSpaceId),
      ),
      insert: () async => OfflineSyncSpace(uuidSpaceId: uuidSpaceId),
      label: 'space $uuidSpaceId',
    );
  }

  /// Returns the local node whose clock timestamps the writes of [userId].
  ///
  /// The node is created on first use with a new identity, so every database
  /// gives the same user a distinct node. Creation commits on its own, and the
  /// unique owner index makes concurrent first uses resolve one node. Every
  /// instance sharing this database then resolves that same node.
  ///
  /// A new clock starts after the legacy database-wide clock that authored
  /// local writes before clocks were owned per user, so a user's first write
  /// still follows the facts that clock produced for them.
  Future<CrdtNode> getOrCreateUserNode(UuidValue userId) async {
    return _userNodes[userId] ??= await _findOrInsert(
      find: () => CrdtNode.db.findFirstRow(
        _session,
        where: (t) => t.localUserUuid.equals(userId),
      ),
      insert: () async {
        final uuidNodeId = const Uuid().v7obj();
        final legacy = await _legacyClock();
        return CrdtNode(
          uuidNodeId: uuidNodeId,
          localUserUuid: userId,
          lastHlc: legacy?.copyWith(nodeId: uuidNodeId) ?? Hlc.zero(uuidNodeId),
        );
      },
      label: 'local clock of user $userId',
    );
  }

  /// Records that the local [node] may author facts in [space].
  ///
  /// The participation row is how a sync handshake finds the local nodes of a
  /// space and reports them as complete, so peers do not echo their facts
  /// back. It is written before any write transaction opens, so a rollback
  /// cannot remove it after this manager cached it.
  Future<void> ensureParticipation(OfflineSyncSpace space, CrdtNode node) async {
    final key = (space.id!, node.id!);
    if (_participations.contains(key)) return;
    await _findOrInsert(
      find: () => OfflineSyncSpaceNode.db.findFirstRow(
        _session,
        where: (t) => t.spaceId.equals(space.id) & t.nodeId.equals(node.id),
      ),
      insert: () async => OfflineSyncSpaceNode(spaceId: space.id!, nodeId: node.id!),
      label: 'participation of node ${node.uuidNodeId} in space ${space.uuidSpaceId}',
    );
    _participations.add(key);
  }

  /// The greatest clock of local nodes no user owns.
  ///
  /// Only local clocks persist a [CrdtNode.lastHlc], so an unowned node with
  /// one is the database-wide node that clocked every user before ownership
  /// moved to users. It is never advanced again, so reading it once per new
  /// user is enough.
  Future<Hlc?> _legacyClock() async {
    final legacyNodes = await CrdtNode.db.find(
      _session,
      where: (t) =>
          t.localUserUuid.equals(null) & Expression('${t.lastHlc} IS NOT NULL'),
    );
    return legacyNodes
        .map((node) => node.lastHlc!)
        .fold<Hlc?>(
          null,
          (latest, hlc) => hlc.maxBetween(latest),
        );
  }

  /// Finds a row, or inserts one and finds it again.
  ///
  /// The insert ignores conflicts, so a concurrent first use waits for the
  /// winning insert and then reads its row instead of failing. Both statements
  /// run outside any transaction, so the second read sees that commit.
  Future<T> _findOrInsert<T extends TableRow>({
    required Future<T?> Function() find,
    required Future<T> Function() insert,
    required String label,
  }) async {
    final existing = await find();
    if (existing != null) return existing;

    await _session.db.insert<T>(
      [await insert()],
      ignoreConflicts: true,
      noReturn: true,
    );
    return await find() ?? (throw StateError('Could not create $label.'));
  }
}
