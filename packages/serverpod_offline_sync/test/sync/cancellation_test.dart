import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given a cancelled admission wait whose predecessor is still pending, '
    'when cancellation settles before that predecessor, '
    'then the caller receives cancellation without waiting for the predecessor.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final predecessor = Completer<void>();
      final waiting = cancellation
          .waitFor(predecessor.future)
          .then<Object?>(
            (_) => null,
            onError: (Object error) => error,
          );

      cancellation.cancel();
      final error = await waiting;
      final predecessorWasPending = !predecessor.isCompleted;
      predecessor.complete();

      expect(error, isA<OfflineSyncCancelledException>());
      expect(predecessorWasPending, isTrue);
    },
  );

  test(
    'Given an admission slot that is released before its waiter resumes, '
    'when cancellation arrives in the same turn, '
    'then the pending wait reports cancellation.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final slot = Completer<void>();
      final waiting = cancellation
          .waitFor(slot.future)
          .then<Object?>(
            (_) => null,
            onError: (Object error) => error,
          );

      slot.complete();
      cancellation.cancel();
      final error = await waiting;

      expect(error, isA<OfflineSyncCancelledException>());
    },
  );

  test(
    'Given a cancelled sync session, '
    'when another merge attempts to enter its transaction, '
    'then the merge callback never runs.',
    () async {
      final cancellation = OfflineSyncCancellation()..cancel();
      final transaction = _Transaction();
      var entered = false;

      final result = cancellation.run(transaction, () async => entered = true);

      await expectLater(result, throwsA(isA<OfflineSyncCancelledException>()));
      expect(entered, isFalse);
      expect(transaction.cancelCalls, 0);
    },
  );

  group('Given an active merge and a driver that has not finished rollback,', () {
    late OfflineSyncCancellation cancellation;
    late _Transaction transaction;
    late Completer<void> releaseCallback;
    late Future<Object?> result;
    late bool completed;

    setUpAll(() {
      cancellation = OfflineSyncCancellation();
      transaction = _Transaction();
      releaseCallback = Completer<void>();
      completed = false;
      result = cancellation
          .run(transaction, () async {
            await releaseCallback.future;
            return 'success';
          })
          .then<Object?>((value) => value, onError: (Object error) => error)
          .whenComplete(() => completed = true);
      addTearDown(() async {
        if (!releaseCallback.isCompleted) releaseCallback.complete();
        if (!transaction.rollback.isCompleted) transaction.rollback.complete();
        await result;
      });
    });

    group('when cancellation is repeated and the callback returns normally,', () {
      late bool completedBeforeRollback;
      late Object? error;

      setUpAll(() async {
        cancellation
          ..cancel()
          ..cancel();
        releaseCallback.complete();
        await Future<void>.delayed(Duration.zero);
        completedBeforeRollback = completed;
        transaction.rollback.complete();
        error = await result;
      });

      test('then the operation waits for rollback and reports cancellation.', () {
        expect(completedBeforeRollback, isFalse);
        expect(error, isA<OfflineSyncCancelledException>());
      });

      test('then the driver receives only one rollback request.', () {
        expect(transaction.cancelCalls, 1);
      });
    });
  });

  test(
    'Given a database error from a cancelled transaction, '
    'when the merge unwinds, '
    'then the operation reports cancellation.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final transaction = _Transaction()..rollback.complete();

      final result = cancellation.run<void>(transaction, () async {
        cancellation.cancel();
        throw DatabaseException('The transaction has closed.');
      });

      await expectLater(result, throwsA(isA<OfflineSyncCancelledException>()));
    },
  );

  test(
    'Given full rollback has removed the merge savepoint, '
    'when savepoint cleanup fails during cancellation, '
    'then the operation reports cancellation.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final transaction = _Transaction()..rollback.complete();

      final result = cancellation.run<void>(transaction, () async {
        cancellation.cancel();
        throw RollbackToSavepointFailedException(
          DatabaseException('The savepoint no longer exists.'),
        );
      });

      await expectLater(result, throwsA(isA<OfflineSyncCancelledException>()));
    },
  );

  test(
    'Given a database error without a cancellation request, '
    'when the merge unwinds, '
    'then the original failure reaches the caller.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final failure = DatabaseException('Connection failed.');

      final result = cancellation.run<void>(_Transaction(), () async => throw failure);

      await expectLater(result, throwsA(same(failure)));
    },
  );

  test(
    'Given cancellation of a normally returning merge, '
    'when the driver fails to roll back, '
    'then the rollback failure reaches the caller.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final transaction = _Transaction();
      final failure = DatabaseException('Rollback failed.');

      final result = cancellation.run(transaction, () async {
        cancellation.cancel();
        transaction.rollback.completeError(failure);
        return 'success';
      });

      await expectLater(result, throwsA(same(failure)));
    },
  );

  test(
    'Given a merge fails with an unrelated programming error, '
    'when its requested rollback also fails, '
    'then cancellation preserves the programming error.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final transaction = _Transaction();
      final failure = StateError('Invalid merge state.');

      final result = cancellation.run<void>(transaction, () async {
        cancellation.cancel();
        transaction.rollback.completeError(DatabaseException('Rollback failed.'));
        throw failure;
      });

      await expectLater(result, throwsA(same(failure)));
    },
  );

  test(
    'Given one transaction is bound to a sync session, '
    'when a second transaction tries to bind concurrently, '
    'then it is rejected without replacing the original cancellation target.',
    () async {
      final cancellation = OfflineSyncCancellation();
      final original = _Transaction()..rollback.complete();
      final other = _Transaction();
      final release = Completer<void>();
      final pending = cancellation.run(original, () => release.future);
      final failure = expectLater(
        pending,
        throwsA(isA<OfflineSyncCancelledException>()),
      );
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });

      await expectLater(
        cancellation.run(other, () async {}),
        throwsStateError,
      );
      cancellation.cancel();
      release.complete();
      await failure;

      expect(original.cancelCalls, 1);
      expect(other.cancelCalls, 0);
    },
  );
}

/// Controls rollback completion without requiring a broken database connection.
class _Transaction implements Transaction {
  final rollback = Completer<void>();
  int cancelCalls = 0;

  @override
  Future<void> cancel() {
    cancelCalls++;
    return rollback.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
