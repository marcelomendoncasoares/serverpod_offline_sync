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

/// Marks the end of a framed sync batch.
abstract class CrdtSyncEndOfBatch extends _icw2tu00.CrdtSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtSyncEndOfBatch._();

  factory CrdtSyncEndOfBatch() = _CrdtSyncEndOfBatchImpl;

  factory CrdtSyncEndOfBatch.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncEndOfBatch();
  }

  /// Returns a shallow copy of this [CrdtSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtSyncEndOfBatch copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.CrdtSyncEndOfBatch'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'serverpod_offline_sync.CrdtSyncEndOfBatch'};
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtSyncEndOfBatchImpl extends CrdtSyncEndOfBatch {
  _CrdtSyncEndOfBatchImpl() : super._();

  /// Returns a shallow copy of this [CrdtSyncEndOfBatch]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtSyncEndOfBatch copyWith() {
    return CrdtSyncEndOfBatch();
  }
}
