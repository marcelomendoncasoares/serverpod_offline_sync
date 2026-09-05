/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart'
    as _i2ap9bqs;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'shared_child.dart' as _ipnbm8e1;
import 'shared_flavor.dart' as _ig8q940r;
import 'shared_parent.dart' as _ikuzrwo6;
export 'shared_child.dart';
export 'shared_flavor.dart';
export 'shared_parent.dart';

class Protocol extends _isd.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  final Set<_iss.SerializationManager> _hostProtocols = {};

  static List<_isd.TableDefinition> get targetTableDefinitions => [
    _isd.TableDefinition(
      name: 'shared_child',
      dartName: 'SharedChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'scopeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'flavor',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'serverpod_offline_sync_test_shared:SharedFlavor',
          columnDefault: '\'plain\'',
        ),
        _isd.ColumnDefinition(
          name: 'parentId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'shared_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'shared_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'shared_parent',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isd.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isd.TableDefinition(
      name: 'shared_parent',
      dartName: 'SharedParent',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'scopeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'shared_parent_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
  ];

  void registerHostProtocol(
    String projectName,
    _iss.SerializationManager protocol,
  ) {
    _hostProtocols.add(protocol);
  }

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _iss.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _ipnbm8e1.SharedChild) {
      return _ipnbm8e1.SharedChild.fromJson(data) as T;
    }
    if (t == _ig8q940r.SharedFlavor) {
      return _ig8q940r.SharedFlavor.fromJson(data) as T;
    }
    if (t == _ikuzrwo6.SharedParent) {
      return _ikuzrwo6.SharedParent.fromJson(data) as T;
    }
    if (t == _iss.getType<_ipnbm8e1.SharedChild?>()) {
      return (data != null ? _ipnbm8e1.SharedChild.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ig8q940r.SharedFlavor?>()) {
      return (data != null ? _ig8q940r.SharedFlavor.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ikuzrwo6.SharedParent?>()) {
      return (data != null ? _ikuzrwo6.SharedParent.fromJson(data) : null) as T;
    }
    if (t == List<_i2ap9bqs.SharedChild>) {
      return (data as List)
              .map((e) => deserialize<_i2ap9bqs.SharedChild>(e))
              .toList()
          as T;
    }
    if (t == _iss.getType<List<_i2ap9bqs.SharedChild>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i2ap9bqs.SharedChild>(e))
                    .toList()
              : null)
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ipnbm8e1.SharedChild => 'SharedChild',
      _ig8q940r.SharedFlavor => 'SharedFlavor',
      _ikuzrwo6.SharedParent => 'SharedParent',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'serverpod_offline_sync_test.',
        '',
      );
    }

    switch (data) {
      case _ipnbm8e1.SharedChild():
        return 'SharedChild';
      case _ig8q940r.SharedFlavor():
        return 'SharedFlavor';
      case _ikuzrwo6.SharedParent():
        return 'SharedParent';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'SharedChild') {
      return deserialize<_ipnbm8e1.SharedChild>(data['data']);
    }
    if (dataClassName == 'SharedFlavor') {
      return deserialize<_ig8q940r.SharedFlavor>(data['data']);
    }
    if (dataClassName == 'SharedParent') {
      return deserialize<_ikuzrwo6.SharedParent>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  Object? dynamicFieldToJson(Object? object, {bool forProtocol = false}) {
    if ((object is List || object is Set || object is Map) ||
        getClassNameForObject(object) != null) {
      return super.dynamicFieldToJson(object, forProtocol: forProtocol);
    }
    for (final protocol in _hostProtocols) {
      final className = protocol.getClassNameForObject(object);
      if (className == null) continue;
      final host = protocol.getModuleName();
      final wrapped = {
        'className': className.contains('.') ? className : '$host.$className',
        'data': object,
      };
      return forProtocol
          ? _iss.SerializationManager.toEncodableForProtocol(wrapped)
          : _iss.SerializationManager.toEncodable(wrapped);
    }
    return super.dynamicFieldToJson(object, forProtocol: forProtocol);
  }

  @override
  dynamic deserializeDynamicFieldValue(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic> || value['className'] is! String) {
      throw FormatException(
        'Dynamic fields are encoded as a Map with className and data, but got '
        '${value.runtimeType} instead.',
      );
    }
    final className = value['className'] as String;
    for (final protocol in _hostProtocols) {
      final host = protocol.getModuleName();
      final hostPrefix = '$host.';
      if (className.startsWith(hostPrefix)) {
        final strippedClassName = className.substring(hostPrefix.length);
        if (strippedClassName.contains('.')) {
          throw FormatException(
            'Dynamic field className must not use multiple prefixes: $className',
          );
        }
        final hostData = Map<String, dynamic>.from(value);
        hostData['className'] = strippedClassName;
        return protocol.deserializeByClassName(hostData);
      }
    }
    if (className.contains('.')) {
      for (final protocol in _hostProtocols) {
        try {
          return protocol.deserializeByClassName(value);
        } on _iss.DeserializationClassNameNotFoundException catch (_) {}
      }
    }
    return deserializeByClassName(value);
  }

  @override
  _isd.Table? getTableForType(Type t) {
    switch (t) {
      case _ipnbm8e1.SharedChild:
        return _ipnbm8e1.SharedChild.t;
      case _ikuzrwo6.SharedParent:
        return _ikuzrwo6.SharedParent.t;
    }
    return null;
  }

  @override
  List<_isd.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'serverpod_offline_sync_test';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
