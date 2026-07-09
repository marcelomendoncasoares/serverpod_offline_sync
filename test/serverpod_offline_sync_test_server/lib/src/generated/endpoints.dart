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
import '../endpoints/demo_auth_endpoint.dart' as _i2;
import '../endpoints/demo_debug_endpoint.dart' as _i3;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i4;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _i5;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'demoAuth': _i2.DemoAuthEndpoint()
        ..initialize(
          server,
          'demoAuth',
          null,
        ),
      'demoDebug': _i3.DemoDebugEndpoint()
        ..initialize(
          server,
          'demoDebug',
          null,
        ),
    };
    connectors['demoAuth'] = _i1.EndpointConnector(
      name: 'demoAuth',
      endpoint: endpoints['demoAuth']!,
      methodConnectors: {
        'loginOrCreateUser': _i1.MethodConnector(
          name: 'loginOrCreateUser',
          params: {
            'username': _i1.ParameterDescription(
              name: 'username',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoAuth'] as _i2.DemoAuthEndpoint)
                  .loginOrCreateUser(
                    session,
                    params['username'],
                  ),
        ),
      },
    );
    connectors['demoDebug'] = _i1.EndpointConnector(
      name: 'demoDebug',
      endpoint: endpoints['demoDebug']!,
      methodConnectors: {
        'fetchScopeSnapshot': _i1.MethodConnector(
          name: 'fetchScopeSnapshot',
          params: {
            'includeHidden': _i1.ParameterDescription(
              name: 'includeHidden',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoDebug'] as _i3.DemoDebugEndpoint)
                  .fetchScopeSnapshot(
                    session,
                    includeHidden: params['includeHidden'],
                  ),
        ),
        'resetScope': _i1.MethodConnector(
          name: 'resetScope',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['demoDebug'] as _i3.DemoDebugEndpoint)
                  .resetScope(session),
        ),
        'seedScope': _i1.MethodConnector(
          name: 'seedScope',
          params: {
            'kind': _i1.ParameterDescription(
              name: 'kind',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'text': _i1.ParameterDescription(
              name: 'text',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['demoDebug'] as _i3.DemoDebugEndpoint).seedScope(
                    session,
                    params['kind'],
                    params['text'],
                  ),
        ),
      },
    );
    modules['serverpod_auth_core'] = _i4.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_offline_sync'] = _i5.Endpoints()
      ..initializeEndpoints(server);
  }
}
