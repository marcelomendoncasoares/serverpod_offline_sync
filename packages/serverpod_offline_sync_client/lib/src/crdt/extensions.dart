import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

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
