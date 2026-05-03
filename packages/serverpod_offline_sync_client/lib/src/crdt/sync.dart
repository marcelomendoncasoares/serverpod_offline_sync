import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

/// Key used to encode a single update value inside [CrdtMergeUpdate.data].
const crdtMergeUpdateValueKey = 'value';

/// Typed view over any merge change entry in a [CrdtMergeSet].
typedef CrdtMergeChange = ({
  String tableName,
  UuidValue rowId,
  UuidValue nodeId,
  Hlc hlc,
  CrdtMergeInsert? insert,
  CrdtMergeUpdate? update,
  CrdtMergeDelete? delete,
});

/// CRDT merge helpers built on top of the generated Serverpod models.
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// All merge changes in this set.
  Iterable<CrdtMergeChange> get changes sync* {
    for (final insert in inserts) {
      yield (
        tableName: insert.tableName,
        rowId: insert.rowId,
        nodeId: insert.nodeId,
        hlc: insert.hlc,
        insert: insert,
        update: null,
        delete: null,
      );
    }
    for (final update in updates) {
      yield (
        tableName: update.tableName,
        rowId: update.rowId,
        nodeId: update.nodeId,
        hlc: update.hlc,
        insert: null,
        update: update,
        delete: null,
      );
    }
    for (final delete in deletes) {
      yield (
        tableName: delete.tableName,
        rowId: delete.rowId,
        nodeId: delete.nodeId,
        hlc: delete.hlc,
        insert: null,
        update: null,
        delete: delete,
      );
    }
  }
}

/// Convenience helpers for insert changes.
extension CrdtMergeInsertExtension on CrdtMergeInsert {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// Convenience helpers for update changes.
extension CrdtMergeUpdateExtension on CrdtMergeUpdate {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);

  /// The decoded value represented by this change.
  Object? get value => data[crdtMergeUpdateValueKey];
}

/// Convenience helpers for delete changes.
extension CrdtMergeDeleteExtension on CrdtMergeDelete {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}
