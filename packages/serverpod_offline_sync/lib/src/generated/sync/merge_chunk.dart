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

/// Changes belonging to one numbered batch. Chunks do not imply commit.
abstract class OfflineSyncMergeChunk extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncMergeChunk._({
    required this.batchId,
    required this.changes,
  });

  factory OfflineSyncMergeChunk({
    required int batchId,
    required List<_icw2tu00.CrdtMergeChange> changes,
  }) = _OfflineSyncMergeChunkImpl;

  factory OfflineSyncMergeChunk.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncMergeChunk(
      batchId: jsonSerialization['batchId'] as int,
      changes: _icw2tu00.Protocol()
          .deserialize<List<_icw2tu00.CrdtMergeChange>>(
            jsonSerialization['changes'],
          ),
    );
  }

  int batchId;

  List<_icw2tu00.CrdtMergeChange> changes;

  /// Returns a shallow copy of this [OfflineSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncMergeChunk copyWith({
    int? batchId,
    List<_icw2tu00.CrdtMergeChange>? changes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncMergeChunk',
      'batchId': batchId,
      'changes': changes.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncMergeChunk',
      'batchId': batchId,
      'changes': changes.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncMergeChunkImpl extends OfflineSyncMergeChunk {
  _OfflineSyncMergeChunkImpl({
    required int batchId,
    required List<_icw2tu00.CrdtMergeChange> changes,
  }) : super._(
         batchId: batchId,
         changes: changes,
       );

  /// Returns a shallow copy of this [OfflineSyncMergeChunk]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncMergeChunk copyWith({
    int? batchId,
    List<_icw2tu00.CrdtMergeChange>? changes,
  }) {
    return OfflineSyncMergeChunk(
      batchId: batchId ?? this.batchId,
      changes: changes ?? this.changes.map((e0) => e0.copyWith()).toList(),
    );
  }
}
