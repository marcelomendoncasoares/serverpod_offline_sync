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

/// Marks a timeout of an idle sync session.
///
/// This is a synthetic event that will be injected in the inbound stream
/// being awaited if it does not emit any events for a given timeout. It is
/// what allows both sides to stay silent if they have nothing to send.
abstract class CrdtSyncIdleTimeout extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel, _i2.ProtocolSerialization {
  CrdtSyncIdleTimeout._();

  factory CrdtSyncIdleTimeout() = _CrdtSyncIdleTimeoutImpl;

  factory CrdtSyncIdleTimeout.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncIdleTimeout();
  }

  /// Returns a shallow copy of this [CrdtSyncIdleTimeout]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncIdleTimeout copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.CrdtSyncIdleTimeout'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'serverpod_offline_sync.CrdtSyncIdleTimeout'};
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncIdleTimeoutImpl extends CrdtSyncIdleTimeout {
  _CrdtSyncIdleTimeoutImpl() : super._();

  /// Returns a shallow copy of this [CrdtSyncIdleTimeout]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncIdleTimeout copyWith() {
    return CrdtSyncIdleTimeout();
  }
}
