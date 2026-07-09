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

/// Per-scope checkpoint sent by each peer before the first visit to a scope.
abstract class CrdtSyncSinceHlc extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel {
  CrdtSyncSinceHlc._({
    required this.uuidScopeId,
    required this.nodeCheckpoints,
  });

  factory CrdtSyncSinceHlc({
    required _i2.UuidValue uuidScopeId,
    required List<_i6.Hlc> nodeCheckpoints,
  }) = _CrdtSyncSinceHlcImpl;

  factory CrdtSyncSinceHlc.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncSinceHlc(
      uuidScopeId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidScopeId'],
      ),
      nodeCheckpoints: _i4.Protocol().deserialize<List<_i6.Hlc>>(
        jsonSerialization['nodeCheckpoints'],
      ),
    );
  }

  /// Scope this checkpoint belongs to.
  _i2.UuidValue uuidScopeId;

  /// Per-node checkpoints that describe which changes the sender already has.
  ///
  /// Each checkpoint is an [Hlc] whose `nodeId` is the source node being
  /// checkpointed. The receiver uses this list to compute a diff without
  /// relying on a single global HLC, which would miss concurrent changes from
  /// nodes unknown at the time of the previous sync.
  List<_i6.Hlc> nodeCheckpoints;

  /// Returns a shallow copy of this [CrdtSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncSinceHlc copyWith({
    _i2.UuidValue? uuidScopeId,
    List<_i6.Hlc>? nodeCheckpoints,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncSinceHlc',
      'uuidScopeId': uuidScopeId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncSinceHlcImpl extends CrdtSyncSinceHlc {
  _CrdtSyncSinceHlcImpl({
    required _i2.UuidValue uuidScopeId,
    required List<_i6.Hlc> nodeCheckpoints,
  }) : super._(
         uuidScopeId: uuidScopeId,
         nodeCheckpoints: nodeCheckpoints,
       );

  /// Returns a shallow copy of this [CrdtSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncSinceHlc copyWith({
    _i2.UuidValue? uuidScopeId,
    List<_i6.Hlc>? nodeCheckpoints,
  }) {
    return CrdtSyncSinceHlc(
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      nodeCheckpoints:
          nodeCheckpoints ??
          this.nodeCheckpoints.map((e0) => e0.copyWith()).toList(),
    );
  }
}
