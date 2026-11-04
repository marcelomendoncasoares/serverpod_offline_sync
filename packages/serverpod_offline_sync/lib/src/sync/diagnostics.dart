import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';

/// A synchronous, best-effort consumer of optional sync measurements.
///
/// Consumers must avoid I/O and expensive work in this callback. Exceptions
/// from a consumer are ignored so diagnostics cannot change sync semantics.
typedef OfflineSyncDiagnosticSink = void Function(Map<String, Object?> event);

/// Opt-in measurements scoped to one asynchronous operation, including streams
/// subscribed inside [run]. Events omit domain payloads and SQL, but may include
/// user, space and node identifiers supplied by instrumented operations.
/// Durations use a monotonic clock local to the operation, not wall-clock time.
class OfflineSyncDiagnostics {
  OfflineSyncDiagnostics._(this._sink);

  static final _key = Object();
  static final _spanKey = Object();
  static final _processClock = Stopwatch()..start();
  final OfflineSyncDiagnosticSink _sink;
  final _originMicros = monotonicMicros;
  var _nextId = 0;

  /// A shared monotonic timestamp for correlations within this isolate.
  /// It has no wall-clock meaning and cannot be compared across processes.
  static int get monotonicMicros => _processClock.elapsedMicroseconds;

  /// Whether the current asynchronous operation has a diagnostics consumer.
  static bool get enabled => Zone.current[_key] != null;

  /// Runs [action] with a new monotonic timeline, inherited by its async work.
  static T run<T>(OfflineSyncDiagnosticSink sink, T Function() action) => runZoned(
    action,
    zoneValues: {_key: OfflineSyncDiagnostics._(sink), _spanKey: null},
  );

  /// Emits a point-in-time observation. Values must be JSON serializable.
  static void event(String name, [Map<String, Object?> data = const {}]) {
    final diagnostics = Zone.current[_key] as OfflineSyncDiagnostics?;
    diagnostics?._emit(
      name,
      'event',
      data,
      parentId: Zone.current[_spanKey] as int?,
    );
  }

  void _emit(
    String name,
    String kind,
    Map<String, Object?> data, {
    required int? parentId,
    int? id,
  }) {
    try {
      final now = monotonicMicros;
      _sink({
        'name': name,
        'kind': kind,
        'atMicros': now - _originMicros,
        'processMicros': now,
        'spanId': id,
        'parentId': parentId,
        'data': data,
      });
    } on Object {
      // An observer is never part of the transaction's success contract.
    }
  }

  /// Times [action], retaining its result, exception and cancellation behavior.
  static Future<T> measure<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object?> data = const {},
  }) {
    final diagnostics = Zone.current[_key] as OfflineSyncDiagnostics?;
    if (diagnostics == null) return action();

    final id = ++diagnostics._nextId;
    final parent = Zone.current[_spanKey] as int?;
    diagnostics._emit(name, 'start', data, id: id, parentId: parent);
    return runZoned(() async {
      var ok = false;
      try {
        final result = await action();
        ok = true;
        return result;
      } finally {
        diagnostics._emit(name, 'end', {'ok': ok}, id: id, parentId: parent);
      }
    }, zoneValues: {_spanKey: id});
  }

  /// Measures the transaction boundary supported by Serverpod's public API.
  /// Callback entry occurs after pool acquisition AND BEGIN. Completion after
  /// the callback includes commit/rollback and connection release. Neither is
  /// claimed to be a measurement of a driver operation in isolation.
  static Future<T> transaction<T>(
    Database database,
    TransactionFunction<T> action, {
    TransactionSettings? settings,
  }) {
    if (!enabled) return database.transaction(action, settings: settings);

    return measure('transaction', () async {
      event('transaction.connectionWaitAndBegin');
      var entered = false;
      try {
        return await database.transaction((transaction) async {
          entered = true;
          event('transaction.body');
          try {
            return await action(transaction);
          } finally {
            event('transaction.commitOrRollbackAndRelease');
          }
        }, settings: settings);
      } finally {
        event('transaction.finished', {'entered': entered});
      }
    });
  }
}
