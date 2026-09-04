import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

import 'hlc_fixtures.dart';

void main() {
  group('Given an HLC', () {
    final hlc = Hlc(hlcTime, 17, hlcNodeId);

    test('when calling copyWith with new dateTime then result has new dateTime.', () {
      final newDateTime = hlcTime.add(const Duration(minutes: 1));
      final newHlc = hlc.copyWith(datetime: newDateTime);

      expect(newHlc.datetime, newDateTime);
    });

    test('when calling copyWith with new counter then result has new counter.', () {
      final newHlc = hlc.copyWith(counter: 18);

      expect(newHlc.counter, 18);
    });

    test('when calling copyWith with new nodeId then result has new nodeId.', () {
      final newHlc = hlc.copyWith(nodeId: hlcSecondNodeId);

      expect(newHlc.nodeId, hlcSecondNodeId);
    });
  });
}
