// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

typedef DiagnosticOutput = void Function(Map<String, dynamic> record);

/// Removes literals before a SQL fingerprint or statement is written to output.
/// Raw SQL is retained only by the server's bounded, read-only plan collector.
String sqlShape(String query) => query
    .replaceAll(RegExp("'(?:''|[^'])*'"), '?')
    .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), '?')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String sqlId(String shape) =>
    sha256.convert(utf8.encode(shape)).toString().substring(0, 16);

class _Phase {
  int micros = 0;
  int statements = 0;
  int rows = 0;
  int sqlMicros = 0;

  Map<String, dynamic> toJson() => {
    'micros': micros,
    'statements': statements,
    'affectedRows': rows,
    'sqlMicros': sqlMicros,
  };
}

class _Span {
  _Span(this.name, this.start, this.parent, this.data);

  final String name;
  final int start;
  final int? parent;
  final Map<String, Object?> data;
  final totals = <String, int>{};
  final transactions = <Map<String, dynamic>>[];
  Map<String, Object?>? queue;
  int? bodyStart;
  int? bodyEnd;
  String phase = 'body';
  int phaseStart = 0;
  final phases = <String, _Phase>{};
  final sqlIntervals = <(int, int)>[];
  final notifications = <Map<String, Object?>>[];
  int statements = 0;
  int rows = 0;
  int sqlMicros = 0;
}

/// One timeline per transport request. Storage is bounded even for long-lived
/// streams; aggregates remain complete when the detailed timeline is truncated.
class SyncTrace {
  SyncTrace({
    required this.side,
    required this.requestId,
    required this.runId,
    required this.userId,
    required this.deviceId,
    required this.once,
    required this.output,
    this.onMerge,
    this.detailLimit = 512,
    this.streamDetails = false,
    this.detailedSql = true,
    this.measurePayloadBytes = true,
    this.enabled = true,
    this.metadata = const {},
  });
  static final _traceKey = Object();
  static SyncTrace? get current => Zone.current[_traceKey] as SyncTrace?;

  final String side;
  final String requestId;
  final String runId;
  final String userId;
  final String deviceId;
  final bool once;
  final DiagnosticOutput output;
  final void Function(Map<String, dynamic> merge)? onMerge;
  final int detailLimit;
  final bool streamDetails;
  final bool detailedSql;
  final bool measurePayloadBytes;
  final bool enabled;
  final Map<String, Object?> metadata;
  final startedAt = DateTime.now().toUtc();
  final processOriginMicros = OfflineSyncDiagnostics.monotonicMicros;
  final watch = Stopwatch()..start();
  final _spans = <int, _Span>{};
  final _events = <Map<String, Object?>>[];
  final stages = <String, int>{};
  final totals = <String, int>{};
  final sql = <String, Map<String, dynamic>>{};
  final _wire = <String, Map<String, int>>{};
  final transactions = <Map<String, dynamic>>[];
  final transactionTotals = <String, int>{};
  String? peerNodeId;
  String _stage = 'beforeEngine';
  int _stageStart = 0;
  int _lastAt = 0;
  int droppedDetails = 0;
  int batchesReceived = 0;
  int batchesSent = 0;
  int batchesCommitted = 0;
  final _pendingBatches = <int, int>{};
  int merges = 0;
  bool finished = false;
  int? _lastTransactionEnd;
  Zone? _zone;

  Map<String, dynamic> get identity => {
    'side': side,
    'requestId': requestId,
    'runId': runId,
    'userId': userId,
    'deviceId': deviceId,
    'peerNodeId': peerNodeId,
    'once': once,
    'startedAt': startedAt.toIso8601String(),
    'processOriginMicros': processOriginMicros,
    ...metadata,
  };

  T run<T>(T Function() action) {
    if (!enabled) return action();
    if (_zone != null) return _zone!.run(action);
    return runZoned(
      () => OfflineSyncDiagnostics.run(observe, () {
        _zone = Zone.current;
        return action();
      }),
      zoneValues: {_traceKey: this},
    );
  }

  void observe(Map<String, Object?> incoming) {
    if (finished) return;
    final at = (incoming['processMicros']! as int) - processOriginMicros;
    final event = {...incoming, 'atMicros': at};
    _lastAt = at;
    final name = event['name']! as String;
    final kind = event['kind'];
    final data = event['data']! as Map<String, Object?>;
    final id = event['spanId'] as int?;
    final parent = event['parentId'] as int?;

    if (name != 'sql') {
      if (streamDetails) {
        output({'type': 'syncTimeline', ...identity, 'event': event});
      } else if (_events.length < detailLimit) {
        _events.add(event);
      } else {
        droppedDetails++;
        if (detailLimit > 1) {
          _events
            ..removeAt(detailLimit ~/ 4)
            ..add(event);
        }
      }
    }

    if (kind == 'start') {
      _spans[id!] = _Span(name, at, parent, data);
      return;
    }
    if (kind == 'end') {
      final span = _spans[id];
      if (span == null) return;
      final elapsed = at - span.start;
      totals.update(name, (v) => v + elapsed, ifAbsent: () => elapsed);
      final merge = _ancestor(span.parent, 'merge');
      merge?.totals.update(name, (v) => v + elapsed, ifAbsent: () => elapsed);
      if (name == 'transaction') {
        final record = _transaction(span, at, data['ok'] == true);
        _lastTransactionEnd = at;
        for (final key in [
          'micros',
          'connectionWaitAndBeginMicros',
          'bodyMicros',
          'commitOrRollbackAndReleaseMicros',
          'statements',
          'affectedRows',
          'sqlMicros',
          'sqlWallMicros',
          'unattributedBodyMicros',
        ]) {
          transactionTotals.update(
            key,
            (v) => v + (record[key] as int),
            ifAbsent: () => record[key] as int,
          );
        }
        if (streamDetails) {
          output({
            'type': 'syncTransaction',
            ...identity,
            'spanId': id,
            'parentId': span.parent,
            ...record,
          });
        }
        if (transactions.length < 64) transactions.add(record);
        if (merge != null && merge.transactions.length < 64) {
          merge.transactions.add(record);
        }
      }
      if (name == 'merge') {
        merges++;
        final record = <String, dynamic>{
          'type': 'mergeTrace',
          ...identity,
          ...span.data,
          'batchId': _ancestor(span.parent, 'sync.inboundBatch')?.data['batchId'],
          'startMicros': span.start,
          'endMicros': at,
          'micros': elapsed,
          'ok': data['ok'],
          'queue': span.queue,
          'timings': span.totals,
          'transactions': span.transactions,
          'commitNotifications': span.notifications,
        };
        output(record);
        onMerge?.call(record);
      }
      _spans.remove(id);
      return;
    }

    final transaction = _ancestor(parent, 'transaction');
    if (name == 'sync.commitNotification') {
      _ancestor(parent, 'merge')?.notifications.add(data);
    }
    if (name == 'queue.join') _ancestor(parent, 'merge')?.queue = data;
    if (name == 'transaction.body' && transaction != null) {
      transaction
        ..bodyStart = at
        ..phaseStart = at;
    }
    if (name == 'transaction.commitOrRollbackAndRelease' && transaction != null) {
      _endPhase(transaction, at);
      transaction.bodyEnd = at;
    }
    if (name == 'merge.phase' && transaction != null) {
      _endPhase(transaction, at);
      transaction
        ..phase = data['phase']! as String
        ..phaseStart = at;
    }
    if (name == 'sync.stage') {
      stages.update(
        _stage,
        (v) => v + at - _stageStart,
        ifAbsent: () => at - _stageStart,
      );
      _stage = data['phase']! as String;
      _stageStart = at;
    }
    if (name == 'sync.batchSent') {
      batchesSent++;
      _pendingBatches[data['batchId']! as int] = at;
    }
    if (name == 'sync.batchApplied') batchesReceived++;
    if (name == 'sync.batchCommitted') {
      batchesCommitted++;
      final sent = _pendingBatches.remove(data['batchId']);
      if (sent != null) {
        output({
          'type': 'syncBatchTrace',
          ...identity,
          'batchId': data['batchId'],
          'sentMicros': sent,
          'committedMicros': at,
          // Includes both transport directions and the peer's queue and merge.
          'acknowledgementWaitMicros': at - sent,
        });
      }
    }
    if (name == 'sync.peer') peerNodeId = data['peerNodeId']! as String;
    if (name == 'sql') {
      final micros = data['micros']! as int;
      final rows = data['rows'] as int? ?? 0;
      final key = data['sqlId']! as String;
      // Cap cardinality without dropping statement/time/row totals.
      final bucket = sql.containsKey(key) || sql.length < 64 ? key : 'other';
      final entry = sql.putIfAbsent(
        bucket,
        () => {
          'sqlId': bucket,
          'statement': bucket == 'other' ? null : data['statement'],
          'statements': 0,
          'micros': 0,
          'affectedRows': 0,
          'maxMicros': 0,
        },
      );
      entry['statements'] = (entry['statements'] as int) + 1;
      entry['micros'] = (entry['micros'] as int) + micros;
      entry['affectedRows'] = (entry['affectedRows'] as int) + rows;
      entry['maxMicros'] = max(entry['maxMicros'] as int, micros);
      if (transaction != null) {
        transaction
          ..statements += 1
          ..rows += rows
          ..sqlMicros += micros;
        // Merge intervals online: parallel statements are not double-counted
        // as wall time. Completion order need not equal start order.
        transaction.sqlIntervals.add((at - micros, at));
        transaction.phases.putIfAbsent(transaction.phase, _Phase.new)
          ..statements += 1
          ..rows += rows
          ..sqlMicros += micros;
      }
    }
  }

  _Span? _ancestor(int? id, String name) {
    var current = id;
    while (current != null) {
      final span = _spans[current];
      if (span == null) return null;
      if (span.name == name) return span;
      current = span.parent;
    }
    return null;
  }

  void _endPhase(_Span span, int at) {
    if (span.bodyStart == null || span.bodyEnd != null) return;
    (span.phases[span.phase] ??= _Phase()).micros += at - span.phaseStart;
    span.phaseStart = at;
  }

  Map<String, dynamic> _transaction(_Span span, int at, bool ok) {
    final start = span.bodyStart ?? at;
    final end = span.bodyEnd ?? at;
    _endPhase(span, end);
    var covered = 0;
    var previousEnd = start;
    for (final interval in span.sqlIntervals..sort((a, b) => a.$1.compareTo(b.$1))) {
      final left = max(start, max(previousEnd, interval.$1));
      final right = min(end, interval.$2);
      if (right > left) covered += right - left;
      previousEnd = max(previousEnd, right);
    }
    return {
      'startMicros': span.start,
      'endMicros': at,
      'micros': at - span.start,
      'ok': ok,
      'entered': span.bodyStart != null,
      'connectionWaitAndBeginMicros': start - span.start,
      'bodyMicros': end - start,
      'commitOrRollbackAndReleaseMicros': at - end,
      'statements': span.statements,
      'affectedRows': span.rows,
      'sqlMicros': span.sqlMicros,
      'sqlWallMicros': covered,
      'unattributedBodyMicros': max(0, end - start - covered),
      'phases': {for (final e in span.phases.entries) e.key: e.value.toJson()},
    };
  }

  void wire(Object event, {required String direction}) {
    final at = watch.elapsedMicroseconds;
    if (streamDetails) {
      final batchId = switch (event) {
        OfflineSyncMergeChunk() => event.batchId,
        OfflineSyncEndOfBatch() => event.batchId,
        OfflineSyncCommitted() => event.batchId,
        _ => null,
      };
      if (batchId != null) {
        output({
          'type': 'syncFrame',
          ...identity,
          'direction': direction,
          'frame': switch (event) {
            OfflineSyncMergeChunk() => 'chunk',
            OfflineSyncEndOfBatch() => 'end',
            OfflineSyncCommitted() => 'committed',
            _ => throw StateError('Unexpected numbered frame'),
          },
          'batchId': batchId,
          'processMicros': OfflineSyncDiagnostics.monotonicMicros,
          if (event is OfflineSyncMergeChunk) 'rounds': benchmarkRounds(event.changes),
        });
      }
    }
    final values = _wire.putIfAbsent(
      direction,
      () => {
        'events': 0,
        'changes': 0,
        'rows': 0,
        'payloadBytes': 0,
        'firstMicros': at,
        'lastMicros': at,
      },
    );
    values['events'] = values['events']! + 1;
    values['lastMicros'] = at;
    // Application JSON bytes, excluding WebSocket framing/compression and
    // transport envelopes. Encoding cost is measured separately.
    if (measurePayloadBytes) {
      final encoding = Stopwatch()..start();
      values['payloadBytes'] =
          values['payloadBytes']! + utf8.encode(jsonEncode(event)).length;
      values.update(
        'measurementMicros',
        (v) => v + encoding.elapsedMicroseconds,
        ifAbsent: () => encoding.elapsedMicroseconds,
      );
    }
    if (event is OfflineSyncMergeChunk) {
      values['changes'] = values['changes']! + event.changes.length;
      values['rows'] =
          values['rows']! +
          {
            for (final c in event.changes) (c.uuidSpaceId, c.tableName, c.uuidRowId),
          }.length;
    }
  }

  Map<String, dynamic> snapshot() => {
    'type': 'syncTrace',
    ...identity,
    'micros': watch.elapsedMicroseconds,
    'batchesReceived': batchesReceived,
    'batchesSent': batchesSent,
    'batchesCommitted': batchesCommitted,
    'pendingBatchIds': _pendingBatches.keys.toList(),
    'timingSemantics':
        'Independent worker spans can overlap; their sums are not an exclusive wall-time breakdown.',
    'merges': merges,
    'stage': _stage,
    'stageAgeMicros': max(0, watch.elapsedMicroseconds - _stageStart),
    'stages': stages,
    'timings': totals,
    'wire': _wire,
    'payloadBytesMeasured': measurePayloadBytes,
    'detailsStreamed': streamDetails,
    'sql': sql.values.toList(),
    'transactions': transactions,
    'transactionTotals': transactionTotals,
    'afterLastTransactionToLastYieldMicros':
        _lastTransactionEnd == null ||
            _wire['yielded'] == null ||
            _wire['yielded']!['lastMicros']! < _lastTransactionEnd!
        ? null
        : _wire['yielded']!['lastMicros']! - _lastTransactionEnd!,
    'timeline': _events,
    'droppedDetails': droppedDetails,
    ...progress(),
  };

  Map<String, dynamic> progress() => {
    'stage': _stage,
    'stageAgeMicros': max(0, watch.elapsedMicroseconds - _stageStart),
    'unfinishedSpans': [
      for (final s in _spans.values)
        {
          'name': s.name,
          'startMicros': s.start,
          if (s.name == 'transaction') ...{
            'phase': s.phase,
            'phaseAgeMicros': watch.elapsedMicroseconds - s.phaseStart,
            'callbackEntered': s.bodyStart != null,
            'callbackFinished': s.bodyEnd != null,
            'completedStatements': s.statements,
            'completedSqlMicros': s.sqlMicros,
            'lastSqlEndMicros': s.sqlIntervals.isEmpty ? null : s.sqlIntervals.last.$2,
          },
        },
    ],
  };

  void finish({required String outcome}) {
    if (finished || !enabled) return;
    final at = max(_lastAt, watch.elapsedMicroseconds);
    stages.update(
      _stage,
      (v) => v + at - _stageStart,
      ifAbsent: () => at - _stageStart,
    );
    finished = true;
    output({...snapshot(), 'outcome': outcome});
  }
}

/// Links the benchmark's authored Person sentinel to a frame without retaining
/// its payload. This is benchmark metadata, not a production protocol field.
List<Map<String, Object>> benchmarkRounds(Iterable<CrdtMergeChange> changes) {
  final identities = <(int, int)>{};
  for (final change in changes) {
    if (!{'person', 'city', 'town'}.contains(change.tableName)) continue;
    final markerColumn = change.tableName == 'person' ? 'surname' : 'name';
    final value = switch (change) {
      CrdtMergeInsert() => change.databaseColumns[markerColumn],
      CrdtMergeUpdate(:final columnName, :final value)
          when columnName == markerColumn =>
        value,
      _ => null,
    };
    if (value is! String) continue;
    final match = RegExp(
      r'^round:(-?\d+)/row:\d+/writer:(\d+)(?:/|$)',
    ).firstMatch(value);
    if (match == null) continue;
    identities.add((int.parse(match[1]!), int.parse(match[2]!)));
  }
  return [
    for (final (round, writer) in identities) {'round': round, 'writer': writer},
  ];
}
