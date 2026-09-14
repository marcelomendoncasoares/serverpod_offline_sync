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
abstract class OfflineSyncIdleTimeout extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncIdleTimeout._();

  factory OfflineSyncIdleTimeout() = _OfflineSyncIdleTimeoutImpl;

  factory OfflineSyncIdleTimeout.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncIdleTimeout();
  }

  /// Returns a shallow copy of this [OfflineSyncIdleTimeout]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncIdleTimeout copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncIdleTimeout'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncIdleTimeout'};
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncIdleTimeoutImpl extends OfflineSyncIdleTimeout {
  _OfflineSyncIdleTimeoutImpl() : super._();

  /// Returns a shallow copy of this [OfflineSyncIdleTimeout]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncIdleTimeout copyWith() {
    return OfflineSyncIdleTimeout();
  }
}
