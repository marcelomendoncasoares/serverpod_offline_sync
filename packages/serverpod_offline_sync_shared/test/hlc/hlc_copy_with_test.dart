import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final _dateTime = DateTime.parse('2001-09-09T01:46:40.000Z');
final _node = NodeWithWorker(nodeId: const Uuid().v4obj(), workerId: 1);

void main() {
  group('Given an HLC', () {
    final hlc = Hlc(_dateTime, 17, _node);

    test('when calling copyWith with new dateTime then result has new dateTime.', () {
      final newDateTime = _dateTime.add(const Duration(minutes: 1));
      final newHlc = hlc.copyWith(datetime: newDateTime);

      expect(newHlc.datetime, newDateTime);
    });

    test('when calling copyWith with new counter then result has new counter.', () {
      final newHlc = hlc.copyWith(counter: 18);

      expect(newHlc.counter, 18);
    });

    test('when calling copyWith with new nodeId then result has new nodeId.', () {
      final newNode = NodeWithWorker(nodeId: const Uuid().v4obj(), workerId: 2);
      final newHlc = hlc.copyWith(node: newNode);

      expect(newHlc.node, newNode);
    });
  });
}
