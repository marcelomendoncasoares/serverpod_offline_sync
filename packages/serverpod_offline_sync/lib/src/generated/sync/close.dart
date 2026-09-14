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

/// Marks a graceful end of a one-shot sync session.
///
/// Both peers send [OfflineSyncClose] after merging the final batch in a
/// one-shot session so each side can shut down without closing the transport
/// early.
abstract class OfflineSyncClose extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncClose._();

  factory OfflineSyncClose() = _OfflineSyncCloseImpl;

  factory OfflineSyncClose.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncClose();
  }

  /// Returns a shallow copy of this [OfflineSyncClose]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncClose copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncClose'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'serverpod_offline_sync.OfflineSyncClose'};
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncCloseImpl extends OfflineSyncClose {
  _OfflineSyncCloseImpl() : super._();

  /// Returns a shallow copy of this [OfflineSyncClose]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncClose copyWith() {
    return OfflineSyncClose();
  }
}
