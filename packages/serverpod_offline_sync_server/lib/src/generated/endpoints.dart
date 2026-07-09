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
import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/crdt_sync_endpoint.dart' as _i2;
import 'package:serverpod_offline_sync_client/src/protocol/sync/stream_event.dart'
    as _i3;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'crdtSync': _i2.CrdtSyncEndpoint()
        ..initialize(
          server,
          'crdtSync',
          'serverpod_offline_sync',
        ),
    };
    connectors['crdtSync'] = _i1.EndpointConnector(
      name: 'crdtSync',
      endpoint: endpoints['crdtSync']!,
      methodConnectors: {
        'sync': _i1.MethodStreamConnector(
          name: 'sync',
          params: {
            'once': _i1.ParameterDescription(
              name: 'once',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          streamParams: {
            'changes': _i1.StreamParameterDescription<_i3.CrdtSyncStreamEvent>(
              name: 'changes',
              nullable: false,
            ),
          },
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['crdtSync'] as _i2.CrdtSyncEndpoint).sync(
                session,
                changes: streamParams['changes']!
                    .cast<_i3.CrdtSyncStreamEvent>(),
                once: params['once'],
              ),
        ),
      },
    );
  }
}
