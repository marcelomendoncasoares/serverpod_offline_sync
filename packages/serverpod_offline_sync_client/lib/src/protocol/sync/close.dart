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
/// Both peers send [CrdtSyncClose] after merging the final batch in a
/// one-shot session so each side can shut down without closing the transport
/// early.
abstract class CrdtSyncClose extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel {
  CrdtSyncClose._();

  factory CrdtSyncClose() = _CrdtSyncCloseImpl;

  factory CrdtSyncClose.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncClose();
  }

  /// Returns a shallow copy of this [CrdtSyncClose]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncClose copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'serverpod_offline_sync.CrdtSyncClose'};
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncCloseImpl extends CrdtSyncClose {
  _CrdtSyncCloseImpl() : super._();

  /// Returns a shallow copy of this [CrdtSyncClose]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncClose copyWith() {
    return CrdtSyncClose();
  }
}
