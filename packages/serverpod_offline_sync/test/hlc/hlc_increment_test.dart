import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final _dateTime = DateTime.parse('2001-09-09T01:46:40.000Z');
final _nodeId = const Uuid().v4obj();

void main() {
  group('Given an HLC with lower canonical time than wall time', () {
    final hlc = Hlc(_dateTime, 17, _nodeId);
    final wallTime = _dateTime.advance();

    test('when incrementing then dateTime becomes wall time and counter resets.', () {
      withClock(Clock.fixed(wallTime), () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, wallTime);
        expect(sendHlc.counter, 0);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with equal canonical time and wall time', () {
    final hlc = Hlc(_dateTime, 17, _nodeId);
    final wallTime = _dateTime;

    test('when incrementing then counter increments and dateTime is unchanged.', () {
      withClock(Clock.fixed(wallTime), () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, hlc.datetime);
        expect(sendHlc.counter, 18);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with higher canonical time than wall time', () {
    final hlc = Hlc(_dateTime, 17, _nodeId);
    final wallTime = _dateTime.retreat();

    test('when incrementing then counter increments and dateTime is unchanged.', () {
      withClock(Clock.fixed(wallTime), () {
        final sendHlc = hlc.increment();

        expect(sendHlc, isNot(hlc));
        expect(sendHlc.datetime, hlc.datetime);
        expect(sendHlc.counter, 18);
        expect(sendHlc.nodeId, hlc.nodeId);
      });
    });
  });

  group('Given an HLC with canonical time more than one minute ahead of wall time', () {
    final hlc = Hlc(_dateTime.add(const Duration(minutes: 1, seconds: 5)), 0, _nodeId);
    final wallTime = _dateTime;

    test('when incrementing then ClockDriftException is thrown.', () {
      withClock(Clock.fixed(wallTime), () {
        expect(hlc.increment, throwsA(isA<ClockDriftException>()));
      });
    });
  });

  group('Given an HLC with counter at maximum and canonical time at wall time', () {
    final hlc = Hlc(_dateTime, 0xFFFF, _nodeId);
    final wallTime = _dateTime;

    test('when incrementing at same time then OverflowException is thrown.', () {
      withClock(Clock.fixed(wallTime), () {
        expect(hlc.increment, throwsA(isA<OverflowException>()));
      });
    });
  });
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
