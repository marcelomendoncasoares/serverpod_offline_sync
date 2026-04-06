import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:drift_offline_sync/src/database/triggers.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';
import '../utils/user.dart';

void main() {
  group('Given a database with in-SQLite HLC view', () {
    test('when reading from the HLC state table for the first time '
        'then it returns null.', () async {
      final state = await _readHlcState();

      expect(state, isNull);
    });

    test('when inserting into the canonical view '
        'then it contains a valid HLC timestamp.', () async {
      await _insertIntoCanonicalView();

      final state = await _readHlcState();
      final expectedHlc = Hlc(
        DateTime.now().toUtc().subtract(const Duration(milliseconds: 100)),
        0,
        testNodeId,
      );

      expect(state, isNotNull);
      expect(state!.toHlc(testNodeId), greaterThan(expectedHlc));
    });
  });

  group('Given HLC state with lower canonical time than wall time', () {
    late int previousTimestamp;

    setUp(() async {
      previousTimestamp = DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch;

      await _seedHlcState(previousTimestamp, 17);
    });

    test('when inserting into the canonical view '
        'then last timestamp becomes wall time and counter resets.', () async {
      await _insertIntoCanonicalView();
      final state = await _readHlcState();

      expect(state, isNotNull);
      expect(state!.lastTimestamp, greaterThan(previousTimestamp));
      expect(state.counter, 0);
    });
  });

  // NOTE: It is not possible to test the scenario in which the canonical time is equal
  // to the wall time since there is no way to override the `unixepoch('now','subsec')`
  // return for the tests as we do in the `hlc_increment_test.dart` file.

  group('Given HLC state with higher canonical time than wall time', () {
    late int previousTimestamp;

    setUp(() async {
      previousTimestamp = DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 5))
          .millisecondsSinceEpoch;

      await _seedHlcState(previousTimestamp, 17);
    });

    test('when inserting into the canonical view '
        'then counter increments and last timestamp is unchanged.', () async {
      await _insertIntoCanonicalView();
      final state = await _readHlcState();

      expect(state, isNotNull);
      expect(state!.lastTimestamp, equals(previousTimestamp));
      expect(state.counter, 18);
    });
  });

  group(
    'Given HLC state with canonical time more than one minute ahead of wall time',
    () {
      setUp(() async {
        final futureTimestamp = DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1, seconds: 5))
            .millisecondsSinceEpoch;

        await _seedHlcState(futureTimestamp, 17);
      });

      test('when inserting into the canonical view '
          'then an exception is thrown with clock drift on message.', () async {
        expect(
          _insertIntoCanonicalView,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Clock drift exceeds 1 minute maximum.'),
            ),
          ),
        );
      });
    },
  );

  group(
    'Given HLC state with counter at maximum and canonical time ahead of wall time',
    () {
      setUp(() async {
        final futureTimestamp = DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 5))
            .millisecondsSinceEpoch;

        await _seedHlcState(futureTimestamp, 0xFFFF);
      });

      test(
        'when inserting into the canonical view '
        'then an exception is thrown with timestamp counter overflow message.',
        () async {
          expect(
            _insertIntoCanonicalView,
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Timestamp counter overflow: 0xFFFF.'),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _insertIntoCanonicalView() => database.customStatement(
  'INSERT INTO "${Sqlite3OfflineSyncTriggers.hlcCanonicalViewName}" ("user_id") '
  "VALUES ('$testUserId')",
);

Future<CrdtHlcEntry> _seedHlcState(int lastTimestamp, int counter) {
  final (_, crdtDb, _) = database.crdtContext;
  return crdtDb.managers.crdtHlcStateTable.createReturning(
    (t) => t(
      userId: testUserId,
      lastTimestamp: lastTimestamp,
      counter: counter,
    ),
  );
}

Future<CrdtHlcEntry?> _readHlcState() async {
  final (_, crdtDb, _) = database.crdtContext;
  return crdtDb.managers.crdtHlcStateTable
      .filter((o) => o.userId.equals(testUserId))
      .getSingleOrNull();
}
