// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'common.dart' show LoopLag, processSample;
import 'diagnostics.dart';
import 'runtime_diagnostics.dart';

final serverDiagnostics = ServerDiagnostics();
final _enabled = Platform.environment['BENCHMARK_DIAGNOSTICS'] != 'off';

/// Reuses Serverpod's existing pool with a query-observing session. The nested
/// createDatabase call is guarded below, and CRDT interception is installed once.
Database benchmarkDatabaseInterceptor(Session session, Database database) {
  if (session is _QuerySession) return database;
  if (!_enabled) return offlineSyncDatabaseInterceptor(session, database);
  return offlineSyncDatabaseInterceptor(session, _QuerySession(session).inner);
}

class _QuerySession extends Session {
  _QuerySession(this.original)
    : super(server: original.server, enableLogging: false, endpoint: original.endpoint);

  final Session original;
  Database get inner => super.db;

  // Includes and any other adapter re-entry retain the original wrapped DB.
  @override
  Database get db => original.db;

  @override
  Transaction? get transaction => (original as DatabaseSession).transaction;

  @override
  LogWarningFunction? get logWarning => original.logWarning;

  @override
  LogQueryFunction get logQuery =>
      ({
        required query,
        required duration,
        required numRowsAffected,
        required error,
        required stackTrace,
      }) {
        if (OfflineSyncDiagnostics.enabled) {
          try {
            final detailed = SyncTrace.current?.detailedSql ?? true;
            final shape = detailed ? sqlShape(query) : null;
            final id = shape == null ? 'aggregate' : sqlId(shape);
            OfflineSyncDiagnostics.event('sql', {
              'sqlId': id,
              if (shape != null)
                'statement': shape.length > 2048
                    ? '${shape.substring(0, 2048)}...'
                    : shape,
              'micros': duration.inMicroseconds,
              'rows': numRowsAffected,
              'failed': error != null,
            });
            if (detailed) serverDiagnostics.query(id, query, duration);
          } on Object {
            serverDiagnostics.observationErrors++;
          }
        }
        original.logQuery?.call(
          query: query,
          duration: duration,
          numRowsAffected: numRowsAffected,
          error: error,
          stackTrace: stackTrace,
        );
      };
}

/// Only generated SELECT statements enter the replay collector. Read-only
/// transactions provide a second guard when EXPLAIN ANALYZE executes the query.
bool isReadOnlyPlanCandidate(String query) {
  final trimmed = query.trimLeft();
  if (RegExp(r'^SELECT\b', caseSensitive: false).hasMatch(trimmed)) return true;
  if (!RegExp(r'^WITH\b', caseSensitive: false).hasMatch(trimmed)) return false;

  final keywords = trimmed
      .replaceAll(RegExp("'(?:''|[^'])*'"), '')
      .replaceAll(RegExp('"(?:""|[^"])*"'), '');
  return !RegExp(
    r'\b(?:INSERT|UPDATE|DELETE|MERGE)\b',
    caseSensitive: false,
  ).hasMatch(keywords);
}

class ServerDiagnostics {
  ({String runId, Set<String> userIds})? sampling;

  Map<String, dynamic> configureSampling(Map<String, dynamic> input) {
    final users = (input['userIds'] as List).cast<String>().toSet();
    if (users.length > 16) throw ArgumentError('Sample at most 16 users.');
    for (final user in users) {
      UuidValue.withValidation(user);
    }
    final runId = input['runId'] as String;
    if (runId.isEmpty) throw ArgumentError('A sampling run id is required.');

    sampling = users.isEmpty ? null : (runId: runId, userIds: users);
    return {'runId': runId, 'userIds': users.toList(), 'enabled': users.isNotEmpty};
  }

  final instanceId = '${DateTime.now().toUtc().microsecondsSinceEpoch}-$pid';
  final records = Queue<Map<String, dynamic>>();
  final active = <String, SyncTrace>{};
  final hot = <String, ({String query, int micros})>{};
  final _fanout =
      <
        String,
        ({
          String requestId,
          String userId,
          String deviceId,
          int at,
          Set<String> recipients,
        })
      >{};
  final _clock = Stopwatch()..start();
  final _lag = LoopLag();
  Timer? _timer;
  var sequence = 0;
  var retainedBytes = 0;
  var evicted = 0;
  var observationErrors = 0;
  String vmMetrics = 'notStarted';
  int? isolateCount;
  WebSocket? _vm;
  var _rpc = 0;

  void add(Map<String, dynamic> record) {
    final row = {
      ...record,
      'instanceId': instanceId,
      'sequence': ++sequence,
      'time': DateTime.now().toUtc().toIso8601String(),
    };
    final encoded = jsonEncode(row);
    row['_bytes'] = utf8.encode(encoded).length;
    records.add(row);
    retainedBytes += row['_bytes'] as int;
    while (records.length > 4096 || retainedBytes > 16 * 1024 * 1024) {
      retainedBytes -= records.removeFirst()['_bytes'] as int;
      evicted++;
    }
    if (record['sampled'] != true &&
        (record['type'] == 'syncTrace' ||
            record['type'] == 'mergeTrace' ||
            record['type'] == 'slowSql')) {
      // Keep Cloud log entries compact; full timelines are available through
      // the authenticated collector and in the benchmark's events.jsonl.
      final line = Map<String, dynamic>.of(row)..remove('_bytes');
      if (record['type'] == 'syncTrace') {
        line
          ..remove('timeline')
          ..remove('transactions');
      }
      stdout.writeln(jsonEncode(line));
    }
  }

  void start() {
    if (_timer != null || !_enabled) return;
    _lag.start();
    unawaited(_connectVm());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      add({
        'type': 'serverProcess',
        'process': processSample(),
        'cpuCgroup': cpuCgroup.sample(),
        'loopLag': _lag.takeWindow(),
        'vmMetrics': vmMetrics,
        'observationErrors': observationErrors,
        'isolateCount': isolateCount,
        'gcPauses': null,
        'gcPauseCapability':
            'Use GC events when the VM service exposes timing; no pause inference from loop lag.',
        'activeRequests': [
          for (final trace in active.values.take(256))
            {
              ...trace.identity,
              'micros': trace.watch.elapsedMicroseconds,
              ...trace.progress(),
            },
        ],
        'activeRequestsTruncated': active.length > 256,
      });
      _vm?.add(jsonEncode({'jsonrpc': '2.0', 'id': '${++_rpc}', 'method': 'getVM'}));
    });
  }

  Future<void> _connectVm() async {
    try {
      final info = await developer.Service.getInfo();
      final uri = info.serverUri;
      if (uri == null) {
        vmMetrics = 'unavailable: VM service disabled (normal for AOT Cloud builds)';
        return;
      }
      _vm = await WebSocket.connect(
        uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
      );
      vmMetrics = 'connected';
      _vm!.listen(
        (message) {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final result = json['result'] as Map<String, dynamic>?;
          if (result?['type'] == 'VM') {
            isolateCount = (result!['isolates'] as List).length;
          }
          final params = json['params'] as Map<String, dynamic>?;
          if (params?['streamId'] == 'GC') {
            final event = params!['event'] as Map<String, dynamic>;
            add({
              'type': 'serverGc',
              'gcType': event['gcType'],
              'timestamp': event['timestamp'],
              'new': event['new'],
              'old': event['old'],
              'isolateId': (event['isolate'] as Map?)?['id'],
            });
          }
        },
        onError: (Object error) {
          vmMetrics = 'disconnected';
          _vm = null;
        },
        onDone: () {
          vmMetrics = 'disconnected';
          _vm = null;
        },
      );
      _vm!.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': '${++_rpc}',
          'method': 'streamListen',
          'params': {'streamId': 'GC'},
        }),
      );
    } on Object {
      vmMetrics = 'unavailable: local VM service connection failed';
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _lag.stop();
    await _vm?.close();
  }

  Map<String, dynamic> read(int after) {
    // Pagination bounds response size; clients keep a cursor per instance.
    final page = records.where((r) => (r['sequence'] as int) > after).take(64).toList();
    return {
      'instanceId': instanceId,
      'activeRequests': active.length,
      'oldestSequence': records.isEmpty ? sequence + 1 : records.first['sequence'],
      'latestSequence': sequence,
      'nextSequence': page.isEmpty ? after : page.last['sequence'],
      'evictedTotal': evicted,
      'records': [for (final r in page) Map<String, dynamic>.of(r)..remove('_bytes')],
    };
  }

  void query(String id, String query, Duration duration) {
    if (duration.inMilliseconds >= 100) {
      final trace = SyncTrace.current;
      add({
        'type': 'slowSql',
        ...?trace?.identity,
        'sqlId': id,
        'statement': sqlShape(query),
        'micros': duration.inMicroseconds,
      });
    }
    if (!isReadOnlyPlanCandidate(query) ||
        !RegExp('"(?:crdt_|offline_sync_)').hasMatch(query)) {
      return;
    }
    final previous = hot[id];
    if (previous != null && duration.inMicroseconds <= previous.micros) return;
    if (previous == null && hot.length >= 32) {
      final coldest = hot.entries.reduce(
        (a, b) => a.value.micros < b.value.micros ? a : b,
      );
      if (duration.inMicroseconds <= coldest.value.micros) return;
      hot.remove(coldest.key);
    }
    hot[id] = (query: query, micros: duration.inMicroseconds);
  }

  String _changeKey(CrdtMergeChange c) => jsonEncode([
    c.uuidSpaceId.toString(),
    c.tableName,
    c.uuidRowId.toString(),
    c.uuidNodeId.toString(),
    c.hlcDatetime.toIso8601String(),
    c.hlcCounter,
    c.runtimeType.toString(),
    if (c is CrdtMergeUpdate) c.columnName,
  ]);

  void committed(SyncTrace trace, Iterable<CrdtMergeChange> changes) {
    for (final change in changes) {
      final key = _changeKey(change);
      _fanout.putIfAbsent(
        key,
        () => (
          requestId: trace.requestId,
          userId: trace.userId,
          deviceId: trace.deviceId,
          at: _clock.elapsedMicroseconds,
          recipients: <String>{},
        ),
      );
    }
    while (_fanout.length > 10000) {
      _fanout.remove(_fanout.keys.first);
    }
  }

  void delivered(SyncTrace trace, Iterable<CrdtMergeChange> changes) {
    final deliveries = <String, List<int>>{};
    for (final change in changes) {
      final source = _fanout[_changeKey(change)];
      if (source == null ||
          source.requestId == trace.requestId ||
          (source.userId == trace.userId && source.deviceId == trace.deviceId) ||
          !source.recipients.add('${trace.userId}/${trace.deviceId}')) {
        continue;
      }
      (deliveries[source.requestId] ??= []).add(_clock.elapsedMicroseconds - source.at);
    }
    for (final entry in deliveries.entries) {
      add({
        'type': 'fanoutDelivery',
        ...trace.identity,
        'sourceRequestId': entry.key,
        'delivery': 'serverYieldToDevice',
        'changes': entry.value.length,
        'minCommitToYieldMicros': entry.value.reduce((a, b) => a < b ? a : b),
        'maxCommitToYieldMicros': entry.value.reduce((a, b) => a > b ? a : b),
      });
    }
  }
}

Stream<dynamic> observeSyncRequest(
  Session session,
  Map<String, dynamic> params,
  Map<String, Stream<dynamic>> streams,
  Stream<dynamic> Function(Map<String, Stream<dynamic>>) start,
) {
  if (!_enabled) return start(streams);
  final sampling = serverDiagnostics.sampling;
  final userId = session.authenticated!.userIdentifier;
  final sampled = sampling?.userIds.contains(userId) ?? false;
  if (sampling != null ? !sampled : params['benchmarkDiagnostics'] == false) {
    return start(streams);
  }
  final pending = <CrdtMergeChange>[];
  late SyncTrace trace;
  trace = SyncTrace(
    side: 'server',
    requestId: params['benchmarkRequestId'] as String? ?? session.sessionId.toString(),
    runId: sampled ? sampling!.runId : params['benchmarkRunId'] as String? ?? 'unknown',
    userId: userId,
    deviceId: params['benchmarkDeviceId'] as String? ?? session.sessionId.toString(),
    streamDetails: sampled,
    detailedSql: !sampled,
    measurePayloadBytes: !sampled,
    once: params['once'] == true,
    metadata: {
      'sampled': sampled,
      'requestArrivedAt': session.startTime.toUtc().toIso8601String(),
      'arrivalToDispatchMicros': DateTime.now()
          .difference(session.startTime)
          .inMicroseconds,
      'transport': 'stream',
      'fanoutMode': 'commitHintsWithPollingFallback',
    },
    output: serverDiagnostics.add,
    onMerge: (merge) {
      if (merge['ok'] != true) return;
      final changes = pending
          .where((c) => c.uuidSpaceId.toString() == merge['spaceId'])
          .toList();
      serverDiagnostics.committed(trace, changes);
      pending.removeWhere((c) => c.uuidSpaceId.toString() == merge['spaceId']);
    },
  );
  late StreamSubscription<dynamic> subscription;
  var completed = false;
  var outcome = 'cancelled';
  // The controller forwards cancellation immediately to the production stream.
  // ignore: close_sinks
  late StreamController<dynamic> controller;
  void finish() {
    trace.finish(outcome: outcome);
    serverDiagnostics.active.remove(trace.requestId);
  }

  controller = StreamController<dynamic>(
    onListen: () => trace.run(() {
      serverDiagnostics.active[trace.requestId] = trace;
      subscription =
          start({
            ...streams,
            'changes': streams['changes']!.map((event) {
              trace.wire(event as Object, direction: 'received');
              if (event is OfflineSyncMergeChunk) pending.addAll(event.changes);
              return event;
            }),
          }).listen(
            (event) {
              trace.wire(event as Object, direction: 'yielded');
              if (event is OfflineSyncMergeChunk) {
                serverDiagnostics.delivered(trace, event.changes);
              }
              controller.add(event);
            },
            onError: (Object error, StackTrace stack) {
              outcome = 'error';
              controller.addError(error, stack);
            },
            onDone: () {
              completed = true;
              if (outcome != 'error') outcome = 'completed';
              finish();
              unawaited(controller.close());
            },
          );
    }),
    onPause: () => subscription.pause(),
    onResume: () => subscription.resume(),
    onCancel: () async {
      if (completed) return;
      try {
        await trace.run(subscription.cancel);
      } finally {
        finish();
      }
    },
  );
  return controller.stream;
}

Future<Map<String, dynamic>> databaseDiagnostics(
  Session session, {
  bool enable = false,
}) async {
  if (session.db.dialect != DatabaseDialect.postgres) {
    return {'available': false, 'reason': 'notPostgreSQL'};
  }
  final db = session.db;
  final result = <String, dynamic>{
    'type': 'databaseDiagnostics',
    'plans': <Object>[],
    'pgStatStatementColumns': [
      'queryId',
      'calls',
      'executionMs',
      'rows',
      'sharedBlocksHit',
      'sharedBlocksRead',
      'tempBlocksWritten',
    ],
    'tableColumns': [
      'table',
      'estimatedLiveRows',
      'estimatedDeadRows',
      'sequentialScans',
      'sequentialRowsRead',
      'indexScans',
      'bytes',
    ],
  };
  try {
    result['roundTripProbe'] = await databaseRoundTripProbe(session);
  } on Object catch (error) {
    result['roundTripProbeUnavailable'] = error.toString();
  }
  try {
    if (enable) {
      await db.unsafeExecute('CREATE EXTENSION IF NOT EXISTS pg_stat_statements');
    }
    result['pgStatStatements'] = (await db.unsafeQuery('''
      SELECT queryid::text, calls, total_exec_time, rows, shared_blks_hit,
             shared_blks_read, temp_blks_written
      FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
        AND (query ILIKE '%crdt_%' OR query ILIKE '%offline_sync_%')
      ORDER BY total_exec_time DESC LIMIT 50
    ''')).toList();
  } on Object catch (error) {
    result['pgStatStatementsUnavailable'] = error.toString();
    result['fallback'] =
        'Application SQL timings; statements >= 100 ms are emitted as slowSql.';
  }
  result['tables'] = (await db.unsafeQuery('''
    SELECT relname, n_live_tup, n_dead_tup, seq_scan, seq_tup_read, idx_scan,
           pg_total_relation_size(relid) AS bytes
    FROM pg_stat_user_tables WHERE relname LIKE 'crdt_%' OR relname LIKE 'offline_sync_%'
    ORDER BY relname
  ''')).toList();
  final hot = serverDiagnostics.hot.entries.toList()
    ..sort((a, b) => b.value.micros.compareTo(a.value.micros));
  for (final entry in hot.take(8)) {
    // Plan the same SELECT predicates without taking application row locks.
    final select = entry.value.query.replaceAll(
      RegExp(
        r'\s+FOR (?:NO KEY UPDATE|KEY SHARE|UPDATE|SHARE)(?:\s+(?:NOWAIT|SKIP LOCKED))?',
        caseSensitive: false,
      ),
      '',
    );
    try {
      final plan = await db.transaction((tx) async {
        await db.unsafeExecute('SET TRANSACTION READ ONLY', transaction: tx);
        await db.unsafeExecute("SET LOCAL statement_timeout = '2s'", transaction: tx);
        return db.unsafeQuery(
          'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) $select',
          transaction: tx,
        );
      });
      (result['plans'] as List).add({
        'sqlId': entry.key,
        'statement': sqlShape(select),
        'rowLocksRemoved': select != entry.value.query,
        'plan': plan.toList(),
      });
    } on Object catch (error) {
      (result['plans'] as List).add({'sqlId': entry.key, 'error': error.toString()});
    }
  }
  return result;
}
