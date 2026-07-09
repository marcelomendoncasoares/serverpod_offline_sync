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

/// A remote row insertion to merge.
abstract class CrdtMergeInsert extends _i1.CrdtMergeChange
    implements _i2.SerializableModel {
  CrdtMergeInsert._({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.uuidScopeId,
    required super.tableName,
    required super.uuidRowId,
    required super.uuidNodeId,
    required this.data,
  });

  factory CrdtMergeInsert({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required dynamic data,
  }) = _CrdtMergeInsertImpl;

  factory CrdtMergeInsert.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtMergeInsert(
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
      data: _i4.Protocol().deserializeDynamicFieldValue(
        jsonSerialization['data'],
      ),
    );
  }

  /// The serialized domain row payload for the insert.
  dynamic data;

  /// Returns a shallow copy of this [CrdtMergeInsert]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtMergeInsert copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    dynamic data,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtMergeInsert',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'uuidScopeId': uuidScopeId.toJson(),
      'tableName': tableName,
      'uuidRowId': uuidRowId.toJson(),
      'uuidNodeId': uuidNodeId.toJson(),
      'data': _i4.Protocol().dynamicFieldToJson(data),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtMergeInsertImpl extends CrdtMergeInsert {
  _CrdtMergeInsertImpl({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required dynamic data,
  }) : super._(
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         uuidScopeId: uuidScopeId,
         tableName: tableName,
         uuidRowId: uuidRowId,
         uuidNodeId: uuidNodeId,
         data: data,
       );

  /// Returns a shallow copy of this [CrdtMergeInsert]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtMergeInsert copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    Object? data = _Undefined,
  }) {
    return CrdtMergeInsert(
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      tableName: tableName ?? this.tableName,
      uuidRowId: uuidRowId ?? this.uuidRowId,
      uuidNodeId: uuidNodeId ?? this.uuidNodeId,
      data: data != _Undefined ? data : this.data,
    );
  }
}
