import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

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

/// Extensions for the [CrdtDataDeletedReason] enum.
extension CrdtDataDeletedReasonExtension on CrdtDataDeletedReason {
  /// Whether this tombstone reason is synced across replicas. All reasons that
  /// start with 'user' are synced.
  bool get isSynced => name.startsWith('user');
}
