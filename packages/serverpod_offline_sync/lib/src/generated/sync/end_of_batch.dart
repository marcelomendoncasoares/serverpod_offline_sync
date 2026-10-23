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
    required this.finalForOnce,
  });

  factory OfflineSyncEndOfBatch({
    required int batchId,
    required bool finalForOnce,
  }) = _OfflineSyncEndOfBatchImpl;

  factory OfflineSyncEndOfBatch.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncEndOfBatch(
      batchId: jsonSerialization['batchId'] as int,
      finalForOnce: _iss.BoolJsonExtension.fromJson(
        jsonSerialization['finalForOnce'],
      ),
    );
  }

  int batchId;

  /// Selects the finite upload or download boundary for syncOnce.
  bool finalForOnce;

  /// Returns a shallow copy of this [OfflineSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncEndOfBatch copyWith({
    int? batchId,
    bool? finalForOnce,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncEndOfBatch',
      'batchId': batchId,
      'finalForOnce': finalForOnce,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncEndOfBatch',
      'batchId': batchId,
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
    required bool finalForOnce,
  }) : super._(
         batchId: batchId,
         finalForOnce: finalForOnce,
       );

  /// Returns a shallow copy of this [OfflineSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncEndOfBatch copyWith({
    int? batchId,
    bool? finalForOnce,
  }) {
    return OfflineSyncEndOfBatch(
      batchId: batchId ?? this.batchId,
      finalForOnce: finalForOnce ?? this.finalForOnce,
    );
  }
}
