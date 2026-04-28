import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final _dateTime = DateTime.now().toUtc();
final _nodeId = const Uuid().v4obj();
final _nodeIdAfter = const Uuid().v4obj();

void main() {
  group('Given local canonical Hlc and remote with higher time', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime.advance(), 2, _nodeIdAfter);

    test('when merging then result has remote time and counter with local nodeId.', () {
      final hlc = canonical.merge(remote);

      expect(hlc, Hlc(remote.datetime, remote.counter, canonical.nodeId));
    });
  });

  group('Given local canonical Hlc and remote with same time but higher counter', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime, 18, _nodeIdAfter);

    test('when merging then result has remote counter with local nodeId.', () {
      final hlc = canonical.merge(remote);

      expect(hlc, Hlc(canonical.datetime, remote.counter, canonical.nodeId));
    });
  });

  group('Given local canonical Hlc and remote with same time and counter', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime, 17, _nodeIdAfter);

    test('when merging then local is returned.', () {
      final hlc = canonical.merge(remote);

      expect(hlc, equals(canonical));
    });
  });

  group('Given local canonical Hlc and remote with lower time', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime.retreat(), 17, _nodeIdAfter);

    test('when merging then local is returned.', () {
      final hlc = canonical.merge(remote);

      expect(hlc, equals(canonical));
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and same time', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime, 17, _nodeId);

    test('when merging then node id is not checked and local is returned.', () {
      expect(canonical.merge(remote), canonical);
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and lower time', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime.retreat(), 17, _nodeId);

    test('when merging then node id is not checked and local is returned.', () {
      expect(canonical.merge(remote), canonical);
    });
  });

  group('Given local canonical Hlc and remote with same nodeId and higher time', () {
    final canonical = Hlc(_dateTime, 17, _nodeId);
    final remote = Hlc(_dateTime.advance(), 0, _nodeId);

    test('when merging then DuplicateNodeException is thrown.', () {
      expect(
        () => canonical.merge(remote),
        throwsA(isA<DuplicateNodeException>()),
      );
    });
  });

  group(
    'Given local canonical Hlc and remote with time more than one minute ahead of wall',
    () {
      final canonical = Hlc(_dateTime, 17, _nodeId);
      final remote = Hlc(_dateTime.advance(const Duration(minutes: 2)), 17, _nodeIdAfter);

      test('when merging then ClockDriftException is thrown.', () {
        withClock(Clock.fixed(_dateTime.advance()), () {
          expect(
            () => canonical.merge(remote),
            throwsA(isA<ClockDriftException>()),
          );
        });
      });
    },
  );
}

extension on DateTime {
  DateTime advance([Duration duration = const Duration(milliseconds: 1)]) =>
      add(duration);

  DateTime retreat([Duration duration = const Duration(milliseconds: 1)]) =>
      subtract(duration);
}
