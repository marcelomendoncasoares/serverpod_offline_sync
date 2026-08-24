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
abstract class CrdtMergeUpdate extends _icw2tu00.CrdtMergeChange
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
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
    required _iss.UuidValue uuidScopeId,
    required String tableName,
    required _iss.UuidValue uuidRowId,
    required _iss.UuidValue uuidNodeId,
    required String columnName,
    required dynamic value,
  }) = _CrdtMergeUpdateImpl;

  factory CrdtMergeUpdate.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtMergeUpdate(
      hlcDatetime: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      uuidScopeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidScopeId'],
      ),
      tableName: jsonSerialization['tableName'] as String,
      uuidRowId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      uuidNodeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidNodeId'],
      ),
      columnName: jsonSerialization['columnName'] as String,
      value: _icw2tu00.Protocol().deserializeDynamicFieldValue(
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
  @_iss.useResult
  CrdtMergeUpdate copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _iss.UuidValue? uuidScopeId,
    String? tableName,
    _iss.UuidValue? uuidRowId,
    _iss.UuidValue? uuidNodeId,
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
      'value': _icw2tu00.Protocol().dynamicFieldToJson(value),
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
      'value': _icw2tu00.Protocol().dynamicFieldToJson(
        value,
        forProtocol: true,
      ),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtMergeUpdateImpl extends CrdtMergeUpdate {
  _CrdtMergeUpdateImpl({
    required DateTime hlcDatetime,
    required int hlcCounter,
    required _iss.UuidValue uuidScopeId,
    required String tableName,
    required _iss.UuidValue uuidRowId,
    required _iss.UuidValue uuidNodeId,
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
  @_iss.useResult
  @override
  CrdtMergeUpdate copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _iss.UuidValue? uuidScopeId,
    String? tableName,
    _iss.UuidValue? uuidRowId,
    _iss.UuidValue? uuidNodeId,
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
