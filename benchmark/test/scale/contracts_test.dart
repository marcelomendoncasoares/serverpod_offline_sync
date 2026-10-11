import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runner.dart';
import 'package:test/test.dart';

void main() {
  test('Given the same seed and user topology, '
      'when device counts and state schedules are recreated, '
      'then they are repeatable across invocations.', () {
    final first = ScaleOptions.parse([
      '--target',
      'https://example.test',
      '--devices',
      '2:5',
      '--seed',
      '42',
    ]);
    final second = ScaleOptions.parse([
      '--target',
      'https://example.test',
      '--devices',
      '2:5',
      '--seed',
      '42',
    ]);

    final firstSchedule = [
      for (var user = 0; user < 10; user++)
        [
          first.devicesFor(user),
          for (var epoch = 0; epoch < 5; epoch++) first.stateFor(user, 0, epoch),
        ],
    ];
    final secondSchedule = [
      for (var user = 0; user < 10; user++)
        [
          second.devicesFor(user),
          for (var epoch = 0; epoch < 5; epoch++) second.stateFor(user, 0, epoch),
        ],
    ];

    expect(firstSchedule, secondSchedule);
    expect(
      {for (var user = 0; user < 10; user++) first.devicesFor(user)}.length,
      greaterThan(1),
    );
  });

  test('Given device state probabilities exceeding one, '
      'when a run is configured, '
      'then it fails before contacting the server.', () {
    expect(
      () => ScaleOptions.parse([
        '--target',
        'https://example.test',
        '--active',
        '0.9',
        '--idle',
        '0.9',
      ]),
      throwsFormatException,
    );
  });

  test('Given an inverted device range, '
      'when a run is configured, '
      'then it rejects the ambiguous topology.', () {
    expect(
      () =>
          ScaleOptions.parse(['--target', 'https://example.test', '--devices', '5:2']),
      throwsFormatException,
    );
  });

  test('Given a run ID containing directory traversal, '
      'when a run is configured, '
      'then it cannot escape the data directory.', () {
    expect(
      () => ScaleOptions.parse([
        '--target',
        'https://example.test',
        '--run-id',
        '../outside',
      ]),
      throwsFormatException,
    );
  });

  test('Given a token signed for one user, '
      'when another user identity is substituted, '
      'then the signature is rejected.', () {
    final first = userToken(
      'a long dedicated secret value',
      benchmarkId('user/1').toString(),
    );
    final forged = first.replaceFirst(
      benchmarkId('user/1').toString(),
      benchmarkId('user/2').toString(),
    );
    final expected = userToken(
      'a long dedicated secret value',
      benchmarkId('user/2').toString(),
    );

    expect(constantTimeEqual(forged, expected), isFalse);
  });

  test('Given equivalent domain data with different local space IDs and row order, '
      'when snapshots are compared, '
      'then they agree.', () {
    final first = snapshotOf({
      'person': [
        {'id': 'a', 'name': 'A', 'spaceId': 1},
        {'id': 'b', 'name': 'B', 'spaceId': 1},
      ],
      'city': [],
      'town': [],
    });
    final second = snapshotOf({
      'person': [
        {'name': 'B', 'spaceId': 50, 'id': 'b'},
        {'name': 'A', 'spaceId': 50, 'id': 'a'},
      ],
      'city': [],
      'town': [],
    });

    expect(first, second);
  });

  test('Given a missing committed receipt on every replica, '
      'when their snapshot is compared with the write journal, '
      'then the independent receipt digest detects the loss.', () {
    final expected = digestStrings(['a', 'b']);
    final incomplete = snapshotOf({
      'person': [
        {'id': 'a', 'name': 'A'},
      ],
      'city': [],
      'town': [],
    });

    expect(incomplete['receiptsDigest'], isNot(expected));
  });

  test('Given one slow failed operation among faster successful operations, '
      'when latency statistics are summarized, '
      'then the failure and tail latency remain visible.', () {
    final latency = Latencies();

    latency
      ..add(100, ok: true)
      ..add(200, ok: true)
      ..add(1000000, ok: false);
    final result = latency.toJson();

    expect(result['count'], 3);
    expect(result['failures'], 1);
    expect(result['maxMicros'], 1000000);
    expect(result['p99UpperMicros'], inInclusiveRange(1000000, 1100000));
  });
}
