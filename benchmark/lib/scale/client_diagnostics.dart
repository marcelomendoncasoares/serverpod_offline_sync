// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'diagnostics.dart';

/// Correlation is confined to the benchmark's connector. Ordinary generated
/// clients and the production offline-sync protocol remain compatible.
class DiagnosticClient extends Client {
  DiagnosticClient(super.host, {this.diagnosticsEnabled = true});

  final bool diagnosticsEnabled;

  /// Optional benchmark observer, installed before opening a sampled stream.
  void Function(Object event, String direction)? onSyncFrame;

  @override
  dynamic callStreamingServerEndpoint<T, G>(
    String endpoint,
    String method,
    Map<String, dynamic> args,
    Map<String, Stream> streams, {
    bool authenticated = true,
  }) {
    if (endpoint != 'serverpod_offline_sync.offlineSync' || method != 'sync') {
      return super.callStreamingServerEndpoint<T, G>(
        endpoint,
        method,
        args,
        streams,
        authenticated: authenticated,
      );
    }

    final trace = diagnosticsEnabled ? SyncTrace.current : null;
    final observer = onSyncFrame;
    final parameters = {
      ...args,
      if (!diagnosticsEnabled) 'benchmarkDiagnostics': false,
      if (trace != null) ...{
        'benchmarkRequestId': trace.requestId,
        'benchmarkRunId': trace.runId,
        'benchmarkDeviceId': trace.deviceId,
      },
    };
    if (trace == null && observer == null) {
      return super.callStreamingServerEndpoint<T, G>(
        endpoint,
        method,
        parameters,
        streams,
        authenticated: authenticated,
      );
    }

    if (trace != null) OfflineSyncDiagnostics.event('client.requestDispatched');
    final response =
        super.callStreamingServerEndpoint<T, G>(
              endpoint,
              method,
              parameters,
              {
                for (final entry in streams.entries)
                  entry.key: entry.value.map((dynamic event) {
                    observer?.call(event as Object, 'sent');
                    trace?.wire(event as Object, direction: 'sent');
                    return event;
                  }),
              },
              authenticated: authenticated,
            )
            as Stream<G>;
    return response.map((event) {
      observer?.call(event as Object, 'received');
      trace?.wire(event as Object, direction: 'received');
      return event;
    });
  }
}
