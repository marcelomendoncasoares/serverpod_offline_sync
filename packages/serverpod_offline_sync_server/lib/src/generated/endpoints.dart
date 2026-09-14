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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import '../endpoints/offline_sync_endpoint.dart' as _i3x2h4cf;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'offlineSync': _i3x2h4cf.OfflineSyncEndpoint()
        ..initialize(
          server,
          'offlineSync',
          'serverpod_offline_sync',
        ),
    };
    connectors['offlineSync'] = _is.EndpointConnector(
      name: 'offlineSync',
      endpoint: endpoints['offlineSync']!,
      methodConnectors: {
        'sync': _is.MethodStreamConnector(
          name: 'sync',
          params: {
            'once': _is.ParameterDescription(
              name: 'once',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          streamParams: {
            'changes':
                _is.StreamParameterDescription<
                  _icw2tu00.OfflineSyncStreamEvent
                >(
                  name: 'changes',
                  nullable: false,
                ),
          },
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['offlineSync'] as _i3x2h4cf.OfflineSyncEndpoint)
                  .sync(
                    session,
                    changes: streamParams['changes']!
                        .cast<_icw2tu00.OfflineSyncStreamEvent>(),
                    once: params['once'],
                  ),
        ),
      },
    );
  }
}
