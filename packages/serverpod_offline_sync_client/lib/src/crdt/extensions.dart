import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import '../protocol/protocol.dart';

/// Last serialized index that still represents a visible CRDT row.
///
/// The [CrdtDataRowVisibility] is ordered by visibility, so the index is used
/// to compare the visibility states. The last visible state in the enum is
/// [CrdtDataRowVisibility.foreignKeyRestrictRestore].
final crdtRowLastVisibleVisibilityIndex =
    CrdtDataRowVisibility.foreignKeyRestrictRestore.index;

/// Extensions for the [CrdtDataRowVisibility] enum.
extension CrdtDataRowVisibilityExtension on CrdtDataRowVisibility {
  /// Whether this visibility state hides the row from domain queries.
  ///
  bool get isHidden => index > crdtRowLastVisibleVisibilityIndex;
}

/// Extensions for the [CrdtDataField] class.
extension CrdtDataFieldExtension on CrdtDataField {
  /// The HLC represented by this field.
  Hlc get hlc => node == null
      ? (throw StateError(
          'Fetch the CRDT field with the node included to get the HLC.',
        ))
      : toHlcForNode(node!.uuidNodeId);
}

/// Extensions for the [CrdtDataRow] class.
extension CrdtDataRowExtension on CrdtDataRow {
  /// Whether this row is currently hidden from domain queries.
  bool get isHidden => visibility.isHidden;

  /// The HLC represented by this row.
  Hlc get hlc => node == null
      ? (throw StateError(
          'Fetch the CRDT row with the node included to get the HLC.',
        ))
      : toHlcForNode(node!.uuidNodeId);
}

/// Extensions for the [CrdtDataDeleted] class.
extension CrdtDataDeletedExtension on CrdtDataDeleted {
  /// Whether this visibility generation hides the row.
  bool get isDeleted => clFlag.isEven;

  /// The HLC represented by this visibility generation.
  Hlc get hlc => node == null
      ? (throw StateError(
          'Fetch the CRDT visibility generation with the node included to get the HLC.',
        ))
      : toHlcForNode(node!.uuidNodeId);
}

/// Extensions for the [CrdtDataForeignKey] class.
extension CrdtDataForeignKeyExtension on CrdtDataForeignKey {
  /// Whether an active projection override exists for this FK field.
  ///
  /// Derived from [CrdtDataForeignKey.overrideReason]: an override is active if
  /// and only if [overrideReason] is non-null. This is the authoritative test
  /// for whether the domain row's FK value differs from the attempted value.
  bool get hasOverride => overrideReason != null;
}

/// Extensions for the [CrdtDataDeletedReason] enum.
extension CrdtDataDeletedReasonExtension on CrdtDataDeletedReason {
  /// Whether this tombstone reason is synced across replicas. All reasons that
  /// start with 'user' are synced.
  bool get isSynced => name.startsWith('user');
}

/// CRDT write capability for a scope role.
///
/// The implicit personal scope resolves to [CrdtScopeRole.readWrite]. A missing
/// role means no shared membership row was found and does not grant writes.
extension CrdtScopeRoleWriteAccess on CrdtScopeRole? {
  /// Whether this role may write CRDT rows in the scope.
  bool get canWrite => this == CrdtScopeRole.readWrite;
}
