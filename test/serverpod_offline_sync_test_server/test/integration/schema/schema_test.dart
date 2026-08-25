import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  tearDown(() async {
    await CrdtSchemaColumn.db.deleteWhere(session, where: (t) => Constant.bool(true));
    await CrdtSchemaTable.db.deleteWhere(session, where: (t) => Constant.bool(true));
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
        (tableRows, columnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
        ).syncAndGetSchema();
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
            table.columns.syncColumnNames,
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

      final (tableRows, columnRows) = await CrdtSchemaRegistry(
        session,
        syncTables: tables,
      ).syncAndGetSchema();

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
        (firstTableRows, firstColumnRows) = await CrdtSchemaRegistry(
          session,
          syncTables: [table],
        ).syncAndGetSchema();
      });

      test(
        'when syncAndGetSchema is called again with the same tables as the sync list, '
        'then the table and columns are not duplicated.',
        () async {
          final (secondTableRows, secondColumnRows) = await CrdtSchemaRegistry(
            session,
            syncTables: [table],
          ).syncAndGetSchema();

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
    'Given resolved projection metadata from an older database, '
    'when a new CRDT database context is initialized, '
    'then the redundant projection row is removed and its field clock remains.',
    () async {
      late Town child;
      await session.db.transactionForUser(testCrdtUserId, (tx) async {
        final parent = await Person.db.insertRow(
          session,
          Person(id: const Uuid().v7obj(), name: 'legacy mayor'),
          transaction: tx,
        );
        child = await Town.db.insertRow(
          session,
          Town(id: const Uuid().v7obj(), name: 'legacy town'),
          transaction: tx,
        );
        child = await Town.db.updateRow(
          session,
          child.copyWith(mayorId: parent.id),
          columns: (t) => [t.mayorId],
          transaction: tx,
        );
      });

      final field = await CrdtDataField.db.findFirstRow(
        session,
        where: (t) =>
            t.row.uuidRowId.equals(child.id) &
            t.column.name.equals(Town.t.mayorId.columnName),
      );
      await CrdtDataForeignKey.db.insertRow(
        session,
        CrdtDataForeignKey(
          fieldId: field!.id!,
          attemptedValue: child.mayorId,
        ),
      );

      final upgradedSession = CrdtDatabaseSession.wraps(
        testSession,
        syncTables: [Person.t, Town.t],
      );
      await upgradedSession.db.initialize();

      expect(
        await CrdtDataForeignKey.db.findFirstRow(
          session,
          where: (t) => t.fieldId.equals(field.id),
        ),
        isNull,
      );
      expect(await CrdtDataField.db.findById(session, field.id!), isNotNull);
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
}

class _UuidPkTable extends Table<UuidValue> {
  _UuidPkTable({String? name}) : super(tableName: name ?? 'uuid_pk_table');

  @override
  List<Column> get columns => [
    id,
    ColumnInt('scopeId', this),
    ColumnString('name', this),
    ColumnBool('is_active', this),
  ];
}

extension on List<Column<dynamic>> {
  List<String> get syncColumnNames =>
      map((column) => column.columnName).where((name) => name != 'scopeId').toList();
}
