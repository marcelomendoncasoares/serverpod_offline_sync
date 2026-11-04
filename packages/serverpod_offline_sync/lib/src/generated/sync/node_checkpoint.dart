/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A committed prefix of a replica's local delivery order.
abstract class OfflineSyncNodeCheckpoint
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncNodeCheckpoint._({
    required this.uuidNodeId,
    required this.revision,
  });

  factory OfflineSyncNodeCheckpoint({
    required _iss.UuidValue uuidNodeId,
    required int revision,
  }) = _OfflineSyncNodeCheckpointImpl;

  factory OfflineSyncNodeCheckpoint.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncNodeCheckpoint(
      uuidNodeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidNodeId'],
      ),
      revision: jsonSerialization['revision'] as int,
    );
  }

  _iss.UuidValue uuidNodeId;

  int revision;

  /// Returns a shallow copy of this [OfflineSyncNodeCheckpoint]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncNodeCheckpoint copyWith({
    _iss.UuidValue? uuidNodeId,
    int? revision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncNodeCheckpoint',
      'uuidNodeId': uuidNodeId.toJson(),
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncNodeCheckpoint',
      'uuidNodeId': uuidNodeId.toJson(),
      'revision': revision,
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncNodeCheckpointImpl extends OfflineSyncNodeCheckpoint {
  _OfflineSyncNodeCheckpointImpl({
    required _iss.UuidValue uuidNodeId,
    required int revision,
  }) : super._(
         uuidNodeId: uuidNodeId,
         revision: revision,
       );

  /// Returns a shallow copy of this [OfflineSyncNodeCheckpoint]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncNodeCheckpoint copyWith({
    _iss.UuidValue? uuidNodeId,
    int? revision,
  }) {
    return OfflineSyncNodeCheckpoint(
      uuidNodeId: uuidNodeId ?? this.uuidNodeId,
      revision: revision ?? this.revision,
    );
  }
}
