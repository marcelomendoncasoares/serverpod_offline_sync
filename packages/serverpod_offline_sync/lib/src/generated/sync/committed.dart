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

/// Confirms that every accepted space in the batch committed durably.
abstract class OfflineSyncCommitted extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncCommitted._({required this.batchId});

  factory OfflineSyncCommitted({required int batchId}) =
      _OfflineSyncCommittedImpl;

  factory OfflineSyncCommitted.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncCommitted(batchId: jsonSerialization['batchId'] as int);
  }

  int batchId;

  /// Returns a shallow copy of this [OfflineSyncCommitted]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncCommitted copyWith({int? batchId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncCommitted',
      'batchId': batchId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncCommitted',
      'batchId': batchId,
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncCommittedImpl extends OfflineSyncCommitted {
  _OfflineSyncCommittedImpl({required int batchId}) : super._(batchId: batchId);

  /// Returns a shallow copy of this [OfflineSyncCommitted]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncCommitted copyWith({int? batchId}) {
    return OfflineSyncCommitted(batchId: batchId ?? this.batchId);
  }
}
