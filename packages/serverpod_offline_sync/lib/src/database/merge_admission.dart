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
  var _queued = 0;
  final _queuedByUser = <UuidValue, int>{};

  Future<T> run<T>(
    UuidValue userId,
    UuidValue spaceId,
    Future<T> Function() action, {
    OfflineSyncCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    OfflineSyncDiagnostics.event('queue.join', {
      'scope': 'serverInstance',
      'serializationKeys': ['user', 'space'],
      'concurrencyLimit': limit,
      'queuedTotalAhead': _queued,
      'queuedForUserAhead': _queuedByUser[userId] ?? 0,
      'waitingForCapacity': _waiting.length,
      'active': _active,
      'userBusy': _users.containsKey(userId),
      'spaceBusy': _spaces.containsKey(spaceId),
    });
    _queued++;
    _queuedByUser.update(userId, (count) => count + 1, ifAbsent: () => 1);
    var queued = true;
    final previousUser = _users[userId];
    final previousSpace = _spaces[spaceId];
    final userReleased = Completer<void>();
    final spaceReleased = Completer<void>();
    _users[userId] = userReleased.future;
    _spaces[spaceId] = spaceReleased.future;
    var hasSlot = false;

    try {
      // Reserve each key before waiting. A cancelled entry forwards each key
      // independently, so an unrelated successor need not wait for both keys.
      final predecessors = Future.wait([?previousUser, ?previousSpace]);
      await OfflineSyncDiagnostics.measure(
        'queue.userOrSpace',
        () => cancellation?.waitFor(predecessors) ?? predecessors,
      );
      if (_active < limit) {
        _active++;
        hasSlot = true;
      } else {
        final ready = Completer<void>();
        _waiting.add(ready);
        try {
          await OfflineSyncDiagnostics.measure(
            'queue.globalCapacity',
            () => cancellation?.waitFor(ready.future) ?? ready.future,
          );
          hasSlot = true;
        } on Object {
          // A release may already have handed us its slot before cancellation
          // wins the await. In that case our finally must hand the slot on.
          hasSlot = !_waiting.remove(ready);
          rethrow;
        }
      }

      cancellation?.throwIfCancelled();
      final queuedForUser = _leaveQueue(userId);
      queued = false;
      OfflineSyncDiagnostics.event('queue.admitted', {
        'queuedTotal': _queued,
        'queuedForUser': queuedForUser,
        'active': _active,
      });
      return await action();
    } finally {
      if (queued) _leaveQueue(userId);
      if (hasSlot) {
        if (_waiting.isEmpty) {
          _active--;
        } else {
          _waiting.removeFirst().complete();
        }
      }
      // An unadmitted cancellation must not bypass an active predecessor on
      // the same key. Forward it, while immediately releasing any free key.
      _releaseKey(_users, userId, userReleased, previousUser);
      _releaseKey(_spaces, spaceId, spaceReleased, previousSpace);
    }
  }

  int _leaveQueue(UuidValue userId) {
    _queued--;
    final remaining = _queuedByUser[userId]! - 1;
    if (remaining == 0) {
      _queuedByUser.remove(userId);
    } else {
      _queuedByUser[userId] = remaining;
    }
    return remaining;
  }

  void _releaseKey(
    Map<UuidValue, Future<void>> tails,
    UuidValue key,
    Completer<void> released,
    Future<void>? predecessor,
  ) {
    released.complete(predecessor);
    unawaited(
      released.future.then((_) {
        if (identical(tails[key], released.future)) {
          unawaited(tails.remove(key));
        }
      }),
    );
  }
}
