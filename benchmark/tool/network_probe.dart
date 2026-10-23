import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_client/serverpod_client.dart';

/// Measures fresh connections separately from database-free endpoint work.
/// Credentials are read from the environment and never written to the report.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Usage: network_probe.dart API_URL OUTPUT_JSON');
  }
  final secret = Platform.environment['BENCHMARK_SECRET'];
  if (secret == null || secret.isEmpty) {
    throw StateError('BENCHMARK_SECRET is required for the control endpoint.');
  }
  final api = Uri.parse(arguments[0]);
  final socketUri = api.replace(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    path: '/v1/websocket',
  );
  final samples = <Map<String, Object>>[];

  final output = File(arguments[1]);
  if (output.existsSync()) throw StateError('Choose a fresh output path.');
  final startedAt = DateTime.now().toUtc().toIso8601String();

  for (var index = 0; index < 16; index++) {
    final sample = <String, Object>{};
    samples.add(sample);
    var operation = '';
    try {
      // Alternate order. Every operation owns a fresh client and connection.
      final order = index.isEven ? ['http', 'webSocket'] : ['webSocket', 'http'];
      for (final next in order) {
        operation = next;
        sample[next] = next == 'http'
            ? await _http(api, secret)
            : await _streaming(socketUri);
      }
    } on Object catch (error) {
      sample['failure'] = {
        'operation': operation,
        'type': error.runtimeType.toString(),
      };
      rethrow;
    } finally {
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'startedAt': startedAt,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'target': api.toString(),
          'samples': samples,
          'semantics': {
            'connectionReadyMicros':
                'HTTP setup through request creation, including DNS, TCP and TLS.',
            'requestMicros': 'HTTP send, server dispatch, response and local decoding.',
            'http': 'Existing authenticated diagnostics-tail endpoint; no SQL or sync.',
            'pingRoundTripMicros':
                'Transport and dispatch on the established WebSocket; no SQL.',
            'limitations':
                'Both transports use Dart default connectors. WebSocket setup includes '
                'its HTTP upgrade; HTTP setup ends at request creation. These '
                'measurements are not substituted for syncOnce timings. Connections are '
                'fresh, but resolver and TLS caches are not cleared. Partial results '
                'and failures are retained.',
          },
        }),
      );
    }
  }
  stdout.writeln('Recorded 16 fresh HTTP and WebSocket connections.');
}

Future<Map<String, Object>> _http(Uri api, String secret) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final timer = Stopwatch()..start();
  try {
    final request = await client.postUrl(api.resolve('/benchmark/control'));
    final connectionReady = timer.elapsedMicroseconds;
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $secret');
    request.write(
      jsonEncode({
        'request': jsonEncode({'action': 'diagnostics', 'tail': true}),
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Control endpoint returned ${response.statusCode}.');
    }
    jsonDecode(body);
    final total = timer.elapsedMicroseconds;
    return {
      'totalMicros': total,
      'connectionReadyMicros': connectionReady,
      'requestMicros': total - connectionReady,
    };
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object>> _streaming(Uri uri) async {
  final timer = Stopwatch()..start();
  final socket = await WebSocket.connect(
    uri.toString(),
  ).timeout(const Duration(seconds: 10));
  final setup = timer.elapsedMicroseconds;
  final inbound = StreamIterator<dynamic>(socket);
  final pings = <int>[];
  try {
    for (var index = 0; index < 4; index++) {
      timer.reset();
      socket.add(PingCommand.buildMessage());
      if (!await inbound.moveNext().timeout(const Duration(seconds: 10))) {
        throw StateError('Socket closed before pong.');
      }
      final elapsed = timer.elapsedMicroseconds;
      final message = WebSocketMessage.fromJsonString(
        inbound.current as String,
        _Serialization(),
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
  return {'totalMicros': setup, 'pingRoundTripMicros': pings};
}

class _Serialization extends SerializationManager {}
