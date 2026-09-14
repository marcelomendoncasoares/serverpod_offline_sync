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
  Future<OfflineSyncSpace> getOrCreate(UuidValue uuidSpaceId) async {
    return _instances[uuidSpaceId] ??= await _session.db.transaction(
      (transaction) => _getOrCreate(uuidSpaceId, transaction),
    );
  }

  Future<OfflineSyncSpace> _getOrCreate(
    UuidValue uuidSpaceId,
    Transaction transaction,
  ) async {
    var space = await OfflineSyncSpace.db.findFirstRow(
      _session,
      where: (t) => t.uuidSpaceId.equals(uuidSpaceId),
      include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    space ??= await OfflineSyncSpace.db.insertRow(
      _session,
      OfflineSyncSpace(uuidSpaceId: uuidSpaceId),
      transaction: transaction,
    );

    var currentNode = await _getOrCreateCurrentNode(transaction);

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

    _cachedCurrentNode = currentNode;

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
      if (node != null) return node;
      _cachedCurrentNode = null;
    }

    final existingSpace = await OfflineSyncSpace.db.findFirstRow(
      _session,
      where: (t) => t.currentNodeId.notEquals(null),
      orderBy: (t) => t.id,
      include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    final existingNode = existingSpace?.currentNode;
    if (existingNode != null) {
      return _cachedCurrentNode = existingNode;
    }

    return _cachedCurrentNode = await CrdtNode.db.insertRow(
      _session,
      CrdtNode(),
      transaction: transaction,
    );
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
