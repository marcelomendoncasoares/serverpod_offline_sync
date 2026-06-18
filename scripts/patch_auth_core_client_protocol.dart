import 'dart:io';

const _protocolPath =
    'test/serverpod_offline_sync_test_client/lib/src/protocol/protocol.dart';

void main() {
  final protocolFile = File(_protocolPath);
  if (!protocolFile.existsSync()) {
    stderr.writeln('Generated protocol file not found: $_protocolPath');
    exitCode = 1;
    return;
  }

  final original = protocolFile.readAsStringSync();
  var patched = original.replaceAllMapped(
    RegExp(
      r'\.\.\.(_i\d+)\.Protocol\(\) is (_i\d+)\.DatabaseSerializationManager\n'
      r'\s+\? \1\.Protocol\.targetTableDefinitions\n'
      r'\s+: \[\],',
    ),
    (match) {
      final modulePrefix = match[1]!;
      final databasePrefix = match[2]!;
      return '''
...$modulePrefix.Protocol() is $databasePrefix.DatabaseSerializationManager
        ? ($modulePrefix.Protocol() as $databasePrefix.DatabaseSerializationManager)
              .getTargetTableDefinitions()
        : [],''';
    },
  );

  patched = patched.replaceAllMapped(
    RegExp(
      r'\{\n'
      r'\s+var table = (_i\d+)\.Protocol\(\) is (_i\d+)\.DatabaseSerializationManager\n'
      r'\s+\? \1\.Protocol\(\)\.getTableForType\(t\)\n'
      r'\s+: null;\n'
      r'\s+if \(table != null\) \{\n'
      r'\s+return table;\n'
      r'\s+\}\n'
      r'\s+\}',
    ),
    (match) {
      final modulePrefix = match[1]!;
      final databasePrefix = match[2]!;
      return '''
{
      var protocol = $modulePrefix.Protocol();
      var table = protocol is $databasePrefix.DatabaseSerializationManager
          ? (protocol as $databasePrefix.DatabaseSerializationManager).getTableForType(t)
          : null;
      if (table != null) {
        return table;
      }
    }''';
    },
  );

  if (patched != original) {
    protocolFile.writeAsStringSync(patched);
  }
}
