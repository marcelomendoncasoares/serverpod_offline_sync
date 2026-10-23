import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/verification.dart';
import 'package:test/test.dart';

ScaleOptions parse(List<String> extra) =>
    ScaleOptions.parse(['--target', 'https://example.test', ...extra]);

void main() {
  test('Given the same seed and user topology, '
      'when device counts and state schedules are recreated, '
      'then they are repeatable across invocations.', () {
    final first = parse(['--devices', '2:5', '--seed', '42', '--users', '10']);
    final second = parse(['--devices', '2:5', '--seed', '42', '--users', '10']);

    List<Object> schedule(ScaleOptions options) => [
      for (var user = 0; user < 10; user++)
        [
          options.devicesFor(user),
          options.churnOffsetMs(user, 0),
          for (var epoch = 0; epoch < 5; epoch++) options.stateFor(user, 0, epoch),
        ],
    ];

    expect(schedule(first), schedule(second));
    expect(
      {for (var user = 0; user < 10; user++) first.devicesFor(user)}.length,
      greaterThan(1),
    );
  });

  test('Given seeded churn, '
      'when each device crosses its epoch boundaries, '
      'then devices change state at different times within one churn period.', () {
    final options = parse(['--users', '20', '--devices', '3', '--churn-seconds', '5']);

    final offsets = [
      for (var user = 0; user < 20; user++)
        for (var device = 0; device < 3; device++) options.churnOffsetMs(user, device),
    ];
    final firstChange = [
      for (var user = 0; user < 20; user++)
        for (var device = 0; device < 3; device++)
          5000 - options.churnOffsetMs(user, device),
    ];

    expect(offsets, everyElement(inInclusiveRange(0, 4999)));
    expect(offsets.toSet().length, greaterThan(50));
    for (final (i, elapsed) in firstChange.indexed) {
      final user = i ~/ 3;
      final device = i % 3;
      expect(options.epochAt(user, device, elapsed - 1), 0);
      expect(options.epochAt(user, device, elapsed), 1);
    }
  });

  test('Given aligned churn is requested, '
      'when epochs are computed, '
      'then every device shares the same boundaries.', () {
    final options = parse(['--users', '5', '--churn-seconds', '2', '--aligned-churn']);

    expect([for (var u = 0; u < 5; u++) options.epochAt(u, 1, 3999)], everyElement(1));
    expect([for (var u = 0; u < 5; u++) options.epochAt(u, 1, 4000)], everyElement(2));
  });

  test('Given a network ramp that outlasts the workload, '
      'when a run is configured, '
      'then it is rejected before contacting the server.', () {
    expect(
      () => parse([
        '--users',
        '4',
        '--devices',
        '5',
        '--ramp-ms',
        '1000',
        '--duration',
        '10',
      ]),
      throwsFormatException,
    );
    expect(
      parse([
        '--users',
        '4',
        '--devices',
        '5',
        '--ramp-ms',
        '400',
        '--duration',
        '10',
      ]).maxDevicesPerWorker,
      20,
    );
  });

  test('Given device state probabilities exceeding one, '
      'when a run is configured, '
      'then it fails before contacting the server.', () {
    expect(() => parse(['--active', '0.9', '--idle', '0.9']), throwsFormatException);
  });

  test('Given an inverted device range, '
      'when a run is configured, '
      'then it rejects the ambiguous topology.', () {
    expect(() => parse(['--devices', '5:2']), throwsFormatException);
  });

  test('Given a run ID containing directory traversal, '
      'when a run is configured, '
      'then it cannot escape the data directory.', () {
    expect(() => parse(['--run-id', '../outside']), throwsFormatException);
  });

  group('Given the shared benchmark secret', () {
    const secret = 'a long dedicated secret value';
    final user1 = benchmarkId('user/1').toString();
    final user2 = benchmarkId('user/2').toString();

    test('when the secret itself is presented, '
        'then it is the admin identity.', () {
      expect(classifyToken(secret, secret), isA<AdminToken>());
    });

    test('when a user token is presented, '
        'then it identifies exactly that user.', () {
      final identity = classifyToken(secret, userToken(secret, user1));

      expect(identity, isA<UserTokenIdentity>());
      expect((identity! as UserTokenIdentity).userId.toString(), user1);
    });

    test('when another user identity is substituted into a signed token, '
        'then it is rejected.', () {
      final forged = userToken(secret, user1).replaceFirst(user1, user2);

      expect(classifyToken(secret, forged), isNull);
    });

    test('when a token is signed with a different secret, malformed, '
        'or the admin secret is extended, '
        'then it is rejected.', () {
      expect(
        classifyToken(secret, userToken('another long secret value!!', user1)),
        isNull,
      );
      expect(classifyToken(secret, 'not-a-token'), isNull);
      expect(classifyToken(secret, '$secret.'), isNull);
      expect(classifyToken(secret, userToken(secret, 'not-a-uuid')), isNull);
    });
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

  test('Given fast failed operations among slower successful operations, '
      'when latency statistics are summarized, '
      'then failures are counted but cannot lower the success percentiles.', () {
    final latency = Latencies();
    for (var i = 0; i < 99; i++) {
      latency.add(10, ok: false);
    }
    latency
      ..add(100000, ok: true)
      ..add(200000, ok: true);

    final result = latency.toJson();

    expect(result['count'], 101);
    expect(result['failures'], 99);
    expect(result['ok'], 2);
    expect(result['maxMicros'], 200000);
    expect(result['failureMaxMicros'], 10);
    expect(result['p50UpperMicros'], inInclusiveRange(100000, 110000));
    expect(result['p99UpperMicros'], inInclusiveRange(200000, 220000));
  });
}
