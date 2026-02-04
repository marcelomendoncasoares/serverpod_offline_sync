import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

final _dateTime = DateTime.parse('2001-09-09T01:46:40.000Z');

void main() {
  group('Given an HLC', () {
    final hlc = Hlc(_dateTime, 17, 'abc');

    test('when calling copyWith with new dateTime then result has new dateTime.', () {
      final newDateTime = _dateTime.add(const Duration(minutes: 1));
      final newHlc = hlc.copyWith(dateTime: newDateTime);

      expect(newHlc.dateTime, newDateTime);
    });

    test('when calling copyWith with new counter then result has new counter.', () {
      final newHlc = hlc.copyWith(counter: 18);

      expect(newHlc.counter, 18);
    });

    test('when calling copyWith with new nodeId then result has new nodeId.', () {
      final newHlc = hlc.copyWith(nodeId: 'abcd');

      expect(newHlc.nodeId, 'abcd');
    });
  });
}
