import 'dart:convert';
import 'dart:io';

// Serverpod currently exposes its SQL generator only through this library.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart' show DatabaseDefinition;

// The committed SQL targets SQLite. Render the current generated
// definition with the same PostgreSQL generator used by serverpod create-migration.
Future<void> preparePostgresMigrations(Directory serverDirectory) async {
  final versions = await File('migrations/migration_registry.txt').readAsLines();
  final version = versions.lastWhere((line) => line.trim().isNotEmpty);
  final source = Directory('migrations/$version');
  final target = Directory('${serverDirectory.path}/migrations/$version');
  await target.create(recursive: true);
  await for (final file in source.list()) {
    if (file is File) {
      await file.copy('${target.path}/${file.uri.pathSegments.last}');
    }
  }
  final definition = DatabaseDefinition.fromJson(
    jsonDecode(await File('${target.path}/definition.json').readAsString())
        as Map<String, dynamic>,
  );
  final sql = definition.toPgSql(installedModules: definition.installedModules);
  await File('${target.path}/definition.sql').writeAsString(sql);
  await File('${target.path}/migration.sql').writeAsString(sql);
  await File(
    '${serverDirectory.path}/migrations/migration_registry.txt',
  ).writeAsString('$version\n');
}
