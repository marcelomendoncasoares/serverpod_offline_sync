// Uses serverpod_database types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

void main() {
  final syncTables = [client.Address.t, client.Person.t, client.Unique.t];
  final protocol = client.Protocol();

  group('Given real sync table definitions', () {
    test(
      'when table and schema element order differs then the hash is stable.',
      () {
        final addressDefinition = _definitionFor(protocol, client.Address.t);
        final personDefinition = _definitionFor(protocol, client.Person.t);
        final uniqueDefinition = _definitionFor(protocol, client.Unique.t);

        final leftManager = _SerializationManagerWithOverrides(
          protocol,
          [addressDefinition, personDefinition, uniqueDefinition],
        );
        final rightManager = _SerializationManagerWithOverrides(
          protocol,
          [
            uniqueDefinition.copyWith(
              columns: uniqueDefinition.columns.reversed.toList(),
            ),
            personDefinition.copyWith(
              columns: personDefinition.columns.reversed.toList(),
              foreignKeys: personDefinition.foreignKeys.reversed.toList(),
            ),
            addressDefinition.copyWith(
              indexes: addressDefinition.indexes.reversed.toList(),
            ),
          ],
        );

        final leftHash = CrdtSync.computeSyncTablesHash(
          syncTables,
          serializationManager: leftManager,
        );
        final rightHash = CrdtSync.computeSyncTablesHash(
          syncTables.reversed.toList(),
          serializationManager: rightManager,
        );

        expect(rightHash, leftHash);
      },
    );

    test(
      'when a table column differs then the hash changes.',
      () {
        final personDefinition = _definitionFor(protocol, client.Person.t);
        final changedManager = _SerializationManagerWithOverrides(
          protocol,
          [
            personDefinition.copyWith(
              columns: [
                ...personDefinition.columns,
                personDefinition.columns.last.copyWith(name: 'shadowColumn'),
              ],
            ),
          ],
        );

        final baseHash = CrdtSync.computeSyncTablesHash(
          [client.Person.t],
          serializationManager: protocol,
        );
        final changedHash = CrdtSync.computeSyncTablesHash(
          [client.Person.t],
          serializationManager: changedManager,
        );

        expect(changedHash, isNot(baseHash));
      },
    );

    test(
      'when a foreign key action differs then the hash changes.',
      () {
        final addressDefinition = _definitionFor(protocol, client.Address.t);
        final changedManager = _SerializationManagerWithOverrides(
          protocol,
          [
            addressDefinition.copyWith(
              foreignKeys: [
                addressDefinition.foreignKeys.single.copyWith(
                  onDelete: ForeignKeyAction.cascade,
                ),
              ],
            ),
            _definitionFor(protocol, client.Person.t),
          ],
        );

        final baseHash = CrdtSync.computeSyncTablesHash(
          [client.Address.t, client.Person.t],
          serializationManager: protocol,
        );
        final changedHash = CrdtSync.computeSyncTablesHash(
          [client.Address.t, client.Person.t],
          serializationManager: changedManager,
        );

        expect(changedHash, isNot(baseHash));
      },
    );

    test(
      'when a unique index definition differs then the hash changes.',
      () {
        final addressDefinition = _definitionFor(protocol, client.Address.t);
        final changedManager = _SerializationManagerWithOverrides(
          protocol,
          [
            addressDefinition.copyWith(
              indexes: [
                addressDefinition.indexes.single.copyWith(
                  elements: [
                    addressDefinition.indexes.single.elements.single.copyWith(
                      definition: 'street',
                    ),
                  ],
                ),
              ],
            ),
            _definitionFor(protocol, client.Person.t),
          ],
        );

        final baseHash = CrdtSync.computeSyncTablesHash(
          [client.Address.t, client.Person.t],
          serializationManager: protocol,
        );
        final changedHash = CrdtSync.computeSyncTablesHash(
          [client.Address.t, client.Person.t],
          serializationManager: changedManager,
        );

        expect(changedHash, isNot(baseHash));
      },
    );
  });
}

TableDefinition _definitionFor(
  DatabaseSerializationManager manager,
  Table table,
) {
  return manager
      .getTargetTableDefinitions()
      .firstWhere((definition) => definition.name == table.tableName)
      .copyWith();
}

class _SerializationManagerWithOverrides extends DatabaseSerializationManager {
  _SerializationManagerWithOverrides(
    this._delegate,
    List<TableDefinition> definitions,
  ) : _definitions = [
        for (final definition in definitions) definition.copyWith(),
      ];

  final DatabaseSerializationManager _delegate;
  final List<TableDefinition> _definitions;

  @override
  T deserialize<T>(dynamic data, [Type? t]) => _delegate.deserialize<T>(data, t);

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) =>
      _delegate.deserializeByClassName(data);

  @override
  String? getClassNameForObject(Object? data) => _delegate.getClassNameForObject(data);

  @override
  String getModuleName() => _delegate.getModuleName();

  @override
  Table? getTableForType(Type t) => _delegate.getTableForType(t);

  @override
  List<TableDefinition> getTargetTableDefinitions() => _definitions;
}
