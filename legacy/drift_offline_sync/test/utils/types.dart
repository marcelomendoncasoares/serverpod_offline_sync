import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

export 'package:uuid/uuid.dart' show UuidValue;

class CustomRowClass {
  CustomRowClass._(
    this.notReallyAnId,
    this.anotherName,
    this.webSafeInt,
    this.custom,
    this.notFromDb,
  );

  factory CustomRowClass.map(
    int notReallyAnId,
    double someFloat, {
    required MyCustomObject custom,
    BigInt? webSafeInt,
    String? notFromDb,
  }) {
    return CustomRowClass._(notReallyAnId, someFloat, webSafeInt, custom, notFromDb);
  }
  final int notReallyAnId;
  final double anotherName;
  final BigInt? webSafeInt;
  final MyCustomObject custom;

  final String? notFromDb;

  double get someFloat => anotherName;
}

// example object used for custom mapping
class MyCustomObject {
  MyCustomObject(this.data);
  final String data;

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) {
    return other is MyCustomObject && other.data == data;
  }
}

class CustomConverter extends TypeConverter<MyCustomObject, String> {
  const CustomConverter();

  @override
  MyCustomObject fromSql(String fromDb) {
    return MyCustomObject(fromDb);
  }

  @override
  String toSql(MyCustomObject value) {
    return value.data;
  }
}

class CustomJsonConverter extends CustomConverter
    with JsonTypeConverter2<MyCustomObject, String, Map> {
  const CustomJsonConverter();

  @override
  MyCustomObject fromJson(Map json) {
    return MyCustomObject(json['data'] as String);
  }

  @override
  Map toJson(MyCustomObject value) {
    return {'data': value.data};
  }
}

class NativeUuidType implements CustomSqlType<UuidValue> {
  const NativeUuidType();

  @override
  String mapToSqlLiteral(UuidValue dartValue) {
    return "'$dartValue'";
  }

  @override
  Object mapToSqlParameter(UuidValue dartValue) {
    return dartValue;
  }

  @override
  UuidValue read(Object fromSql) {
    return fromSql as UuidValue;
  }

  @override
  String sqlTypeName(GenerationContext context) => 'uuid';
}

class _UuidAsTextType implements CustomSqlType<UuidValue> {
  const _UuidAsTextType();

  @override
  String mapToSqlLiteral(UuidValue dartValue) {
    return "'$dartValue'";
  }

  @override
  Object mapToSqlParameter(UuidValue dartValue) {
    return dartValue.toString();
  }

  @override
  UuidValue read(Object fromSql) {
    return UuidValue.fromString(fromSql as String);
  }

  @override
  String sqlTypeName(GenerationContext context) => 'text';
}

const uuidType = DialectAwareSqlType<UuidValue>.via(
  fallback: _UuidAsTextType(),
  overrides: {SqlDialect.postgres: NativeUuidType()},
);
