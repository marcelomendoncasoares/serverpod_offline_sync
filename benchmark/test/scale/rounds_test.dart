import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_runner.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_worker.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  group('Given paginated diagnostics that keep growing during collection,', () {
    late List<Map<String, dynamic>> pages;
    late Map<String, int> cursors;
    late List<Map<String, dynamic>> records;

    setUpAll(() {
      cursors = {'server': 10};
      records = [];
      pages = [
        {
          'instanceId': 'server',
          'oldestSequence': 1,
          'latestSequence': 14,
          'nextSequence': 12,
          'records': [
            {'sequence': 11},
            {'sequence': 12},
          ],
        },
        {
          'instanceId': 'server',
          'oldestSequence': 1,
          'latestSequence': 100,
          'nextSequence': 14,
          'records': [
            {'sequence': 13},
            {'sequence': 14},
          ],
        },
      ];
    });

    group('when the initial snapshot is collected,', () {
      setUpAll(() async {
        await collectDiagnosticSnapshot(
          cursors: cursors,
          readPage: () async => pages.removeAt(0),
          record: records.add,
        );
      });

      test('then it returns after the original head despite newer records.', () {
        expect(records.map((r) => r['sequence']), [11, 12, 13, 14]);
      });

      test('then the next collection resumes after the last delivered record.', () {
        expect(cursors, {'server': 14});
      });
    });
  });

  test('Given diagnostics evicted before the next page is read, '
      'when the snapshot is collected, '
      'then missing evidence fails collection.', () async {
    final cursors = {'server': 10};
    final operation = collectDiagnosticSnapshot(
      cursors: cursors,
      readPage: () async => {
        'instanceId': 'server',
        'oldestSequence': 12,
        'latestSequence': 14,
        'nextSequence': 14,
        'records': [
          {'sequence': 12},
          {'sequence': 13},
          {'sequence': 14},
        ],
      },
      record: (_) {},
    );

    await expectLater(operation, throwsStateError);
  });

  group('Given a two-row delivery expectation,', () {
    late List<Person> expected;

    setUp(() {
      expected = [
        Person(id: benchmarkId('a'), name: 'Alice', surname: 'one'),
        Person(id: benchmarkId('b'), name: 'Bob', surname: 'two'),
      ];
    });

    test('when the rows arrive in a different order, '
        'then the exact batch is accepted.', () {
      final delivered = deliveredRows(expected.reversed.toList(), expected);

      expect(delivered, isTrue);
    });

    test('when one row is missing, '
        'then the batch is incomplete.', () {
      final delivered = deliveredRows([expected.first], expected);

      expect(delivered, isFalse);
    });

    test('when the row count matches but a value is stale, '
        'then the batch is incomplete.', () {
      final delivered = deliveredRows([
        expected.first,
        expected.last.copyWith(name: 'stale'),
      ], expected);

      expect(delivered, isFalse);
    });

    test('when an unrelated row substitutes for an expected row, '
        'then the batch is incomplete.', () {
      final delivered = deliveredRows([
        expected.first,
        expected.last.copyWith(id: benchmarkId('unrelated')),
      ], expected);

      expect(delivered, isFalse);
    });
  });

  test('Given a round benchmark with only one device, '
      'when its options are parsed, '
      'then it rejects a workload that cannot measure peer delivery.', () {
    expect(
      () =>
          RoundOptions.parse(['--target', 'http://localhost:8080/', '--devices', '1']),
      throwsFormatException,
    );
  });

  test('Given an aborted idle transaction after all streams close, '
      'when server cleanup is judged, '
      'then the unfinished transaction prevents a clean result.', () {
    final clean = cleanRoundServer({
      'streams': {'open': 0},
      'storage': {
        'connections': [
          {'state': 'idle in transaction (aborted)', 'count': 1},
        ],
      },
    });

    expect(clean, isFalse);
  });
}
