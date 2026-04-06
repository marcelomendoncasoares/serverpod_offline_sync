// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CrdtDataTableTable extends CrdtDataTable
    with TableInfo<$CrdtDataTableTable, CrdtDataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtDataTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tblNameMeta = const VerificationMeta(
    'tblName',
  );
  @override
  late final GeneratedColumn<String> tblName = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _columnNameMeta = const VerificationMeta(
    'columnName',
  );
  @override
  late final GeneratedColumn<String> columnName = GeneratedColumn<String>(
    'column_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Hlc, String> hlcTimestamp =
      GeneratedColumn<String>(
        'hlc_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Hlc>($CrdtDataTableTable.$converterhlcTimestamp);
  static const VerificationMeta _rawValueMeta = const VerificationMeta(
    'rawValue',
  );
  @override
  late final GeneratedColumn<DriftAny> rawValue = GeneratedColumn<DriftAny>(
    'raw_value',
    aliasedName,
    true,
    type: DriftSqlType.any,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    tblName,
    columnName,
    rowId,
    hlcTimestamp,
    rawValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = '__crdt_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrdtDataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tblNameMeta,
        tblName.isAcceptableOrUnknown(data['table_name']!, _tblNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tblNameMeta);
    }
    if (data.containsKey('column_name')) {
      context.handle(
        _columnNameMeta,
        columnName.isAcceptableOrUnknown(data['column_name']!, _columnNameMeta),
      );
    } else if (isInserting) {
      context.missing(_columnNameMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('raw_value')) {
      context.handle(
        _rawValueMeta,
        rawValue.isAcceptableOrUnknown(data['raw_value']!, _rawValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, tblName, columnName, rowId};
  @override
  CrdtDataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtDataEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      tblName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      columnName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}column_name'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      hlcTimestamp: $CrdtDataTableTable.$converterhlcTimestamp.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}hlc_timestamp'],
        )!,
      ),
      rawValue: attachedDatabase.typeMapping.read(
        DriftSqlType.any,
        data['${effectivePrefix}raw_value'],
      ),
    );
  }

  @override
  $CrdtDataTableTable createAlias(String alias) {
    return $CrdtDataTableTable(attachedDatabase, alias);
  }

  static TypeConverter<Hlc, String> $converterhlcTimestamp = hlcConverter;
  @override
  bool get withoutRowId => true;
  @override
  bool get isStrict => true;
}

class CrdtDataEntry extends DataClass implements Insertable<CrdtDataEntry> {
  /// Identifier for the user or client that owns the data.
  final String userId;

  /// Name of the table that data belongs to.
  final String tblName;

  /// Name of the column this data belongs to.
  final String columnName;

  /// Unique identifier for the row in the table.
  final String rowId;

  /// Hybrid Logical Clock timestamp of the data update.
  final Hlc hlcTimestamp;

  /// Raw value of the data.
  final DriftAny? rawValue;
  const CrdtDataEntry({
    required this.userId,
    required this.tblName,
    required this.columnName,
    required this.rowId,
    required this.hlcTimestamp,
    this.rawValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['table_name'] = Variable<String>(tblName);
    map['column_name'] = Variable<String>(columnName);
    map['row_id'] = Variable<String>(rowId);
    {
      map['hlc_timestamp'] = Variable<String>(
        $CrdtDataTableTable.$converterhlcTimestamp.toSql(hlcTimestamp),
      );
    }
    if (!nullToAbsent || rawValue != null) {
      map['raw_value'] = Variable<DriftAny>(rawValue);
    }
    return map;
  }

  CrdtDataTableCompanion toCompanion(bool nullToAbsent) {
    return CrdtDataTableCompanion(
      userId: Value(userId),
      tblName: Value(tblName),
      columnName: Value(columnName),
      rowId: Value(rowId),
      hlcTimestamp: Value(hlcTimestamp),
      rawValue: rawValue == null && nullToAbsent
          ? const Value.absent()
          : Value(rawValue),
    );
  }

  factory CrdtDataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtDataEntry(
      userId: serializer.fromJson<String>(json['user_id']),
      tblName: serializer.fromJson<String>(json['table_name']),
      columnName: serializer.fromJson<String>(json['column_name']),
      rowId: serializer.fromJson<String>(json['row_id']),
      hlcTimestamp: serializer.fromJson<Hlc>(json['hlc_timestamp']),
      rawValue: serializer.fromJson<DriftAny?>(json['raw_value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'table_name': serializer.toJson<String>(tblName),
      'column_name': serializer.toJson<String>(columnName),
      'row_id': serializer.toJson<String>(rowId),
      'hlc_timestamp': serializer.toJson<Hlc>(hlcTimestamp),
      'raw_value': serializer.toJson<DriftAny?>(rawValue),
    };
  }

  CrdtDataEntry copyWith({
    String? userId,
    String? tblName,
    String? columnName,
    String? rowId,
    Hlc? hlcTimestamp,
    Value<DriftAny?> rawValue = const Value.absent(),
  }) => CrdtDataEntry(
    userId: userId ?? this.userId,
    tblName: tblName ?? this.tblName,
    columnName: columnName ?? this.columnName,
    rowId: rowId ?? this.rowId,
    hlcTimestamp: hlcTimestamp ?? this.hlcTimestamp,
    rawValue: rawValue.present ? rawValue.value : this.rawValue,
  );
  CrdtDataEntry copyWithCompanion(CrdtDataTableCompanion data) {
    return CrdtDataEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      tblName: data.tblName.present ? data.tblName.value : this.tblName,
      columnName: data.columnName.present
          ? data.columnName.value
          : this.columnName,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      hlcTimestamp: data.hlcTimestamp.present
          ? data.hlcTimestamp.value
          : this.hlcTimestamp,
      rawValue: data.rawValue.present ? data.rawValue.value : this.rawValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtDataEntry(')
          ..write('userId: $userId, ')
          ..write('tblName: $tblName, ')
          ..write('columnName: $columnName, ')
          ..write('rowId: $rowId, ')
          ..write('hlcTimestamp: $hlcTimestamp, ')
          ..write('rawValue: $rawValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, tblName, columnName, rowId, hlcTimestamp, rawValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtDataEntry &&
          other.userId == this.userId &&
          other.tblName == this.tblName &&
          other.columnName == this.columnName &&
          other.rowId == this.rowId &&
          other.hlcTimestamp == this.hlcTimestamp &&
          other.rawValue == this.rawValue);
}

class CrdtDataTableCompanion extends UpdateCompanion<CrdtDataEntry> {
  final Value<String> userId;
  final Value<String> tblName;
  final Value<String> columnName;
  final Value<String> rowId;
  final Value<Hlc> hlcTimestamp;
  final Value<DriftAny?> rawValue;
  const CrdtDataTableCompanion({
    this.userId = const Value.absent(),
    this.tblName = const Value.absent(),
    this.columnName = const Value.absent(),
    this.rowId = const Value.absent(),
    this.hlcTimestamp = const Value.absent(),
    this.rawValue = const Value.absent(),
  });
  CrdtDataTableCompanion.insert({
    required String userId,
    required String tblName,
    required String columnName,
    required String rowId,
    required Hlc hlcTimestamp,
    this.rawValue = const Value.absent(),
  }) : userId = Value(userId),
       tblName = Value(tblName),
       columnName = Value(columnName),
       rowId = Value(rowId),
       hlcTimestamp = Value(hlcTimestamp);
  static Insertable<CrdtDataEntry> custom({
    Expression<String>? userId,
    Expression<String>? tblName,
    Expression<String>? columnName,
    Expression<String>? rowId,
    Expression<String>? hlcTimestamp,
    Expression<DriftAny>? rawValue,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (tblName != null) 'table_name': tblName,
      if (columnName != null) 'column_name': columnName,
      if (rowId != null) 'row_id': rowId,
      if (hlcTimestamp != null) 'hlc_timestamp': hlcTimestamp,
      if (rawValue != null) 'raw_value': rawValue,
    });
  }

  CrdtDataTableCompanion copyWith({
    Value<String>? userId,
    Value<String>? tblName,
    Value<String>? columnName,
    Value<String>? rowId,
    Value<Hlc>? hlcTimestamp,
    Value<DriftAny?>? rawValue,
  }) {
    return CrdtDataTableCompanion(
      userId: userId ?? this.userId,
      tblName: tblName ?? this.tblName,
      columnName: columnName ?? this.columnName,
      rowId: rowId ?? this.rowId,
      hlcTimestamp: hlcTimestamp ?? this.hlcTimestamp,
      rawValue: rawValue ?? this.rawValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (tblName.present) {
      map['table_name'] = Variable<String>(tblName.value);
    }
    if (columnName.present) {
      map['column_name'] = Variable<String>(columnName.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (hlcTimestamp.present) {
      map['hlc_timestamp'] = Variable<String>(
        $CrdtDataTableTable.$converterhlcTimestamp.toSql(hlcTimestamp.value),
      );
    }
    if (rawValue.present) {
      map['raw_value'] = Variable<DriftAny>(rawValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtDataTableCompanion(')
          ..write('userId: $userId, ')
          ..write('tblName: $tblName, ')
          ..write('columnName: $columnName, ')
          ..write('rowId: $rowId, ')
          ..write('hlcTimestamp: $hlcTimestamp, ')
          ..write('rawValue: $rawValue')
          ..write(')'))
        .toString();
  }
}

class $CrdtNormalizedDataTableTable extends CrdtNormalizedDataTable
    with TableInfo<$CrdtNormalizedDataTableTable, CrdtNormalizedDataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtNormalizedDataTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tblNameMeta = const VerificationMeta(
    'tblName',
  );
  @override
  late final GeneratedColumn<String> tblName = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _columnNameMeta = const VerificationMeta(
    'columnName',
  );
  @override
  late final GeneratedColumn<String> columnName = GeneratedColumn<String>(
    'column_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcTimestampMeta = const VerificationMeta(
    'hlcTimestamp',
  );
  @override
  late final GeneratedColumn<int> hlcTimestamp = GeneratedColumn<int>(
    'hlc_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcCounterMeta = const VerificationMeta(
    'hlcCounter',
  );
  @override
  late final GeneratedColumn<int> hlcCounter = GeneratedColumn<int>(
    'hlc_counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcNodeIdMeta = const VerificationMeta(
    'hlcNodeId',
  );
  @override
  late final GeneratedColumn<String> hlcNodeId = GeneratedColumn<String>(
    'hlc_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawValueMeta = const VerificationMeta(
    'rawValue',
  );
  @override
  late final GeneratedColumn<DriftAny> rawValue = GeneratedColumn<DriftAny>(
    'raw_value',
    aliasedName,
    true,
    type: DriftSqlType.any,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    tblName,
    columnName,
    rowId,
    hlcTimestamp,
    hlcCounter,
    hlcNodeId,
    rawValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = '__crdt_normalized_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrdtNormalizedDataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tblNameMeta,
        tblName.isAcceptableOrUnknown(data['table_name']!, _tblNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tblNameMeta);
    }
    if (data.containsKey('column_name')) {
      context.handle(
        _columnNameMeta,
        columnName.isAcceptableOrUnknown(data['column_name']!, _columnNameMeta),
      );
    } else if (isInserting) {
      context.missing(_columnNameMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('hlc_timestamp')) {
      context.handle(
        _hlcTimestampMeta,
        hlcTimestamp.isAcceptableOrUnknown(
          data['hlc_timestamp']!,
          _hlcTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hlcTimestampMeta);
    }
    if (data.containsKey('hlc_counter')) {
      context.handle(
        _hlcCounterMeta,
        hlcCounter.isAcceptableOrUnknown(data['hlc_counter']!, _hlcCounterMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcCounterMeta);
    }
    if (data.containsKey('hlc_node_id')) {
      context.handle(
        _hlcNodeIdMeta,
        hlcNodeId.isAcceptableOrUnknown(data['hlc_node_id']!, _hlcNodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcNodeIdMeta);
    }
    if (data.containsKey('raw_value')) {
      context.handle(
        _rawValueMeta,
        rawValue.isAcceptableOrUnknown(data['raw_value']!, _rawValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, tblName, columnName, rowId};
  @override
  CrdtNormalizedDataEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtNormalizedDataEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      tblName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      columnName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}column_name'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      hlcTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hlc_timestamp'],
      )!,
      hlcCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hlc_counter'],
      )!,
      hlcNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc_node_id'],
      )!,
      rawValue: attachedDatabase.typeMapping.read(
        DriftSqlType.any,
        data['${effectivePrefix}raw_value'],
      ),
    );
  }

  @override
  $CrdtNormalizedDataTableTable createAlias(String alias) {
    return $CrdtNormalizedDataTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  bool get isStrict => true;
}

class CrdtNormalizedDataEntry extends DataClass
    implements Insertable<CrdtNormalizedDataEntry> {
  /// Identifier for the user or client that owns the data.
  final String userId;

  /// Name of the table that data belongs to.
  final String tblName;

  /// Name of the column this data belongs to.
  final String columnName;

  /// Unique identifier for the row in the table.
  final String rowId;

  /// Hybrid Logical Clock timestamp component (milliseconds since epoch).
  final int hlcTimestamp;

  /// Hybrid Logical Clock counter component.
  final int hlcCounter;

  /// Hybrid Logical Clock node ID component.
  final String hlcNodeId;

  /// Raw value of the data.
  final DriftAny? rawValue;
  const CrdtNormalizedDataEntry({
    required this.userId,
    required this.tblName,
    required this.columnName,
    required this.rowId,
    required this.hlcTimestamp,
    required this.hlcCounter,
    required this.hlcNodeId,
    this.rawValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['table_name'] = Variable<String>(tblName);
    map['column_name'] = Variable<String>(columnName);
    map['row_id'] = Variable<String>(rowId);
    map['hlc_timestamp'] = Variable<int>(hlcTimestamp);
    map['hlc_counter'] = Variable<int>(hlcCounter);
    map['hlc_node_id'] = Variable<String>(hlcNodeId);
    if (!nullToAbsent || rawValue != null) {
      map['raw_value'] = Variable<DriftAny>(rawValue);
    }
    return map;
  }

  CrdtNormalizedDataTableCompanion toCompanion(bool nullToAbsent) {
    return CrdtNormalizedDataTableCompanion(
      userId: Value(userId),
      tblName: Value(tblName),
      columnName: Value(columnName),
      rowId: Value(rowId),
      hlcTimestamp: Value(hlcTimestamp),
      hlcCounter: Value(hlcCounter),
      hlcNodeId: Value(hlcNodeId),
      rawValue: rawValue == null && nullToAbsent
          ? const Value.absent()
          : Value(rawValue),
    );
  }

  factory CrdtNormalizedDataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtNormalizedDataEntry(
      userId: serializer.fromJson<String>(json['user_id']),
      tblName: serializer.fromJson<String>(json['table_name']),
      columnName: serializer.fromJson<String>(json['column_name']),
      rowId: serializer.fromJson<String>(json['row_id']),
      hlcTimestamp: serializer.fromJson<int>(json['hlc_timestamp']),
      hlcCounter: serializer.fromJson<int>(json['hlc_counter']),
      hlcNodeId: serializer.fromJson<String>(json['hlc_node_id']),
      rawValue: serializer.fromJson<DriftAny?>(json['raw_value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'table_name': serializer.toJson<String>(tblName),
      'column_name': serializer.toJson<String>(columnName),
      'row_id': serializer.toJson<String>(rowId),
      'hlc_timestamp': serializer.toJson<int>(hlcTimestamp),
      'hlc_counter': serializer.toJson<int>(hlcCounter),
      'hlc_node_id': serializer.toJson<String>(hlcNodeId),
      'raw_value': serializer.toJson<DriftAny?>(rawValue),
    };
  }

  CrdtNormalizedDataEntry copyWith({
    String? userId,
    String? tblName,
    String? columnName,
    String? rowId,
    int? hlcTimestamp,
    int? hlcCounter,
    String? hlcNodeId,
    Value<DriftAny?> rawValue = const Value.absent(),
  }) => CrdtNormalizedDataEntry(
    userId: userId ?? this.userId,
    tblName: tblName ?? this.tblName,
    columnName: columnName ?? this.columnName,
    rowId: rowId ?? this.rowId,
    hlcTimestamp: hlcTimestamp ?? this.hlcTimestamp,
    hlcCounter: hlcCounter ?? this.hlcCounter,
    hlcNodeId: hlcNodeId ?? this.hlcNodeId,
    rawValue: rawValue.present ? rawValue.value : this.rawValue,
  );
  CrdtNormalizedDataEntry copyWithCompanion(
    CrdtNormalizedDataTableCompanion data,
  ) {
    return CrdtNormalizedDataEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      tblName: data.tblName.present ? data.tblName.value : this.tblName,
      columnName: data.columnName.present
          ? data.columnName.value
          : this.columnName,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      hlcTimestamp: data.hlcTimestamp.present
          ? data.hlcTimestamp.value
          : this.hlcTimestamp,
      hlcCounter: data.hlcCounter.present
          ? data.hlcCounter.value
          : this.hlcCounter,
      hlcNodeId: data.hlcNodeId.present ? data.hlcNodeId.value : this.hlcNodeId,
      rawValue: data.rawValue.present ? data.rawValue.value : this.rawValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtNormalizedDataEntry(')
          ..write('userId: $userId, ')
          ..write('tblName: $tblName, ')
          ..write('columnName: $columnName, ')
          ..write('rowId: $rowId, ')
          ..write('hlcTimestamp: $hlcTimestamp, ')
          ..write('hlcCounter: $hlcCounter, ')
          ..write('hlcNodeId: $hlcNodeId, ')
          ..write('rawValue: $rawValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    tblName,
    columnName,
    rowId,
    hlcTimestamp,
    hlcCounter,
    hlcNodeId,
    rawValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtNormalizedDataEntry &&
          other.userId == this.userId &&
          other.tblName == this.tblName &&
          other.columnName == this.columnName &&
          other.rowId == this.rowId &&
          other.hlcTimestamp == this.hlcTimestamp &&
          other.hlcCounter == this.hlcCounter &&
          other.hlcNodeId == this.hlcNodeId &&
          other.rawValue == this.rawValue);
}

class CrdtNormalizedDataTableCompanion
    extends UpdateCompanion<CrdtNormalizedDataEntry> {
  final Value<String> userId;
  final Value<String> tblName;
  final Value<String> columnName;
  final Value<String> rowId;
  final Value<int> hlcTimestamp;
  final Value<int> hlcCounter;
  final Value<String> hlcNodeId;
  final Value<DriftAny?> rawValue;
  const CrdtNormalizedDataTableCompanion({
    this.userId = const Value.absent(),
    this.tblName = const Value.absent(),
    this.columnName = const Value.absent(),
    this.rowId = const Value.absent(),
    this.hlcTimestamp = const Value.absent(),
    this.hlcCounter = const Value.absent(),
    this.hlcNodeId = const Value.absent(),
    this.rawValue = const Value.absent(),
  });
  CrdtNormalizedDataTableCompanion.insert({
    required String userId,
    required String tblName,
    required String columnName,
    required String rowId,
    required int hlcTimestamp,
    required int hlcCounter,
    required String hlcNodeId,
    this.rawValue = const Value.absent(),
  }) : userId = Value(userId),
       tblName = Value(tblName),
       columnName = Value(columnName),
       rowId = Value(rowId),
       hlcTimestamp = Value(hlcTimestamp),
       hlcCounter = Value(hlcCounter),
       hlcNodeId = Value(hlcNodeId);
  static Insertable<CrdtNormalizedDataEntry> custom({
    Expression<String>? userId,
    Expression<String>? tblName,
    Expression<String>? columnName,
    Expression<String>? rowId,
    Expression<int>? hlcTimestamp,
    Expression<int>? hlcCounter,
    Expression<String>? hlcNodeId,
    Expression<DriftAny>? rawValue,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (tblName != null) 'table_name': tblName,
      if (columnName != null) 'column_name': columnName,
      if (rowId != null) 'row_id': rowId,
      if (hlcTimestamp != null) 'hlc_timestamp': hlcTimestamp,
      if (hlcCounter != null) 'hlc_counter': hlcCounter,
      if (hlcNodeId != null) 'hlc_node_id': hlcNodeId,
      if (rawValue != null) 'raw_value': rawValue,
    });
  }

  CrdtNormalizedDataTableCompanion copyWith({
    Value<String>? userId,
    Value<String>? tblName,
    Value<String>? columnName,
    Value<String>? rowId,
    Value<int>? hlcTimestamp,
    Value<int>? hlcCounter,
    Value<String>? hlcNodeId,
    Value<DriftAny?>? rawValue,
  }) {
    return CrdtNormalizedDataTableCompanion(
      userId: userId ?? this.userId,
      tblName: tblName ?? this.tblName,
      columnName: columnName ?? this.columnName,
      rowId: rowId ?? this.rowId,
      hlcTimestamp: hlcTimestamp ?? this.hlcTimestamp,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      hlcNodeId: hlcNodeId ?? this.hlcNodeId,
      rawValue: rawValue ?? this.rawValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (tblName.present) {
      map['table_name'] = Variable<String>(tblName.value);
    }
    if (columnName.present) {
      map['column_name'] = Variable<String>(columnName.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (hlcTimestamp.present) {
      map['hlc_timestamp'] = Variable<int>(hlcTimestamp.value);
    }
    if (hlcCounter.present) {
      map['hlc_counter'] = Variable<int>(hlcCounter.value);
    }
    if (hlcNodeId.present) {
      map['hlc_node_id'] = Variable<String>(hlcNodeId.value);
    }
    if (rawValue.present) {
      map['raw_value'] = Variable<DriftAny>(rawValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtNormalizedDataTableCompanion(')
          ..write('userId: $userId, ')
          ..write('tblName: $tblName, ')
          ..write('columnName: $columnName, ')
          ..write('rowId: $rowId, ')
          ..write('hlcTimestamp: $hlcTimestamp, ')
          ..write('hlcCounter: $hlcCounter, ')
          ..write('hlcNodeId: $hlcNodeId, ')
          ..write('rawValue: $rawValue')
          ..write(')'))
        .toString();
  }
}

class $CrdtControlTableTable extends CrdtControlTable
    with TableInfo<$CrdtControlTableTable, CrdtControlEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtControlTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _crdtTriggersOnMeta = const VerificationMeta(
    'crdtTriggersOn',
  );
  @override
  late final GeneratedColumn<bool> crdtTriggersOn = GeneratedColumn<bool>(
    'crdt_triggers_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("crdt_triggers_on" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Hlc?, String> lastSyncHlc =
      GeneratedColumn<String>(
        'last_sync_hlc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Hlc?>($CrdtControlTableTable.$converterlastSyncHlc);
  @override
  late final GeneratedColumnWithTypeConverter<Hlc?, String> lastApplyHlc =
      GeneratedColumn<String>(
        'last_apply_hlc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Hlc?>($CrdtControlTableTable.$converterlastApplyHlc);
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    nodeId,
    crdtTriggersOn,
    schemaVersion,
    lastSyncHlc,
    lastApplyHlc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = '__crdt_control';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrdtControlEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('crdt_triggers_on')) {
      context.handle(
        _crdtTriggersOnMeta,
        crdtTriggersOn.isAcceptableOrUnknown(
          data['crdt_triggers_on']!,
          _crdtTriggersOnMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, nodeId};
  @override
  CrdtControlEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtControlEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      crdtTriggersOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}crdt_triggers_on'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      lastSyncHlc: $CrdtControlTableTable.$converterlastSyncHlc.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_sync_hlc'],
        ),
      ),
      lastApplyHlc: $CrdtControlTableTable.$converterlastApplyHlc.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_apply_hlc'],
        ),
      ),
    );
  }

  @override
  $CrdtControlTableTable createAlias(String alias) {
    return $CrdtControlTableTable(attachedDatabase, alias);
  }

  static TypeConverter<Hlc?, String?> $converterlastSyncHlc =
      nullableHlcConverter;
  static TypeConverter<Hlc?, String?> $converterlastApplyHlc =
      nullableHlcConverter;
}

class CrdtControlEntry extends DataClass
    implements Insertable<CrdtControlEntry> {
  /// Identifier for the user or client.
  final String userId;

  /// Node identifier for the client.
  final String nodeId;

  /// Whether CRDT triggers are currently enabled for this user.
  final bool crdtTriggersOn;

  /// The schema version of the CRDT data.
  final int schemaVersion;

  /// The last HLC timestamp when the user synchronized.
  final Hlc? lastSyncHlc;

  /// The last HLC timestamp when merged changes were applied.
  final Hlc? lastApplyHlc;
  const CrdtControlEntry({
    required this.userId,
    required this.nodeId,
    required this.crdtTriggersOn,
    required this.schemaVersion,
    this.lastSyncHlc,
    this.lastApplyHlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['node_id'] = Variable<String>(nodeId);
    map['crdt_triggers_on'] = Variable<bool>(crdtTriggersOn);
    map['schema_version'] = Variable<int>(schemaVersion);
    if (!nullToAbsent || lastSyncHlc != null) {
      map['last_sync_hlc'] = Variable<String>(
        $CrdtControlTableTable.$converterlastSyncHlc.toSql(lastSyncHlc),
      );
    }
    if (!nullToAbsent || lastApplyHlc != null) {
      map['last_apply_hlc'] = Variable<String>(
        $CrdtControlTableTable.$converterlastApplyHlc.toSql(lastApplyHlc),
      );
    }
    return map;
  }

  CrdtControlTableCompanion toCompanion(bool nullToAbsent) {
    return CrdtControlTableCompanion(
      userId: Value(userId),
      nodeId: Value(nodeId),
      crdtTriggersOn: Value(crdtTriggersOn),
      schemaVersion: Value(schemaVersion),
      lastSyncHlc: lastSyncHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncHlc),
      lastApplyHlc: lastApplyHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastApplyHlc),
    );
  }

  factory CrdtControlEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtControlEntry(
      userId: serializer.fromJson<String>(json['user_id']),
      nodeId: serializer.fromJson<String>(json['node_id']),
      crdtTriggersOn: serializer.fromJson<bool>(json['crdt_triggers_on']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
      lastSyncHlc: serializer.fromJson<Hlc?>(json['last_sync_hlc']),
      lastApplyHlc: serializer.fromJson<Hlc?>(json['last_apply_hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'node_id': serializer.toJson<String>(nodeId),
      'crdt_triggers_on': serializer.toJson<bool>(crdtTriggersOn),
      'schema_version': serializer.toJson<int>(schemaVersion),
      'last_sync_hlc': serializer.toJson<Hlc?>(lastSyncHlc),
      'last_apply_hlc': serializer.toJson<Hlc?>(lastApplyHlc),
    };
  }

  CrdtControlEntry copyWith({
    String? userId,
    String? nodeId,
    bool? crdtTriggersOn,
    int? schemaVersion,
    Value<Hlc?> lastSyncHlc = const Value.absent(),
    Value<Hlc?> lastApplyHlc = const Value.absent(),
  }) => CrdtControlEntry(
    userId: userId ?? this.userId,
    nodeId: nodeId ?? this.nodeId,
    crdtTriggersOn: crdtTriggersOn ?? this.crdtTriggersOn,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    lastSyncHlc: lastSyncHlc.present ? lastSyncHlc.value : this.lastSyncHlc,
    lastApplyHlc: lastApplyHlc.present ? lastApplyHlc.value : this.lastApplyHlc,
  );
  CrdtControlEntry copyWithCompanion(CrdtControlTableCompanion data) {
    return CrdtControlEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      crdtTriggersOn: data.crdtTriggersOn.present
          ? data.crdtTriggersOn.value
          : this.crdtTriggersOn,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      lastSyncHlc: data.lastSyncHlc.present
          ? data.lastSyncHlc.value
          : this.lastSyncHlc,
      lastApplyHlc: data.lastApplyHlc.present
          ? data.lastApplyHlc.value
          : this.lastApplyHlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtControlEntry(')
          ..write('userId: $userId, ')
          ..write('nodeId: $nodeId, ')
          ..write('crdtTriggersOn: $crdtTriggersOn, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('lastSyncHlc: $lastSyncHlc, ')
          ..write('lastApplyHlc: $lastApplyHlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    nodeId,
    crdtTriggersOn,
    schemaVersion,
    lastSyncHlc,
    lastApplyHlc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtControlEntry &&
          other.userId == this.userId &&
          other.nodeId == this.nodeId &&
          other.crdtTriggersOn == this.crdtTriggersOn &&
          other.schemaVersion == this.schemaVersion &&
          other.lastSyncHlc == this.lastSyncHlc &&
          other.lastApplyHlc == this.lastApplyHlc);
}

class CrdtControlTableCompanion extends UpdateCompanion<CrdtControlEntry> {
  final Value<String> userId;
  final Value<String> nodeId;
  final Value<bool> crdtTriggersOn;
  final Value<int> schemaVersion;
  final Value<Hlc?> lastSyncHlc;
  final Value<Hlc?> lastApplyHlc;
  final Value<int> rowid;
  const CrdtControlTableCompanion({
    this.userId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.crdtTriggersOn = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.lastSyncHlc = const Value.absent(),
    this.lastApplyHlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CrdtControlTableCompanion.insert({
    required String userId,
    required String nodeId,
    this.crdtTriggersOn = const Value.absent(),
    required int schemaVersion,
    this.lastSyncHlc = const Value.absent(),
    this.lastApplyHlc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       nodeId = Value(nodeId),
       schemaVersion = Value(schemaVersion);
  static Insertable<CrdtControlEntry> custom({
    Expression<String>? userId,
    Expression<String>? nodeId,
    Expression<bool>? crdtTriggersOn,
    Expression<int>? schemaVersion,
    Expression<String>? lastSyncHlc,
    Expression<String>? lastApplyHlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (nodeId != null) 'node_id': nodeId,
      if (crdtTriggersOn != null) 'crdt_triggers_on': crdtTriggersOn,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (lastSyncHlc != null) 'last_sync_hlc': lastSyncHlc,
      if (lastApplyHlc != null) 'last_apply_hlc': lastApplyHlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CrdtControlTableCompanion copyWith({
    Value<String>? userId,
    Value<String>? nodeId,
    Value<bool>? crdtTriggersOn,
    Value<int>? schemaVersion,
    Value<Hlc?>? lastSyncHlc,
    Value<Hlc?>? lastApplyHlc,
    Value<int>? rowid,
  }) {
    return CrdtControlTableCompanion(
      userId: userId ?? this.userId,
      nodeId: nodeId ?? this.nodeId,
      crdtTriggersOn: crdtTriggersOn ?? this.crdtTriggersOn,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      lastSyncHlc: lastSyncHlc ?? this.lastSyncHlc,
      lastApplyHlc: lastApplyHlc ?? this.lastApplyHlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (crdtTriggersOn.present) {
      map['crdt_triggers_on'] = Variable<bool>(crdtTriggersOn.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (lastSyncHlc.present) {
      map['last_sync_hlc'] = Variable<String>(
        $CrdtControlTableTable.$converterlastSyncHlc.toSql(lastSyncHlc.value),
      );
    }
    if (lastApplyHlc.present) {
      map['last_apply_hlc'] = Variable<String>(
        $CrdtControlTableTable.$converterlastApplyHlc.toSql(lastApplyHlc.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtControlTableCompanion(')
          ..write('userId: $userId, ')
          ..write('nodeId: $nodeId, ')
          ..write('crdtTriggersOn: $crdtTriggersOn, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('lastSyncHlc: $lastSyncHlc, ')
          ..write('lastApplyHlc: $lastApplyHlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CrdtHlcStateTableTable extends CrdtHlcStateTable
    with TableInfo<$CrdtHlcStateTableTable, CrdtHlcEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtHlcStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastTimestampMeta = const VerificationMeta(
    'lastTimestamp',
  );
  @override
  late final GeneratedColumn<int> lastTimestamp = GeneratedColumn<int>(
    'last_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterMeta = const VerificationMeta(
    'counter',
  );
  @override
  late final GeneratedColumn<int> counter = GeneratedColumn<int>(
    'counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, lastTimestamp, counter];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = '__hlc_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrdtHlcEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('last_timestamp')) {
      context.handle(
        _lastTimestampMeta,
        lastTimestamp.isAcceptableOrUnknown(
          data['last_timestamp']!,
          _lastTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastTimestampMeta);
    }
    if (data.containsKey('counter')) {
      context.handle(
        _counterMeta,
        counter.isAcceptableOrUnknown(data['counter']!, _counterMeta),
      );
    } else if (isInserting) {
      context.missing(_counterMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CrdtHlcEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtHlcEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      lastTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_timestamp'],
      )!,
      counter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counter'],
      )!,
    );
  }

  @override
  $CrdtHlcStateTableTable createAlias(String alias) {
    return $CrdtHlcStateTableTable(attachedDatabase, alias);
  }
}

class CrdtHlcEntry extends DataClass implements Insertable<CrdtHlcEntry> {
  /// Identifier for the user or client.
  final String userId;

  /// Last HLC timestamp in milliseconds since epoch (logical time component).
  final int lastTimestamp;

  /// Counter for events at the same logical time (count component).
  final int counter;
  const CrdtHlcEntry({
    required this.userId,
    required this.lastTimestamp,
    required this.counter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['last_timestamp'] = Variable<int>(lastTimestamp);
    map['counter'] = Variable<int>(counter);
    return map;
  }

  CrdtHlcStateTableCompanion toCompanion(bool nullToAbsent) {
    return CrdtHlcStateTableCompanion(
      userId: Value(userId),
      lastTimestamp: Value(lastTimestamp),
      counter: Value(counter),
    );
  }

  factory CrdtHlcEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtHlcEntry(
      userId: serializer.fromJson<String>(json['user_id']),
      lastTimestamp: serializer.fromJson<int>(json['last_timestamp']),
      counter: serializer.fromJson<int>(json['counter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'last_timestamp': serializer.toJson<int>(lastTimestamp),
      'counter': serializer.toJson<int>(counter),
    };
  }

  CrdtHlcEntry copyWith({String? userId, int? lastTimestamp, int? counter}) =>
      CrdtHlcEntry(
        userId: userId ?? this.userId,
        lastTimestamp: lastTimestamp ?? this.lastTimestamp,
        counter: counter ?? this.counter,
      );
  CrdtHlcEntry copyWithCompanion(CrdtHlcStateTableCompanion data) {
    return CrdtHlcEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      lastTimestamp: data.lastTimestamp.present
          ? data.lastTimestamp.value
          : this.lastTimestamp,
      counter: data.counter.present ? data.counter.value : this.counter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtHlcEntry(')
          ..write('userId: $userId, ')
          ..write('lastTimestamp: $lastTimestamp, ')
          ..write('counter: $counter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, lastTimestamp, counter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtHlcEntry &&
          other.userId == this.userId &&
          other.lastTimestamp == this.lastTimestamp &&
          other.counter == this.counter);
}

class CrdtHlcStateTableCompanion extends UpdateCompanion<CrdtHlcEntry> {
  final Value<String> userId;
  final Value<int> lastTimestamp;
  final Value<int> counter;
  final Value<int> rowid;
  const CrdtHlcStateTableCompanion({
    this.userId = const Value.absent(),
    this.lastTimestamp = const Value.absent(),
    this.counter = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CrdtHlcStateTableCompanion.insert({
    required String userId,
    required int lastTimestamp,
    required int counter,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       lastTimestamp = Value(lastTimestamp),
       counter = Value(counter);
  static Insertable<CrdtHlcEntry> custom({
    Expression<String>? userId,
    Expression<int>? lastTimestamp,
    Expression<int>? counter,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (lastTimestamp != null) 'last_timestamp': lastTimestamp,
      if (counter != null) 'counter': counter,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CrdtHlcStateTableCompanion copyWith({
    Value<String>? userId,
    Value<int>? lastTimestamp,
    Value<int>? counter,
    Value<int>? rowid,
  }) {
    return CrdtHlcStateTableCompanion(
      userId: userId ?? this.userId,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      counter: counter ?? this.counter,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (lastTimestamp.present) {
      map['last_timestamp'] = Variable<int>(lastTimestamp.value);
    }
    if (counter.present) {
      map['counter'] = Variable<int>(counter.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtHlcStateTableCompanion(')
          ..write('userId: $userId, ')
          ..write('lastTimestamp: $lastTimestamp, ')
          ..write('counter: $counter, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CrdtMergeHlcTableTable extends CrdtMergeHlcTable
    with TableInfo<$CrdtMergeHlcTableTable, CrdtMergeHlcEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtMergeHlcTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Hlc, String> lastReceivedHlc =
      GeneratedColumn<String>(
        'last_received_hlc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Hlc>($CrdtMergeHlcTableTable.$converterlastReceivedHlc);
  @override
  List<GeneratedColumn> get $columns => [userId, nodeId, lastReceivedHlc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = '__crdt_merge_hlc';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrdtMergeHlcEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, nodeId};
  @override
  CrdtMergeHlcEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtMergeHlcEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      lastReceivedHlc: $CrdtMergeHlcTableTable.$converterlastReceivedHlc
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}last_received_hlc'],
            )!,
          ),
    );
  }

  @override
  $CrdtMergeHlcTableTable createAlias(String alias) {
    return $CrdtMergeHlcTableTable(attachedDatabase, alias);
  }

  static TypeConverter<Hlc, String> $converterlastReceivedHlc = hlcConverter;
}

class CrdtMergeHlcEntry extends DataClass
    implements Insertable<CrdtMergeHlcEntry> {
  /// Identifier for the user or client.
  final String userId;

  /// Node identifier for the client.
  final String nodeId;

  /// The last HLC timestamp received from this node when merging changes.
  final Hlc lastReceivedHlc;
  const CrdtMergeHlcEntry({
    required this.userId,
    required this.nodeId,
    required this.lastReceivedHlc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['node_id'] = Variable<String>(nodeId);
    {
      map['last_received_hlc'] = Variable<String>(
        $CrdtMergeHlcTableTable.$converterlastReceivedHlc.toSql(
          lastReceivedHlc,
        ),
      );
    }
    return map;
  }

  CrdtMergeHlcTableCompanion toCompanion(bool nullToAbsent) {
    return CrdtMergeHlcTableCompanion(
      userId: Value(userId),
      nodeId: Value(nodeId),
      lastReceivedHlc: Value(lastReceivedHlc),
    );
  }

  factory CrdtMergeHlcEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtMergeHlcEntry(
      userId: serializer.fromJson<String>(json['user_id']),
      nodeId: serializer.fromJson<String>(json['node_id']),
      lastReceivedHlc: serializer.fromJson<Hlc>(json['last_received_hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'node_id': serializer.toJson<String>(nodeId),
      'last_received_hlc': serializer.toJson<Hlc>(lastReceivedHlc),
    };
  }

  CrdtMergeHlcEntry copyWith({
    String? userId,
    String? nodeId,
    Hlc? lastReceivedHlc,
  }) => CrdtMergeHlcEntry(
    userId: userId ?? this.userId,
    nodeId: nodeId ?? this.nodeId,
    lastReceivedHlc: lastReceivedHlc ?? this.lastReceivedHlc,
  );
  CrdtMergeHlcEntry copyWithCompanion(CrdtMergeHlcTableCompanion data) {
    return CrdtMergeHlcEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      lastReceivedHlc: data.lastReceivedHlc.present
          ? data.lastReceivedHlc.value
          : this.lastReceivedHlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtMergeHlcEntry(')
          ..write('userId: $userId, ')
          ..write('nodeId: $nodeId, ')
          ..write('lastReceivedHlc: $lastReceivedHlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, nodeId, lastReceivedHlc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtMergeHlcEntry &&
          other.userId == this.userId &&
          other.nodeId == this.nodeId &&
          other.lastReceivedHlc == this.lastReceivedHlc);
}

class CrdtMergeHlcTableCompanion extends UpdateCompanion<CrdtMergeHlcEntry> {
  final Value<String> userId;
  final Value<String> nodeId;
  final Value<Hlc> lastReceivedHlc;
  final Value<int> rowid;
  const CrdtMergeHlcTableCompanion({
    this.userId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.lastReceivedHlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CrdtMergeHlcTableCompanion.insert({
    required String userId,
    required String nodeId,
    required Hlc lastReceivedHlc,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       nodeId = Value(nodeId),
       lastReceivedHlc = Value(lastReceivedHlc);
  static Insertable<CrdtMergeHlcEntry> custom({
    Expression<String>? userId,
    Expression<String>? nodeId,
    Expression<String>? lastReceivedHlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (nodeId != null) 'node_id': nodeId,
      if (lastReceivedHlc != null) 'last_received_hlc': lastReceivedHlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CrdtMergeHlcTableCompanion copyWith({
    Value<String>? userId,
    Value<String>? nodeId,
    Value<Hlc>? lastReceivedHlc,
    Value<int>? rowid,
  }) {
    return CrdtMergeHlcTableCompanion(
      userId: userId ?? this.userId,
      nodeId: nodeId ?? this.nodeId,
      lastReceivedHlc: lastReceivedHlc ?? this.lastReceivedHlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (lastReceivedHlc.present) {
      map['last_received_hlc'] = Variable<String>(
        $CrdtMergeHlcTableTable.$converterlastReceivedHlc.toSql(
          lastReceivedHlc.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtMergeHlcTableCompanion(')
          ..write('userId: $userId, ')
          ..write('nodeId: $nodeId, ')
          ..write('lastReceivedHlc: $lastReceivedHlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CrdtDatabase extends GeneratedDatabase {
  _$CrdtDatabase(QueryExecutor e) : super(e);
  $CrdtDatabaseManager get managers => $CrdtDatabaseManager(this);
  late final $CrdtDataTableTable crdtDataTable = $CrdtDataTableTable(this);
  late final $CrdtNormalizedDataTableTable crdtNormalizedDataTable =
      $CrdtNormalizedDataTableTable(this);
  late final $CrdtControlTableTable crdtControlTable = $CrdtControlTableTable(
    this,
  );
  late final $CrdtHlcStateTableTable crdtHlcStateTable =
      $CrdtHlcStateTableTable(this);
  late final $CrdtMergeHlcTableTable crdtMergeHlcTable =
      $CrdtMergeHlcTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    crdtDataTable,
    crdtNormalizedDataTable,
    crdtControlTable,
    crdtHlcStateTable,
    crdtMergeHlcTable,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CrdtDataTableTableCreateCompanionBuilder =
    CrdtDataTableCompanion Function({
      required String userId,
      required String tblName,
      required String columnName,
      required String rowId,
      required Hlc hlcTimestamp,
      Value<DriftAny?> rawValue,
    });
typedef $$CrdtDataTableTableUpdateCompanionBuilder =
    CrdtDataTableCompanion Function({
      Value<String> userId,
      Value<String> tblName,
      Value<String> columnName,
      Value<String> rowId,
      Value<Hlc> hlcTimestamp,
      Value<DriftAny?> rawValue,
    });

class $$CrdtDataTableTableFilterComposer
    extends Composer<_$CrdtDatabase, $CrdtDataTableTable> {
  $$CrdtDataTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Hlc, Hlc, String> get hlcTimestamp =>
      $composableBuilder(
        column: $table.hlcTimestamp,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DriftAny> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CrdtDataTableTableOrderingComposer
    extends Composer<_$CrdtDatabase, $CrdtDataTableTable> {
  $$CrdtDataTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlcTimestamp => $composableBuilder(
    column: $table.hlcTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DriftAny> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrdtDataTableTableAnnotationComposer
    extends Composer<_$CrdtDatabase, $CrdtDataTableTable> {
  $$CrdtDataTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get tblName =>
      $composableBuilder(column: $table.tblName, builder: (column) => column);

  GeneratedColumn<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Hlc, String> get hlcTimestamp =>
      $composableBuilder(
        column: $table.hlcTimestamp,
        builder: (column) => column,
      );

  GeneratedColumn<DriftAny> get rawValue =>
      $composableBuilder(column: $table.rawValue, builder: (column) => column);
}

class $$CrdtDataTableTableTableManager
    extends
        RootTableManager<
          _$CrdtDatabase,
          $CrdtDataTableTable,
          CrdtDataEntry,
          $$CrdtDataTableTableFilterComposer,
          $$CrdtDataTableTableOrderingComposer,
          $$CrdtDataTableTableAnnotationComposer,
          $$CrdtDataTableTableCreateCompanionBuilder,
          $$CrdtDataTableTableUpdateCompanionBuilder,
          (
            CrdtDataEntry,
            BaseReferences<_$CrdtDatabase, $CrdtDataTableTable, CrdtDataEntry>,
          ),
          CrdtDataEntry,
          PrefetchHooks Function()
        > {
  $$CrdtDataTableTableTableManager(_$CrdtDatabase db, $CrdtDataTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtDataTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrdtDataTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrdtDataTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> tblName = const Value.absent(),
                Value<String> columnName = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<Hlc> hlcTimestamp = const Value.absent(),
                Value<DriftAny?> rawValue = const Value.absent(),
              }) => CrdtDataTableCompanion(
                userId: userId,
                tblName: tblName,
                columnName: columnName,
                rowId: rowId,
                hlcTimestamp: hlcTimestamp,
                rawValue: rawValue,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String tblName,
                required String columnName,
                required String rowId,
                required Hlc hlcTimestamp,
                Value<DriftAny?> rawValue = const Value.absent(),
              }) => CrdtDataTableCompanion.insert(
                userId: userId,
                tblName: tblName,
                columnName: columnName,
                rowId: rowId,
                hlcTimestamp: hlcTimestamp,
                rawValue: rawValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrdtDataTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtDatabase,
      $CrdtDataTableTable,
      CrdtDataEntry,
      $$CrdtDataTableTableFilterComposer,
      $$CrdtDataTableTableOrderingComposer,
      $$CrdtDataTableTableAnnotationComposer,
      $$CrdtDataTableTableCreateCompanionBuilder,
      $$CrdtDataTableTableUpdateCompanionBuilder,
      (
        CrdtDataEntry,
        BaseReferences<_$CrdtDatabase, $CrdtDataTableTable, CrdtDataEntry>,
      ),
      CrdtDataEntry,
      PrefetchHooks Function()
    >;
typedef $$CrdtNormalizedDataTableTableCreateCompanionBuilder =
    CrdtNormalizedDataTableCompanion Function({
      required String userId,
      required String tblName,
      required String columnName,
      required String rowId,
      required int hlcTimestamp,
      required int hlcCounter,
      required String hlcNodeId,
      Value<DriftAny?> rawValue,
    });
typedef $$CrdtNormalizedDataTableTableUpdateCompanionBuilder =
    CrdtNormalizedDataTableCompanion Function({
      Value<String> userId,
      Value<String> tblName,
      Value<String> columnName,
      Value<String> rowId,
      Value<int> hlcTimestamp,
      Value<int> hlcCounter,
      Value<String> hlcNodeId,
      Value<DriftAny?> rawValue,
    });

class $$CrdtNormalizedDataTableTableFilterComposer
    extends Composer<_$CrdtDatabase, $CrdtNormalizedDataTableTable> {
  $$CrdtNormalizedDataTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hlcTimestamp => $composableBuilder(
    column: $table.hlcTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hlcCounter => $composableBuilder(
    column: $table.hlcCounter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlcNodeId => $composableBuilder(
    column: $table.hlcNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DriftAny> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CrdtNormalizedDataTableTableOrderingComposer
    extends Composer<_$CrdtDatabase, $CrdtNormalizedDataTableTable> {
  $$CrdtNormalizedDataTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hlcTimestamp => $composableBuilder(
    column: $table.hlcTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hlcCounter => $composableBuilder(
    column: $table.hlcCounter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlcNodeId => $composableBuilder(
    column: $table.hlcNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DriftAny> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrdtNormalizedDataTableTableAnnotationComposer
    extends Composer<_$CrdtDatabase, $CrdtNormalizedDataTableTable> {
  $$CrdtNormalizedDataTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get tblName =>
      $composableBuilder(column: $table.tblName, builder: (column) => column);

  GeneratedColumn<String> get columnName => $composableBuilder(
    column: $table.columnName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get hlcTimestamp => $composableBuilder(
    column: $table.hlcTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hlcCounter => $composableBuilder(
    column: $table.hlcCounter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hlcNodeId =>
      $composableBuilder(column: $table.hlcNodeId, builder: (column) => column);

  GeneratedColumn<DriftAny> get rawValue =>
      $composableBuilder(column: $table.rawValue, builder: (column) => column);
}

class $$CrdtNormalizedDataTableTableTableManager
    extends
        RootTableManager<
          _$CrdtDatabase,
          $CrdtNormalizedDataTableTable,
          CrdtNormalizedDataEntry,
          $$CrdtNormalizedDataTableTableFilterComposer,
          $$CrdtNormalizedDataTableTableOrderingComposer,
          $$CrdtNormalizedDataTableTableAnnotationComposer,
          $$CrdtNormalizedDataTableTableCreateCompanionBuilder,
          $$CrdtNormalizedDataTableTableUpdateCompanionBuilder,
          (
            CrdtNormalizedDataEntry,
            BaseReferences<
              _$CrdtDatabase,
              $CrdtNormalizedDataTableTable,
              CrdtNormalizedDataEntry
            >,
          ),
          CrdtNormalizedDataEntry,
          PrefetchHooks Function()
        > {
  $$CrdtNormalizedDataTableTableTableManager(
    _$CrdtDatabase db,
    $CrdtNormalizedDataTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtNormalizedDataTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CrdtNormalizedDataTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CrdtNormalizedDataTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> tblName = const Value.absent(),
                Value<String> columnName = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<int> hlcTimestamp = const Value.absent(),
                Value<int> hlcCounter = const Value.absent(),
                Value<String> hlcNodeId = const Value.absent(),
                Value<DriftAny?> rawValue = const Value.absent(),
              }) => CrdtNormalizedDataTableCompanion(
                userId: userId,
                tblName: tblName,
                columnName: columnName,
                rowId: rowId,
                hlcTimestamp: hlcTimestamp,
                hlcCounter: hlcCounter,
                hlcNodeId: hlcNodeId,
                rawValue: rawValue,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String tblName,
                required String columnName,
                required String rowId,
                required int hlcTimestamp,
                required int hlcCounter,
                required String hlcNodeId,
                Value<DriftAny?> rawValue = const Value.absent(),
              }) => CrdtNormalizedDataTableCompanion.insert(
                userId: userId,
                tblName: tblName,
                columnName: columnName,
                rowId: rowId,
                hlcTimestamp: hlcTimestamp,
                hlcCounter: hlcCounter,
                hlcNodeId: hlcNodeId,
                rawValue: rawValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrdtNormalizedDataTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtDatabase,
      $CrdtNormalizedDataTableTable,
      CrdtNormalizedDataEntry,
      $$CrdtNormalizedDataTableTableFilterComposer,
      $$CrdtNormalizedDataTableTableOrderingComposer,
      $$CrdtNormalizedDataTableTableAnnotationComposer,
      $$CrdtNormalizedDataTableTableCreateCompanionBuilder,
      $$CrdtNormalizedDataTableTableUpdateCompanionBuilder,
      (
        CrdtNormalizedDataEntry,
        BaseReferences<
          _$CrdtDatabase,
          $CrdtNormalizedDataTableTable,
          CrdtNormalizedDataEntry
        >,
      ),
      CrdtNormalizedDataEntry,
      PrefetchHooks Function()
    >;
typedef $$CrdtControlTableTableCreateCompanionBuilder =
    CrdtControlTableCompanion Function({
      required String userId,
      required String nodeId,
      Value<bool> crdtTriggersOn,
      required int schemaVersion,
      Value<Hlc?> lastSyncHlc,
      Value<Hlc?> lastApplyHlc,
      Value<int> rowid,
    });
typedef $$CrdtControlTableTableUpdateCompanionBuilder =
    CrdtControlTableCompanion Function({
      Value<String> userId,
      Value<String> nodeId,
      Value<bool> crdtTriggersOn,
      Value<int> schemaVersion,
      Value<Hlc?> lastSyncHlc,
      Value<Hlc?> lastApplyHlc,
      Value<int> rowid,
    });

class $$CrdtControlTableTableFilterComposer
    extends Composer<_$CrdtDatabase, $CrdtControlTableTable> {
  $$CrdtControlTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get crdtTriggersOn => $composableBuilder(
    column: $table.crdtTriggersOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Hlc?, Hlc, String> get lastSyncHlc =>
      $composableBuilder(
        column: $table.lastSyncHlc,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Hlc?, Hlc, String> get lastApplyHlc =>
      $composableBuilder(
        column: $table.lastApplyHlc,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$CrdtControlTableTableOrderingComposer
    extends Composer<_$CrdtDatabase, $CrdtControlTableTable> {
  $$CrdtControlTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get crdtTriggersOn => $composableBuilder(
    column: $table.crdtTriggersOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncHlc => $composableBuilder(
    column: $table.lastSyncHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastApplyHlc => $composableBuilder(
    column: $table.lastApplyHlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrdtControlTableTableAnnotationComposer
    extends Composer<_$CrdtDatabase, $CrdtControlTableTable> {
  $$CrdtControlTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<bool> get crdtTriggersOn => $composableBuilder(
    column: $table.crdtTriggersOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Hlc?, String> get lastSyncHlc =>
      $composableBuilder(
        column: $table.lastSyncHlc,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Hlc?, String> get lastApplyHlc =>
      $composableBuilder(
        column: $table.lastApplyHlc,
        builder: (column) => column,
      );
}

class $$CrdtControlTableTableTableManager
    extends
        RootTableManager<
          _$CrdtDatabase,
          $CrdtControlTableTable,
          CrdtControlEntry,
          $$CrdtControlTableTableFilterComposer,
          $$CrdtControlTableTableOrderingComposer,
          $$CrdtControlTableTableAnnotationComposer,
          $$CrdtControlTableTableCreateCompanionBuilder,
          $$CrdtControlTableTableUpdateCompanionBuilder,
          (
            CrdtControlEntry,
            BaseReferences<
              _$CrdtDatabase,
              $CrdtControlTableTable,
              CrdtControlEntry
            >,
          ),
          CrdtControlEntry,
          PrefetchHooks Function()
        > {
  $$CrdtControlTableTableTableManager(
    _$CrdtDatabase db,
    $CrdtControlTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtControlTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrdtControlTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrdtControlTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<bool> crdtTriggersOn = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<Hlc?> lastSyncHlc = const Value.absent(),
                Value<Hlc?> lastApplyHlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CrdtControlTableCompanion(
                userId: userId,
                nodeId: nodeId,
                crdtTriggersOn: crdtTriggersOn,
                schemaVersion: schemaVersion,
                lastSyncHlc: lastSyncHlc,
                lastApplyHlc: lastApplyHlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String nodeId,
                Value<bool> crdtTriggersOn = const Value.absent(),
                required int schemaVersion,
                Value<Hlc?> lastSyncHlc = const Value.absent(),
                Value<Hlc?> lastApplyHlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CrdtControlTableCompanion.insert(
                userId: userId,
                nodeId: nodeId,
                crdtTriggersOn: crdtTriggersOn,
                schemaVersion: schemaVersion,
                lastSyncHlc: lastSyncHlc,
                lastApplyHlc: lastApplyHlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrdtControlTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtDatabase,
      $CrdtControlTableTable,
      CrdtControlEntry,
      $$CrdtControlTableTableFilterComposer,
      $$CrdtControlTableTableOrderingComposer,
      $$CrdtControlTableTableAnnotationComposer,
      $$CrdtControlTableTableCreateCompanionBuilder,
      $$CrdtControlTableTableUpdateCompanionBuilder,
      (
        CrdtControlEntry,
        BaseReferences<
          _$CrdtDatabase,
          $CrdtControlTableTable,
          CrdtControlEntry
        >,
      ),
      CrdtControlEntry,
      PrefetchHooks Function()
    >;
typedef $$CrdtHlcStateTableTableCreateCompanionBuilder =
    CrdtHlcStateTableCompanion Function({
      required String userId,
      required int lastTimestamp,
      required int counter,
      Value<int> rowid,
    });
typedef $$CrdtHlcStateTableTableUpdateCompanionBuilder =
    CrdtHlcStateTableCompanion Function({
      Value<String> userId,
      Value<int> lastTimestamp,
      Value<int> counter,
      Value<int> rowid,
    });

class $$CrdtHlcStateTableTableFilterComposer
    extends Composer<_$CrdtDatabase, $CrdtHlcStateTableTable> {
  $$CrdtHlcStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTimestamp => $composableBuilder(
    column: $table.lastTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CrdtHlcStateTableTableOrderingComposer
    extends Composer<_$CrdtDatabase, $CrdtHlcStateTableTable> {
  $$CrdtHlcStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTimestamp => $composableBuilder(
    column: $table.lastTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrdtHlcStateTableTableAnnotationComposer
    extends Composer<_$CrdtDatabase, $CrdtHlcStateTableTable> {
  $$CrdtHlcStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get lastTimestamp => $composableBuilder(
    column: $table.lastTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get counter =>
      $composableBuilder(column: $table.counter, builder: (column) => column);
}

class $$CrdtHlcStateTableTableTableManager
    extends
        RootTableManager<
          _$CrdtDatabase,
          $CrdtHlcStateTableTable,
          CrdtHlcEntry,
          $$CrdtHlcStateTableTableFilterComposer,
          $$CrdtHlcStateTableTableOrderingComposer,
          $$CrdtHlcStateTableTableAnnotationComposer,
          $$CrdtHlcStateTableTableCreateCompanionBuilder,
          $$CrdtHlcStateTableTableUpdateCompanionBuilder,
          (
            CrdtHlcEntry,
            BaseReferences<
              _$CrdtDatabase,
              $CrdtHlcStateTableTable,
              CrdtHlcEntry
            >,
          ),
          CrdtHlcEntry,
          PrefetchHooks Function()
        > {
  $$CrdtHlcStateTableTableTableManager(
    _$CrdtDatabase db,
    $CrdtHlcStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtHlcStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrdtHlcStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrdtHlcStateTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<int> lastTimestamp = const Value.absent(),
                Value<int> counter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CrdtHlcStateTableCompanion(
                userId: userId,
                lastTimestamp: lastTimestamp,
                counter: counter,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required int lastTimestamp,
                required int counter,
                Value<int> rowid = const Value.absent(),
              }) => CrdtHlcStateTableCompanion.insert(
                userId: userId,
                lastTimestamp: lastTimestamp,
                counter: counter,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrdtHlcStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtDatabase,
      $CrdtHlcStateTableTable,
      CrdtHlcEntry,
      $$CrdtHlcStateTableTableFilterComposer,
      $$CrdtHlcStateTableTableOrderingComposer,
      $$CrdtHlcStateTableTableAnnotationComposer,
      $$CrdtHlcStateTableTableCreateCompanionBuilder,
      $$CrdtHlcStateTableTableUpdateCompanionBuilder,
      (
        CrdtHlcEntry,
        BaseReferences<_$CrdtDatabase, $CrdtHlcStateTableTable, CrdtHlcEntry>,
      ),
      CrdtHlcEntry,
      PrefetchHooks Function()
    >;
typedef $$CrdtMergeHlcTableTableCreateCompanionBuilder =
    CrdtMergeHlcTableCompanion Function({
      required String userId,
      required String nodeId,
      required Hlc lastReceivedHlc,
      Value<int> rowid,
    });
typedef $$CrdtMergeHlcTableTableUpdateCompanionBuilder =
    CrdtMergeHlcTableCompanion Function({
      Value<String> userId,
      Value<String> nodeId,
      Value<Hlc> lastReceivedHlc,
      Value<int> rowid,
    });

class $$CrdtMergeHlcTableTableFilterComposer
    extends Composer<_$CrdtDatabase, $CrdtMergeHlcTableTable> {
  $$CrdtMergeHlcTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Hlc, Hlc, String> get lastReceivedHlc =>
      $composableBuilder(
        column: $table.lastReceivedHlc,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$CrdtMergeHlcTableTableOrderingComposer
    extends Composer<_$CrdtDatabase, $CrdtMergeHlcTableTable> {
  $$CrdtMergeHlcTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReceivedHlc => $composableBuilder(
    column: $table.lastReceivedHlc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrdtMergeHlcTableTableAnnotationComposer
    extends Composer<_$CrdtDatabase, $CrdtMergeHlcTableTable> {
  $$CrdtMergeHlcTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Hlc, String> get lastReceivedHlc =>
      $composableBuilder(
        column: $table.lastReceivedHlc,
        builder: (column) => column,
      );
}

class $$CrdtMergeHlcTableTableTableManager
    extends
        RootTableManager<
          _$CrdtDatabase,
          $CrdtMergeHlcTableTable,
          CrdtMergeHlcEntry,
          $$CrdtMergeHlcTableTableFilterComposer,
          $$CrdtMergeHlcTableTableOrderingComposer,
          $$CrdtMergeHlcTableTableAnnotationComposer,
          $$CrdtMergeHlcTableTableCreateCompanionBuilder,
          $$CrdtMergeHlcTableTableUpdateCompanionBuilder,
          (
            CrdtMergeHlcEntry,
            BaseReferences<
              _$CrdtDatabase,
              $CrdtMergeHlcTableTable,
              CrdtMergeHlcEntry
            >,
          ),
          CrdtMergeHlcEntry,
          PrefetchHooks Function()
        > {
  $$CrdtMergeHlcTableTableTableManager(
    _$CrdtDatabase db,
    $CrdtMergeHlcTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtMergeHlcTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrdtMergeHlcTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrdtMergeHlcTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<Hlc> lastReceivedHlc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CrdtMergeHlcTableCompanion(
                userId: userId,
                nodeId: nodeId,
                lastReceivedHlc: lastReceivedHlc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String nodeId,
                required Hlc lastReceivedHlc,
                Value<int> rowid = const Value.absent(),
              }) => CrdtMergeHlcTableCompanion.insert(
                userId: userId,
                nodeId: nodeId,
                lastReceivedHlc: lastReceivedHlc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrdtMergeHlcTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtDatabase,
      $CrdtMergeHlcTableTable,
      CrdtMergeHlcEntry,
      $$CrdtMergeHlcTableTableFilterComposer,
      $$CrdtMergeHlcTableTableOrderingComposer,
      $$CrdtMergeHlcTableTableAnnotationComposer,
      $$CrdtMergeHlcTableTableCreateCompanionBuilder,
      $$CrdtMergeHlcTableTableUpdateCompanionBuilder,
      (
        CrdtMergeHlcEntry,
        BaseReferences<
          _$CrdtDatabase,
          $CrdtMergeHlcTableTable,
          CrdtMergeHlcEntry
        >,
      ),
      CrdtMergeHlcEntry,
      PrefetchHooks Function()
    >;

class $CrdtDatabaseManager {
  final _$CrdtDatabase _db;
  $CrdtDatabaseManager(this._db);
  $$CrdtDataTableTableTableManager get crdtDataTable =>
      $$CrdtDataTableTableTableManager(_db, _db.crdtDataTable);
  $$CrdtNormalizedDataTableTableTableManager get crdtNormalizedDataTable =>
      $$CrdtNormalizedDataTableTableTableManager(
        _db,
        _db.crdtNormalizedDataTable,
      );
  $$CrdtControlTableTableTableManager get crdtControlTable =>
      $$CrdtControlTableTableTableManager(_db, _db.crdtControlTable);
  $$CrdtHlcStateTableTableTableManager get crdtHlcStateTable =>
      $$CrdtHlcStateTableTableTableManager(_db, _db.crdtHlcStateTable);
  $$CrdtMergeHlcTableTableTableManager get crdtMergeHlcTable =>
      $$CrdtMergeHlcTableTableTableManager(_db, _db.crdtMergeHlcTable);
}
