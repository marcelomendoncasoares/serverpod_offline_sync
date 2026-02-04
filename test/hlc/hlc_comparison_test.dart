import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

final _dateTime = DateTime.parse('2001-09-09T01:46:40.000Z');

void main() {
  group('Given two Hlcs with same dateTime, counter and nodeId when comparing ', () {
    final hlc1 = Hlc(_dateTime, 17, 'abc');
    final hlc2 = Hlc(_dateTime, 17, 'abc');

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
      final hlc1 = Hlc(_dateTime, 17, 'abc');
      final hlc2 = Hlc(_dateTime, 17, 'abb');

      test('then they are not equal.', () {
        expect(hlc1, isNot(hlc2));
      });

      test('then compareTo returns 1.', () {
        expect(hlc1.compareTo(hlc2), 1);
      });

      test('then lexicographically greater nodeId is greater.', () {
        expect(hlc1 > hlc2, isTrue);
        expect(hlc1, greaterThan(hlc2));
      });

      test('then >= is true.', () {
        expect(hlc1 >= hlc2, isTrue);
        expect(hlc1, greaterThanOrEqualTo(hlc2));
      });

      test('then < is false.', () {
        expect(hlc1 < hlc2, isFalse);
      });

      test('then <= is false.', () {
        expect(hlc1 <= hlc2, isFalse);
        expect(hlc1, isNot(lessThanOrEqualTo(hlc2)));
      });
    },
  );

  group('Given two Hlcs with same dateTime and different counter when comparing ', () {
    final hlc1 = Hlc(_dateTime, 17, 'abc');
    final hlc2 = Hlc(_dateTime, 18, 'abc');

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
      final hlc1 = Hlc(_dateTime, 0, 'abc');
      final hlc2 = Hlc(_dateTime.add(const Duration(milliseconds: 1)), 17, 'abc');

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
