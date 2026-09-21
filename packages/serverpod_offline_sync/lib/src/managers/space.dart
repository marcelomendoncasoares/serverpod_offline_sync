import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';

/// A manager for [OfflineSyncSpace] instances.
class OfflineSyncSpaceManager {
  /// Creates a [OfflineSyncSpaceManager] bound to a database session.
  OfflineSyncSpaceManager(this._session);

  final DatabaseSession _session;

  final Map<UuidValue, OfflineSyncSpace> _instances = {};

  /// Canonical [CrdtNode] shared across all spaces on this database.
  CrdtNode? _cachedCurrentNode;

  /// Returns the cached [OfflineSyncSpace] for the given space ID.
  OfflineSyncSpace getCached(UuidValue uuidSpaceId) =>
      _instances[uuidSpaceId] ??
      (throw StateError(
        'Space $uuidSpaceId not found in cache. '
        'Ensure OfflineSyncSpaceManager.getOrCreate() is called before getCached().',
      ));

  /// Clears the in-memory cache so state is reloaded from the store.
  void clearCache() {
    _instances.clear();
    _cachedCurrentNode = null;
  }

  /// Returns the [OfflineSyncSpace] for the given space ID.
  ///
  /// Will create a new [OfflineSyncSpace] if no space is found.
  ///
  /// Preparation commits in its own transaction. Call this before opening a
  /// transaction that writes domain rows, so cached IDs cannot be rolled back.
  Future<OfflineSyncSpace> getOrCreate(UuidValue uuidSpaceId) async {
    final cached = _instances[uuidSpaceId];
    if (cached != null) return cached;

    final space = await _session.db.transaction(
      (tx) => _getOrCreate(uuidSpaceId, tx),
    );
    _cachedCurrentNode = space.currentNode;
    return _instances[uuidSpaceId] = space;
  }

  Future<OfflineSyncSpace> _getOrCreate(
    UuidValue uuidSpaceId,
    Transaction transaction,
  ) async {
    // Resolve the replica before inserting a space. A concurrent first-time
    // preparation must not hold a space row while waiting for the replica lock.
    var currentNode = await _getOrCreateCurrentNode(transaction);
    var space = await OfflineSyncSpace.db.findFirstRow(
      _session,
      where: (t) => t.uuidSpaceId.equals(uuidSpaceId),
      include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    if (space == null) {
      // Another transaction may have passed the same lookup. Let the unique
      // index arbitrate, then read its committed row (or our own new row).
      await OfflineSyncSpace.db.insert(
        _session,
        [OfflineSyncSpace(uuidSpaceId: uuidSpaceId)],
        transaction: transaction,
        ignoreConflicts: true,
      );
      space = await OfflineSyncSpace.db.findFirstRow(
        _session,
        where: (t) => t.uuidSpaceId.equals(uuidSpaceId),
        include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
        transaction: transaction,
      );
      if (space == null) throw StateError('Could not create space $uuidSpaceId.');
    }

    currentNode = await _preserveLatestCurrentNodeHlc(
      currentNode,
      space.currentNode,
      transaction,
    );
    if (space.currentNodeId != currentNode.id) {
      await OfflineSyncSpace.db.attachRow.currentNode(
        _session,
        space,
        currentNode,
        transaction: transaction,
      );
    }

    await _ensureSpaceNode(space.id!, currentNode.id!, transaction);

    return space.copyWith(
      currentNodeId: currentNode.id,
      currentNode: currentNode,
    );
  }

  Future<CrdtNode> _getOrCreateCurrentNode(Transaction transaction) async {
    final cachedId = _cachedCurrentNode?.id;
    if (cachedId != null) {
      final node = await CrdtNode.db.findById(
        _session,
        cachedId,
        transaction: transaction,
      );
      if (node?.uuidNodeId == _cachedCurrentNode?.uuidNodeId && node != null) {
        return node;
      }
      _cachedCurrentNode = null;
    }

    final existingNode = await _findCurrentNode(transaction);
    if (existingNode != null) return existingNode;

    if (_session.db.dialect == DatabaseDialect.postgres) {
      // Serialize only first-replica initialization across sessions/processes.
      // The two-key advisory lock is namespaced to offline sync ("osyn", 1).
      // SQLite already serializes write transactions.
      await _session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock(1869838702, 1)',
        transaction: transaction,
      );
      final concurrentNode = await _findCurrentNode(transaction);
      if (concurrentNode != null) return concurrentNode;
    }

    return CrdtNode.db.insertRow(
      _session,
      CrdtNode(),
      transaction: transaction,
    );
  }

  Future<CrdtNode?> _findCurrentNode(Transaction transaction) async {
    final existingSpace = await OfflineSyncSpace.db.findFirstRow(
      _session,
      where: (t) => t.currentNodeId.notEquals(null),
      orderBy: (t) => t.id,
      include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    return existingSpace?.currentNode;
  }

  Future<CrdtNode> _preserveLatestCurrentNodeHlc(
    CrdtNode currentNode,
    CrdtNode? spaceCurrentNode,
    Transaction transaction,
  ) async {
    final spaceLastHlc = spaceCurrentNode?.lastHlc;
    if (spaceLastHlc == null || spaceCurrentNode?.id == currentNode.id) {
      return currentNode;
    }

    final currentLastHlc = currentNode.lastHlc;
    if (currentLastHlc != null && currentLastHlc >= spaceLastHlc) {
      return currentNode;
    }

    final updatedNode = currentNode.copyWith(
      lastHlc: spaceLastHlc.copyWith(nodeId: currentNode.uuidNodeId),
    );
    await CrdtNode.db.updateRow(
      _session,
      updatedNode,
      columns: (t) => [t.lastHlc],
      transaction: transaction,
    );
    return updatedNode;
  }

  Future<void> _ensureSpaceNode(
    int spaceId,
    int nodeId,
    Transaction transaction,
  ) async {
    await OfflineSyncSpaceNode.db.insert(
      _session,
      [OfflineSyncSpaceNode(spaceId: spaceId, nodeId: nodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    );
  }
}
