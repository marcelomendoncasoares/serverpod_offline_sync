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
abstract class CrdtSyncMergeChunk extends _icw2tu00.CrdtSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtSyncMergeChunk._({required this.changes});

  factory CrdtSyncMergeChunk({
    required List<_icw2tu00.CrdtMergeChange> changes,
  }) = _CrdtSyncMergeChunkImpl;

  factory CrdtSyncMergeChunk.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncMergeChunk(
      changes: _icw2tu00.Protocol()
          .deserialize<List<_icw2tu00.CrdtMergeChange>>(
            jsonSerialization['changes'],
          ),
    );
  }

  /// The merge changes to apply.
  List<_icw2tu00.CrdtMergeChange> changes;

  /// Returns a shallow copy of this [CrdtSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtSyncMergeChunk copyWith({List<_icw2tu00.CrdtMergeChange>? changes});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncMergeChunk',
      'changes': changes.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncMergeChunk',
      'changes': changes.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtSyncMergeChunkImpl extends CrdtSyncMergeChunk {
  _CrdtSyncMergeChunkImpl({required List<_icw2tu00.CrdtMergeChange> changes})
    : super._(changes: changes);

  /// Returns a shallow copy of this [CrdtSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtSyncMergeChunk copyWith({List<_icw2tu00.CrdtMergeChange>? changes}) {
    return CrdtSyncMergeChunk(
      changes: changes ?? this.changes.map((e0) => e0.copyWith()).toList(),
    );
  }
}
