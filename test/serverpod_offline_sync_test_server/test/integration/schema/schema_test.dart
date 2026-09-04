import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  test(
    'Given a CRDT schema registry with an empty sync table list, '
    'when syncAndGetSchema is called, '
    'then no tables or columns are created.',
    () async {
      final (tableRows, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: [],
      ).syncAndGetSchema();

      expect(tableRows, isEmpty);
      expect(columnRows, isEmpty);
    },
  );

  group(
    'Given a CRDT schema registry with only one table with UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called,',
    () {
      final table = _UuidPkTable(tableName: 'uuid_pk_table', textColumnName: 'name');
      late List<CrdtSchemaTable> tableRows;
      late List<CrdtSchemaColumn> columnRows;

      setUp(() async {
        (tableRows, columnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
          tableDefinitions: [table.toTableDefinition()],
        ).syncAndGetSchema();
      });

      test(
        'then the table is registered with the correct name and ID.',
        () async {
          expect(tableRows, hasLength(1));
          expect(tableRows.single.name, 'uuid_pk_table');
          expect(tableRows.single.id, isNotNull);
        },
      );

      test(
        'then the columns are registered with the correct names and IDs.',
        () async {
          // scopeId is CRDT-managed and never registered as a synced column.
          expect(columnRows.map((column) => column.name).toSet(), {
            'id',
            'name',
            'is_active',
          });
          expect(columnRows.map((column) => column.tblId).toSet(), {
            tableRows.single.id,
          });
        },
      );
    },
  );

  test(
    'Given a CRDT schema registry with several tables with UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called, '
    'then the tables are registered with the correct names and IDs.',
    () async {
      final tables = [
        _UuidPkTable(tableName: 'table1', textColumnName: 'name'),
        _UuidPkTable(tableName: 'table2', textColumnName: 'name'),
        _UuidPkTable(tableName: 'table3', textColumnName: 'name'),
      ];

      final (tableRows, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: tables,
        tableDefinitions: [
          for (final table in tables) table.toTableDefinition(),
        ],
      ).syncAndGetSchema();

      expect(tableRows.map((table) => table.name).toSet(), {
        'table1',
        'table2',
        'table3',
      });
      // Three synced columns each: id, name and is_active.
      expect(columnRows, hasLength(9));
    },
  );

  group(
    'Given a CRDT schema registry with tables already registered,',
    () {
      final table = _UuidPkTable(tableName: 'uuid_pk_table', textColumnName: 'name');
      late List<CrdtSchemaTable> firstTableRows;
      late List<CrdtSchemaColumn> firstColumnRows;

      setUp(() async {
        (firstTableRows, firstColumnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
          tableDefinitions: [table.toTableDefinition()],
        ).syncAndGetSchema();
      });

      test(
        'when syncAndGetSchema is called again with the same tables as the sync list, '
        'then the table and columns are not duplicated.',
        () async {
          final (secondTableRows, secondColumnRows) = await CrdtSchemaRegistry(
            session,
            syncTables: [table],
            tableDefinitions: [table.toTableDefinition()],
          ).syncAndGetSchema();

          expect(secondTableRows, hasLength(1));
          expect(secondTableRows.single.name, 'uuid_pk_table');
          expect(secondTableRows.single.id, firstTableRows.single.id);

          expect(secondColumnRows, hasLength(3));
          expect(
            secondColumnRows.map((column) => column.id).toSet(),
            firstColumnRows.map((column) => column.id).toSet(),
          );
        },
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced nullable foreign-key-only unique index, '
    'when syncAndGetSchema is called, '
    'then the index is accepted.',
    () async {
      final (tableRows, _) = await CrdtSchemaRegistry(
        session,
        syncTables: [Address.t, Person.t],
      ).syncAndGetSchema();

      expect(tableRows.map((table) => table.name).toSet(), {
        Address.t.tableName,
        Person.t.tableName,
      });
    },
  );

  test(
    'Given a CRDT schema registry with a global unique index containing only foreign keys to synced tables, '
    'when syncAndGetSchema is called, '
    'then the index is accepted.',
    () async {
      final tableDefinitions = testSession.db.serializationManager
          .getTargetTableDefinitions();
      final townDefinition = tableDefinitions.firstWhere(
        (definition) => definition.name == Town.t.tableName,
      );
      final addressDefinition = tableDefinitions.firstWhere(
        (definition) => definition.name == Address.t.tableName,
      );
      final indexTemplate = addressDefinition.indexes.singleWhere(
        (index) => index.indexName == 'address__inhabitantId__unique_idx',
      );
      final fkOnlyDefinition = townDefinition.copyWith(
        indexes: [
          indexTemplate.copyWith(
            indexName: 'town_global_city_mayor_unique_idx',
            elements: [
              indexTemplate.elements.single.copyWith(definition: 'cityId'),
              indexTemplate.elements.single.copyWith(definition: 'mayorId'),
            ],
          ),
        ],
      );

      final (tableRows, _) = await CrdtSchemaRegistry(
        session,
        syncTables: [Town.t, City.t, Person.t],
        tableDefinitions: [fkOnlyDefinition],
      ).syncAndGetSchema();

      expect(tableRows.map((table) => table.name).toSet(), {
        Town.t.tableName,
        City.t.tableName,
        Person.t.tableName,
      });
    },
  );

  test(
    'Given a CRDT database with a scoped composite unique index that has a stable discriminator and a releasable column, '
    'when the database is initialized, '
    'then the unique index metadata is accepted.',
    () async {
      final crdtSession = CrdtDatabaseSession.wraps(
        testSession,
        syncTables: [UniqueDiscriminator.t],
      );

      await expectLater(crdtSession.db.initialize(), completes);
    },
  );

  test(
    'Given a CRDT schema registry with a synced table that has the scopeId cascade relation to crdt_scopes, '
    'when the registry is created, '
    'then no error is thrown.',
    () async {
      final (tableRows, _) = await CrdtSchemaRegistry(
        session,
        syncTables: [Person.t],
      ).syncAndGetSchema();

      expect(tableRows.map((t) => t.name).toSet(), {Person.t.tableName});
    },
  );

  test(
    'Given a CRDT schema registry with a table with non-UuidValue primary key in the sync list, '
    'when syncAndGetSchema is called, '
    'then an error is thrown.',
    () async {
      const tableName = 'int_pk_table';
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Table<int>(tableName: tableName)],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CRDT can only synchronize tables with a UUID primary key, but '
                '1 table(s) do not have a UUID primary key: "$tableName"',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with a global unique index, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final uniqueDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Unique.t.tableName);
      final scopedUniqueIndex = uniqueDefinition.indexes.singleWhere(
        (index) => index.isUnique && !index.isPrimary,
      );
      final globalUniqueDefinition = uniqueDefinition.copyWith(
        indexes: [
          scopedUniqueIndex.copyWith(
            elements: [
              for (final element in scopedUniqueIndex.elements)
                if (element.definition != 'scopeId') element,
            ],
          ),
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
          tableDefinitions: [globalUniqueDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT can only synchronize tables with per-scope unique indexes',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced required foreign-key-only unique index, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final addressDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Address.t.tableName);
      final requiredForeignKeyDefinition = addressDefinition.copyWith(
        columns: [
          for (final column in addressDefinition.columns)
            column.name == 'inhabitantId' ? column.copyWith(isNullable: false) : column,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Address.t, Person.t],
          tableDefinitions: [requiredForeignKeyDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT can only synchronize 1:1 relations when the foreign key column is '
              'nullable, but the following foreign keys are non-nullable: '
              '"address.inhabitantId". Make the relation optional/nullable.',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a global unique index containing a required foreign key to a synced table, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final tableDefinitions = testSession.db.serializationManager
          .getTargetTableDefinitions();
      final townDefinition = tableDefinitions.firstWhere(
        (definition) => definition.name == Town.t.tableName,
      );
      final addressDefinition = tableDefinitions.firstWhere(
        (definition) => definition.name == Address.t.tableName,
      );
      final indexTemplate = addressDefinition.indexes.singleWhere(
        (index) => index.indexName == 'address__inhabitantId__unique_idx',
      );
      final requiredForeignKeyDefinition = townDefinition.copyWith(
        columns: [
          for (final column in townDefinition.columns)
            column.name == 'cityId' ? column.copyWith(isNullable: false) : column,
        ],
        indexes: [
          indexTemplate.copyWith(
            indexName: 'town_global_city_mayor_unique_idx',
            elements: [
              indexTemplate.elements.single.copyWith(definition: 'cityId'),
              indexTemplate.elements.single.copyWith(definition: 'mayorId'),
            ],
          ),
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Town.t, City.t, Person.t],
          tableDefinitions: [requiredForeignKeyDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT can only synchronize 1:1 relations when the foreign key column is '
              'nullable, but the following foreign keys are non-nullable: '
              '"town.cityId". Make the relation optional/nullable.',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a global unique index mixing a foreign key and an application column, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final addressDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Address.t.tableName);
      final foreignKeyUniqueIndex = addressDefinition.indexes.singleWhere(
        (index) => index.indexName == 'address__inhabitantId__unique_idx',
      );
      final foreignKeyElement = foreignKeyUniqueIndex.elements.single;
      final mixedUniqueDefinition = addressDefinition.copyWith(
        indexes: [
          foreignKeyUniqueIndex.copyWith(
            indexName: 'address_global_inhabitant_street_unique_idx',
            elements: [
              foreignKeyElement,
              foreignKeyElement.copyWith(definition: 'street'),
            ],
          ),
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Address.t, Person.t],
          tableDefinitions: [mixedUniqueDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('foreign-key-only indexes'),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a scoped unique index that has no releasable non-scope column, '
    'when the registry is created, '
    'then an error is thrown.',
    () {
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [UniqueNoRelease.t],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT unique conflict resolution requires at least one '
              'releasable non-scope column',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT database with a scoped unique index that has no releasable non-scope column, '
    'when the database is initialized, '
    'then an error is thrown.',
    () async {
      final crdtSession = CrdtDatabaseSession.wraps(
        testSession,
        syncTables: [UniqueNoRelease.t],
      );

      await expectLater(
        crdtSession.db.initialize(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT unique conflict resolution requires at least one '
              'releasable non-scope column',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table missing the scopeId cascade relation to crdt_scopes, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);

      final noScopeRelationDefinition = personDefinition.copyWith(
        foreignKeys: personDefinition.foreignKeys
            .where(
              (fk) =>
                  !(fk.columns.contains('scopeId') &&
                      fk.referenceTable == 'crdt_scopes'),
            )
            .toList(),
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [noScopeRelationDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT synced tables must declare scopeId as a cascade relation to crdt_scopes',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with scopeId referencing crdt_scopes but without onDelete=Cascade, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);
      final wrongActionDefinition = personDefinition.copyWith(
        foreignKeys: [
          for (final fk in personDefinition.foreignKeys)
            fk.columns.contains('scopeId') && fk.referenceTable == 'crdt_scopes'
                ? fk.copyWith(onDelete: .restrict)
                : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [wrongActionDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'CRDT synced tables must declare scopeId as a cascade relation to crdt_scopes',
            ),
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table whose only non-deferred foreign key is the scopeId relation to crdt_scopes, '
    'when the registry is created, '
    'then no error is thrown.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);
      final nonDeferredScopeDefinition = personDefinition.copyWith(
        foreignKeys: [
          for (final fk in personDefinition.foreignKeys)
            fk.columns.contains('scopeId') && fk.referenceTable == 'crdt_scopes'
                ? fk.copyWith(deferrable: null)
                : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [nonDeferredScopeDefinition],
        ),
        returnsNormally,
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with a non-deferred non-nullable foreign key, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final childDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere(
            (definition) => definition.name == RequiredSetNullChild.t.tableName,
          );
      final nonDeferredDefinition = childDefinition.copyWith(
        foreignKeys: [
          for (final fk in childDefinition.foreignKeys)
            fk.columns.contains('parentId') ? fk.copyWith(deferrable: null) : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [RequiredSetNullChild.t],
          tableDefinitions: [nonDeferredDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CRDT requires deferred foreign keys for non-optional relations, '
                'but 1 foreign key(s) are not deferred: '
                '"required_set_null_child.parentId". Mark these as "deferred" '
                'or make the relation optional.',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with an initiallyImmediate non-nullable foreign key, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final childDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere(
            (definition) => definition.name == RequiredSetNullChild.t.tableName,
          );
      final immediateDefinition = childDefinition.copyWith(
        foreignKeys: [
          for (final fk in childDefinition.foreignKeys)
            fk.columns.contains('parentId')
                ? fk.copyWith(deferrable: .initiallyImmediate)
                : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [RequiredSetNullChild.t],
          tableDefinitions: [immediateDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CRDT requires deferred foreign keys for non-optional relations, '
                'but 1 foreign key(s) are not deferred: '
                '"required_set_null_child.parentId". Mark these as "deferred" '
                'or make the relation optional.',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with a non-deferred nullable foreign key, '
    'when the registry is created, '
    'then no error is thrown because projection can repair it.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);
      final nonDeferredNullableDefinition = personDefinition.copyWith(
        foreignKeys: [
          for (final fk in personDefinition.foreignKeys)
            fk.columns.contains('organizationId') ? fk.copyWith(deferrable: null) : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [nonDeferredNullableDefinition],
        ),
        returnsNormally,
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table with a deferred foreign key using onDelete Restrict, '
    'when the registry is created, '
    'then an error is thrown.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);
      final restrictDefinition = personDefinition.copyWith(
        foreignKeys: [
          for (final fk in personDefinition.foreignKeys)
            fk.columns.contains('organizationId')
                ? fk.copyWith(onDelete: ForeignKeyAction.restrict)
                : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [restrictDefinition],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CRDT cannot synchronize tables with "onDelete=Restrict" foreign '
                'keys, but 1 foreign key(s) use it: "person.organizationId". '
                'Replace by "onDelete=NoAction" instead, which produces the '
                'same effect.',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a synced table whose scopeId relation uses onDelete Restrict, '
    'when the registry is created, '
    'then the scopeId relation is not exempt from the cascade requirement.',
    () async {
      final personDefinition = testSession.db.serializationManager
          .getTargetTableDefinitions()
          .firstWhere((definition) => definition.name == Person.t.tableName);
      final restrictScopeDefinition = personDefinition.copyWith(
        foreignKeys: [
          for (final fk in personDefinition.foreignKeys)
            fk.columns.contains('scopeId') && fk.referenceTable == 'crdt_scopes'
                ? fk.copyWith(onDelete: ForeignKeyAction.restrict)
                : fk,
        ],
      );

      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Person.t],
          tableDefinitions: [restrictScopeDefinition],
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'Given a CRDT schema registry for Unique, '
    'when syncAndGetSchema is called, '
    'then the name column persists storage type, Dart type, and nullability.',
    () async {
      final (_, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: [Unique.t],
      ).syncAndGetSchema();

      final nameColumn = columnRows.singleWhere((column) => column.name == 'name');
      expect(nameColumn.columnType, ColumnType.text.name);
      expect(nameColumn.dartType, 'String');
      expect(nameColumn.isNullable, isFalse);
    },
  );

  group(
    'Given a Unique name column already registered with its current type identity,',
    () {
      late CrdtSchemaRegistry registry;
      late CrdtSchemaColumn registeredName;

      setUp(() async {
        registry = CrdtSchemaRegistry(session, syncTables: [Unique.t]);
        final (_, columns) = await registry.syncAndGetSchema();
        registeredName = columns.singleWhere((column) => column.name == 'name');
      });

      test(
        'when syncAndGetSchema is called again, '
        'then the registry is left unchanged.',
        () async {
          final (_, columns) = await registry.syncAndGetSchema();
          final syncedName = columns.singleWhere((column) => column.name == 'name');

          expect(syncedName.id, registeredName.id);
          expect(syncedName.columnType, ColumnType.text.name);
          expect(syncedName.dartType, 'String');
          expect(syncedName.isNullable, isFalse);
          expect(registry.registryChanged, isFalse);
        },
      );
    },
  );

  test(
    'Given a CRDT schema registry with a nullable json unique index, '
    'when the registry is created, '
    'then an error is thrown.',
    () {
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
          tableDefinitions: [
            _uniqueNameDefinition(
              columnType: ColumnType.json,
              dartType: 'String?',
              isNullable: true,
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'CRDT cannot synchronize unique indexes that include json or jsonb '
                'columns, because sync does not define canonical cross-dialect '
                'JSON equality: unique.unique__scopeId__name__unique_idx. Remove '
                'those columns from the unique index.',
          ),
        ),
      );
    },
  );

  test(
    'Given a CRDT schema registry with a non-nullable jsonb unique index, '
    'when the registry is created, '
    'then an error is thrown.',
    () {
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
          tableDefinitions: [
            _uniqueNameDefinition(
              columnType: ColumnType.jsonb,
              dartType: 'String',
              isNullable: false,
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'CRDT cannot synchronize unique indexes that include json or jsonb '
                'columns, because sync does not define canonical cross-dialect '
                'JSON equality: unique.unique__scopeId__name__unique_idx. Remove '
                'those columns from the unique index.',
          ),
        ),
      );
    },
  );

  group(
    'Given a registered Unique name column with no CRDT metadata, '
    'and a definition that makes it a nullable String,',
    () {
      late CrdtSchemaColumn registeredName;
      late TableDefinition nullableNameDefinition;

      setUp(() async {
        final (_, columns) = await CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
        ).syncAndGetSchema();
        registeredName = columns.singleWhere((column) => column.name == 'name');
        nullableNameDefinition = _uniqueNameDefinition(
          columnType: ColumnType.text,
          dartType: 'String?',
          isNullable: true,
        );
      });

      test(
        'when syncAndGetSchema is called, '
        'then the registered column is updated in place.',
        () async {
          final (_, columns) = await CrdtSchemaRegistry(
            session,
            syncTables: [Unique.t],
            tableDefinitions: [nullableNameDefinition],
          ).syncAndGetSchema();

          final syncedName = columns.singleWhere((column) => column.name == 'name');
          expect(syncedName.id, registeredName.id);
          expect(syncedName.columnType, ColumnType.text.name);
          expect(syncedName.dartType, 'String?');
          expect(syncedName.isNullable, isTrue);
        },
      );
    },
  );

  group(
    'Given a registered Unique name column with field metadata but no attempted '
    'value, and a definition that makes it a nullable String,',
    () {
      late CrdtSchemaColumn registeredName;
      late TableDefinition nullableNameDefinition;

      setUp(() async {
        final (tables, columns) = await CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
        ).syncAndGetSchema();
        registeredName = columns.singleWhere((column) => column.name == 'name');
        await _insertFieldMetadata(column: registeredName, table: tables.single);
        nullableNameDefinition = _uniqueNameDefinition(
          columnType: ColumnType.text,
          dartType: 'String?',
          isNullable: true,
        );
      });

      test(
        'when syncAndGetSchema is called, '
        'then the registered column is updated in place.',
        () async {
          final (_, columns) = await CrdtSchemaRegistry(
            session,
            syncTables: [Unique.t],
            tableDefinitions: [nullableNameDefinition],
          ).syncAndGetSchema();

          final syncedName = columns.singleWhere((column) => column.name == 'name');
          expect(syncedName.id, registeredName.id);
          expect(syncedName.dartType, 'String?');
          expect(syncedName.isNullable, isTrue);
        },
      );
    },
  );

  group(
    'Given a registered Unique name column holding an attempted value, '
    'and a definition that makes it a nullable String,',
    () {
      late CrdtSchemaColumn registeredName;
      late TableDefinition nullableNameDefinition;

      setUp(() async {
        final (tables, columns) = await CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
        ).syncAndGetSchema();
        registeredName = columns.singleWhere((column) => column.name == 'name');
        await _insertAttemptedValue(
          column: registeredName,
          table: tables.single,
          value: 'released-name',
          reason: CrdtProjectionReason.uniqueConflict,
        );
        nullableNameDefinition = _uniqueNameDefinition(
          columnType: ColumnType.text,
          dartType: 'String?',
          isNullable: true,
        );
      });

      test(
        'when syncAndGetSchema is called, '
        'then it throws and the registered column keeps its type identity.',
        () async {
          await expectLater(
            CrdtSchemaRegistry(
              session,
              syncTables: [Unique.t],
              tableDefinitions: [nullableNameDefinition],
            ).syncAndGetSchema(),
            throwsA(
              isA<CrdtSchemaReconciliationException>().having(
                (error) => error.toString(),
                'toString',
                'CrdtSchemaReconciliationException: Cannot change unique.name type '
                    'identity from columnType=text dartType=String isNullable=false '
                    'to columnType=text dartType=String? isNullable=true, because '
                    'attempted-value rows still exist. Convert the domain column and '
                    'every affected attempted-value envelope to the target types, '
                    'then attest completion by updating CrdtSchemaColumn for '
                    'unique.name to columnType=text dartType=String? isNullable=true '
                    'as the final step of the same migration.',
              ),
            ),
          );

          final stored = await CrdtSchemaColumn.db.findById(
            session,
            registeredName.id!,
          );
          expect(stored!.columnType, ColumnType.text.name);
          expect(stored.dartType, 'String');
          expect(stored.isNullable, isFalse);
        },
      );
    },
  );

  group(
    'Given a registered uuid-pk table with no CRDT field metadata, '
    'and a table that replaces its name column with a title column,',
    () {
      late _UuidPkTable renamed;

      setUp(() async {
        final original = _UuidPkTable(
          tableName: 'uuid_pk_table',
          textColumnName: 'name',
        );
        await CrdtSchemaRegistry(
          session,
          syncTables: [original],
          tableDefinitions: [_uuidPkTableDefinition(original)],
        ).syncAndGetSchema();
        renamed = _UuidPkTable(
          tableName: 'uuid_pk_table',
          textColumnName: 'title',
        );
      });

      test(
        'when syncAndGetSchema is called, '
        'then the drop and the add are both applied.',
        () async {
          final (_, columns) = await CrdtSchemaRegistry(
            session,
            syncTables: [renamed],
            tableDefinitions: [_uuidPkTableDefinition(renamed)],
          ).syncAndGetSchema();

          expect(columns.map((column) => column.name).toSet(), {
            'id',
            'title',
            'is_active',
          });
        },
      );
    },
  );

  group(
    'Given a registered uuid-pk table whose name column has CRDT field metadata, '
    'and a table that replaces its name column with a title column,',
    () {
      late CrdtSchemaTable registeredTable;
      late _UuidPkTable renamed;

      setUp(() async {
        final original = _UuidPkTable(
          tableName: 'uuid_pk_table',
          textColumnName: 'name',
        );
        final (tables, columns) = await CrdtSchemaRegistry(
          session,
          syncTables: [original],
          tableDefinitions: [_uuidPkTableDefinition(original)],
        ).syncAndGetSchema();
        registeredTable = tables.single;
        await _insertFieldMetadata(
          column: columns.singleWhere((column) => column.name == 'name'),
          table: registeredTable,
        );
        renamed = _UuidPkTable(
          tableName: 'uuid_pk_table',
          textColumnName: 'title',
        );
      });

      test(
        'when syncAndGetSchema is called, '
        'then it throws and the registered columns are left unchanged.',
        () async {
          await expectLater(
            CrdtSchemaRegistry(
              session,
              syncTables: [renamed],
              tableDefinitions: [_uuidPkTableDefinition(renamed)],
            ).syncAndGetSchema(),
            throwsA(
              isA<CrdtSchemaReconciliationException>().having(
                (error) => error.toString(),
                'toString',
                'CrdtSchemaReconciliationException: Cannot reconcile '
                    'uuid_pk_table: columns uuid_pk_table.name would be dropped '
                    'while uuid_pk_table.title would be added, and the dropped '
                    'columns still have CRDT field metadata. Update '
                    'CrdtSchemaColumn.name in a migration to rename, or '
                    'explicitly delete the old schema column (cascading field '
                    'metadata) for a real drop, then initialize again.',
              ),
            ),
          );

          final stored = await CrdtSchemaColumn.db.find(session);
          expect(
            stored
                .where((column) => column.tblId == registeredTable.id)
                .map((column) => column.name)
                .toSet(),
            {'id', 'name', 'is_active'},
          );
        },
      );
    },
  );

  test(
    'Given a CRDT schema registry for a table with no TableDefinition, '
    'when the registry is created, '
    'then an error is thrown.',
    () {
      expect(
        () => CrdtSchemaRegistry(
          session,
          syncTables: [
            _UuidPkTable(tableName: 'uuid_pk_table', textColumnName: 'name'),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'CRDT requires a TableDefinition for every synced table, but '
                '1 table(s) have none: "uuid_pk_table".',
          ),
        ),
      );
    },
  );
}

/// A synced table with a UUID primary key, the CRDT scope relation, one text
/// column named by the test, and one boolean column.
class _UuidPkTable extends Table<UuidValue> {
  _UuidPkTable({required super.tableName, required this.textColumnName});

  final String textColumnName;

  @override
  List<Column> get columns => [
    id,
    ColumnInt('scopeId', this),
    ColumnString(textColumnName, this),
    ColumnBool('is_active', this),
  ];

  TableDefinition toTableDefinition() {
    return TableDefinition(
      name: tableName,
      schema: 'public',
      columns: [
        for (final column in columns)
          ColumnDefinition(
            name: column.columnName,
            columnType: switch (column.columnName) {
              'id' => ColumnType.uuid,
              'scopeId' => ColumnType.bigint,
              'is_active' => ColumnType.boolean,
              _ => ColumnType.text,
            },
            isNullable: column.columnName == 'id' || column.columnName == 'scopeId',
            dartType: switch (column.columnName) {
              'id' => 'UuidValue?',
              'scopeId' => 'int?',
              'is_active' => 'bool',
              _ => 'String',
            },
          ),
      ],
      foreignKeys: [
        ForeignKeyDefinition(
          constraintName: '${tableName}_fk_scopeId',
          columns: const ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: const ['id'],
          onDelete: ForeignKeyAction.cascade,
        ),
      ],
      indexes: const [],
    );
  }
}

TableDefinition _uuidPkTableDefinition(_UuidPkTable table) {
  return TableDefinition(
    name: table.tableName,
    schema: 'public',
    columns: [
      for (final column in table.columns)
        ColumnDefinition(
          name: column.columnName,
          columnType: switch (column.columnName) {
            'id' => ColumnType.uuid,
            'scopeId' => ColumnType.bigint,
            'is_active' => ColumnType.boolean,
            _ => ColumnType.text,
          },
          isNullable: column.columnName == 'id' || column.columnName == 'scopeId',
          dartType: switch (column.columnName) {
            'id' => 'UuidValue?',
            'scopeId' => 'int?',
            'is_active' => 'bool',
            _ => 'String',
          },
        ),
    ],
    foreignKeys: [
      ForeignKeyDefinition(
        constraintName: '${table.tableName}_fk_scopeId',
        columns: const ['scopeId'],
        referenceTable: 'crdt_scopes',
        referenceTableSchema: 'public',
        referenceColumns: const ['id'],
        onDelete: ForeignKeyAction.cascade,
      ),
    ],
    indexes: const [],
  );
}

/// The generated `Unique` definition with `name` given the type identity the
/// test is registering, every part of it stated by the caller.
TableDefinition _uniqueNameDefinition({
  required ColumnType columnType,
  required String dartType,
  required bool isNullable,
}) {
  final definition = session.db.serializationManager
      .getTargetTableDefinitions()
      .firstWhere((table) => table.name == Unique.t.tableName);
  return definition.copyWith(
    columns: [
      for (final column in definition.columns)
        column.name == 'name'
            ? column.copyWith(
                columnType: columnType,
                dartType: dartType,
                isNullable: isNullable,
              )
            : column,
    ],
  );
}

/// Registers CRDT field metadata for [column] on a new row of [table].
///
/// The scope, node and data row are the metadata chain a field hangs off; only
/// the field's existence is what a test asserts against.
Future<CrdtDataField> _insertFieldMetadata({
  required CrdtSchemaColumn column,
  required CrdtSchemaTable table,
}) async {
  final node = await CrdtNode.db.insertRow(
    session,
    CrdtNode(uuidNodeId: const Uuid().v7obj()),
  );
  final scope = await CrdtScope.db.insertRow(
    session,
    CrdtScope(uuidScopeId: testCrdtUserId, currentNodeId: node.id),
  );
  final row = await CrdtDataRow.db.insertRow(
    session,
    CrdtDataRow(
      scopeId: scope.id!,
      tblId: table.id!,
      uuidRowId: const Uuid().v7obj(),
      nodeId: node.id!,
      hlcDatetime: DateTime.now().toUtc(),
      hlcCounter: 0,
    ),
  );
  return CrdtDataField.db.insertRow(
    session,
    CrdtDataField(
      rowId: row.id!,
      columnId: column.id!,
      nodeId: node.id!,
      hlcDatetime: row.hlcDatetime,
      hlcCounter: 0,
    ),
  );
}

/// Retains [value] as the authored value of [column] on a new row of [table].
Future<void> _insertAttemptedValue({
  required CrdtSchemaColumn column,
  required CrdtSchemaTable table,
  required Object value,
  required CrdtProjectionReason reason,
}) async {
  final field = await _insertFieldMetadata(column: column, table: table);
  await CrdtDataAttemptedValue.db.insertRow(
    session,
    CrdtDataAttemptedValue(
      fieldId: field.id!,
      value: value,
      projectionReason: reason,
    ),
  );
}
