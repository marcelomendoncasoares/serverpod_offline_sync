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

  /// Returns all locally known scope UUIDs.
  Future<List<UuidValue>> listScopeIds() async {
    final scopes = await CrdtScope.db.find(_session);
    return [for (final scope in scopes) scope.uuidScopeId];
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

    if (scope.currentNode != null) {
      return scope;
    }

    final currentNode = await CrdtNode.db.insertRow(
      _session,
      CrdtNode(scopeId: scope.id!),
      transaction: transaction,
    );

    await CrdtScope.db.attachRow.currentNode(
      _session,
      scope,
      currentNode,
      transaction: transaction,
    );

    return scope.copyWith(
      currentNodeId: currentNode.id,
      currentNode: currentNode,
    );
  }
}
