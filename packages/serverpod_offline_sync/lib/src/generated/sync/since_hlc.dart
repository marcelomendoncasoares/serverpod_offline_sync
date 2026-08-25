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
abstract class CrdtSyncSinceHlc extends _icw2tu00.CrdtSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtSyncSinceHlc._({
    required this.uuidScopeId,
    required this.nodeCheckpoints,
  });

  factory CrdtSyncSinceHlc({
    required _iss.UuidValue uuidScopeId,
    required List<_icw2tu00.Hlc> nodeCheckpoints,
  }) = _CrdtSyncSinceHlcImpl;

  factory CrdtSyncSinceHlc.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncSinceHlc(
      uuidScopeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidScopeId'],
      ),
      nodeCheckpoints: _icw2tu00.Protocol().deserialize<List<_icw2tu00.Hlc>>(
        jsonSerialization['nodeCheckpoints'],
      ),
    );
  }

  /// Scope this checkpoint belongs to.
  _iss.UuidValue uuidScopeId;

  /// Per-node checkpoints that describe which changes the sender already has.
  ///
  /// Each checkpoint is an [Hlc] whose `nodeId` is the source node being
  /// checkpointed. The receiver uses this list to compute a diff without
  /// relying on a single global HLC, which would miss concurrent changes from
  /// nodes unknown at the time of the previous sync.
  List<_icw2tu00.Hlc> nodeCheckpoints;

  /// Returns a shallow copy of this [CrdtSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtSyncSinceHlc copyWith({
    _iss.UuidValue? uuidScopeId,
    List<_icw2tu00.Hlc>? nodeCheckpoints,
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
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncSinceHlc',
      'uuidScopeId': uuidScopeId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(
        valueToJson: (v) =>
            // ignore: unnecessary_type_check
            v is _iss.ProtocolSerialization
            ? (v as _iss.ProtocolSerialization).toJsonForProtocol()
            :
              // ignore: dead_code
              v.toJson(),
      ),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtSyncSinceHlcImpl extends CrdtSyncSinceHlc {
  _CrdtSyncSinceHlcImpl({
    required _iss.UuidValue uuidScopeId,
    required List<_icw2tu00.Hlc> nodeCheckpoints,
  }) : super._(
         uuidScopeId: uuidScopeId,
         nodeCheckpoints: nodeCheckpoints,
       );

  /// Returns a shallow copy of this [CrdtSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtSyncSinceHlc copyWith({
    _iss.UuidValue? uuidScopeId,
    List<_icw2tu00.Hlc>? nodeCheckpoints,
  }) {
    return CrdtSyncSinceHlc(
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      nodeCheckpoints:
          nodeCheckpoints ??
          this.nodeCheckpoints.map((e0) => e0.copyWith()).toList(),
    );
  }
}
