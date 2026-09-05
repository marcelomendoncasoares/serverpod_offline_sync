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
import 'dart:io' as _idi;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _izehhkf5;
import 'endpoints.dart' as _iavctuc6;
import 'protocol.dart' as _il2as5qe;
import 'sync_tables.dart' as _ii3f3u05;
export 'package:serverpod/serverpod.dart' hide Serverpod;

/// The Serverpod server for this project.
///
/// Pre-configured with the generated Protocol serialization manager and
/// Endpoints, so a server can be created with just the command line
/// arguments:
///
/// ```dart
/// final pod = Serverpod(args);
/// ```
///
/// The `serverpod_offline_sync` engine is initialized with the tables
/// declared with `database: sync`, wrapping any provided
/// [databaseInterceptor] with `crdtDatabaseInterceptor`.
class Serverpod extends _is.Serverpod {
  Serverpod(
    List<String> args, {
    _idi.Directory? serverDirectory,
    _is.ServerpodConfig? config,
    _is.ServerpodConfig Function(_is.ServerpodConfig)? configOverride,
    _is.AuthenticationHandler? authenticationHandler,
    _is.HealthCheckHandler? healthCheckHandler,
    _is.HealthConfig? healthConfig,
    _is.Headers? httpResponseHeaders,
    _is.Headers? httpOptionsResponseHeaders,
    _is.SecurityContextConfig? securityContextConfig,
    _is.ExperimentalFeatures? experimentalFeatures,
    _is.RuntimeParametersListBuilder? runtimeParametersBuilder,
    _is.DatabaseInterceptor? databaseInterceptor,
  }) : super(
         args,
         _il2as5qe.Protocol(),
         _iavctuc6.Endpoints(),
         serverDirectory: serverDirectory,
         config: config,
         configOverride: configOverride,
         authenticationHandler: authenticationHandler,
         healthCheckHandler: healthCheckHandler,
         healthConfig: healthConfig,
         httpResponseHeaders: httpResponseHeaders,
         httpOptionsResponseHeaders: httpOptionsResponseHeaders,
         securityContextConfig: securityContextConfig,
         experimentalFeatures: experimentalFeatures,
         runtimeParametersBuilder: runtimeParametersBuilder,
         databaseInterceptor:
             (
               session,
               inner,
             ) => _izehhkf5.crdtDatabaseInterceptor(
               session,
               databaseInterceptor?.call(
                     session,
                     inner,
                   ) ??
                   inner,
             ),
       ) {
    initializeCrdtSync(syncTables: _ii3f3u05.syncTables);
  }
}
