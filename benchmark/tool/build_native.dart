import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';

/// Builds a native bundle with `dart build cli` and writes `build-info.json`
/// beside it. The running executable trusts that source identity only while
/// the recorded hash matches its own, so a stale stamp is detected.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'target',
      defaultsTo: 'bin/scale.dart',
      allowed: ['bin/scale.dart', 'bin/scale_server.dart'],
    )
    ..addOption('output', help: 'Directory that receives bundle/.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final options = parser.parse(args);
  if (options['help'] as bool || options['output'] == null) {
    stdout.writeln(
      'dart run benchmark/tool/build_native.dart --output DIR\n${parser.usage}',
    );
    return;
  }
  final package = p.normalize(p.join(File.fromUri(Platform.script).parent.path, '..'));
  final target = options['target'] as String;
  final output = p.absolute(options['output'] as String);
  final source = await gitMetadata(package);
  final build = await Process.start(
    Platform.resolvedExecutable,
    ['build', 'cli', '--target', target, '--output', output],
    workingDirectory: package,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await build.exitCode;
  if (code != 0) {
    exitCode = code;
    return;
  }
  final executable = p.join(
    output,
    'bundle',
    'bin',
    p.basenameWithoutExtension(target),
  );
  final stamp = {
    'target': target,
    'builtAt': DateTime.now().toUtc().toIso8601String(),
    'dartVersion': Platform.version,
    'source': source,
    'executableSha256': await sha256OfFile(executable),
  };
  await File(
    p.join(output, 'bundle', 'build-info.json'),
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(stamp));
  stdout.writeln(
    'Built $executable from ${source['revision']}'
    '${source['dirty'] == true ? ' (dirty)' : ''}.',
  );
}
