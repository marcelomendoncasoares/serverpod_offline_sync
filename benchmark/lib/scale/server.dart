// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    show AuthUser;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as sync;
// Reuse application models; the offline-sync package is used via public APIs.
// ignore: implementation_imports
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart';

import 'common.dart'
    show
        benchmarkScope,
        constantTimeEqual,
        processSample,
        snapshotOf,
        sqliteFiles,
        userToken;

/// Observation around the unmodified module's public endpoint dispatch. Events
/// and errors pass through unchanged; no engine state or merge code is accessed.
class StreamMetrics {
  final _open = <int, DateTime?>{};
  var opened = 0;
  var closed = 0;
  var failed = 0;
  var inboundChanges = 0;
  var outboundChanges = 0;

  Stream<dynamic> observe(
    MethodStreamConnector original,
    Session session,
    Map<String, dynamic> params,
    Map<String, Stream<dynamic>> streams,
  ) async* {
    final id = ++opened;
    _open[id] = null;
    try {
      void inspect(dynamic event, {required bool inbound}) {
        if (event is sync.OfflineSyncMergeChunk && event.changes.isNotEmpty) {
          _open[id] = DateTime.now().toUtc();
          if (inbound) {
            inboundChanges += event.changes.length;
          } else {
            outboundChanges += event.changes.length;
          }
        }
      }

      final inbound = streams['changes']!.map((event) {
        inspect(event, inbound: true);
        return event;
      });
      final output =
          original.call(session, params, {...streams, 'changes': inbound}) as Stream;
      await for (final event in output) {
        inspect(event, inbound: false);
        yield event;
      }
    } catch (_) {
      failed++;
      rethrow;
    } finally {
      _open.remove(id);
      closed++;
    }
  }

  Map<String, dynamic> sample() {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(seconds: 2));
    final active = _open.values
        .where((time) => time != null && time.isAfter(cutoff))
        .length;
    return {
      'open': _open.length,
      'active': active,
      'idle': _open.length - active,
      'activityWindowMs': 2000,
      'openedTotal': opened,
      'closedTotal': closed,
      'failedTotal': failed,
      'inboundChanges': inboundChanges,
      'outboundChanges': outboundChanges,
    };
  }
}

class BenchmarkEndpoint extends Endpoint {
  BenchmarkEndpoint(this.metrics);

  final StreamMetrics metrics;

  @override
  bool get requireLogin => true;

  @override
  Set<Scope> get requiredScopes => {const Scope(benchmarkScope)};

  Future<String> control(Session session, String request) async {
    final input = jsonDecode(request) as Map<String, dynamic>;
    final result = switch (input['action']) {
      'provision' => await _provision(session, input),
      'snapshot' => await _snapshot(session, input),
      'metrics' => await _metrics(session),
      _ => throw ArgumentError('Unknown benchmark action'),
    };
    return jsonEncode(result);
  }

  Future<Map<String, dynamic>> _provision(
    Session session,
    Map<String, dynamic> input,
  ) async {
    final id = UuidValue.withValidation(input['userId'] as String);
    // An existing identity is an error: silently reusing it would mix runs.
    await AuthUser.db.insertRow(
      session,
      AuthUser(id: id, scopeNames: {'offline-sync-benchmark-user'}),
    );
    return {'userId': id.toString()};
  }

  Future<Map<String, dynamic>> _snapshot(
    Session session,
    Map<String, dynamic> input,
  ) async {
    final id = UuidValue.withValidation(input['userId'] as String);
    final db = session.db as sync.OfflineSyncDatabase;
    return db.transactionForUser(id, (transaction) async {
      return snapshotOf({
        'person': (await Person.db.find(
          session,
          transaction: transaction,
        )).map((r) => r.toJson()).toList(),
        'city': (await City.db.find(
          session,
          transaction: transaction,
        )).map((r) => r.toJson()).toList(),
        'town': (await Town.db.find(
          session,
          transaction: transaction,
        )).map((r) => r.toJson()).toList(),
      });
    });
  }

  Future<Map<String, dynamic>> _metrics(Session session) async {
    final timer = Stopwatch()..start();
    final db = session.db;
    final tables = <String, dynamic>{};
    // Read-only storage inspection outside the workload; exact counts can be
    // costly. The sample reports its own duration so this overhead is visible.
    for (final table in [
      'serverpod_auth_core_user',
      'person',
      'city',
      'town',
      'offline_sync_spaces',
      'crdt_nodes',
      'crdt_data_rows',
      'crdt_data_fields',
      'crdt_data_tombstone',
    ]) {
      final rows = await db.unsafeQuery('SELECT COUNT(*) FROM "$table"');
      tables[table] = rows.single.single;
    }
    final storage = <String, dynamic>{};
    if (db.dialect == DatabaseDialect.postgres) {
      storage['databaseBytes'] = (await db.unsafeQuery(
        'SELECT pg_database_size(current_database())',
      )).single.single;
      storage['relations'] =
          (await db.unsafeQuery('''
SELECT relname, pg_total_relation_size(relid), n_live_tup, n_dead_tup
FROM pg_stat_user_tables ORDER BY relname
'''))
              .map(
                (row) => {
                  'table': row[0],
                  'totalBytes': row[1],
                  'estimatedLiveRows': row[2],
                  'estimatedDeadRows': row[3],
                },
              )
              .toList();
      storage['connections'] =
          (await db.unsafeQuery('''
SELECT state, wait_event_type, COUNT(*) FROM pg_stat_activity
WHERE datname = current_database() GROUP BY state, wait_event_type
'''))
              .map((row) => {'state': row[0], 'waitEventType': row[1], 'count': row[2]})
              .toList();
    } else {
      final config = session.serverpod.config.database! as SqliteDatabaseConfig;
      storage.addAll(sqliteFiles(config.filePath));
    }
    return {
      'instance': Platform.localHostname,
      'time': DateTime.now().toUtc().toIso8601String(),
      'backend': db.dialect.name,
      'process': processSample(),
      'streams': metrics.sample(),
      'tables': tables,
      'storage': storage,
      'collectionMicros': timer.elapsedMicroseconds,
    };
  }
}

/// Small JSON control plane uses only core wire types, avoiding changes to the
/// reused project's generated client, test helpers, schema, and migrations.
class BenchmarkEndpoints extends EndpointDispatch {
  final metrics = StreamMetrics();

  @override
  void initializeEndpoints(Server server) {
    final endpoint = BenchmarkEndpoint(metrics)..initialize(server, 'benchmark', null);
    connectors['benchmark'] = EndpointConnector(
      name: 'benchmark',
      endpoint: endpoint,
      methodConnectors: {
        'control': MethodConnector(
          name: 'control',
          params: {
            'request': ParameterDescription(
              name: 'request',
              type: getType<String>(),
              nullable: false,
            ),
          },
          call: (session, params) =>
              endpoint.control(session, params['request'] as String),
        ),
      },
    );
    final module = sync.Endpoints()..initializeEndpoints(server);
    modules['serverpod_offline_sync'] = module;
    final connector = module.connectors['offlineSync']!;
    final original = connector.methodConnectors['sync']! as MethodStreamConnector;
    connector.methodConnectors['sync'] = MethodStreamConnector(
      name: original.name,
      params: original.params,
      streamParams: original.streamParams,
      returnType: original.returnType,
      call: (session, params, streams) =>
          metrics.observe(original, session, params, streams),
    );
  }
}

AuthenticationHandler benchmarkAuthentication(String secret) => (session, token) async {
  if (constantTimeEqual(token, secret)) {
    return AuthenticationInfo('benchmark-admin', {
      const Scope(benchmarkScope),
    }, authId: 'benchmark-admin');
  }
  final parts = token.split('.');
  if (parts.length != 2 || !constantTimeEqual(token, userToken(secret, parts.first))) {
    return null;
  }
  final UuidValue id;
  try {
    id = UuidValue.withValidation(parts.first);
  } on FormatException {
    return null;
  }
  final user = await AuthUser.db.findById(session, id);
  if (user == null || user.blocked) return null;
  return AuthenticationInfo(id.toString(), {}, authId: id.toString());
};
