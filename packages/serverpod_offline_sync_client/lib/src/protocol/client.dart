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
class EndpointCrdtSync extends _isc.EndpointRef {
  EndpointCrdtSync(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'serverpod_offline_sync.crdtSync';

  /// Opens a bidirectional CRDT sync session with the authenticated client.
  _ida.Stream<_icw2tu00.CrdtSyncStreamEvent> sync({
    required _ida.Stream<_icw2tu00.CrdtSyncStreamEvent> changes,
    required bool once,
  }) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_icw2tu00.CrdtSyncStreamEvent>,
        _icw2tu00.CrdtSyncStreamEvent
      >(
        'serverpod_offline_sync.crdtSync',
        'sync',
        {'once': once},
        {'changes': changes},
      );
}

class Caller extends _isc.ModuleEndpointCaller {
  Caller(_isc.ServerpodClientShared client) : super(client) {
    crdtSync = EndpointCrdtSync(this);
  }

  late final EndpointCrdtSync crdtSync;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'serverpod_offline_sync.crdtSync': crdtSync,
  };
}
