// Diagnostic adapter only. Reuse Serverpod's exact method-stream implementation
// while changing the WebSocket compression negotiation. No wire protocol is
// reimplemented here, and production clients do not use this adapter.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
// ignore_for_file: invalid_use_of_visible_for_testing_member, public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_client/src/client_method_stream_manager.dart';
import 'package:serverpod_client/src/method_stream/method_stream_connection_details.dart';
import 'package:web_socket_channel/io.dart';

class CompressionProbe {
  static final _httpClient = HttpClient();

  CompressionProbe({
    required String target,
    required bool compression,
    required SerializationManager serializationManager,
    required ClientAuthKeyProvider authKeyProvider,
    required Stream<String> input,
    required Duration connectionTimeout,
  }) {
    final uri = Uri.parse(target);
    manager = ClientMethodStreamManager(
      connectionTimeout: connectionTimeout,
      webSocketHost: uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: '/v1/websocket',
      ),
      serializationManager: serializationManager,
      webSocketConnector: (address) => IOWebSocketChannel(
        WebSocket.connect(
          address.toString(),
          customClient: _HandshakeClient(
            _httpClient,
            (response) {
              httpStatusCode = response.statusCode;
              extensions = response.headers.value('Sec-WebSocket-Extensions') ?? '';
            },
          ),
          compression: compression
              ? CompressionOptions.compressionDefault
              : CompressionOptions.compressionOff,
        ).then((socket) {
          _socket = socket;
          return socket;
        }),
      ),
    );
    final details = MethodStreamConnectionDetails(
      endpoint: 'benchmark',
      method: 'echo',
      args: {},
      parameterStreams: {'messages': input},
      outputController: output,
      authKeyProvider: authKeyProvider,
    );
    unawaited(
      manager
          .openMethodStream(details)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              if (!output.isClosed) {
                output.addError(error, stack);
                unawaited(output.close());
              }
            },
          ),
    );
  }

  final output = StreamController<String>();
  late final ClientMethodStreamManager manager;
  String? extensions;
  int? httpStatusCode;
  WebSocket? _socket;

  int? get closeCode => _socket?.closeCode;

  Future<void> close() => manager.closeAllConnections();
}

// dart:io's WebSocket.extensions returns an empty string even when compression
// is negotiated in the pinned SDK. Observe the actual upgrade response instead.
// These diagnostic delegates implement only the HttpClient operations used by
// WebSocket.connect; unexpected operations fail rather than being approximated.
class _HandshakeClient implements HttpClient {
  _HandshakeClient(this.delegate, this.onResponse);

  final HttpClient delegate;
  final void Function(HttpClientResponse) onResponse;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _HandshakeRequest(await delegate.openUrl(method, url), onResponse);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HandshakeRequest implements HttpClientRequest {
  _HandshakeRequest(this.delegate, this.onResponse);

  final HttpClientRequest delegate;
  final void Function(HttpClientResponse) onResponse;

  @override
  HttpHeaders get headers => delegate.headers;

  @override
  Future<HttpClientResponse> close() async {
    final response = await delegate.close();
    onResponse(response);
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
