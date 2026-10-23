import 'dart:async';

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Given a measured operation, '
    'when it opens a nested span and a fresh timeline,',
    () {
      late List<Map<String, Object?>> outer;
      late List<Map<String, Object?>> inner;

      setUpAll(() async {
        outer = [];
        inner = [];
        await OfflineSyncDiagnostics.run(
          outer.add,
          () => OfflineSyncDiagnostics.measure('root', () async {
            await OfflineSyncDiagnostics.measure('child', () async {});
            await OfflineSyncDiagnostics.run(
              inner.add,
              () => OfflineSyncDiagnostics.measure('inner', () async {
                OfflineSyncDiagnostics.event('innerPoint');
              }),
            );
            OfflineSyncDiagnostics.event('outerPoint');
          }),
        );
      });

      test('then each span retains the same parent at its start and end.', () {
        expect(
          outer.map(
            (event) => (
              event['name'],
              event['kind'],
              event['spanId'],
              event['parentId'],
            ),
          ),
          [
            ('root', 'start', 1, null),
            ('child', 'start', 2, 1),
            ('child', 'end', 2, 1),
            ('outerPoint', 'event', null, 1),
            ('root', 'end', 1, null),
          ],
        );
      });

      test('then the fresh timeline has no parent from the outer timeline.', () {
        expect(
          inner.map(
            (event) => (
              event['name'],
              event['kind'],
              event['spanId'],
              event['parentId'],
            ),
          ),
          [
            ('inner', 'start', 1, null),
            ('innerPoint', 'event', null, 1),
            ('inner', 'end', 1, null),
          ],
        );
      });
    },
  );

  test('Given a diagnostics consumer that throws, '
      'when an observed operation succeeds or fails, '
      'then its result and original error are preserved.', () async {
    final failure = StateError('operation failed');
    final result = await OfflineSyncDiagnostics.run(
      (_) => throw StateError('observer failed'),
      () => OfflineSyncDiagnostics.measure('success', () async => 42),
    );
    Object? caught;
    try {
      await OfflineSyncDiagnostics.run(
        (_) => throw StateError('observer failed'),
        () =>
            OfflineSyncDiagnostics.measure<void>('failure', () async => throw failure),
      );
    } on Object catch (error) {
      caught = error;
    }

    expect(result, 42);
    expect(caught, same(failure));
    expect(OfflineSyncDiagnostics.enabled, isFalse);
  });

  test('Given two overlapping observed operations, '
      'when their asynchronous work resumes in reverse order, '
      'then events retain their own request and nested span.', () async {
    final firstEvents = <Map<String, Object?>>[];
    final secondEvents = <Map<String, Object?>>[];
    final release = Completer<void>();
    final first = OfflineSyncDiagnostics.run(
      firstEvents.add,
      () => OfflineSyncDiagnostics.measure('first', () async {
        await release.future;
        OfflineSyncDiagnostics.event('firstOnly');
      }),
    );
    await OfflineSyncDiagnostics.run(
      secondEvents.add,
      () => OfflineSyncDiagnostics.measure('second', () async {
        OfflineSyncDiagnostics.event('secondOnly');
      }),
    );
    release.complete();
    await first;

    expect(firstEvents.map((e) => e['name']), ['first', 'firstOnly', 'first']);
    expect(secondEvents.map((e) => e['name']), ['second', 'secondOnly', 'second']);
    expect(firstEvents[1]['parentId'], firstEvents.first['spanId']);
    expect(firstEvents.last['data'], {'ok': true});
  });

  test('Given nested and overlapping diagnostic timelines, '
      'when their events cross request boundaries, '
      'then all events share one ordered monotonic clock.', () async {
    final events = <Map<String, Object?>>[];
    final release = Completer<void>();
    final first = OfflineSyncDiagnostics.run(events.add, () async {
      OfflineSyncDiagnostics.event('firstStart');
      await release.future;
      OfflineSyncDiagnostics.event('firstEnd');
    });
    await OfflineSyncDiagnostics.run(events.add, () async {
      OfflineSyncDiagnostics.event('secondStart');
      release.complete();
      await first;
      OfflineSyncDiagnostics.event('secondEnd');
    });

    expect(events.map((event) => event['name']), [
      'firstStart',
      'secondStart',
      'firstEnd',
      'secondEnd',
    ]);
    final times = events.map((event) => event['processMicros']! as int).toList();
    expect(times, orderedEquals([...times]..sort()));
    for (final event in events) {
      expect(event['atMicros'], isNonNegative);
      expect(event['processMicros'], greaterThanOrEqualTo(event['atMicros']! as int));
    }
  });
}
