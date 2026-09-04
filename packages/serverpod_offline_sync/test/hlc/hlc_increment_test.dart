import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

import 'hlc_fixtures.dart';

/// [Hlc.increment] derives its result from `clock.now()`, so every increment
/// here runs with the wall clock pinned to an explicit instant.
void main() {
  group('Given an HLC with lower canonical time than wall time', () {
    final hlc = Hlc(hlcTime, 17, hlcNodeId);
    final wallTime = hlcTime.advance();

    test('when incrementing then dateTime becomes wall time and counter resets.', () {
      atWallTime(wallTime, () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, wallTime);
        expect(sendHlc.counter, 0);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with equal canonical time and wall time', () {
    final hlc = Hlc(hlcTime, 17, hlcNodeId);
    final wallTime = hlcTime;

    test('when incrementing then counter increments and dateTime is unchanged.', () {
      atWallTime(wallTime, () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, hlc.datetime);
        expect(sendHlc.counter, 18);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with higher canonical time than wall time', () {
    final hlc = Hlc(hlcTime, 17, hlcNodeId);
    final wallTime = hlcTime.retreat();

    test('when incrementing then counter increments and dateTime is unchanged.', () {
      atWallTime(wallTime, () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, hlc.datetime);
        expect(sendHlc.counter, 18);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with canonical time more than one minute ahead of wall time', () {
    final hlc = Hlc(hlcTime.add(const Duration(minutes: 1, seconds: 5)), 0, hlcNodeId);
    final wallTime = hlcTime;

    test('when incrementing then ClockDriftException is thrown.', () {
      atWallTime(wallTime, () {
        expect(hlc.increment, throwsA(isA<ClockDriftException>()));
      });
    });
  });

  group('Given an HLC with counter at maximum and canonical time at wall time', () {
    final hlc = Hlc(hlcTime, 0xFFFF, hlcNodeId);
    final wallTime = hlcTime;

    test('when incrementing at same time then OverflowException is thrown.', () {
      atWallTime(wallTime, () {
        expect(hlc.increment, throwsA(isA<OverflowException>()));
      });
    });
  });
}
