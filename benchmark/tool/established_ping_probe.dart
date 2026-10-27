import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_offline_sync_benchmark/scale/elapsed_clock.dart';

/// An idle transport control, run after a workload has drained.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Usage: established_ping_probe.dart API_URL OUTPUT_JSON');
  }

  final output = File(args[1]);
  if (output.existsSync()) throw StateError('Choose a fresh output path.');
  final api = Uri.parse(args[0]);
  final socketUri = api.replace(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    path: '/v1/websocket',
  );
  final socket = await WebSocket.connect(
    socketUri.toString(),
  ).timeout(const Duration(seconds: 10));
  final inbound = StreamIterator<dynamic>(socket);
  final samples = <int>[];
  final started = DateTime.now().toUtc();
  try {
    for (var index = 0; index < 22; index++) {
      final clock = ElapsedClock()..start();
      socket.add(PingCommand.buildMessage());
      if (!await inbound.moveNext().timeout(const Duration(seconds: 10))) {
        throw StateError('Socket closed before pong.');
      }
      final elapsed = clock.elapsedMicroseconds;
      final message = WebSocketMessage.fromJsonString(
        inbound.current as String,
        _Serialization(),
      );
      if (message is! PongCommand) throw StateError('Expected pong.');
      if (index >= 2) samples.add(elapsed);
    }
  } finally {
    final closing = socket.close();
    await inbound.cancel();
    await closing.timeout(const Duration(seconds: 5));
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'startedAt': started.toIso8601String(),
        'elapsedClock': ElapsedClock.source,
        'samplesMicros': samples,
        'warmupPingsExcluded': 2,
        'semantics':
            'One established TLS WebSocket, Serverpod ping/pong, no SQL; '
            'includes both network directions and transport dispatch. '
            'Connection setup and two warmup pings excluded. Run at idle.',
      }),
    );
  }
}

class _Serialization extends SerializationManager {}
