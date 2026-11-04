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

/// Completes a numbered batch, allowing its receiver to apply it.
abstract class OfflineSyncEndOfBatch extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncEndOfBatch._({
    required this.batchId,
    required this.checkpoints,
    required this.finalForOnce,
  });

  factory OfflineSyncEndOfBatch({
    required int batchId,
    required List<_icw2tu00.OfflineSyncSpaceCheckpoint> checkpoints,
    required bool finalForOnce,
  }) = _OfflineSyncEndOfBatchImpl;

  factory OfflineSyncEndOfBatch.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncEndOfBatch(
      batchId: jsonSerialization['batchId'] as int,
      checkpoints: _icw2tu00.Protocol()
          .deserialize<List<_icw2tu00.OfflineSyncSpaceCheckpoint>>(
            jsonSerialization['checkpoints'],
          ),
      finalForOnce: _iss.BoolJsonExtension.fromJson(
        jsonSerialization['finalForOnce'],
      ),
    );
  }

  int batchId;

  /// Complete per-space capture bounds in the sending replica's revision order.
  List<_icw2tu00.OfflineSyncSpaceCheckpoint> checkpoints;

  /// Selects the finite upload or download boundary for syncOnce.
  bool finalForOnce;

  /// Returns a shallow copy of this [OfflineSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncEndOfBatch copyWith({
    int? batchId,
    List<_icw2tu00.OfflineSyncSpaceCheckpoint>? checkpoints,
    bool? finalForOnce,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncEndOfBatch',
      'batchId': batchId,
      'checkpoints': checkpoints.toJson(valueToJson: (v) => v.toJson()),
      'finalForOnce': finalForOnce,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncEndOfBatch',
      'batchId': batchId,
      'checkpoints': checkpoints.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'finalForOnce': finalForOnce,
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncEndOfBatchImpl extends OfflineSyncEndOfBatch {
  _OfflineSyncEndOfBatchImpl({
    required int batchId,
    required List<_icw2tu00.OfflineSyncSpaceCheckpoint> checkpoints,
    required bool finalForOnce,
  }) : super._(
         batchId: batchId,
         checkpoints: checkpoints,
         finalForOnce: finalForOnce,
       );

  /// Returns a shallow copy of this [OfflineSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncEndOfBatch copyWith({
    int? batchId,
    List<_icw2tu00.OfflineSyncSpaceCheckpoint>? checkpoints,
    bool? finalForOnce,
  }) {
    return OfflineSyncEndOfBatch(
      batchId: batchId ?? this.batchId,
      checkpoints:
          checkpoints ?? this.checkpoints.map((e0) => e0.copyWith()).toList(),
      finalForOnce: finalForOnce ?? this.finalForOnce,
    );
  }
}
