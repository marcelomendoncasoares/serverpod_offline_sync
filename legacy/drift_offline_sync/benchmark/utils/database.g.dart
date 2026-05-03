// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TableWithEveryColumnTypeTable extends TableWithEveryColumnType
    with TableInfo<$TableWithEveryColumnTypeTable, TableWithEveryColumnTypeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TableWithEveryColumnTypeTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<RowId, int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  ).withConverter<RowId>($TableWithEveryColumnTypeTable.$converterid);
  static const VerificationMeta _aBoolMeta = const VerificationMeta('aBool');
  @override
  late final GeneratedColumn<bool> aBool = GeneratedColumn<bool>(
    'a_bool',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("a_bool" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
  );
  static const VerificationMeta _aDateTimeMeta = const VerificationMeta(
    'aDateTime',
  );
  @override
  late final GeneratedColumn<DateTime> aDateTime = GeneratedColumn<DateTime>(
    'a_date_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aTextMeta = const VerificationMeta('aText');
  @override
  late final GeneratedColumn<String> aText = GeneratedColumn<String>(
    'a_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anIntMeta = const VerificationMeta('anInt');
  @override
  late final GeneratedColumn<int> anInt = GeneratedColumn<int>(
    'an_int',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anInt64Meta = const VerificationMeta(
    'anInt64',
  );
  @override
  late final GeneratedColumn<BigInt> anInt64 = GeneratedColumn<BigInt>(
    'an_int64',
    aliasedName,
    true,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aRealMeta = const VerificationMeta('aReal');
  @override
  late final GeneratedColumn<double> aReal = GeneratedColumn<double>(
    'a_real',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aBlobMeta = const VerificationMeta('aBlob');
  @override
  late final GeneratedColumn<Uint8List> aBlob = GeneratedColumn<Uint8List>(
    'a_blob',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TodoStatus?, int> anIntEnum =
      GeneratedColumn<int>(
        'an_int_enum',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<TodoStatus?>(
        $TableWithEveryColumnTypeTable.$converteranIntEnumn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<MyCustomObject?, String>
  aTextWithConverter =
      GeneratedColumn<String>(
        'insert',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<MyCustomObject?>(
        $TableWithEveryColumnTypeTable.$converteraTextWithConvertern,
      );
  static const VerificationMeta _aUuidMeta = const VerificationMeta('aUuid');
  @override
  late final GeneratedColumn<UuidValue> aUuid = GeneratedColumn<UuidValue>(
    'a_uuid',
    aliasedName,
    true,
    type: uuidType,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    aBool,
    aDateTime,
    aText,
    anInt,
    anInt64,
    aReal,
    aBlob,
    anIntEnum,
    aTextWithConverter,
    aUuid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'table_with_every_column_type';
  @override
  VerificationContext validateIntegrity(
    Insertable<TableWithEveryColumnTypeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('a_bool')) {
      context.handle(
        _aBoolMeta,
        aBool.isAcceptableOrUnknown(data['a_bool']!, _aBoolMeta),
      );
    }
    if (data.containsKey('a_date_time')) {
      context.handle(
        _aDateTimeMeta,
        aDateTime.isAcceptableOrUnknown(data['a_date_time']!, _aDateTimeMeta),
      );
    }
    if (data.containsKey('a_text')) {
      context.handle(
        _aTextMeta,
        aText.isAcceptableOrUnknown(data['a_text']!, _aTextMeta),
      );
    }
    if (data.containsKey('an_int')) {
      context.handle(
        _anIntMeta,
        anInt.isAcceptableOrUnknown(data['an_int']!, _anIntMeta),
      );
    }
    if (data.containsKey('an_int64')) {
      context.handle(
        _anInt64Meta,
        anInt64.isAcceptableOrUnknown(data['an_int64']!, _anInt64Meta),
      );
    }
    if (data.containsKey('a_real')) {
      context.handle(
        _aRealMeta,
        aReal.isAcceptableOrUnknown(data['a_real']!, _aRealMeta),
      );
    }
    if (data.containsKey('a_blob')) {
      context.handle(
        _aBlobMeta,
        aBlob.isAcceptableOrUnknown(data['a_blob']!, _aBlobMeta),
      );
    }
    if (data.containsKey('a_uuid')) {
      context.handle(
        _aUuidMeta,
        aUuid.isAcceptableOrUnknown(data['a_uuid']!, _aUuidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TableWithEveryColumnTypeData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TableWithEveryColumnTypeData(
      id: $TableWithEveryColumnTypeTable.$converterid.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}id'],
        )!,
      ),
      aBool: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}a_bool'],
      ),
      aDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}a_date_time'],
      ),
      aText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a_text'],
      ),
      anInt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}an_int'],
      ),
      anInt64: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}an_int64'],
      ),
      aReal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a_real'],
      ),
      aBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}a_blob'],
      ),
      anIntEnum: $TableWithEveryColumnTypeTable.$converteranIntEnumn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}an_int_enum'],
        ),
      ),
      aTextWithConverter: $TableWithEveryColumnTypeTable.$converteraTextWithConvertern
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}insert'],
            ),
          ),
      aUuid: attachedDatabase.typeMapping.read(
        uuidType,
        data['${effectivePrefix}a_uuid'],
      ),
    );
  }

  @override
  $TableWithEveryColumnTypeTable createAlias(String alias) {
    return $TableWithEveryColumnTypeTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RowId, int, int> $converterid =
      TypeConverter.extensionType<RowId, int>();
  static JsonTypeConverter2<TodoStatus, int, int> $converteranIntEnum =
      const EnumIndexConverter<TodoStatus>(TodoStatus.values);
  static JsonTypeConverter2<TodoStatus?, int?, int?> $converteranIntEnumn =
      JsonTypeConverter2.asNullable($converteranIntEnum);
  static JsonTypeConverter2<MyCustomObject, String, Map<dynamic, dynamic>>
  $converteraTextWithConverter = const CustomJsonConverter();
  static JsonTypeConverter2<MyCustomObject?, String?, Map<dynamic, dynamic>?>
  $converteraTextWithConvertern = JsonTypeConverter2.asNullable(
    $converteraTextWithConverter,
  );
}

class TableWithEveryColumnTypeData extends DataClass
    implements Insertable<TableWithEveryColumnTypeData> {
  final RowId id;
  final bool? aBool;
  final DateTime? aDateTime;
  final String? aText;
  final int? anInt;
  final BigInt? anInt64;
  final double? aReal;
  final Uint8List? aBlob;
  final TodoStatus? anIntEnum;
  final MyCustomObject? aTextWithConverter;
  final UuidValue? aUuid;
  const TableWithEveryColumnTypeData({
    required this.id,
    this.aBool,
    this.aDateTime,
    this.aText,
    this.anInt,
    this.anInt64,
    this.aReal,
    this.aBlob,
    this.anIntEnum,
    this.aTextWithConverter,
    this.aUuid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['id'] = Variable<int>(
        $TableWithEveryColumnTypeTable.$converterid.toSql(id),
      );
    }
    if (!nullToAbsent || aBool != null) {
      map['a_bool'] = Variable<bool>(aBool);
    }
    if (!nullToAbsent || aDateTime != null) {
      map['a_date_time'] = Variable<DateTime>(aDateTime);
    }
    if (!nullToAbsent || aText != null) {
      map['a_text'] = Variable<String>(aText);
    }
    if (!nullToAbsent || anInt != null) {
      map['an_int'] = Variable<int>(anInt);
    }
    if (!nullToAbsent || anInt64 != null) {
      map['an_int64'] = Variable<BigInt>(anInt64);
    }
    if (!nullToAbsent || aReal != null) {
      map['a_real'] = Variable<double>(aReal);
    }
    if (!nullToAbsent || aBlob != null) {
      map['a_blob'] = Variable<Uint8List>(aBlob);
    }
    if (!nullToAbsent || anIntEnum != null) {
      map['an_int_enum'] = Variable<int>(
        $TableWithEveryColumnTypeTable.$converteranIntEnumn.toSql(anIntEnum),
      );
    }
    if (!nullToAbsent || aTextWithConverter != null) {
      map['insert'] = Variable<String>(
        $TableWithEveryColumnTypeTable.$converteraTextWithConvertern.toSql(
          aTextWithConverter,
        ),
      );
    }
    if (!nullToAbsent || aUuid != null) {
      map['a_uuid'] = Variable<UuidValue>(aUuid, uuidType);
    }
    return map;
  }

  TableWithEveryColumnTypeCompanion toCompanion(bool nullToAbsent) {
    return TableWithEveryColumnTypeCompanion(
      id: Value(id),
      aBool: aBool == null && nullToAbsent ? const Value.absent() : Value(aBool),
      aDateTime: aDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(aDateTime),
      aText: aText == null && nullToAbsent ? const Value.absent() : Value(aText),
      anInt: anInt == null && nullToAbsent ? const Value.absent() : Value(anInt),
      anInt64: anInt64 == null && nullToAbsent ? const Value.absent() : Value(anInt64),
      aReal: aReal == null && nullToAbsent ? const Value.absent() : Value(aReal),
      aBlob: aBlob == null && nullToAbsent ? const Value.absent() : Value(aBlob),
      anIntEnum: anIntEnum == null && nullToAbsent
          ? const Value.absent()
          : Value(anIntEnum),
      aTextWithConverter: aTextWithConverter == null && nullToAbsent
          ? const Value.absent()
          : Value(aTextWithConverter),
      aUuid: aUuid == null && nullToAbsent ? const Value.absent() : Value(aUuid),
    );
  }

  factory TableWithEveryColumnTypeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TableWithEveryColumnTypeData(
      id: $TableWithEveryColumnTypeTable.$converterid.fromJson(
        serializer.fromJson<int>(json['id']),
      ),
      aBool: serializer.fromJson<bool?>(json['a_bool']),
      aDateTime: serializer.fromJson<DateTime?>(json['a_date_time']),
      aText: serializer.fromJson<String?>(json['a_text']),
      anInt: serializer.fromJson<int?>(json['an_int']),
      anInt64: serializer.fromJson<BigInt?>(json['an_int64']),
      aReal: serializer.fromJson<double?>(json['a_real']),
      aBlob: serializer.fromJson<Uint8List?>(json['a_blob']),
      anIntEnum: $TableWithEveryColumnTypeTable.$converteranIntEnumn.fromJson(
        serializer.fromJson<int?>(json['an_int_enum']),
      ),
      aTextWithConverter: $TableWithEveryColumnTypeTable.$converteraTextWithConvertern
          .fromJson(
            serializer.fromJson<Map<dynamic, dynamic>?>(json['insert']),
          ),
      aUuid: serializer.fromJson<UuidValue?>(json['a_uuid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(
        $TableWithEveryColumnTypeTable.$converterid.toJson(id),
      ),
      'a_bool': serializer.toJson<bool?>(aBool),
      'a_date_time': serializer.toJson<DateTime?>(aDateTime),
      'a_text': serializer.toJson<String?>(aText),
      'an_int': serializer.toJson<int?>(anInt),
      'an_int64': serializer.toJson<BigInt?>(anInt64),
      'a_real': serializer.toJson<double?>(aReal),
      'a_blob': serializer.toJson<Uint8List?>(aBlob),
      'an_int_enum': serializer.toJson<int?>(
        $TableWithEveryColumnTypeTable.$converteranIntEnumn.toJson(anIntEnum),
      ),
      'insert': serializer.toJson<Map<dynamic, dynamic>?>(
        $TableWithEveryColumnTypeTable.$converteraTextWithConvertern.toJson(
          aTextWithConverter,
        ),
      ),
      'a_uuid': serializer.toJson<UuidValue?>(aUuid),
    };
  }

  TableWithEveryColumnTypeData copyWith({
    RowId? id,
    Value<bool?> aBool = const Value.absent(),
    Value<DateTime?> aDateTime = const Value.absent(),
    Value<String?> aText = const Value.absent(),
    Value<int?> anInt = const Value.absent(),
    Value<BigInt?> anInt64 = const Value.absent(),
    Value<double?> aReal = const Value.absent(),
    Value<Uint8List?> aBlob = const Value.absent(),
    Value<TodoStatus?> anIntEnum = const Value.absent(),
    Value<MyCustomObject?> aTextWithConverter = const Value.absent(),
    Value<UuidValue?> aUuid = const Value.absent(),
  }) => TableWithEveryColumnTypeData(
    id: id ?? this.id,
    aBool: aBool.present ? aBool.value : this.aBool,
    aDateTime: aDateTime.present ? aDateTime.value : this.aDateTime,
    aText: aText.present ? aText.value : this.aText,
    anInt: anInt.present ? anInt.value : this.anInt,
    anInt64: anInt64.present ? anInt64.value : this.anInt64,
    aReal: aReal.present ? aReal.value : this.aReal,
    aBlob: aBlob.present ? aBlob.value : this.aBlob,
    anIntEnum: anIntEnum.present ? anIntEnum.value : this.anIntEnum,
    aTextWithConverter: aTextWithConverter.present
        ? aTextWithConverter.value
        : this.aTextWithConverter,
    aUuid: aUuid.present ? aUuid.value : this.aUuid,
  );
  TableWithEveryColumnTypeData copyWithCompanion(
    TableWithEveryColumnTypeCompanion data,
  ) {
    return TableWithEveryColumnTypeData(
      id: data.id.present ? data.id.value : this.id,
      aBool: data.aBool.present ? data.aBool.value : this.aBool,
      aDateTime: data.aDateTime.present ? data.aDateTime.value : this.aDateTime,
      aText: data.aText.present ? data.aText.value : this.aText,
      anInt: data.anInt.present ? data.anInt.value : this.anInt,
      anInt64: data.anInt64.present ? data.anInt64.value : this.anInt64,
      aReal: data.aReal.present ? data.aReal.value : this.aReal,
      aBlob: data.aBlob.present ? data.aBlob.value : this.aBlob,
      anIntEnum: data.anIntEnum.present ? data.anIntEnum.value : this.anIntEnum,
      aTextWithConverter: data.aTextWithConverter.present
          ? data.aTextWithConverter.value
          : this.aTextWithConverter,
      aUuid: data.aUuid.present ? data.aUuid.value : this.aUuid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TableWithEveryColumnTypeData(')
          ..write('id: $id, ')
          ..write('aBool: $aBool, ')
          ..write('aDateTime: $aDateTime, ')
          ..write('aText: $aText, ')
          ..write('anInt: $anInt, ')
          ..write('anInt64: $anInt64, ')
          ..write('aReal: $aReal, ')
          ..write('aBlob: $aBlob, ')
          ..write('anIntEnum: $anIntEnum, ')
          ..write('aTextWithConverter: $aTextWithConverter, ')
          ..write('aUuid: $aUuid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    aBool,
    aDateTime,
    aText,
    anInt,
    anInt64,
    aReal,
    $driftBlobEquality.hash(aBlob),
    anIntEnum,
    aTextWithConverter,
    aUuid,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TableWithEveryColumnTypeData &&
          other.id == this.id &&
          other.aBool == this.aBool &&
          other.aDateTime == this.aDateTime &&
          other.aText == this.aText &&
          other.anInt == this.anInt &&
          other.anInt64 == this.anInt64 &&
          other.aReal == this.aReal &&
          $driftBlobEquality.equals(other.aBlob, this.aBlob) &&
          other.anIntEnum == this.anIntEnum &&
          other.aTextWithConverter == this.aTextWithConverter &&
          other.aUuid == this.aUuid);
}

class TableWithEveryColumnTypeCompanion
    extends UpdateCompanion<TableWithEveryColumnTypeData> {
  final Value<RowId> id;
  final Value<bool?> aBool;
  final Value<DateTime?> aDateTime;
  final Value<String?> aText;
  final Value<int?> anInt;
  final Value<BigInt?> anInt64;
  final Value<double?> aReal;
  final Value<Uint8List?> aBlob;
  final Value<TodoStatus?> anIntEnum;
  final Value<MyCustomObject?> aTextWithConverter;
  final Value<UuidValue?> aUuid;
  const TableWithEveryColumnTypeCompanion({
    this.id = const Value.absent(),
    this.aBool = const Value.absent(),
    this.aDateTime = const Value.absent(),
    this.aText = const Value.absent(),
    this.anInt = const Value.absent(),
    this.anInt64 = const Value.absent(),
    this.aReal = const Value.absent(),
    this.aBlob = const Value.absent(),
    this.anIntEnum = const Value.absent(),
    this.aTextWithConverter = const Value.absent(),
    this.aUuid = const Value.absent(),
  });
  TableWithEveryColumnTypeCompanion.insert({
    this.id = const Value.absent(),
    this.aBool = const Value.absent(),
    this.aDateTime = const Value.absent(),
    this.aText = const Value.absent(),
    this.anInt = const Value.absent(),
    this.anInt64 = const Value.absent(),
    this.aReal = const Value.absent(),
    this.aBlob = const Value.absent(),
    this.anIntEnum = const Value.absent(),
    this.aTextWithConverter = const Value.absent(),
    this.aUuid = const Value.absent(),
  });
  static Insertable<TableWithEveryColumnTypeData> custom({
    Expression<int>? id,
    Expression<bool>? aBool,
    Expression<DateTime>? aDateTime,
    Expression<String>? aText,
    Expression<int>? anInt,
    Expression<BigInt>? anInt64,
    Expression<double>? aReal,
    Expression<Uint8List>? aBlob,
    Expression<int>? anIntEnum,
    Expression<String>? aTextWithConverter,
    Expression<UuidValue>? aUuid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (aBool != null) 'a_bool': aBool,
      if (aDateTime != null) 'a_date_time': aDateTime,
      if (aText != null) 'a_text': aText,
      if (anInt != null) 'an_int': anInt,
      if (anInt64 != null) 'an_int64': anInt64,
      if (aReal != null) 'a_real': aReal,
      if (aBlob != null) 'a_blob': aBlob,
      if (anIntEnum != null) 'an_int_enum': anIntEnum,
      if (aTextWithConverter != null) 'insert': aTextWithConverter,
      if (aUuid != null) 'a_uuid': aUuid,
    });
  }

  TableWithEveryColumnTypeCompanion copyWith({
    Value<RowId>? id,
    Value<bool?>? aBool,
    Value<DateTime?>? aDateTime,
    Value<String?>? aText,
    Value<int?>? anInt,
    Value<BigInt?>? anInt64,
    Value<double?>? aReal,
    Value<Uint8List?>? aBlob,
    Value<TodoStatus?>? anIntEnum,
    Value<MyCustomObject?>? aTextWithConverter,
    Value<UuidValue?>? aUuid,
  }) {
    return TableWithEveryColumnTypeCompanion(
      id: id ?? this.id,
      aBool: aBool ?? this.aBool,
      aDateTime: aDateTime ?? this.aDateTime,
      aText: aText ?? this.aText,
      anInt: anInt ?? this.anInt,
      anInt64: anInt64 ?? this.anInt64,
      aReal: aReal ?? this.aReal,
      aBlob: aBlob ?? this.aBlob,
      anIntEnum: anIntEnum ?? this.anIntEnum,
      aTextWithConverter: aTextWithConverter ?? this.aTextWithConverter,
      aUuid: aUuid ?? this.aUuid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(
        $TableWithEveryColumnTypeTable.$converterid.toSql(id.value),
      );
    }
    if (aBool.present) {
      map['a_bool'] = Variable<bool>(aBool.value);
    }
    if (aDateTime.present) {
      map['a_date_time'] = Variable<DateTime>(aDateTime.value);
    }
    if (aText.present) {
      map['a_text'] = Variable<String>(aText.value);
    }
    if (anInt.present) {
      map['an_int'] = Variable<int>(anInt.value);
    }
    if (anInt64.present) {
      map['an_int64'] = Variable<BigInt>(anInt64.value);
    }
    if (aReal.present) {
      map['a_real'] = Variable<double>(aReal.value);
    }
    if (aBlob.present) {
      map['a_blob'] = Variable<Uint8List>(aBlob.value);
    }
    if (anIntEnum.present) {
      map['an_int_enum'] = Variable<int>(
        $TableWithEveryColumnTypeTable.$converteranIntEnumn.toSql(
          anIntEnum.value,
        ),
      );
    }
    if (aTextWithConverter.present) {
      map['insert'] = Variable<String>(
        $TableWithEveryColumnTypeTable.$converteraTextWithConvertern.toSql(
          aTextWithConverter.value,
        ),
      );
    }
    if (aUuid.present) {
      map['a_uuid'] = Variable<UuidValue>(aUuid.value, uuidType);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TableWithEveryColumnTypeCompanion(')
          ..write('id: $id, ')
          ..write('aBool: $aBool, ')
          ..write('aDateTime: $aDateTime, ')
          ..write('aText: $aText, ')
          ..write('anInt: $anInt, ')
          ..write('anInt64: $anInt64, ')
          ..write('aReal: $aReal, ')
          ..write('aBlob: $aBlob, ')
          ..write('anIntEnum: $anIntEnum, ')
          ..write('aTextWithConverter: $aTextWithConverter, ')
          ..write('aUuid: $aUuid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CrdtBenchmarkDatabase extends GeneratedDatabase {
  _$CrdtBenchmarkDatabase(QueryExecutor e) : super(e);
  $CrdtBenchmarkDatabaseManager get managers => $CrdtBenchmarkDatabaseManager(this);
  late final $TableWithEveryColumnTypeTable tableWithEveryColumnType =
      $TableWithEveryColumnTypeTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tableWithEveryColumnType,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$TableWithEveryColumnTypeTableCreateCompanionBuilder =
    TableWithEveryColumnTypeCompanion Function({
      Value<RowId> id,
      Value<bool?> aBool,
      Value<DateTime?> aDateTime,
      Value<String?> aText,
      Value<int?> anInt,
      Value<BigInt?> anInt64,
      Value<double?> aReal,
      Value<Uint8List?> aBlob,
      Value<TodoStatus?> anIntEnum,
      Value<MyCustomObject?> aTextWithConverter,
      Value<UuidValue?> aUuid,
    });
typedef $$TableWithEveryColumnTypeTableUpdateCompanionBuilder =
    TableWithEveryColumnTypeCompanion Function({
      Value<RowId> id,
      Value<bool?> aBool,
      Value<DateTime?> aDateTime,
      Value<String?> aText,
      Value<int?> anInt,
      Value<BigInt?> anInt64,
      Value<double?> aReal,
      Value<Uint8List?> aBlob,
      Value<TodoStatus?> anIntEnum,
      Value<MyCustomObject?> aTextWithConverter,
      Value<UuidValue?> aUuid,
    });

class $$TableWithEveryColumnTypeTableFilterComposer
    extends Composer<_$CrdtBenchmarkDatabase, $TableWithEveryColumnTypeTable> {
  $$TableWithEveryColumnTypeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<RowId, RowId, int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get aBool => $composableBuilder(
    column: $table.aBool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get aDateTime => $composableBuilder(
    column: $table.aDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aText => $composableBuilder(
    column: $table.aText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anInt => $composableBuilder(
    column: $table.anInt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get anInt64 => $composableBuilder(
    column: $table.anInt64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aReal => $composableBuilder(
    column: $table.aReal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get aBlob => $composableBuilder(
    column: $table.aBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TodoStatus?, TodoStatus, int> get anIntEnum =>
      $composableBuilder(
        column: $table.anIntEnum,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MyCustomObject?, MyCustomObject, String>
  get aTextWithConverter => $composableBuilder(
    column: $table.aTextWithConverter,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<UuidValue> get aUuid => $composableBuilder(
    column: $table.aUuid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TableWithEveryColumnTypeTableOrderingComposer
    extends Composer<_$CrdtBenchmarkDatabase, $TableWithEveryColumnTypeTable> {
  $$TableWithEveryColumnTypeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aBool => $composableBuilder(
    column: $table.aBool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get aDateTime => $composableBuilder(
    column: $table.aDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aText => $composableBuilder(
    column: $table.aText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anInt => $composableBuilder(
    column: $table.anInt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get anInt64 => $composableBuilder(
    column: $table.anInt64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aReal => $composableBuilder(
    column: $table.aReal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get aBlob => $composableBuilder(
    column: $table.aBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anIntEnum => $composableBuilder(
    column: $table.anIntEnum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aTextWithConverter => $composableBuilder(
    column: $table.aTextWithConverter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<UuidValue> get aUuid => $composableBuilder(
    column: $table.aUuid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TableWithEveryColumnTypeTableAnnotationComposer
    extends Composer<_$CrdtBenchmarkDatabase, $TableWithEveryColumnTypeTable> {
  $$TableWithEveryColumnTypeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<RowId, int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get aBool =>
      $composableBuilder(column: $table.aBool, builder: (column) => column);

  GeneratedColumn<DateTime> get aDateTime =>
      $composableBuilder(column: $table.aDateTime, builder: (column) => column);

  GeneratedColumn<String> get aText =>
      $composableBuilder(column: $table.aText, builder: (column) => column);

  GeneratedColumn<int> get anInt =>
      $composableBuilder(column: $table.anInt, builder: (column) => column);

  GeneratedColumn<BigInt> get anInt64 =>
      $composableBuilder(column: $table.anInt64, builder: (column) => column);

  GeneratedColumn<double> get aReal =>
      $composableBuilder(column: $table.aReal, builder: (column) => column);

  GeneratedColumn<Uint8List> get aBlob =>
      $composableBuilder(column: $table.aBlob, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TodoStatus?, int> get anIntEnum =>
      $composableBuilder(column: $table.anIntEnum, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MyCustomObject?, String> get aTextWithConverter =>
      $composableBuilder(
        column: $table.aTextWithConverter,
        builder: (column) => column,
      );

  GeneratedColumn<UuidValue> get aUuid =>
      $composableBuilder(column: $table.aUuid, builder: (column) => column);
}

class $$TableWithEveryColumnTypeTableTableManager
    extends
        RootTableManager<
          _$CrdtBenchmarkDatabase,
          $TableWithEveryColumnTypeTable,
          TableWithEveryColumnTypeData,
          $$TableWithEveryColumnTypeTableFilterComposer,
          $$TableWithEveryColumnTypeTableOrderingComposer,
          $$TableWithEveryColumnTypeTableAnnotationComposer,
          $$TableWithEveryColumnTypeTableCreateCompanionBuilder,
          $$TableWithEveryColumnTypeTableUpdateCompanionBuilder,
          (
            TableWithEveryColumnTypeData,
            BaseReferences<
              _$CrdtBenchmarkDatabase,
              $TableWithEveryColumnTypeTable,
              TableWithEveryColumnTypeData
            >,
          ),
          TableWithEveryColumnTypeData,
          PrefetchHooks Function()
        > {
  $$TableWithEveryColumnTypeTableTableManager(
    _$CrdtBenchmarkDatabase db,
    $TableWithEveryColumnTypeTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TableWithEveryColumnTypeTableFilterComposer(
            $db: db,
            $table: table,
          ),
          createOrderingComposer: () => $$TableWithEveryColumnTypeTableOrderingComposer(
            $db: db,
            $table: table,
          ),
          createComputedFieldComposer: () =>
              $$TableWithEveryColumnTypeTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<bool?> aBool = const Value.absent(),
                Value<DateTime?> aDateTime = const Value.absent(),
                Value<String?> aText = const Value.absent(),
                Value<int?> anInt = const Value.absent(),
                Value<BigInt?> anInt64 = const Value.absent(),
                Value<double?> aReal = const Value.absent(),
                Value<Uint8List?> aBlob = const Value.absent(),
                Value<TodoStatus?> anIntEnum = const Value.absent(),
                Value<MyCustomObject?> aTextWithConverter = const Value.absent(),
                Value<UuidValue?> aUuid = const Value.absent(),
              }) => TableWithEveryColumnTypeCompanion(
                id: id,
                aBool: aBool,
                aDateTime: aDateTime,
                aText: aText,
                anInt: anInt,
                anInt64: anInt64,
                aReal: aReal,
                aBlob: aBlob,
                anIntEnum: anIntEnum,
                aTextWithConverter: aTextWithConverter,
                aUuid: aUuid,
              ),
          createCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<bool?> aBool = const Value.absent(),
                Value<DateTime?> aDateTime = const Value.absent(),
                Value<String?> aText = const Value.absent(),
                Value<int?> anInt = const Value.absent(),
                Value<BigInt?> anInt64 = const Value.absent(),
                Value<double?> aReal = const Value.absent(),
                Value<Uint8List?> aBlob = const Value.absent(),
                Value<TodoStatus?> anIntEnum = const Value.absent(),
                Value<MyCustomObject?> aTextWithConverter = const Value.absent(),
                Value<UuidValue?> aUuid = const Value.absent(),
              }) => TableWithEveryColumnTypeCompanion.insert(
                id: id,
                aBool: aBool,
                aDateTime: aDateTime,
                aText: aText,
                anInt: anInt,
                anInt64: anInt64,
                aReal: aReal,
                aBlob: aBlob,
                anIntEnum: anIntEnum,
                aTextWithConverter: aTextWithConverter,
                aUuid: aUuid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TableWithEveryColumnTypeTableProcessedTableManager =
    ProcessedTableManager<
      _$CrdtBenchmarkDatabase,
      $TableWithEveryColumnTypeTable,
      TableWithEveryColumnTypeData,
      $$TableWithEveryColumnTypeTableFilterComposer,
      $$TableWithEveryColumnTypeTableOrderingComposer,
      $$TableWithEveryColumnTypeTableAnnotationComposer,
      $$TableWithEveryColumnTypeTableCreateCompanionBuilder,
      $$TableWithEveryColumnTypeTableUpdateCompanionBuilder,
      (
        TableWithEveryColumnTypeData,
        BaseReferences<
          _$CrdtBenchmarkDatabase,
          $TableWithEveryColumnTypeTable,
          TableWithEveryColumnTypeData
        >,
      ),
      TableWithEveryColumnTypeData,
      PrefetchHooks Function()
    >;

class $CrdtBenchmarkDatabaseManager {
  final _$CrdtBenchmarkDatabase _db;
  $CrdtBenchmarkDatabaseManager(this._db);
  $$TableWithEveryColumnTypeTableTableManager get tableWithEveryColumnType =>
      $$TableWithEveryColumnTypeTableTableManager(
        _db,
        _db.tableWithEveryColumnType,
      );
}
