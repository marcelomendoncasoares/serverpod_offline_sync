part of 'recorder.dart';

/// Keeps merges waiting for the same clock or space outside the database pool.
/// PostgreSQL locks still serialize against other processes and authored writes.
class _MergeAdmission {
  _MergeAdmission(this.limit) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'maxConcurrentMerges', 'Must be >= 1');
    }
  }

  final int limit;
  final _users = <UuidValue, Future<void>>{};
  final _spaces = <UuidValue, Future<void>>{};
  final _waiting = Queue<Completer<void>>();
  var _active = 0;

  Future<T> run<T>(
    UuidValue userId,
    UuidValue spaceId,
    Future<T> Function() action,
  ) async {
    final previous = [?_users[userId], ?_spaces[spaceId]];
    final released = Completer<void>();
    _users[userId] = released.future;
    _spaces[spaceId] = released.future;

    try {
      // Reserve both resources before waiting, preserving arrival order for
      // overlapping merges without holding a connection or a global slot.
      await Future.wait(previous);
      if (_active < limit) {
        _active++;
      } else {
        final ready = Completer<void>();
        _waiting.add(ready);
        await ready.future;
      }

      try {
        return await action();
      } finally {
        if (_waiting.isEmpty) {
          _active--;
        } else {
          _waiting.removeFirst().complete();
        }
      }
    } finally {
      if (identical(_users[userId], released.future)) {
        unawaited(_users.remove(userId));
      }
      if (identical(_spaces[spaceId], released.future)) {
        unawaited(_spaces.remove(spaceId));
      }
      // A failed merge must release its successors without forwarding its error.
      released.complete();
    }
  }
}
