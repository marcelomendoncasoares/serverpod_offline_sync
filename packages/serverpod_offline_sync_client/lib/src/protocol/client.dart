/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;

/// Endpoint for CRDT-based offline-first synchronization.
/// {@category Endpoint}
class EndpointOfflineSync extends _isc.EndpointRef {
  EndpointOfflineSync(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'serverpod_offline_sync.offlineSync';

  /// Opens a bidirectional CRDT sync session with the authenticated client.
  _ida.Stream<_icw2tu00.OfflineSyncStreamEvent> sync({
    required _ida.Stream<_icw2tu00.OfflineSyncStreamEvent> changes,
    required bool once,
  }) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_icw2tu00.OfflineSyncStreamEvent>,
        _icw2tu00.OfflineSyncStreamEvent
      >(
        'serverpod_offline_sync.offlineSync',
        'sync',
        {'once': once},
        {'changes': changes},
      );
}

class Caller extends _isc.ModuleEndpointCaller {
  Caller(_isc.ServerpodClientShared client) : super(client) {
    offlineSync = EndpointOfflineSync(this);
  }

  late final EndpointOfflineSync offlineSync;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'serverpod_offline_sync.offlineSync': offlineSync,
  };
}
