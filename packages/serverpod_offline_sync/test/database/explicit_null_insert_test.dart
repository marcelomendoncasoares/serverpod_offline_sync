import 'dart:io';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync/src/database/merge_utils/database_helpers.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late ClientDatabaseSession session;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('explicit_null_insert_');
    session = await ClientDatabaseSession.open(
      '${directory.path}/test.db',
      _Serialization(),
      runMigrations: false,
    );
    await session.db.unsafeExecute('''
      CREATE TABLE batch_rows (
        id BLOB PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        value TEXT DEFAULT 'database default'
      ) STRICT
    ''');
  });

  tearDown(() async {
    await session.close();
    await directory.delete(recursive: true);
  });

  group('Given rows alternating projected nulls and database defaults,', () {
    late List<_Row> inputs;
    late Map<UuidValue, Set<String>> explicitNulls;

    setUp(() {
      inputs = [
        _Row(name: 'first null'),
        _Row(name: 'first default'),
        _Row(name: 'second null'),
        _Row(name: 'second default'),
        _Row(name: 'third null'),
      ];
      explicitNulls = {
        inputs[0].id!: {'value'},
        inputs[2].id!: {'value'},
        inputs[4].id!: {'value'},
      };
    });

    group('when inserting them in one SQLite operation,', () {
      late List<_Row> returned;
      late Map<UuidValue?, String?> persisted;

      setUp(() async {
        returned = await session.db.transaction(
          (tx) => insertWithExplicitNulls(
            session.db,
            inputs,
            explicitNulls: explicitNulls,
            transaction: tx,
          ),
        );
        persisted = {
          for (final row in await session.db.find<_Row>()) row.id: row.value,
        };
      });

      test('then every row retains its own null or default semantics.', () {
        expect(persisted, {
          inputs[0].id: null,
          inputs[1].id: 'database default',
          inputs[2].id: null,
          inputs[3].id: 'database default',
          inputs[4].id: null,
        });
      });

      test('then returned rows preserve the input order and resolved values.', () {
        expect(returned.map((row) => (row.id, row.name, row.value)), [
          (inputs[0].id, 'first null', null),
          (inputs[1].id, 'first default', 'database default'),
          (inputs[2].id, 'second null', null),
          (inputs[3].id, 'second default', 'database default'),
          (inputs[4].id, 'third null', null),
        ]);
      });
    });

    test(
      'when inserting without returned rows, '
      'then all nulls and defaults are still persisted.',
      () async {
        final returned = await session.db.transaction(
          (tx) => insertWithExplicitNulls(
            session.db,
            inputs,
            explicitNulls: explicitNulls,
            transaction: tx,
            noReturn: true,
          ),
        );
        final stored = await session.db.find<_Row>();

        expect(returned, isEmpty);
        expect(
          {for (final row in stored) row.id: row.value},
          {
            inputs[0].id: null,
            inputs[1].id: 'database default',
            inputs[2].id: null,
            inputs[3].id: 'database default',
            inputs[4].id: null,
          },
        );
      },
    );
  });

  group('Given a defaulted insert followed by competing projected-null inserts,', () {
    late _Row first;
    late _Row middle;
    late _Row conflicting;
    late List<_Row> inputs;
    late Map<UuidValue, Set<String>> explicitNulls;

    setUp(() {
      first = _Row(name: 'contested');
      middle = _Row(name: 'middle');
      conflicting = _Row(name: 'contested');
      inputs = [first, middle, conflicting];
      explicitNulls = {
        middle.id!: {'value'},
        conflicting.id!: {'value'},
      };
    });

    test(
      'when ignoring conflicts, '
      'then the first claim wins and only accepted rows are returned in order.',
      () async {
        final returned = await session.db.transaction(
          (tx) => insertWithExplicitNulls(
            session.db,
            inputs,
            explicitNulls: explicitNulls,
            transaction: tx,
            ignoreConflicts: true,
          ),
        );
        final stored = await session.db.find<_Row>();

        expect(returned.map((row) => (row.id, row.value)), [
          (first.id, 'database default'),
          (middle.id, null),
        ]);
        expect(
          {for (final row in stored) row.id: row.value},
          {
            first.id: 'database default',
            middle.id: null,
          },
        );
      },
    );

    test(
      'when ignoring conflicts without returned rows, '
      'then the same first claim wins and the result is empty.',
      () async {
        final returned = await session.db.transaction(
          (tx) => insertWithExplicitNulls(
            session.db,
            inputs,
            explicitNulls: explicitNulls,
            transaction: tx,
            ignoreConflicts: true,
            noReturn: true,
          ),
        );
        final stored = await session.db.find<_Row>();

        expect(returned, isEmpty);
        expect(
          {for (final row in stored) row.id: row.value},
          {
            first.id: 'database default',
            middle.id: null,
          },
        );
      },
    );

    test(
      'when the duplicate claim fails the transaction, '
      'then no earlier row remains persisted.',
      () async {
        final inserting = session.db.transaction(
          (tx) => insertWithExplicitNulls(
            session.db,
            inputs,
            explicitNulls: explicitNulls,
            transaction: tx,
          ),
        );

        await expectLater(inserting, throwsA(isA<DatabaseUniqueViolationException>()));
        expect(await session.db.find<_Row>(), isEmpty);
      },
    );
  });
}

class _Row implements TableRow<UuidValue?> {
  _Row({required this.name, UuidValue? id, this.value})
    : id = id ?? const Uuid().v7obj();

  @override
  final UuidValue? id;

  final String name;
  final String? value;

  @override
  Table<UuidValue?> get table => _Table();

  @override
  Map<String, dynamic> toJson() => {
    '__className__': 'BatchRow',
    'id': id?.toJson(),
    'name': name,
    'value': value,
  };
}

class _Table extends Table<UuidValue?> {
  _Table() : super(tableName: 'batch_rows');

  late final name = ColumnString('name', this);
  late final value = ColumnString('value', this, hasDefault: true);

  @override
  List<Column> get columns => [id, name, value];
}

class _Serialization extends DatabaseSerializationManager {
  @override
  String getModuleName() => 'explicit_null_test';

  @override
  List<TableDefinition> getTargetTableDefinitions() => [];

  @override
  Table? getTableForType(Type t) => t == _Row ? _Table() : null;

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    if ((t ?? T) == _Row || (data is Map && data['__className__'] == 'BatchRow')) {
      final json = data as Map<String, dynamic>;
      return _Row(
            id: UuidValueJsonExtension.fromJson(json['id']),
            name: json['name'] as String,
            value: json['value'] as String?,
          )
          as T;
    }
    return super.deserialize<T>(data, t);
  }
}
