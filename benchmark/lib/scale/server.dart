// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres_tls/postgres_tls.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    show AuthUser;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as sync;
// Reuse application models; the offline-sync package is used via public APIs.
// ignore: implementation_imports
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart';

import 'commit_hints.dart';
import 'common.dart'
    show
        AdminToken,
        UserTokenIdentity,
        benchmarkScope,
        classifyToken,
        defaultPasswordName,
        executableIdentity,
        processSample,
        sqliteFiles;
import 'diagnostics.dart' show sqlShape;
import 'runtime_diagnostics.dart';
import 'server_diagnostics.dart';
import 'tls_experiment.dart';
import 'verification.dart' show snapshotOf;

Map<String, bool>? _loadedSessionLogging;

/// An explicit benchmark control applied after framework configuration loading.
/// Leave unset to use the ordinary Serverpod logging configuration.
ServerpodConfig benchmarkServerConfig(ServerpodConfig loadedConfig) {
  var config = loadedConfig;
  final isolatedDatabase = Platform.environment['BENCHMARK_DATABASE'];
  if (isolatedDatabase != null) {
    validateCapacityDatabase(isolatedDatabase);
    final database = config.database! as PostgresDatabaseConfig;
    config = config.copyWith(database: database.withName(isolatedDatabase));
  }
  if (benchmarkSchema == 'city' &&
      !(isolatedDatabase?.startsWith('benchmark_capacity_city_') ?? false)) {
    throw StateError('The City-only registry requires an isolated capacity database.');
  }
  _loadedSessionLogging = {
    'persistentEnabled': config.sessionLogs.persistentEnabled,
    'consoleEnabled': config.sessionLogs.consoleEnabled,
  };
  final override = Platform.environment['BENCHMARK_SESSION_LOGGING'];
  if (override == null) return config;

  if (override != 'on' && override != 'off') {
    throw ArgumentError('BENCHMARK_SESSION_LOGGING must be on or off.');
  }

  final enabled = override == 'on';
  return config.copyWith(
    sessionLogs: config.sessionLogs.copyWith(
      persistentEnabled: enabled,
      consoleEnabled: enabled,
    ),
  );
}

/// Observation around the unmodified module's public endpoint dispatch. Events
/// and errors pass through unchanged; no engine state or merge code is accessed.
class StreamMetrics {
  StreamMetrics({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _open = <int, DateTime?>{};
  var opened = 0;
  var closed = 0;
  var failed = 0;
  var inboundChanges = 0;
  var outboundChanges = 0;

  /// Runs [start] with an inbound stream that counts merge chunks, and counts
  /// the chunks it emits.
  Stream<dynamic> observe(
    Stream<dynamic> Function(Map<String, Stream<dynamic>> streams) start,
    Map<String, Stream<dynamic>> streams,
  ) async* {
    final id = ++opened;
    _open[id] = null;
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      _open.remove(id);
      closed++;
    }

    try {
      void inspect(dynamic event, {required bool inbound}) {
        if (event is sync.OfflineSyncMergeChunk && event.changes.isNotEmpty) {
          _open[id] = _now().toUtc();
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
      // Delegate cancellation even while sync is waiting on database work.
      yield* start({...streams, 'changes': inbound})
          .map((event) {
            inspect(event, inbound: false);
            return event;
          })
          .transform(
            StreamTransformer<dynamic, dynamic>.fromHandlers(
              handleError: (error, stack, sink) {
                failed++;
                serverDiagnostics.add({
                  'type': 'serverStreamError',
                  'streamOrdinal': id,
                  'errorType': error.runtimeType.toString(),
                  'error': error.toString(),
                });
                finish();
                sink
                  ..addError(error, stack)
                  ..close();
              },
            ),
          );
    } catch (_) {
      failed++;
      rethrow;
    } finally {
      finish();
    }
  }

  Map<String, dynamic> sample() {
    final cutoff = _now().toUtc().subtract(const Duration(seconds: 2));
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

const countedTables = [
  'serverpod_auth_core_user',
  'person',
  'city',
  'town',
  'offline_sync_spaces',
  'crdt_nodes',
  'crdt_data_rows',
  'crdt_data_fields',
  'crdt_data_tombstone',
];

final _startedAt = DateTime.now().toUtc();
Future<Map<String, dynamic>>? _identity;

/// Non-secret provenance written by tool/prepare_cloud.dart into a prepared
/// server [directory], or null when the server was not prepared.
Map<String, dynamic>? preparedBuild([String directory = '.']) {
  final file = File('$directory/config/benchmark_build.json');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Each prepared export names its own secret password. Cloud's launch wizard
/// only imports passwords a project lacks, so a fixed name would keep an
/// earlier export's secret.
String benchmarkPasswordName([String directory = '.']) =>
    preparedBuild(directory)?['passwordName'] as String? ?? defaultPasswordName;

/// Non-secret facts about this server process, computed once. Connection
/// settings other than dialect and pool size are deliberately omitted.
final benchmarkSchema = Platform.environment['BENCHMARK_SCHEMA'] ?? 'full';

Future<Map<String, dynamic>> serverIdentity(Serverpod pod) => _identity ??= () async {
  final database = pod.config.database;
  return <String, dynamic>{
    'instanceId': '${Platform.localHostname}/$pid/${_startedAt.microsecondsSinceEpoch}',
    'diagnosticInstanceId': serverDiagnostics.instanceId,
    'hostname': Platform.localHostname,
    'pid': pid,
    'startedAt': _startedAt.toIso8601String(),
    'runMode': pod.runMode,
    'dialect': database?.dialect.name,
    'maxConnectionCount': database?.maxConnectionCount,
    'benchmarkSchema': benchmarkSchema,
    'benchmarkDatabase': Platform.environment['BENCHMARK_DATABASE'] ?? 'original',
    'tlsExperiment': {
      'variant': tlsExperimentVariant,
      'pipelineDepth': postgresPipelineDepth,
      'nativeConnectorInstalled':
          identical(postgresTlsConnector, nativeTlsConnector),
      'databaseRequiresSsl':
          database is PostgresDatabaseConfig ? database.requireSsl : null,
    },
    'processors': Platform.numberOfProcessors,
    'sessionLogging': {
      'beforeBenchmarkOverride': _loadedSessionLogging,
      'persistentEnabled': pod.config.sessionLogs.persistentEnabled,
      'consoleEnabled': pod.config.sessionLogs.consoleEnabled,
      'benchmarkOverride': Platform.environment['BENCHMARK_SESSION_LOGGING'],
      'persistentEnvironment':
          Platform.environment['SERVERPOD_SESSION_PERSISTENT_LOG_ENABLED'],
      'consoleEnvironment':
          Platform.environment['SERVERPOD_SESSION_CONSOLE_LOG_ENABLED'],
    },
    'executable': await executableIdentity(),
    'preparedSource': preparedBuild(),
  };
}();

class BenchmarkEndpoint extends Endpoint {
  BenchmarkEndpoint([StreamMetrics? metrics]) : metrics = metrics ?? StreamMetrics();

  final StreamMetrics metrics;

  @override
  bool get requireLogin => true;

  @override
  Set<Scope> get requiredScopes => {const Scope(benchmarkScope)};

  Future<String> control(Session session, String request) async {
    final input = jsonDecode(request) as Map<String, dynamic>;
    final result = switch (input['action']) {
      'provision' => await _provision(session, input),
      'configureSampling' => _configureSampling(input),
      'hintDelivery' => _configureHintDelivery(input),
      'hintStatus' => _hintStatus(),
      'snapshot' => await _snapshot(session, input),
      'metrics' => await _metrics(session, exact: input['exact'] == true),
      'diagnostics' => serverDiagnostics.read(
        input['tail'] == true
            ? serverDiagnostics.sequence
            : (input['cursors'] as Map?)?[serverDiagnostics.instanceId] as int? ?? 0,
      ),
      'runtime' => {
        'server': await serverIdentity(session.serverpod),
        'process': processSample(),
        'cpuCgroup': cpuCgroup.sample(),
        'memoryCgroup': memoryCgroup.sample(),
        'streams': metrics.sample(),
      },
      'databaseTransportProbe' => await databaseTransportProbe(session),
      'createCapacityDatabase' => await _createCapacityDatabase(session, input),
      'databaseDiagnostics' => await databaseDiagnostics(
        session,
        enable: input['enable'] == true,
      ),
      _ => throw ArgumentError('Unknown benchmark action'),
    };
    return jsonEncode(result);
  }

  Future<Map<String, dynamic>> _createCapacityDatabase(
    Session session,
    Map<String, dynamic> input,
  ) async {
    if (metrics.sample()['open'] != 0) {
      throw StateError('Close all streams before creating an experiment database.');
    }
    final name = input['name'] as String;
    validateCapacityDatabase(name);
    // The restrictive identifier validator excludes quotes and all SQL syntax.
    final existing = await session.db.unsafeQuery(
      "SELECT datname FROM pg_database WHERE datname = '$name'",
    );
    if (existing.isNotEmpty) {
      throw StateError('Experiment database already exists; use a new name.');
    }
    await session.db.unsafeExecute('CREATE DATABASE "$name"');
    return {'createdDatabase': name};
  }

  Map<String, dynamic> _hintStatus() => {
    'instanceId': serverDiagnostics.instanceId,
    'transport': benchmarkCommitHints?.status ?? {'enabled': false},
    'streams': metrics.sample(),
    'active': [for (final trace in serverDiagnostics.active.values) trace.identity],
  };

  Map<String, dynamic> _configureHintDelivery(Map<String, dynamic> input) {
    if (metrics.sample()['open'] != 0) {
      throw StateError('Close all sync streams before changing hint delivery.');
    }
    final hints = benchmarkCommitHints;
    if (hints == null) throw StateError('Commit hints are disabled.');
    hints.deliver = input['deliver'] as bool;
    return _hintStatus();
  }

  Map<String, dynamic> _configureSampling(Map<String, dynamic> input) {
    if (metrics.sample()['open'] != 0) {
      throw StateError('Close all sync streams before changing sampling.');
    }
    return {
      'instanceId': serverDiagnostics.instanceId,
      ...serverDiagnostics.configureSampling(input),
    };
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
        'person': benchmarkSchema == 'city'
            ? <Map<String, dynamic>>[]
            : (await Person.db.find(
                session,
                transaction: transaction,
              )).map((r) => r.toJson()).toList(),
        'city': (await City.db.find(
          session,
          transaction: transaction,
        )).map((r) => r.toJson()).toList(),
        'town': benchmarkSchema == 'city'
            ? <Map<String, dynamic>>[]
            : (await Town.db.find(
                session,
                transaction: transaction,
              )).map((r) => r.toJson()).toList(),
      });
    });
  }

  /// Exact counts scan whole tables, which competes with the workload on large
  /// PostgreSQL databases, so periodic samples use statistics estimates.
  Future<Map<String, dynamic>> _metrics(Session session, {required bool exact}) async {
    final timer = Stopwatch()..start();
    final db = session.db;
    final postgres = db.dialect == DatabaseDialect.postgres;
    final tables = <String, dynamic>{};
    if (exact || !postgres) {
      for (final table in countedTables) {
        final rows = await db.unsafeQuery('SELECT COUNT(*) FROM "$table"');
        tables[table] = rows.single.single;
      }
    } else {
      final names = countedTables.map((t) => "'$t'").join(', ');
      final rows = await db.unsafeQuery(
        'SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE relname IN ($names)',
      );
      for (final row in rows) {
        tables[row[0] as String] = row[1];
      }
    }
    final storage = <String, dynamic>{};
    if (postgres) {
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
      storage['transactions'] =
          (await db.unsafeQuery('''
SELECT pid, state, wait_event_type, wait_event,
       EXTRACT(EPOCH FROM (clock_timestamp() - xact_start)) * 1000 AS transaction_ms,
       EXTRACT(EPOCH FROM (clock_timestamp() - state_change)) * 1000 AS state_ms,
       query
FROM pg_stat_activity
WHERE datname = current_database() AND xact_start IS NOT NULL
ORDER BY xact_start LIMIT 32
'''))
              .map(
                (row) => {
                  'pid': row[0],
                  'state': row[1],
                  'waitEventType': row[2],
                  'waitEvent': row[3],
                  'transactionMs': row[4]?.toString(),
                  'stateMs': row[5]?.toString(),
                  'lastStatement': sqlShape(row[6] as String),
                },
              )
              .toList();
    } else {
      final config = session.serverpod.config.database! as SqliteDatabaseConfig;
      storage.addAll(sqliteFiles(config.filePath));
    }
    final identity = await serverIdentity(session.serverpod);
    return {
      'server': exact ? identity : {'instanceId': identity['instanceId']},
      'time': DateTime.now().toUtc().toIso8601String(),
      'backend': db.dialect.name,
      'process': processSample(),
      'cpuCgroup': cpuCgroup.sample(),
      'memoryCgroup': memoryCgroup.sample(),
      'streams': metrics.sample(),
      'commitHints': benchmarkCommitHints?.status ?? {'enabled': false},
      'tables': tables,
      'tableCountsExact': exact || !postgres,
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
      params: {
        ...original.params,
        'benchmarkDiagnostics': ParameterDescription(
          name: 'benchmarkDiagnostics',
          type: getType<bool?>(),
          nullable: true,
        ),
        for (final name in [
          'benchmarkRequestId',
          'benchmarkRunId',
          'benchmarkDeviceId',
        ])
          name: ParameterDescription(
            name: name,
            type: getType<String?>(),
            nullable: true,
          ),
      },
      streamParams: original.streamParams,
      returnType: original.returnType,
      call: (session, params, streams) => observeSyncRequest(
        session,
        params,
        streams,
        (observed) => metrics.observe(
          (counted) => original.call(session, params, counted) as Stream<dynamic>,
          observed,
        ),
      ),
    );
  }
}

/// Admin tokens carry the benchmark scope; user tokens must name a provisioned,
/// unblocked user. Each user authentication costs one AuthUser lookup.
AuthenticationHandler benchmarkAuthentication(String secret) => (session, token) async {
  switch (classifyToken(secret, token)) {
    case AdminToken():
      return AuthenticationInfo('benchmark-admin', {
        const Scope(benchmarkScope),
      }, authId: 'benchmark-admin');
    case UserTokenIdentity(:final userId):
      final user = await AuthUser.db.findById(session, userId);
      if (user == null || user.blocked) return null;
      return AuthenticationInfo(userId.toString(), {}, authId: userId.toString());
    case null:
      return null;
  }
};

/// Capacity tests may create new databases, never overwrite the deployed one.
void validateCapacityDatabase(String name) {
  if (name.length > 63 ||
      !RegExp(r'^benchmark_capacity_(city|full)_[a-z0-9_]+$').hasMatch(name)) {
    throw ArgumentError.value(
      name,
      'name',
      'Expected an isolated capacity database name.',
    );
  }
}
