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

/// Session handshake sent once by each peer before any space work.
///
/// [localNodeId] is this peer's persistent CRDT replica identity, shared
/// across all spaces. It is announced once on connect rather than per space.
/// [syncTablesHash] is the deterministic schema hash both sides must agree on
/// before merging data.
abstract class OfflineSyncConnect extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncConnect._({
    required this.localNodeId,
    required this.syncTablesHash,
  });

  factory OfflineSyncConnect({
    required _iss.UuidValue localNodeId,
    required String syncTablesHash,
  }) = _OfflineSyncConnectImpl;

  factory OfflineSyncConnect.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncConnect(
      localNodeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['localNodeId'],
      ),
      syncTablesHash: jsonSerialization['syncTablesHash'] as String,
    );
  }

  /// This peer's node identifier.
  _iss.UuidValue localNodeId;

  /// The hash of the synchronized schema configured on this peer.
  String syncTablesHash;

  /// Returns a shallow copy of this [OfflineSyncConnect]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncConnect copyWith({
    _iss.UuidValue? localNodeId,
    String? syncTablesHash,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncConnect',
      'localNodeId': localNodeId.toJson(),
      'syncTablesHash': syncTablesHash,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncConnect',
      'localNodeId': localNodeId.toJson(),
      'syncTablesHash': syncTablesHash,
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncConnectImpl extends OfflineSyncConnect {
  _OfflineSyncConnectImpl({
    required _iss.UuidValue localNodeId,
    required String syncTablesHash,
  }) : super._(
         localNodeId: localNodeId,
         syncTablesHash: syncTablesHash,
       );

  /// Returns a shallow copy of this [OfflineSyncConnect]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncConnect copyWith({
    _iss.UuidValue? localNodeId,
    String? syncTablesHash,
  }) {
    return OfflineSyncConnect(
      localNodeId: localNodeId ?? this.localNodeId,
      syncTablesHash: syncTablesHash ?? this.syncTablesHash,
    );
  }
}
