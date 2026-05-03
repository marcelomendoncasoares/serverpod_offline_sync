import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final _dateTime = DateTime.parse('2001-09-09T01:46:40.000Z');
final _nodeId = const Uuid().v4obj();

void main() {
  group('Given two Hlcs with same dateTime, counter and nodeId when comparing ', () {
    final hlc1 = Hlc(_dateTime, 17, _nodeId);
    final hlc2 = Hlc(_dateTime, 17, _nodeId);

    test('then they are equal.', () {
      expect(hlc1, hlc2);
      expect(hlc1 == hlc2, isTrue);
      expect(hlc1, equals(hlc2));
    });

    test('then compareTo returns 0.', () {
      expect(hlc1.compareTo(hlc2), 0);
    });

    test('then <= is true.', () {
      expect(hlc1 <= hlc2, isTrue);
      expect(hlc1, lessThanOrEqualTo(hlc2));
    });

    test('then >= is true.', () {
      expect(hlc1 >= hlc2, isTrue);
      expect(hlc1, greaterThanOrEqualTo(hlc2));
    });
  });

  group(
    'Given two Hlcs with same dateTime and counter and different nodeId when comparing ',
    () {
      final node2 = const Uuid().v4obj();

      final hlc1 = Hlc(_dateTime, 17, _nodeId);
      final hlc2 = Hlc(_dateTime, 17, node2);

      test('then they are not equal.', () {
        expect(hlc1, isNot(hlc2));
      });

      test('then compareTo follows lexicographic node uuid order.', () {
        expect(
          hlc1.compareTo(hlc2),
          hlc1.nodeId.uuid.compareTo(hlc2.nodeId.uuid),
        );
      });

      test('then one is greater or less by uuid order.', () {
        if (_nodeId.uuid.compareTo(node2.uuid) > 0) {
          expect(hlc1 > hlc2, isTrue);
        } else {
          expect(hlc1 < hlc2, isTrue);
        }
      });
    },
  );

  group('Given two Hlcs with same dateTime and different counter when comparing ', () {
    final hlc1 = Hlc(_dateTime, 17, _nodeId);
    final hlc2 = Hlc(_dateTime, 18, _nodeId);

    test('then they are not equal.', () {
      expect(hlc1, isNot(hlc2));
    });

    test('then compareTo returns -1.', () {
      expect(hlc1.compareTo(hlc2), -1);
    });

    test('then < is true.', () {
      expect(hlc1 < hlc2, isTrue);
      expect(hlc1, lessThan(hlc2));
    });

    test('then <= is true.', () {
      expect(hlc1 <= hlc2, isTrue);
      expect(hlc1, lessThanOrEqualTo(hlc2));
    });

    test('then > is false.', () {
      expect(hlc1 > hlc2, isFalse);
    });

    test('then >= is false.', () {
      expect(hlc1 >= hlc2, isFalse);
      expect(hlc1, isNot(greaterThanOrEqualTo(hlc2)));
    });
  });

  group(
    'Given two Hlcs with different dateTime when comparing ',
    () {
      final hlc1 = Hlc(_dateTime, 0, _nodeId);
      final hlc2 = Hlc(_dateTime.add(const Duration(milliseconds: 1)), 17, _nodeId);

      test('then they are not equal.', () {
        expect(hlc1, isNot(hlc2));
      });

      test('then compareTo returns -1.', () {
        expect(hlc1.compareTo(hlc2), -1);
      });

      test('then < is true.', () {
        expect(hlc1 < hlc2, isTrue);
        expect(hlc1, lessThan(hlc2));
      });

      test('then <= is true.', () {
        expect(hlc1 <= hlc2, isTrue);
        expect(hlc1, lessThanOrEqualTo(hlc2));
      });

      test('then > is false.', () {
        expect(hlc1 > hlc2, isFalse);
      });

      test('then >= is false.', () {
        expect(hlc1 >= hlc2, isFalse);
        expect(hlc1, isNot(greaterThanOrEqualTo(hlc2)));
      });
    },
  );
}
