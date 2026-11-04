import 'package:serverpod_offline_sync/src/database/native_watch_effects.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given a query started before a visibility change, '
    'when the change commits before the query completes, '
    'then acknowledging the query start retains the change.',
    () {
      final effects = NativeWatchEffects();
      final queryStart = effects.capture({'notes'});
      final transaction = Object();

      effects
        ..begin(transaction)
        ..record(transaction, {'notes'})
        ..seal(transaction)
        ..committed(transaction);

      expect(effects.shouldQuery({'notes'}, queryStart), isTrue);
    },
  );

  test(
    'Given an acknowledged watch, '
    'when a relevant commit dispatches before its Future resolves, '
    'then its sealed effects require a query.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();

      effects
        ..begin(transaction)
        ..record(transaction, {'notes'})
        ..seal(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isTrue);
    },
  );

  test(
    'Given an acknowledged watch, '
    'when a different table commits, '
    'then metadata alone does not require its query.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();

      effects
        ..begin(transaction)
        ..record(transaction, {'tasks'})
        ..seal(transaction)
        ..committed(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isFalse);
    },
  );

  test(
    'Given a transaction with a classified write, '
    'when an additional write is unclassified, '
    'then every watch must query after commit.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();

      effects
        ..begin(transaction)
        ..record(transaction, {'tasks'})
        ..unknown(transaction)
        ..seal(transaction)
        ..committed(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isTrue);
    },
  );

  test(
    'Given nested savepoints with a visibility change and an unknown write, '
    'when rollback returns to the outer savepoint twice, '
    'then its retained checkpoint restores known empty effects.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();
      final outer = Object();
      final inner = Object();

      effects
        ..begin(transaction)
        ..savepoint(transaction, outer)
        ..record(transaction, {'notes'})
        ..savepoint(transaction, inner)
        ..unknown(transaction)
        ..rollbackTo(transaction, outer)
        ..record(transaction, {'notes'})
        ..rollbackTo(transaction, outer)
        ..seal(transaction)
        ..committed(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isFalse);
    },
  );

  test(
    'Given a visibility change inside a savepoint, '
    'when the savepoint is released and the transaction commits, '
    'then the affected watch still queries.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();
      final savepoint = Object();

      effects
        ..begin(transaction)
        ..savepoint(transaction, savepoint)
        ..record(transaction, {'notes'})
        ..release(transaction, savepoint)
        ..seal(transaction)
        ..committed(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isTrue);
    },
  );

  test(
    'Given sealed effects for an acknowledged watch, '
    'when commit fails, '
    'then the discarded effects do not advance committed versions.',
    () {
      final effects = NativeWatchEffects();
      final acknowledged = effects.capture({'notes'});
      final transaction = Object();

      effects
        ..begin(transaction)
        ..record(transaction, {'notes'})
        ..unknown(transaction)
        ..seal(transaction)
        ..aborted(transaction);

      expect(effects.shouldQuery({'notes'}, acknowledged), isFalse);
    },
  );

  test(
    'Given a write in an unobserved transaction, '
    'when a watch acknowledges a read before the eventual commit, '
    'then later metadata events remain eligible without a timeout.',
    () {
      final effects = NativeWatchEffects()..unknown(Object());
      final afterWrite = effects.capture({'notes'});

      expect(effects.shouldQuery({'notes'}, afterWrite), isTrue);
    },
  );
}
