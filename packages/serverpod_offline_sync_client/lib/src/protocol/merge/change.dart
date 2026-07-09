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
import '../protocol.dart' as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import '../data/deleted_reason.dart' as _i3;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i4;
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart'
    as _i5;
part 'delete.dart';
part 'insert.dart';
part 'update.dart';

/// A remote CRDT change to merge.
sealed class CrdtMergeChange extends _i5.BaseHlc
    implements _i2.SerializableModel {
  CrdtMergeChange({
    required super.hlcDatetime,
    required super.hlcCounter,
    required this.uuidScopeId,
    required this.tableName,
    required this.uuidRowId,
    required this.uuidNodeId,
  });

  /// The scope this change belongs to.
  _i2.UuidValue uuidScopeId;

  /// The table receiving the change.
  String tableName;

  /// The domain row identifier receiving the change.
  _i2.UuidValue uuidRowId;

  /// The remote node that produced the change.
  _i2.UuidValue uuidNodeId;

  /// Returns a shallow copy of this [CrdtMergeChange]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  CrdtMergeChange copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i2.UuidValue? uuidScopeId,
    String? tableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? uuidNodeId,
  });
}

class _Undefined {}
