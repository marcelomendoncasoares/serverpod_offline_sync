import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

export 'package:crdt/crdt.dart' show Hlc;

class _HlcConverter extends TypeConverter<Hlc, String> {
  const _HlcConverter();

  @override
  Hlc fromSql(String fromDb) => Hlc.parse(fromDb);

  @override
  String toSql(Hlc value) => value.toJson();
}

/// Converter for [Hlc] to store it in the database as string.
const hlcConverter = _HlcConverter();

/// Null-aware converter for [Hlc] to handle nullable fields.
const nullableHlcConverter = NullAwareTypeConverter.wrap(hlcConverter);
