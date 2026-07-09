/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'change.dart';

/// A remote visibility CLFlag update to merge.
abstract class CrdtMergeDelete extends _i1.CrdtMergeChange
    implements _i2.SerializableModel, _i2.ProtocolSerialization {
  CrdtMergeDelete._({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.uuidScopeId,
    required super.tableName,
    required super.uuidRowId,
    required super.uuidNodeId,
    required this.clFlag,
    required this.reason,
  });

  factory CrdtMergeDelete({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required int clFlag,
    required _i3.CrdtDataDeletedReason reason,
  }) = _CrdtMergeDeleteImpl;

  factory CrdtMergeDelete.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtMergeDelete(
      hlcDatetime: _i2.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      uuidScopeId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidScopeId'],
      ),
      tableName: jsonSerialization['tableName'] as String,
      uuidRowId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      uuidNodeId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidNodeId'],
      ),
      clFlag: jsonSerialization['clFlag'] as int,
      reason: _i3.CrdtDataDeletedReason.fromJson(
        (jsonSerialization['reason'] as int),
      ),
    );
  }

  /// Monotone causal-length flag. Odd values are visible and even values are deleted.
  int clFlag;

  /// Why the row entered its current visibility generation.
  _i3.CrdtDataDeletedReason reason;

  /// Returns a shallow copy of this [CrdtMergeDelete]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtMergeDelete copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    int? clFlag,
    _i3.CrdtDataDeletedReason? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtMergeDelete',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'uuidScopeId': uuidScopeId.toJson(),
      'tableName': tableName,
      'uuidRowId': uuidRowId.toJson(),
      'uuidNodeId': uuidNodeId.toJson(),
      'clFlag': clFlag,
      'reason': reason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtMergeDelete',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'uuidScopeId': uuidScopeId.toJson(),
      'tableName': tableName,
      'uuidRowId': uuidRowId.toJson(),
      'uuidNodeId': uuidNodeId.toJson(),
      'clFlag': clFlag,
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtMergeDeleteImpl extends CrdtMergeDelete {
  _CrdtMergeDeleteImpl({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required int clFlag,
    required _i3.CrdtDataDeletedReason reason,
  }) : super._(
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         uuidScopeId: uuidScopeId,
         tableName: tableName,
         uuidRowId: uuidRowId,
         uuidNodeId: uuidNodeId,
         clFlag: clFlag,
         reason: reason,
       );

  /// Returns a shallow copy of this [CrdtMergeDelete]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtMergeDelete copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    int? clFlag,
    _i3.CrdtDataDeletedReason? reason,
  }) {
    return CrdtMergeDelete(
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      tableName: tableName ?? this.tableName,
      uuidRowId: uuidRowId ?? this.uuidRowId,
      uuidNodeId: uuidNodeId ?? this.uuidNodeId,
      clFlag: clFlag ?? this.clFlag,
      reason: reason ?? this.reason,
    );
  }
}
