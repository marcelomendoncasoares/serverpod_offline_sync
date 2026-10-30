// Local attribution probe. This is not a Cloud capacity measurement.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--server')) {
    await server();
    return;
  }

  if (args.length != 1) throw ArgumentError('Supply an output JSON path.');
  final results = <Map<String, dynamic>>[];

  for (final count in [256, 2048]) {
    for (final compression in [true, false]) {
      final child = await Process.start(Platform.resolvedExecutable, ['--server']);
      final replies = StreamIterator(
        child.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      final errors = child.stderr.transform(utf8.decoder).join();

      Future<Map<String, dynamic>> receive() async {
        if (!await replies.moveNext().timeout(const Duration(seconds: 30))) {
          throw StateError('Server closed before the expected observation.');
        }
        return jsonDecode(replies.current) as Map<String, dynamic>;
      }

      final sockets = <WebSocket>[];
      final closed = <Completer<void>>[];

      try {
        final ready = await receive();
        var next = 0;

        Future<void> openWorker() async {
          while (next < count) {
            final id = next++;
            final expected = 'connection-$id'.padRight(128, 'x');
            final socket = await WebSocket.connect(
              'ws://127.0.0.1:${ready['port']}/',
              compression: compression
                  ? CompressionOptions.compressionDefault
                  : CompressionOptions.compressionOff,
            );
            sockets.add(socket);
            final echo = Completer<void>();
            final done = Completer<void>();
            closed.add(done);
            socket.listen(
              (Object? message) {
                if (message != expected || echo.isCompleted) {
                  throw StateError('Unexpected or duplicate echo.');
                }
                echo.complete();
              },
              onError: echo.completeError,
              onDone: done.complete,
            );
            socket.add(expected);
            await echo.future.timeout(const Duration(seconds: 30));
          }
        }

        await Future.wait(List.generate(8, (_) => openWorker()));
        await Future<void>.delayed(const Duration(seconds: 5));
        child.stdin.writeln('sample');
        final opened = await receive();
        if (opened['open'] != count || opened['messages'] != count) {
          throw StateError('Incomplete server-side connection or echo count.');
        }
        if (opened['compressedHandshakes'] != (compression ? count : 0)) {
          throw StateError('Compression negotiation did not match the request.');
        }

        var closeIndex = 0;

        Future<void> closeWorker() async {
          while (closeIndex < sockets.length) {
            final index = closeIndex++;
            await sockets[index].close();
            await closed[index].future.timeout(const Duration(seconds: 30));
          }
        }

        await Future.wait(List.generate(64, (_) => closeWorker()));
        await Future<void>.delayed(const Duration(seconds: 5));
        child.stdin.writeln('sample');
        final drained = await receive();
        if (drained['open'] != 0) throw StateError('Server sockets did not drain.');
        final result = {
          'connections': count,
          'compressionRequested': compression,
          'idleSeconds': 5,
          'before': ready,
          'opened': opened,
          'afterClose': drained,
          'serverRssIncreaseBytes':
              (opened['rssBytes'] as int) - (ready['rssBytes'] as int),
        };
        results.add(result);
        stdout.writeln(jsonEncode(result));
        await File(args.single).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(results)}\n',
        );
      } finally {
        child.stdin.writeln('exit');
        await child.stdin.close();
        final exit = await child.exitCode.timeout(const Duration(seconds: 30));
        await replies.cancel();
        final stderr = await errors;
        if (exit != 0 || stderr.isNotEmpty) {
          throw StateError('Server exit $exit: $stderr');
        }
      }
    }
  }
}

Future<void> server() async {
  final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var open = 0;
  var messages = 0;
  var compressedHandshakes = 0;

  Map<String, dynamic> sample() => {
    'port': http.port,
    'open': open,
    'messages': messages,
    'compressedHandshakes': compressedHandshakes,
    'rssBytes': ProcessInfo.currentRss,
    'maxRssBytes': ProcessInfo.maxRss,
    'openFileDescriptors': Directory('/proc/self/fd').listSync().length,
  };

  http.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final negotiated = request.response.headers.value('Sec-WebSocket-Extensions');
    if (negotiated?.contains('permessage-deflate') == true) {
      compressedHandshakes++;
    }
    open++;
    socket.listen(
      (Object? message) {
        messages++;
        socket.add(message);
      },
      onDone: () => open--,
    );
  });
  stdout.writeln(jsonEncode(sample()));

  await for (final command
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (command == 'exit') break;
    if (command != 'sample') throw ArgumentError('Unexpected command.');
    stdout.writeln(jsonEncode(sample()));
  }

  await http.close(force: true);
}
