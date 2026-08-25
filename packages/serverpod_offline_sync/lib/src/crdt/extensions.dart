import '../generated/protocol.dart';
import '../hlc/hlc.dart';

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
  /// Sparse projection rows should always carry a non-null [overrideReason].
  /// This remains defensive for data created by older package versions.
  bool get hasOverride => overrideReason != null;
}

/// Extensions for the [CrdtDataDeletedReason] enum.
extension CrdtDataDeletedReasonExtension on CrdtDataDeletedReason {
  /// Whether this tombstone reason is synced across replicas. All reasons that
  /// start with 'user' are synced.
  bool get isSynced => name.startsWith('user');

  /// The row visibility that corresponds to this tombstone reason.
  CrdtDataRowVisibility toVisibility({required bool isDeleted}) {
    if (!isDeleted) {
      return switch (this) {
        CrdtDataDeletedReason.userReinsert => CrdtDataRowVisibility.userReinsert,
        _ => CrdtDataRowVisibility.userInsert,
      };
    }

    return switch (this) {
      CrdtDataDeletedReason.userDelete => CrdtDataRowVisibility.userDelete,
      CrdtDataDeletedReason.userCascadeDelete =>
        CrdtDataRowVisibility.userCascadeDelete,
      _ => CrdtDataRowVisibility.userDelete,
    };
  }
}

/// CRDT write capability for a scope role.
///
/// The implicit personal scope resolves to [CrdtScopeRole.readWrite]. A missing
/// role means no shared membership row was found and does not grant writes.
extension CrdtScopeRoleWriteAccess on CrdtScopeRole? {
  /// Whether this role may write CRDT rows in the scope.
  bool get canWrite => this == CrdtScopeRole.readWrite;
}
