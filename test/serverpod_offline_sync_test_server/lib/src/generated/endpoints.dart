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
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _izehhkf5;
import '../endpoints/demo_auth_endpoint.dart' as _il5og7ym;
import '../endpoints/demo_debug_endpoint.dart' as _ikfteyi1;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'demoAuth': _il5og7ym.DemoAuthEndpoint()
        ..initialize(
          server,
          'demoAuth',
          null,
        ),
      'demoDebug': _ikfteyi1.DemoDebugEndpoint()
        ..initialize(
          server,
          'demoDebug',
          null,
        ),
    };
    connectors['demoAuth'] = _is.EndpointConnector(
      name: 'demoAuth',
      endpoint: endpoints['demoAuth']!,
      methodConnectors: {
        'loginOrCreateUser': _is.MethodConnector(
          name: 'loginOrCreateUser',
          params: {
            'username': _is.ParameterDescription(
              name: 'username',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoAuth'] as _il5og7ym.DemoAuthEndpoint)
                  .loginOrCreateUser(
                    session,
                    params['username'],
                  ),
        ),
      },
    );
    connectors['demoDebug'] = _is.EndpointConnector(
      name: 'demoDebug',
      endpoint: endpoints['demoDebug']!,
      methodConnectors: {
        'fetchScopeSnapshot': _is.MethodConnector(
          name: 'fetchScopeSnapshot',
          params: {
            'includeHidden': _is.ParameterDescription(
              name: 'includeHidden',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoDebug'] as _ikfteyi1.DemoDebugEndpoint)
                  .fetchScopeSnapshot(
                    session,
                    includeHidden: params['includeHidden'],
                  ),
        ),
        'resetScope': _is.MethodConnector(
          name: 'resetScope',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoDebug'] as _ikfteyi1.DemoDebugEndpoint)
                  .resetScope(session),
        ),
        'seedScope': _is.MethodConnector(
          name: 'seedScope',
          params: {
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'text': _is.ParameterDescription(
              name: 'text',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoDebug'] as _ikfteyi1.DemoDebugEndpoint)
                  .seedScope(
                    session,
                    params['kind'],
                    params['text'],
                  ),
        ),
      },
    );
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_offline_sync'] = _izehhkf5.Endpoints()
      ..initializeEndpoints(server);
  }
}
