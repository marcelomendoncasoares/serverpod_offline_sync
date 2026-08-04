import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

import 'hlc_fixtures.dart';

/// [Hlc.merge] compares the remote timestamp against `clock.now()`, so every
/// merge here runs with the wall clock pinned to [hlcTime]. Without that the
/// outcome depends on how far real time has drifted from the fixtures.
void main() {
  group('Given local canonical Hlc and remote with higher time', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime.advance(), 2, hlcSecondNodeId);

    test('when merging then result has remote time and counter with local nodeId.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, Hlc(remote.datetime, remote.counter, canonical.nodeId));
    });
  });

  group('Given local canonical Hlc and remote with same time but higher counter', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime, 18, hlcSecondNodeId);

    test('when merging then result has remote counter with local nodeId.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, Hlc(canonical.datetime, remote.counter, canonical.nodeId));
    });
  });

  group('Given local canonical Hlc and remote with same time and counter', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime, 17, hlcSecondNodeId);

    test('when merging then local is returned.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, equals(canonical));
    });
  });

  group('Given local canonical Hlc and remote with lower time', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime.retreat(), 17, hlcSecondNodeId);

    test('when merging then local is returned.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, equals(canonical));
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and same time', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime, 17, hlcNodeId);

    test('when merging then node id is not checked and local is returned.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, canonical);
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and lower time', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime.retreat(), 17, hlcNodeId);

    test('when merging then node id is not checked and local is returned.', () {
      final hlc = atWallTime(hlcTime, () => canonical.merge(remote));

      expect(hlc, canonical);
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and higher time', () {
    final canonical = Hlc(hlcTime, 17, hlcNodeId);
    final remote = Hlc(hlcTime.advance(), 0, hlcNodeId);

    test('when merging then DuplicateNodeException is thrown.', () {
      expect(
        () => atWallTime(hlcTime, () => canonical.merge(remote)),
        throwsA(isA<DuplicateNodeException>()),
      );
    });
  });

  group(
    'Given local canonical Hlc and remote with time more than one minute ahead of wall',
    () {
      final canonical = Hlc(hlcTime, 17, hlcNodeId);
      final remote = Hlc(
        hlcTime.advance(const Duration(minutes: 2)),
        17,
        hlcSecondNodeId,
      );

      test('when merging then ClockDriftException is thrown.', () {
        expect(
          () => atWallTime(hlcTime, () => canonical.merge(remote)),
          throwsA(isA<ClockDriftException>()),
        );
      });
    },
  );
}
