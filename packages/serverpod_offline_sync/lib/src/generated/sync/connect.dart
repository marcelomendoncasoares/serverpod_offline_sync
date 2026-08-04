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

/// Session handshake sent once by each peer before any scope work.
///
/// [localNodeId] is this peer's persistent CRDT replica identity, shared
/// across all scopes. It is announced once on connect rather than per scope.
/// [syncTablesHash] is the deterministic schema hash both sides must agree on
/// before merging data.
abstract class CrdtSyncConnect extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel, _i2.ProtocolSerialization {
  CrdtSyncConnect._({
    required this.localNodeId,
    required this.syncTablesHash,
  });

  factory CrdtSyncConnect({
    required _i2.UuidValue localNodeId,
    required String syncTablesHash,
  }) = _CrdtSyncConnectImpl;

  factory CrdtSyncConnect.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncConnect(
      localNodeId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['localNodeId'],
      ),
      syncTablesHash: jsonSerialization['syncTablesHash'] as String,
    );
  }

  /// This peer's node identifier.
  _i2.UuidValue localNodeId;

  /// The hash of the synchronized schema configured on this peer.
  String syncTablesHash;

  /// Returns a shallow copy of this [CrdtSyncConnect]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncConnect copyWith({
    _i2.UuidValue? localNodeId,
    String? syncTablesHash,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncConnect',
      'localNodeId': localNodeId.toJson(),
      'syncTablesHash': syncTablesHash,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncConnect',
      'localNodeId': localNodeId.toJson(),
      'syncTablesHash': syncTablesHash,
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncConnectImpl extends CrdtSyncConnect {
  _CrdtSyncConnectImpl({
    required _i2.UuidValue localNodeId,
    required String syncTablesHash,
  }) : super._(
         localNodeId: localNodeId,
         syncTablesHash: syncTablesHash,
       );

  /// Returns a shallow copy of this [CrdtSyncConnect]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncConnect copyWith({
    _i2.UuidValue? localNodeId,
    String? syncTablesHash,
  }) {
    return CrdtSyncConnect(
      localNodeId: localNodeId ?? this.localNodeId,
      syncTablesHash: syncTablesHash ?? this.syncTablesHash,
    );
  }
}
