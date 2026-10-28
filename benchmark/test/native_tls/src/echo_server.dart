import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'certificates.dart';

late Directory _certificates;

Future<void> prepareCertificates() async {
  _certificates = await createCertificates();
}

Future<void> removeCertificates() => _certificates.delete(recursive: true);

/// The test CA, PEM, which signed the server's certificate for localhost.
List<int> get caPem => File('${_certificates.path}/ca.pem').readAsBytesSync();

/// A stand-in for a Postgres server that echoes over TLS.
///
/// It answers an SSLRequest with [sslResponse], followed by [trailing],
/// and then runs dart:io's TLS server. After the handshake it echoes
/// every byte, and [received] completes with all of them once the client
/// closes.
final class EchoServer {
  EchoServer._(this._server, this.sslResponse, this.trailing);

  static Future<EchoServer> start({
    int sslResponse = 0x53,
    List<int> trailing = const [],
    bool closeAfterHandshake = false,
  }) async {
    final server = await RawServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final echo = EchoServer._(server, sslResponse, trailing)
      .._closeAfterHandshake = closeAfterHandshake;
    server.listen(echo._accept);
    return echo;
  }

  final RawServerSocket _server;
  final int sslResponse;
  final List<int> trailing;
  late final bool _closeAfterHandshake;
  final _received = BytesBuilder();
  final _done = Completer<Uint8List>();
  final _rawClients = <RawSocket>{};
  final _secureClients = <RawSecureSocket>{};
  var _closing = false;

  int get port => _server.port;

  /// Everything the client sent over TLS, once it closed.
  Future<Uint8List> get received => _done.future;

  static final _context = SecurityContext()
    ..useCertificateChain('${_certificates.path}/server.pem')
    ..usePrivateKey('${_certificates.path}/server.key');

  void _accept(RawSocket raw) {
    _rawClients.add(raw);
    final head = <int>[];
    // Ownership passes to RawSecureSocket.secureServer; closing the accepted
    // raw/secure sockets in close() tears down the corresponding subscription.
    // ignore: cancel_subscriptions
    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = raw.listen((event) async {
      if (event != RawSocketEvent.read) return;
      head.addAll(raw.read() ?? const []);
      if (head.length < 8) return;
      raw.write([sslResponse, ...trailing]);
      if (sslResponse != 0x53) return;
      final RawSecureSocket secure;
      try {
        secure = await RawSecureSocket.secureServer(
          raw,
          _context,
          subscription: subscription,
        );
      } on Object {
        await raw.close();
        return;
      }
      _rawClients.remove(raw);
      _secureClients.add(secure);
      if (_closeAfterHandshake || _closing) {
        await secure.close();
        return;
      }
      _echo(secure);
    });
  }

  void _echo(RawSecureSocket secure) {
    final pending = ListQueue<Uint8List>();
    var offset = 0;
    void flush() {
      while (pending.isNotEmpty) {
        final chunk = pending.first;
        offset += secure.write(chunk, offset);
        if (offset < chunk.length) {
          secure.writeEventsEnabled = true;
          return;
        }
        pending.removeFirst();
        offset = 0;
      }
    }

    secure.listen(
      (event) {
        switch (event) {
          case RawSocketEvent.read:
            final data = secure.read();
            if (data == null) return;
            _received.add(data);
            pending.add(data);
            if (pending.length == 1) flush();
          case RawSocketEvent.write:
            flush();
          case RawSocketEvent.readClosed:
          case RawSocketEvent.closed:
            if (!_done.isCompleted) _done.complete(_received.takeBytes());
            unawaited(secure.close());
        }
      },
      onError: (Object _) {
        if (!_done.isCompleted) _done.complete(_received.takeBytes());
      },
    );
  }

  Future<void> close() async {
    _closing = true;
    await _server.close();
    for (final client in _secureClients.toList()) {
      await client.close();
    }
    for (final client in _rawClients.toList()) {
      await client.close();
    }
  }
}
