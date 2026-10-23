import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_client/serverpod_client.dart';

/// Separately measures fresh WebSocket setup and warmed transport round trips.
/// This sends no sync requests and does not reuse connections between samples.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Usage: transport_probe.dart API_URL OUTPUT_JSON');
  }
  final api = Uri.parse(arguments[0]);
  final uri = api.replace(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    path: '/v1/websocket',
  );
  final samples = <Map<String, Object>>[];
  final serializer = _Serialization();

  for (var index = 0; index < 16; index++) {
    final timer = Stopwatch()..start();
    final socket = await WebSocket.connect(uri.toString()).timeout(
      const Duration(seconds: 10),
    );
    final setup = timer.elapsedMicroseconds;
    final inbound = StreamIterator<dynamic>(socket);
    final pings = <int>[];
    try {
      for (var ping = 0; ping < 4; ping++) {
        timer.reset();
        socket.add(PingCommand.buildMessage());
        if (!await inbound.moveNext().timeout(const Duration(seconds: 10))) {
          throw StateError('Socket closed before pong.');
        }
        final elapsed = timer.elapsedMicroseconds;
        final message = WebSocketMessage.fromJsonString(
          inbound.current as String,
          serializer,
        );
        if (message is! PongCommand) {
          throw StateError('Expected pong; received ${message.runtimeType}.');
        }
        pings.add(elapsed);
      }
    } finally {
      final closing = socket.close();
      await inbound.cancel();
      await closing.timeout(const Duration(seconds: 5));
    }
    samples.add({'freshSetupMicros': setup, 'pingRoundTripMicros': pings});
  }

  final report = {
    'startedFrom': Platform.localHostname,
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'target': uri.toString(),
    'samples': samples,
    'semantics':
        'Fresh setup includes DNS, TCP, TLS and HTTP upgrade. Ping round trips '
        'include transport, server dispatch and scheduling; no database or sync '
        'method is involved. Each sample uses a new WebSocket. This is a '
        'diagnostic probe, separate from syncOnce benchmark timings.',
  };
  await File(arguments[1]).writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln('Recorded ${samples.length} fresh connections and 64 round trips.');
}

class _Serialization extends SerializationManager {}
