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
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as _ipulbpi2;
import 'protocol.dart' as _il2as5qe;
import 'sync_tables.dart' as _ii3f3u05;
import 'package:serverpod_offline_sync_test_client/migrations/migration_registry.dart';

/// Passwordless auth endpoint used by the offline-sync demo app.
/// {@category Endpoint}
class EndpointDemoAuth extends _isc.EndpointRef {
  EndpointDemoAuth(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'demoAuth';

  /// Creates or reuses a demo auth user and returns its bearer token.
  _ida.Future<String> loginOrCreateUser(String username) =>
      caller.callServerEndpoint<String>(
        'demoAuth',
        'loginOrCreateUser',
        {'username': username},
      );
}

/// Read-only inspection endpoint used by the offline-sync demo app to show the
/// server's merged truth for the authenticated user's scope.
/// {@category Endpoint}
class EndpointDemoDebug extends _isc.EndpointRef {
  EndpointDemoDebug(_isc.EndpointCaller caller) : super(caller);

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
  _ida.Future<List<dynamic>> fetchScopeSnapshot({
    required bool includeHidden,
  }) => caller.callServerEndpoint<List<dynamic>>(
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
  _ida.Future<void> resetScope() => caller.callServerEndpoint<void>(
    'demoDebug',
    'resetScope',
    {},
  );

  /// Inserts demo rows of [kind] directly into the caller's scope on the server,
  /// without going through a replica. Lets the "Server" seed target exercise the
  /// fetch-from-scratch flow: seed here, reset a replica, then sync to pull it
  /// down. [text] carries an optional name/value for the single-row kinds.
  _ida.Future<void> seedScope(
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
    serverpod_auth_core = _iacc.Caller(client);
    serverpod_offline_sync = _ipulbpi2.Caller(client);
  }

  late final _iacc.Caller serverpod_auth_core;

  late final _ipulbpi2.Caller serverpod_offline_sync;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
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
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'demoAuth': demoAuth,
    'demoDebug': demoDebug,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
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
  _ida.Future<_isd.ClientDatabaseSession> createSession(
    String path, {
    bool runMigrations = true,
    bool isDebugMode = false,
  }) async {
    return await _isd.ClientDatabaseSession.open(
      path,
      _il2as5qe.Protocol(),
      clientMigrations: MigrationRegistry.migrations,
      runMigrations: runMigrations,
      isDebugMode: isDebugMode,
    );
  }

  /// Creates a new client-side database session for the given path, wrapped
  /// with the `serverpod_offline_sync` engine for the tables declared with
  /// `database: sync`. See [createSession] for the [path], [runMigrations] and
  /// [isDebugMode] parameters.
  ///
  /// The [persistentUserId] is the user all local operations belong to. When
  /// omitted, the user must be passed through the transaction.
  _ida.Future<_ipulbpi2.CrdtDatabaseSession> createSyncSession(
    String path, {
    bool runMigrations = true,
    bool isDebugMode = false,
    _isc.UuidValue? persistentUserId,
  }) async {
    final session = _ipulbpi2.CrdtDatabaseSession.wraps(
      await createSession(
        path,
        runMigrations: runMigrations,
        isDebugMode: isDebugMode,
      ),
      syncTables: _ii3f3u05.syncTables,
      persistentUserId: persistentUserId,
    );
    await session.db.initialize();
    return session;
  }
}
