import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/prepare_cloud.dart' show copyServerSources;

void main() {
  late Directory scratch;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('benchmark-source-export-');
  });

  tearDownAll(() async {
    await scratch.delete(recursive: true);
  });

  group('Given server sources with nested and conditional local dependencies,', () {
    late Directory source;
    late Directory output;

    setUpAll(() async {
      source = Directory(p.join(scratch.path, 'source'));
      output = Directory(p.join(scratch.path, 'output'));
      final sources = {
        'bin/scale_server.dart':
            "import 'package:serverpod_offline_sync_benchmark/scale/server.dart';\n",
        'lib/scale/server.dart':
            "import 'nested/hints.dart';\n"
            "export 'fallback.dart' if (dart.library.io) 'native.dart';\n"
            "part 'state.dart';\n",
        'lib/scale/nested/hints.dart': "import '../server.dart';\n",
        'lib/scale/fallback.dart': '// fallback\n',
        'lib/scale/native.dart': '// native\n',
        'lib/scale/state.dart': "part of 'server.dart';\n",
        'lib/scale/client_only.dart': '// not reachable from the server\n',
      };
      for (final entry in sources.entries) {
        final file = File(p.join(source.path, 'benchmark', entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
      }
    });

    group('when the server sources are exported,', () {
      late Set<String> files;
      late String entrypoint;

      setUpAll(() async {
        await copyServerSources(source, output);
        files = {
          await for (final entity in output.list(recursive: true))
            if (entity is File) p.relative(entity.path, from: output.path),
        };
        entrypoint = await File(
          p.join(output.path, 'bin/main.dart'),
        ).readAsString();
      });

      test('then every reachable source is included once.', () {
        expect(files, {
          'bin/main.dart',
          'lib/scale/server.dart',
          'lib/scale/nested/hints.dart',
          'lib/scale/fallback.dart',
          'lib/scale/native.dart',
          'lib/scale/state.dart',
        });
      });

      test('then the entrypoint addresses the exported server package.', () {
        expect(
          entrypoint,
          "import 'package:serverpod_offline_sync_test_server/scale/server.dart';\n",
        );
      });
    });
  });
}
