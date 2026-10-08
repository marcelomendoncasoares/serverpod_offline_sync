import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a nullable foreign key with SetNull on delete and update,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(UniqueSetNullChild.t.tableName);
      definition = original.copyWith(
        foreignKeys: [
          for (final foreignKey in original.foreignKeys)
            foreignKey.columns.contains('parentId')
                ? foreignKey.copyWith(onUpdate: ForeignKeyAction.setNull)
                : foreignKey,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it accepts the relation.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          returnsNormally,
        );
      },
    );
  });

  group(
    'Given SetDefault on delete and update with a fixed UUID database default,',
    () {
      late TableDefinition definition;

      setUp(() {
        final original = _definitionFor(UniqueSetDefaultChild.t.tableName);
        definition = original.copyWith(
          foreignKeys: [
            for (final foreignKey in original.foreignKeys)
              foreignKey.columns.contains('parentId')
                  ? foreignKey.copyWith(onUpdate: ForeignKeyAction.setDefault)
                  : foreignKey,
          ],
        );
      });

      test(
        'when the schema registry is created, '
        'then it accepts the relation.',
        () {
          expect(
            () => CrdtSchemaRegistry(
              testSession,
              syncTables: testSyncTables,
              tableDefinitions: _definitionsWith(definition),
            ),
            returnsNormally,
          );
        },
      );
    },
  );

  group('Given a SetDefault foreign key with a random UUID database default,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(UniqueSetDefaultChild.t.tableName);
      definition = original.copyWith(
        columns: [
          for (final column in original.columns)
            column.name == 'parentId'
                ? column.copyWith(columnDefault: 'random')
                : column,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it accepts the declared database default.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('Given a SetDefault foreign key with a random v7 UUID database default,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(UniqueSetDefaultChild.t.tableName);
      definition = original.copyWith(
        columns: [
          for (final column in original.columns)
            column.name == 'parentId'
                ? column.copyWith(columnDefault: 'random_v7')
                : column,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it accepts the declared database default.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('Given a required foreign key with onDelete SetNull,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(RequiredNoActionChild.t.tableName);
      definition = original.copyWith(
        foreignKeys: [
          for (final foreignKey in original.foreignKeys)
            foreignKey.columns.contains('parentId')
                ? foreignKey.copyWith(onDelete: ForeignKeyAction.setNull)
                : foreignKey,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it rejects the action that cannot write null.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'CRDT requires foreign key actions compatible with their columns: '
                  'required_no_action_child.parentId (onDelete=SetNull requires a nullable column).',
            ),
          ),
        );
      },
    );
  });

  group('Given a required foreign key with onUpdate SetNull,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(RequiredNoActionChild.t.tableName);
      definition = original.copyWith(
        foreignKeys: [
          for (final foreignKey in original.foreignKeys)
            foreignKey.columns.contains('parentId')
                ? foreignKey.copyWith(onUpdate: ForeignKeyAction.setNull)
                : foreignKey,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it rejects the action that cannot write null.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'CRDT requires foreign key actions compatible with their columns: '
                  'required_no_action_child.parentId (onUpdate=SetNull requires a nullable column).',
            ),
          ),
        );
      },
    );
  });

  group('Given a nullable SetDefault foreign key without a database default,', () {
    late TableDefinition definition;

    setUp(() {
      final original = _definitionFor(UniqueSetDefaultChild.t.tableName);
      definition = original.copyWith(
        columns: [
          for (final column in original.columns)
            column.name == 'parentId' ? column.copyWith(columnDefault: null) : column,
        ],
      );
    });

    test(
      'when the schema registry is created, '
      'then it rejects the action without a database default.',
      () {
        expect(
          () => CrdtSchemaRegistry(
            testSession,
            syncTables: testSyncTables,
            tableDefinitions: _definitionsWith(definition),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'CRDT requires foreign key actions compatible with their columns: '
                  'unique_set_default_child.parentId (onDelete=SetDefault requires a database default).',
            ),
          ),
        );
      },
    );
  });

  group(
    'Given a required foreign key with onDelete SetDefault and no database default,',
    () {
      late TableDefinition definition;

      setUp(() {
        final original = _definitionFor(RequiredNoActionChild.t.tableName);
        definition = original.copyWith(
          foreignKeys: [
            for (final foreignKey in original.foreignKeys)
              foreignKey.columns.contains('parentId')
                  ? foreignKey.copyWith(onDelete: ForeignKeyAction.setDefault)
                  : foreignKey,
          ],
        );
      });

      test(
        'when the schema registry is created, '
        'then it rejects the action without a database default.',
        () {
          expect(
            () => CrdtSchemaRegistry(
              testSession,
              syncTables: testSyncTables,
              tableDefinitions: _definitionsWith(definition),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'CRDT requires foreign key actions compatible with their columns: '
                    'required_no_action_child.parentId (onDelete=SetDefault requires a database default).',
              ),
            ),
          );
        },
      );
    },
  );

  group(
    'Given a required foreign key with onUpdate SetDefault and no database default,',
    () {
      late TableDefinition definition;

      setUp(() {
        final original = _definitionFor(RequiredNoActionChild.t.tableName);
        definition = original.copyWith(
          foreignKeys: [
            for (final foreignKey in original.foreignKeys)
              foreignKey.columns.contains('parentId')
                  ? foreignKey.copyWith(onUpdate: ForeignKeyAction.setDefault)
                  : foreignKey,
          ],
        );
      });

      test(
        'when the schema registry is created, '
        'then it rejects the action without a database default.',
        () {
          expect(
            () => CrdtSchemaRegistry(
              testSession,
              syncTables: testSyncTables,
              tableDefinitions: _definitionsWith(definition),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'CRDT requires foreign key actions compatible with their columns: '
                    'required_no_action_child.parentId (onUpdate=SetDefault requires a database default).',
              ),
            ),
          );
        },
      );
    },
  );
}

TableDefinition _definitionFor(String tableName) => testSession.db.serializationManager
    .getTargetTableDefinitions()
    .singleWhere((definition) => definition.name == tableName);

List<TableDefinition> _definitionsWith(TableDefinition replacement) => [
  for (final definition
      in testSession.db.serializationManager.getTargetTableDefinitions())
    definition.name == replacement.name ? replacement : definition,
];
