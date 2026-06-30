import '../protocol/protocol.dart';

/// CRDT write capability for a scope role.
///
/// The implicit personal scope resolves to [CrdtScopeRole.readWrite]. A missing
/// role means no shared membership row was found and does not grant writes.
extension CrdtScopeRoleWriteAccess on CrdtScopeRole? {
  /// Whether this role may write CRDT rows in the scope.
  bool get canWrite => this == CrdtScopeRole.readWrite;
}
