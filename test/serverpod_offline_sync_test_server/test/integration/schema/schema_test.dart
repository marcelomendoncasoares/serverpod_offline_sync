import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  tearDown(() async {
    await session.db.unsafeExecute('PRAGMA foreign_keys = OFF');
    await CrdtDataForeignKey.db.deleteWhere(
      session,
      where: (t) => Constant.bool(true),
    );
    await CrdtDataField.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await CrdtDataRow.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await CrdtSchemaColumn.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await CrdtSchemaTable.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await session.db.unsafeExecute('PRAGMA foreign_keys = ON');
  });

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
      final table = _UuidPkTable();
      late List<CrdtSchemaTable> tableRows;
      late List<CrdtSchemaColumn> columnRows;

      setUp(() async {
        (tableRows, columnRows) = await _uuidPkRegistry([table]).syncAndGetSchema();
      });

      test(
        'then the table is registered with the correct name and ID.',
        () async {
          expect(tableRows, hasLength(1));
          expect(tableRows.single.name, table.tableName);
          expect(tableRows.single.id, isNotNull);
        },
      );

      test(
        'then the columns are registered with the correct names and IDs.',
        () async {
          expect(columnRows, hasLength(table.columns.syncColumnNames.length));
          expect(
            columnRows.map((c) => c.name).toSet(),
            table.columns.syncColumnNames.toSet(),
          );
          expect(columnRows.map((c) => c.tblId).toSet(), {tableRows.single.id!});
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
        _UuidPkTable(name: 'table1'),
        _UuidPkTable(name: 'table2'),
        _UuidPkTable(name: 'table3'),
      ];

      final (tableRows, columnRows) = await _uuidPkRegistry(tables).syncAndGetSchema();

      expect(tableRows, hasLength(tables.length));
      expect(
        tableRows.map((t) => t.name).toSet(),
        tables.map((t) => t.tableName).toSet(),
      );
      expect(
        columnRows,
        hasLength(
          tables.fold<int>(0, (sum, t) => sum + t.columns.syncColumnNames.length),
        ),
      );
    },
  );

  group(
    'Given a CRDT schema registry with tables already registered,',
    () {
      final table = _UuidPkTable();
      late List<CrdtSchemaTable> firstTableRows;
      late List<CrdtSchemaColumn> firstColumnRows;

      setUp(() async {
        (firstTableRows, firstColumnRows) = await _uuidPkRegistry([
          table,
        ]).syncAndGetSchema();
      });

      test(
        'when syncAndGetSchema is called again with the same tables as the sync list, '
        'then the table and columns are not duplicated.',
        () async {
          final (secondTableRows, secondColumnRows) = await _uuidPkRegistry([
            table,
          ]).syncAndGetSchema();

          expect(secondTableRows, hasLength(1));
          expect(secondTableRows.single.name, table.tableName);
          expect(secondTableRows.single.id, firstTableRows.single.id);

          expect(secondColumnRows, hasLength(table.columns.syncColumnNames.length));
          expect(
            secondColumnRows.map((c) => c.id).toSet(),
            firstColumnRows.map((c) => c.id).toSet(),
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

  test(
    'Given a synced Unique name column whose type identity already matches, '
    'when syncAndGetSchema is called again, '
    'then the persisted column id and type identity are unchanged.',
    () async {
      final registry = CrdtSchemaRegistry(session, syncTables: [Unique.t]);
      final (_, firstColumns) = await registry.syncAndGetSchema();
      final firstName = firstColumns.singleWhere((column) => column.name == 'name');

      final (_, secondColumns) = await registry.syncAndGetSchema();
      final secondName = secondColumns.singleWhere((column) => column.name == 'name');

      expect(secondName.id, firstName.id);
      expect(secondName.columnType, firstName.columnType);
      expect(secondName.dartType, firstName.dartType);
      expect(secondName.isNullable, firstName.isNullable);
      expect(registry.registryChanged, isFalse);
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
              isNullable: true,
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('json or jsonb'),
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
            _uniqueNameDefinition(columnType: ColumnType.jsonb),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('json or jsonb'),
          ),
        ),
      );
    },
  );

  test(
    'Given a registered Unique name column with no attempted-value rows, '
    'when the persisted type identity changes, '
    'then the existing schema column is updated in place.',
    () async {
      final registry = CrdtSchemaRegistry(session, syncTables: [Unique.t]);
      final (_, firstColumns) = await registry.syncAndGetSchema();
      final firstName = firstColumns.singleWhere((column) => column.name == 'name');

      final (_, secondColumns) = await CrdtSchemaRegistry(
        session,
        syncTables: [Unique.t],
        tableDefinitions: [
          _uniqueNameDefinition(dartType: 'String?', isNullable: true),
        ],
      ).syncAndGetSchema();
      final secondName = secondColumns.singleWhere((column) => column.name == 'name');

      expect(secondName.id, firstName.id);
      expect(secondName.columnType, ColumnType.text.name);
      expect(secondName.dartType, 'String?');
      expect(secondName.isNullable, isTrue);
    },
  );

  test(
    'Given a registered Unique name column with an attempted-value row, '
    'when the persisted type identity changes, '
    'then initialization fails without mutating the registry.',
    () async {
      final registry = CrdtSchemaRegistry(session, syncTables: [Unique.t]);
      final (tables, firstColumns) = await registry.syncAndGetSchema();
      final firstName = firstColumns.singleWhere((column) => column.name == 'name');
      await _insertAttemptedValue(column: firstName, table: tables.single);

      await expectLater(
        CrdtSchemaRegistry(
          session,
          syncTables: [Unique.t],
          tableDefinitions: [
            _uniqueNameDefinition(dartType: 'String?', isNullable: true),
          ],
        ).syncAndGetSchema(),
        throwsA(
          isA<CrdtSchemaReconciliationException>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('${Unique.t.tableName}.name'),
              contains('columnType=${ColumnType.text.name}'),
              contains('dartType=String'),
              contains('isNullable=false'),
              contains('dartType=String?'),
              contains('isNullable=true'),
              contains('attest completion'),
            ),
          ),
        ),
      );

      final stored = await CrdtSchemaColumn.db.findById(session, firstName.id!);
      expect(stored!.dartType, 'String');
      expect(stored.isNullable, isFalse);
    },
  );

  test(
    'Given a registered Unique name column with field metadata but no attempted '
    'value, '
    'when the persisted type identity changes, '
    'then the existing schema column is updated in place.',
    () async {
      final registry = CrdtSchemaRegistry(session, syncTables: [Unique.t]);
      final (tables, firstColumns) = await registry.syncAndGetSchema();
      final firstName = firstColumns.singleWhere((column) => column.name == 'name');
      await _insertFieldMetadata(column: firstName, table: tables.single);

      final (_, secondColumns) = await CrdtSchemaRegistry(
        session,
        syncTables: [Unique.t],
        tableDefinitions: [
          _uniqueNameDefinition(dartType: 'String?', isNullable: true),
        ],
      ).syncAndGetSchema();
      final secondName = secondColumns.singleWhere((column) => column.name == 'name');

      expect(secondName.id, firstName.id);
      expect(secondName.dartType, 'String?');
      expect(secondName.isNullable, isTrue);
    },
  );

  test(
    'Given a registered uuid-pk table whose name column has field metadata, '
    'when the table both drops that column and adds another, '
    'then initialization fails without mutating the registry.',
    () async {
      final original = _UuidPkTable();
      final (tables, firstColumns) = await _uuidPkRegistry([
        original,
      ]).syncAndGetSchema();
      final nameColumn = firstColumns.singleWhere((column) => column.name == 'name');
      await _insertFieldMetadata(column: nameColumn, table: tables.single);

      final renamed = _UuidPkTable(extraColumnNames: const ['title', 'is_active']);
      await expectLater(
        _uuidPkRegistry([renamed]).syncAndGetSchema(),
        throwsA(
          isA<CrdtSchemaReconciliationException>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('${original.tableName}.name'),
              contains('${original.tableName}.title'),
              contains('Update CrdtSchemaColumn.name'),
            ),
          ),
        ),
      );

      final storedNames = (await CrdtSchemaColumn.db.find(session))
          .where((column) => column.tblId == tables.single.id)
          .map((column) => column.name)
          .toSet();
      expect(storedNames, contains('name'));
      expect(storedNames, isNot(contains('title')));
    },
  );

  test(
    'Given a registered uuid-pk table with no field metadata, '
    'when the table both drops a column and adds another, '
    'then the drop and add are applied.',
    () async {
      await _uuidPkRegistry([_UuidPkTable()]).syncAndGetSchema();

      final renamed = _UuidPkTable(extraColumnNames: const ['title', 'is_active']);
      final (_, columns) = await _uuidPkRegistry([renamed]).syncAndGetSchema();

      expect(columns.map((column) => column.name).toSet(), {
        'id',
        'title',
        'is_active',
      });
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
          syncTables: [_UuidPkTable()],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('TableDefinition'),
          ),
        ),
      );
    },
  );
}

class _UuidPkTable extends Table<UuidValue> {
  _UuidPkTable({
    String? name,
    this.extraColumnNames = const ['name', 'is_active'],
  }) : super(tableName: name ?? 'uuid_pk_table');

  final List<String> extraColumnNames;

  @override
  List<Column> get columns => [
    id,
    ColumnInt('scopeId', this),
    for (final columnName in extraColumnNames)
      if (columnName == 'is_active')
        ColumnBool(columnName, this)
      else
        ColumnString(columnName, this),
  ];
}

CrdtSchemaRegistry _uuidPkRegistry(List<_UuidPkTable> tables) {
  return CrdtSchemaRegistry(
    session,
    syncTables: tables,
    tableDefinitions: [for (final table in tables) _uuidPkTableDefinition(table)],
  );
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

TableDefinition _uniqueNameDefinition({
  ColumnType? columnType,
  String? dartType,
  bool? isNullable,
}) {
  final definition = session.db.serializationManager
      .getTargetTableDefinitions()
      .firstWhere((table) => table.name == Unique.t.tableName);
  return definition.copyWith(
    columns: [
      for (final column in definition.columns)
        column.name == 'name'
            ? column.copyWith(
                columnType: columnType ?? column.columnType,
                dartType: dartType ?? column.dartType,
                isNullable: isNullable ?? column.isNullable,
              )
            : column,
    ],
  );
}

Future<({CrdtScope scope, CrdtNode node})> _insertScopeAndNode() async {
  final node = await CrdtNode.db.insertRow(
    session,
    CrdtNode(uuidNodeId: const Uuid().v7obj()),
  );
  final scope = await CrdtScope.db.insertRow(
    session,
    CrdtScope(uuidScopeId: testCrdtUserId, currentNodeId: node.id),
  );
  return (scope: scope, node: node);
}

Future<CrdtDataField> _insertFieldMetadata({
  required CrdtSchemaColumn column,
  required CrdtSchemaTable table,
}) async {
  final (:scope, :node) = await _insertScopeAndNode();
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

Future<void> _insertAttemptedValue({
  required CrdtSchemaColumn column,
  required CrdtSchemaTable table,
}) async {
  final field = await _insertFieldMetadata(column: column, table: table);
  await CrdtDataForeignKey.db.insertRow(
    session,
    CrdtDataForeignKey(
      fieldId: field.id!,
      attemptedValue: const Uuid().v7obj(),
    ),
  );
}

extension on List<Column<dynamic>> {
  List<String> get syncColumnNames =>
      map((column) => column.columnName).where((name) => name != 'scopeId').toList();
}
