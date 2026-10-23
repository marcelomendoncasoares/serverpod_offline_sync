import 'package:serverpod_offline_sync_benchmark/scale/elapsed_clock.dart';
import 'package:test/test.dart';

void main() {
  group('Given a running benchmark elapsed clock,', () {
    late ElapsedClock clock;
    late int stopped;
    late int stillStopped;
    late int resumed;

    setUpAll(() async {
      clock = ElapsedClock()..start();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      clock.stop();
      stopped = clock.elapsedMicroseconds;
    });

    group('when it remains stopped and then resumes,', () {
      setUpAll(() async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        stillStopped = clock.elapsedMicroseconds;
        clock.start();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        clock.stop();
        resumed = clock.elapsedMicroseconds;
      });

      test('then stopped time is excluded and resumed time accumulates.', () {
        expect(stopped, greaterThan(0));
        expect(stillStopped, stopped);
        expect(resumed, greaterThan(stopped));
      });
    });
  });
}
