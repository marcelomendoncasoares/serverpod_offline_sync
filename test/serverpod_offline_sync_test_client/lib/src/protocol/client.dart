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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i3;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as _i4;
import 'package:http/http.dart' as _i5;
import 'protocol.dart' as _i6;
import 'package:serverpod_database/serverpod_database.dart' as _i7;
import 'package:serverpod_offline_sync_test_client/migrations/migration_registry.dart';

/// Passwordless auth endpoint used by the offline-sync demo app.
/// {@category Endpoint}
class EndpointDemoAuth extends _i1.EndpointRef {
  EndpointDemoAuth(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'demoAuth';

  /// Creates or reuses a demo auth user and returns its bearer token.
  _i2.Future<String> loginOrCreateUser(String username) =>
      caller.callServerEndpoint<String>(
        'demoAuth',
        'loginOrCreateUser',
        {'username': username},
      );
}

/// Read-only inspection endpoint used by the offline-sync demo app to show the
/// server's merged truth for the authenticated user's scope.
/// {@category Endpoint}
class EndpointDemoDebug extends _i1.EndpointRef {
  EndpointDemoDebug(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'demoDebug';

  /// Returns every synced domain row in the caller's scope on the server as a
  /// flat list of models. When [includeHidden] is true, the list also includes
  /// CRDT-hidden rows (conflict losers, soft-deleted rows) via the
  /// `t.includeHiddenRows` expression; otherwise only visible rows are returned.
  ///
  /// The rows cross the wire as `dynamic`: Serverpod tags each model with its
  /// class name — the same mechanism the CRDT sync layer uses — so the client
  /// deserializes them straight back into typed models with no per-table
  /// plumbing on either side. The client flags hidden rows by diffing a
  /// visible-only fetch against an include-hidden one.
  _i2.Future<List<dynamic>> fetchScopeSnapshot({required bool includeHidden}) =>
      caller.callServerEndpoint<List<dynamic>>(
        'demoDebug',
        'fetchScopeSnapshot',
        {'includeHidden': includeHidden},
      );

  /// Clears the caller's scope by deleting its `crdt_scopes` row. Every synced
  /// table cascades on `scopeId` → `crdt_scopes`, so all domain rows and CRDT
  /// metadata are removed with it — no manual per-table cleanup needed.
  ///
  /// The delete runs with `defer_foreign_keys` on: the scopeId cascade fans out
  /// across the CRDT metadata diamond (`crdt_data_rows`/`crdt_data_fields`/
  /// `crdt_data_tombstone` reference `crdt_nodes` with NO ACTION while both sides
  /// cascade off `crdt_scopes`), and SQLite's cascade order can transiently
  /// violate those immediate checks. Deferring them to commit lets the whole
  /// cascade complete first.
  _i2.Future<void> resetScope() => caller.callServerEndpoint<void>(
    'demoDebug',
    'resetScope',
    {},
  );

  /// Inserts demo rows of [kind] directly into the caller's scope on the server,
  /// without going through a replica. Lets the "Server" seed target exercise the
  /// fetch-from-scratch flow: seed here, reset a replica, then sync to pull it
  /// down. [text] carries an optional name/value for the single-row kinds.
  _i2.Future<void> seedScope(
    String kind,
    String? text,
  ) => caller.callServerEndpoint<void>(
    'demoDebug',
    'seedScope',
    {
      'kind': kind,
      'text': text,
    },
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_core = _i3.Caller(client);
    serverpod_offline_sync = _i4.Caller(client);
  }

  late final _i3.Caller serverpod_auth_core;

  late final _i4.Caller serverpod_offline_sync;
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i5.Client? httpClientOverride,
  }) : super(
         host,
         _i6.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    demoAuth = EndpointDemoAuth(this);
    demoDebug = EndpointDemoDebug(this);
    modules = Modules(this);
  }

  late final EndpointDemoAuth demoAuth;

  late final EndpointDemoDebug demoDebug;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'demoAuth': demoAuth,
    'demoDebug': demoDebug,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_core': modules.serverpod_auth_core,
    'serverpod_offline_sync': modules.serverpod_offline_sync,
  };

  /// Creates a new client-side database session for the given path.
  ///
  /// The [path] is the file path to the SQLite database file. Since SQLite uses
  /// WAL mode, note that `[path]-shm` and `[path]-wal` files might also exist
  /// transiently for the database while the session is open.
  ///
  /// If [runMigrations] is true, pending migrations will be applied when
  /// opening the database. Be careful when setting this to false, as it might
  /// lead to inconsistencies between the models and the database.
  ///
  /// If [isDebugMode] is true, the database integrity will be verified after
  /// the migrations are applied to provide feedback of possible issues. On a
  /// Flutter application, this should be set to [kDebugMode].
  _i2.Future<_i7.ClientDatabaseSession> createSession(
    String path, {
    bool runMigrations = true,
    bool isDebugMode = false,
  }) async {
    return await _i7.ClientDatabaseSession.open(
      path,
      _i6.Protocol(),
      clientMigrations: MigrationRegistry.migrations,
      runMigrations: runMigrations,
      isDebugMode: isDebugMode,
    );
  }
}
