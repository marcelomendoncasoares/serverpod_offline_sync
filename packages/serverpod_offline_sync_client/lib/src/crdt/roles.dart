import '../protocol/protocol.dart';

/// CRDT write capability for a scope role.
///
/// A null role represents a user's implicit personal scope or a legacy shared
/// membership without an explicit role. Those remain writable for backwards
/// compatibility.
extension CrdtScopeRoleWriteAccess on CrdtScopeRole? {
  /// Whether this role may write CRDT rows in the scope.
  bool get canWrite => this != CrdtScopeRole.readOnly;
}
