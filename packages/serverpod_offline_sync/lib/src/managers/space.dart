import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import '../hlc/hlc.dart';

/// A manager for [OfflineSyncSpace] rows and the local user clocks acting in them.
class OfflineSyncSpaceManager {
  /// Creates a [OfflineSyncSpaceManager] bound to a database session.
  OfflineSyncSpaceManager(this._session);

  final DatabaseSession _session;

  final Map<UuidValue, OfflineSyncSpace> _instances = {};

  final Map<UuidValue, CrdtNode> _userNodes = {};

  final Set<(int, int)> _participations = {};

  final Set<UuidValue> _knownNodes = {};

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
    _knownNodes.clear();
  }

  /// Returns the [OfflineSyncSpace] for the given space ID.
  ///
  /// Will create a new [OfflineSyncSpace] if no space is found.
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
  /// A new node starts after the legacy database-wide clock.
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

  /// Records that the local [node] authors in [space], before any write
  /// transaction opens so a rollback cannot undo it.
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

  /// Commits a node row for each source in [uuidNodeIds] before a merge.
  ///
  /// Creating them inside merges into different spaces could deadlock, so they
  /// are inserted up front in one statement, in UUID order.
  Future<void> ensureNodes(Set<UuidValue> uuidNodeIds) async {
    final unknown = uuidNodeIds.difference(_knownNodes);
    if (unknown.isEmpty) return;

    final existing = await CrdtNode.db.find(
      _session,
      where: (t) => t.uuidNodeId.inSet(unknown),
    );
    final missing = unknown.difference({
      for (final node in existing) node.uuidNodeId,
    });
    if (missing.isNotEmpty) {
      await CrdtNode.db.insert(
        _session,
        [
          for (final uuidNodeId in missing.toList()..sort(_byUuid))
            CrdtNode(uuidNodeId: uuidNodeId),
        ],
        ignoreConflicts: true,
      );
    }
    _knownNodes.addAll(unknown);
  }

  static int _byUuid(UuidValue a, UuidValue b) => a.uuid.compareTo(b.uuid);

  /// The greatest clock of unowned local nodes, from before per-user clocks.
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

  /// Finds a row, or inserts it ignoring conflicts and finds it again.
  ///
  /// Runs outside any transaction, so a concurrent winner's row is visible.
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
