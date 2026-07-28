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

/// A remote field update to merge.
abstract class CrdtMergeUpdate extends _i1.CrdtMergeChange
    implements _i2.SerializableModel, _i2.ProtocolSerialization {
  CrdtMergeUpdate._({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.uuidScopeId,
    required super.tableName,
    required super.uuidRowId,
    required super.uuidNodeId,
    required this.columnName,
    required this.value,
  });

  factory CrdtMergeUpdate({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required String columnName,
    required dynamic value,
  }) = _CrdtMergeUpdateImpl;

  factory CrdtMergeUpdate.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtMergeUpdate(
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
      columnName: jsonSerialization['columnName'] as String,
      value: _i4.Protocol().deserializeDynamicFieldValue(
        jsonSerialization['value'],
      ),
    );
  }

  /// The updated database column name.
  String columnName;

  /// The serialized new value for the column.
  dynamic value;

  /// Returns a shallow copy of this [CrdtMergeUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtMergeUpdate copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    String? columnName,
    dynamic value,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtMergeUpdate',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'uuidScopeId': uuidScopeId.toJson(),
      'tableName': tableName,
      'uuidRowId': uuidRowId.toJson(),
      'uuidNodeId': uuidNodeId.toJson(),
      'columnName': columnName,
      'value': _i4.Protocol().dynamicFieldToJson(value),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtMergeUpdate',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'uuidScopeId': uuidScopeId.toJson(),
      'tableName': tableName,
      'uuidRowId': uuidRowId.toJson(),
      'uuidNodeId': uuidNodeId.toJson(),
      'columnName': columnName,
      'value': _i4.Protocol().dynamicFieldToJson(
        value,
        forProtocol: true,
      ),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtMergeUpdateImpl extends CrdtMergeUpdate {
  _CrdtMergeUpdateImpl({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _i2.UuidValue uuidScopeId,
    required String tableName,
    required _i2.UuidValue uuidRowId,
    required _i2.UuidValue uuidNodeId,
    required String columnName,
    required dynamic value,
  }) : super._(
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         uuidScopeId: uuidScopeId,
         tableName: tableName,
         uuidRowId: uuidRowId,
         uuidNodeId: uuidNodeId,
         columnName: columnName,
         value: value,
       );

  /// Returns a shallow copy of this [CrdtMergeUpdate]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtMergeUpdate copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
    String? columnName,
    Object? value = _Undefined,
  }) {
    return CrdtMergeUpdate(
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      tableName: tableName ?? this.tableName,
      uuidRowId: uuidRowId ?? this.uuidRowId,
      uuidNodeId: uuidNodeId ?? this.uuidNodeId,
      columnName: columnName ?? this.columnName,
      value: value != _Undefined ? value : this.value,
    );
  }
}
