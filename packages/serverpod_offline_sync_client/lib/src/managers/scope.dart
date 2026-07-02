import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [CrdtScope] instances.
class CrdtScopeManager {
  /// Creates a [CrdtScopeManager] bound to a database session.
  CrdtScopeManager(this._session);

  final DatabaseSession _session;

  final Map<UuidValue, CrdtScope> _instances = {};

  /// Returns the cached [CrdtScope] for the given scope ID.
  CrdtScope getCached(UuidValue uuidScopeId) =>
      _instances[uuidScopeId] ??
      (throw StateError(
        'Scope $uuidScopeId not found in cache. '
        'Ensure CrdtScopeManager.getOrCreate() is called before getCached().',
      ));

  /// Clears the in-memory cache so state is reloaded from the store.
  void clearCache() {
    _instances.clear();
  }

  /// Returns the [CrdtScope] for the given scope ID.
  ///
  /// Will create a new [CrdtScope] if no scope is found.
  Future<CrdtScope> getOrCreate(UuidValue uuidScopeId) async {
    return _instances[uuidScopeId] ??= await _session.db.transaction(
      (transaction) => _getOrCreate(uuidScopeId, transaction),
    );
  }

  Future<CrdtScope> _getOrCreate(
    UuidValue uuidScopeId,
    Transaction transaction,
  ) async {
    var scope = await CrdtScope.db.findFirstRow(
      _session,
      where: (t) => t.uuidScopeId.equals(uuidScopeId),
      include: CrdtScope.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    scope ??= await CrdtScope.db.insertRow(
      _session,
      CrdtScope(uuidScopeId: uuidScopeId),
      transaction: transaction,
    );

    var currentNode = await _getOrCreateCurrentNode(transaction);
    currentNode = await _preserveLatestCurrentNodeHlc(
      currentNode,
      scope.currentNode,
      transaction,
    );
    if (scope.currentNodeId != currentNode.id) {
      await CrdtScope.db.attachRow.currentNode(
        _session,
        scope,
        currentNode,
        transaction: transaction,
      );
    }

    await _ensureScopeNode(scope.id!, currentNode.id!, transaction);

    return scope.copyWith(
      currentNodeId: currentNode.id,
      currentNode: currentNode,
    );
  }

  Future<CrdtNode> _getOrCreateCurrentNode(Transaction transaction) async {
    final result = await _session.db.unsafeQuery(
      'SELECT "${CrdtScope.t.currentNodeId.columnName}" '
      'FROM "${CrdtScope.t.tableName}" '
      'WHERE "${CrdtScope.t.currentNodeId.columnName}" IS NOT NULL '
      'ORDER BY "${CrdtScope.t.id.columnName}" '
      'LIMIT 1',
      transaction: transaction,
    );

    if (result.isNotEmpty) {
      final node = await CrdtNode.db.findById(
        _session,
        result.first[0] as int,
        transaction: transaction,
      );
      if (node != null) return node;
    }

    return CrdtNode.db.insertRow(
      _session,
      CrdtNode(),
      transaction: transaction,
    );
  }

  Future<CrdtNode> _preserveLatestCurrentNodeHlc(
    CrdtNode currentNode,
    CrdtNode? scopeCurrentNode,
    Transaction transaction,
  ) async {
    final scopeLastHlc = scopeCurrentNode?.lastHlc;
    if (scopeLastHlc == null || scopeCurrentNode?.id == currentNode.id) {
      return currentNode;
    }

    final currentLastHlc = currentNode.lastHlc;
    if (currentLastHlc != null && currentLastHlc >= scopeLastHlc) {
      return currentNode;
    }

    final updatedNode = currentNode.copyWith(
      lastHlc: scopeLastHlc.copyWith(nodeId: currentNode.uuidNodeId),
    );
    await CrdtNode.db.updateRow(
      _session,
      updatedNode,
      columns: (t) => [t.lastHlc],
      transaction: transaction,
    );
    return updatedNode;
  }

  Future<void> _ensureScopeNode(
    int scopeId,
    int nodeId,
    Transaction transaction,
  ) async {
    await CrdtScopeNode.db.insert(
      _session,
      [CrdtScopeNode(scopeId: scopeId, nodeId: nodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    );
  }
}
