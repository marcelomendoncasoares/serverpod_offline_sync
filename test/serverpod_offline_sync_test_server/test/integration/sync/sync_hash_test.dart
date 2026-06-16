// Uses serverpod_database types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    hide Protocol;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  final protocol = Protocol();

  final syncTables = [Address.t, Person.t, Unique.t];

  final addressDefinition = protocol.getTableDefinition(Address.t);
  final personDefinition = protocol.getTableDefinition(Person.t);
  final uniqueDefinition = protocol.getTableDefinition(Unique.t);
  final typesDefinition = protocol.getTableDefinition(Types.t);

  group('Given table definitions with different table and schema elements order', () {
    final baseDefinitions = [
      addressDefinition,
      personDefinition,
      uniqueDefinition,
    ];

    final changedDefinitions = [
      for (final definition in baseDefinitions)
        definition.copyWith(
          columns: definition.columns.reversed.toList(),
          foreignKeys: definition.foreignKeys.reversed.toList(),
          indexes: definition.indexes.reversed.toList(),
        ),
    ];

    test(
      'when comparing the definition hashes '
      'then their hash values are equal.',
      () {
        final baseHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: baseDefinitions,
        );

        final changedHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: changedDefinitions,
        );

        expect(changedHash, baseHash);
      },
    );
  });

  group('Given table definitions with different columns', () {
    final baseDefinitions = [
      personDefinition,
    ];

    final changedDefinitions = [
      personDefinition.copyWith(
        columns: [
          ...personDefinition.columns,
          personDefinition.columns.last.copyWith(name: 'shadowColumn'),
        ],
      ),
    ];

    test(
      'when comparing the definition hashes '
      'then their hash values are different.',
      () {
        final baseHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: baseDefinitions,
        );

        final changedHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: changedDefinitions,
        );

        expect(changedHash, isNot(baseHash));
      },
    );
  });

  group('Given table definitions with different foreign keys', () {
    final baseDefinitions = [
      addressDefinition,
    ];
    final changedDefinitions = [
      addressDefinition.copyWith(
        foreignKeys: [
          addressDefinition.foreignKeys.single.copyWith(
            onDelete: ForeignKeyAction.cascade,
          ),
        ],
      ),
    ];

    test(
      'when comparing the definition hashes '
      'then their hash values are different.',
      () {
        final baseHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: baseDefinitions,
        );

        final changedHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: changedDefinitions,
        );

        expect(changedHash, isNot(baseHash));
      },
    );
  });

  group('Given table definitions with different unique indexes', () {
    final baseDefinitions = [
      addressDefinition,
    ];
    final foreignKeyUniqueIndex = addressDefinition.indexes.singleWhere(
      (index) => index.indexName == 'address__inhabitantId__unique_idx',
    );
    final changedDefinitions = [
      addressDefinition.copyWith(
        indexes: [
          foreignKeyUniqueIndex.copyWith(
            elements: [
              for (final element in foreignKeyUniqueIndex.elements)
                element.definition == 'inhabitantId'
                    ? element.copyWith(definition: 'street')
                    : element,
            ],
          ),
        ],
      ),
    ];

    test(
      'when comparing the definition hashes '
      'then their hash values are different.',
      () {
        final baseHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: baseDefinitions,
        );

        final changedHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: changedDefinitions,
        );

        expect(changedHash, isNot(baseHash));
      },
    );
  });

  group('Given table definitions with different non-unique indexes', () {
    final baseDefinitions = [
      typesDefinition,
    ];
    final changedDefinitions = [
      typesDefinition.copyWith(
        indexes: [
          typesDefinition.indexes.single.copyWith(
            elements: [
              typesDefinition.indexes.single.elements.single.copyWith(
                definition: 'aText',
              ),
            ],
          ),
        ],
      ),
    ];

    test(
      'when comparing the definition hashes '
      'then their hash values are equal.',
      () {
        final baseHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: baseDefinitions,
        );

        final changedHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          tableDefinitions: changedDefinitions,
        );

        expect(changedHash, baseHash);
      },
    );
  });
}

extension on DatabaseSerializationManager {
  TableDefinition getTableDefinition(Table table) {
    return getTargetTableDefinitions()
        .firstWhere((def) => def.name == table.tableName)
        .copyWith();
  }
}
