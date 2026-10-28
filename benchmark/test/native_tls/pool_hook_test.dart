import 'dart:io';

import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_shared/serverpod_shared.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given a postgresTlsConnector and a config that requires SSL, '
    'when the pool opens a connection, '
    'then it connects through the connector with SslMode.require.',
    () async {
      final calls = <(String, int, pg.SslMode)>[];
      postgresTlsConnector = (host, port, {required sslMode, required timeout}) async {
        calls.add((host, port, sslMode));
        throw const SocketException('Refused by the test connector');
      };
      addTearDown(() => postgresTlsConnector = null);

      final poolManager =
          DatabaseProvider.forDialect(DatabaseDialect.postgres).createPoolManager(
            _TestSerializationManager(),
            null,
            PostgresDatabaseConfig(
              host: 'db.example.com',
              port: 5432,
              user: 'postgres',
              password: 'password',
              name: 'serverpod_test',
              requireSsl: true,
            ),
          )..start();
      addTearDown(poolManager.stop);

      await expectLater(poolManager.testConnection(), throwsA(anything));
      expect(calls, [('db.example.com', 5432, pg.SslMode.require)]);
    },
  );
}

class _TestSerializationManager extends DatabaseSerializationManager {
  @override
  String getModuleName() => 'test';

  @override
  Table? getTableForType(Type t) => null;

  @override
  List<TableDefinition> getTargetTableDefinitions() => const [];
}
