/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'stream_event.dart';

/// A chunk of merge changes carried inside a framed sync batch.
abstract class CrdtSyncMergeChunk extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel {
  CrdtSyncMergeChunk._({required this.changes});

  factory CrdtSyncMergeChunk({required List<_i3.CrdtMergeChange> changes}) =
      _CrdtSyncMergeChunkImpl;

  factory CrdtSyncMergeChunk.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncMergeChunk(
      changes: _i4.Protocol().deserialize<List<_i3.CrdtMergeChange>>(
        jsonSerialization['changes'],
      ),
    );
  }

  /// The merge changes to apply.
  List<_i3.CrdtMergeChange> changes;

  /// Returns a shallow copy of this [CrdtSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncMergeChunk copyWith({List<_i3.CrdtMergeChange>? changes});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncMergeChunk',
      'changes': changes.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncMergeChunkImpl extends CrdtSyncMergeChunk {
  _CrdtSyncMergeChunkImpl({required List<_i3.CrdtMergeChange> changes})
    : super._(changes: changes);

  /// Returns a shallow copy of this [CrdtSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncMergeChunk copyWith({List<_i3.CrdtMergeChange>? changes}) {
    return CrdtSyncMergeChunk(
      changes: changes ?? this.changes.map((e0) => e0.copyWith()).toList(),
    );
  }
}
