import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

class SpaceCachePeer {
  SpaceCachePeer._(this._process) {
    _responses = StreamIterator(
      _process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.startsWith('{')),
    );
    _stderr = _process.stderr.transform(utf8.decoder).join();
  }

  final Process _process;
  late final StreamIterator<String> _responses;
  late final Future<String> _stderr;
  late final int pid;

  static Future<SpaceCachePeer> start(
    Directory server,
    PostgresDatabaseConfig config,
  ) async {
    final peer = SpaceCachePeer._(
      await Process.start(
        Platform.resolvedExecutable,
        ['run', 'test/integration/test_tools/space_cache_peer.dart'],
        workingDirectory: server.path,
      ),
    );
    try {
      final ready = await peer.command({
        'action': 'open',
        'host': config.host,
        'port': config.port,
        'user': config.user,
        'password': config.password,
        'name': config.name,
        'isUnixSocket': config.isUnixSocket,
      });
      peer.pid = ready['pid'] as int;
      return peer;
    } on Object {
      peer._process.kill(ProcessSignal.sigkill);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> command(Map<String, Object?> message) async {
    _process.stdin.writeln(jsonEncode(message));
    if (!await _responses.moveNext().timeout(const Duration(seconds: 30))) {
      throw StateError('Space peer exited: ${await _stderr}');
    }
    final response = jsonDecode(_responses.current) as Map<String, dynamic>;
    if (response['error'] != null) {
      throw StateError('${response['error']}\n${response['stack']}');
    }
    return response;
  }

  Future<Set<String>> read(UuidValue user) async {
    final response = await command({'action': 'read', 'userUuid': user.uuid});
    return (response['names'] as List).cast<String>().toSet();
  }

  Future<void> close() async {
    try {
      await command({'action': 'close'});
      await _process.stdin.close();
      await _process.exitCode.timeout(const Duration(seconds: 10));
    } finally {
      _process.kill(ProcessSignal.sigkill);
      await _responses.cancel();
    }
  }
}
