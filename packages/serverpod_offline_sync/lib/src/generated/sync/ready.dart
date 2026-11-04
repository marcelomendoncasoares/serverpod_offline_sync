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

/// Completes initial grant and resume-vector announcements.
abstract class OfflineSyncReady extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncReady._();

  factory OfflineSyncReady() = _OfflineSyncReadyImpl;

  factory OfflineSyncReady.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncReady();
  }

  /// Returns a shallow copy of this [OfflineSyncReady]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncReady copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncReady'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncReady'};
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncReadyImpl extends OfflineSyncReady {
  _OfflineSyncReadyImpl() : super._();

  /// Returns a shallow copy of this [OfflineSyncReady]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncReady copyWith() {
    return OfflineSyncReady();
  }
}
