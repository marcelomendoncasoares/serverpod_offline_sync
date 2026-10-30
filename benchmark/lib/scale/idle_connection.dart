// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'elapsed_clock.dart';

/// Verifies a unique response on the existing connection, without reconnecting.
class IdleConnection {
  IdleConnection({
    required Stream<String> responses,
    required this.send,
    required this.closeInput,
    required this.closeClient,
    required this.onFailure,
    required this.timeout,
  }) {
    subscription = responses.listen(
      (message) {
        final pending = _pending;
        if (pending == null || pending.isCompleted || message != _expected) {
          fail(StateError('Unexpected echo response.'));
        } else {
          pending.complete();
        }
      },
      onError: fail,
      onDone: () {
        if (!_closing) fail(StateError('Stream ended before intentional close.'));
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  final void Function(String) send;
  final Future<void> Function() closeInput;
  final void Function() closeClient;
  final void Function(Object) onFailure;
  final Duration timeout;
  late final StreamSubscription<String> subscription;
  final _done = Completer<void>();
  Completer<void>? _pending;
  String? _expected;
  Object? failure;
  bool _closing = false;

  void fail(Object error) {
    failure ??= error;
    onFailure(error);
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  Future<int> exchange(String message) async {
    if (failure != null || _done.isCompleted || _closing) {
      throw StateError('Connection is not healthy: $failure');
    }
    if (_pending != null) throw StateError('Only one probe per stream at a time.');
    _expected = message;
    final pending = _pending = Completer<void>();
    final waiting = pending.future.timeout(timeout);
    final clock = ElapsedClock()..start();
    try {
      send(message);
      await waiting;
      return clock.elapsedMicroseconds;
    } finally {
      _pending = null;
    }
  }

  Future<void> close() async {
    _closing = true;
    try {
      await closeInput().timeout(timeout);
      await _done.future.timeout(timeout);
    } finally {
      closeClient();
      await subscription.cancel();
    }
  }
}
