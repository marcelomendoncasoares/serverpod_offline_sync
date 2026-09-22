import 'dart:convert';
import 'dart:io';

// The CLI is already a workspace tooling dependency.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
// The database package is provided by the workspace's test server.
// ignore: depend_on_referenced_packages
import 'package:serverpod_database/serverpod_database.dart';

/// Generates a PostgreSQL test schema from the stored Serverpod definitions.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Expected the server directory and output directory.');
  }
  final project = Directory(arguments[0]);
  final target = Directory(arguments[1]);
  await Directory('${target.path}/config').create(recursive: true);
  await for (final file in Directory('${project.path}/config').list()) {
    if (file is File) {
      await file.copy('${target.path}/config/${file.uri.pathSegments.last}');
    }
  }
  final versions = await Directory(
    '${project.path}/migrations',
  ).list().where((entry) => entry is Directory).cast<Directory>().toList();
  versions.sort((a, b) => a.path.compareTo(b.path));
  final latest = versions.last;
  final version = latest.uri.pathSegments.where((s) => s.isNotEmpty).last;
  final destination = Directory('${target.path}/migrations/$version');
  await destination.create(recursive: true);
  await for (final file in latest.list()) {
    if (file is File && file.path.endsWith('.json')) {
      await file.copy('${destination.path}/${file.uri.pathSegments.last}');
    }
  }
  final definition = DatabaseDefinition.fromJson(
    jsonDecode(await File('${latest.path}/definition.json').readAsString())
        as Map<String, dynamic>,
  );
  final sql = PostgresSqlGenerator().generateDatabaseDefinitionSql(
    definition,
    installedModules: definition.installedModules,
  );
  await File('${destination.path}/definition.sql').writeAsString(sql);
  await File('${destination.path}/migration.sql').writeAsString(sql);
  await File(
    '${target.path}/migrations/migration_registry.txt',
  ).writeAsString('$version\n');
}
