import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

import 'hlc_fixtures.dart';

void main() {
  group('Given two Hlcs with same dateTime, counter and nodeId when comparing ', () {
    final hlc1 = Hlc(hlcTime, 17, hlcNodeId);
    final hlc2 = Hlc(hlcTime, 17, hlcNodeId);

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
      final hlc1 = Hlc(hlcTime, 17, hlcNodeId);
      final hlc2 = Hlc(hlcTime, 17, hlcSecondNodeId);

      test('then they are not equal.', () {
        expect(hlc1, isNot(hlc2));
      });

      test('then compareTo follows lexicographic node uuid order.', () {
        expect(
          hlc1.compareTo(hlc2),
          hlc1.nodeId.uuid.compareTo(hlc2.nodeId.uuid),
        );
      });

      test('then the lower node uuid is the lesser Hlc.', () {
        expect(hlc1 < hlc2, isTrue);
        expect(hlc2 > hlc1, isTrue);
      });
    },
  );

  group('Given two Hlcs with same dateTime and different counter when comparing ', () {
    final hlc1 = Hlc(hlcTime, 17, hlcNodeId);
    final hlc2 = Hlc(hlcTime, 18, hlcNodeId);

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
      final hlc1 = Hlc(hlcTime, 0, hlcNodeId);
      final hlc2 = Hlc(hlcTime.advance(), 17, hlcNodeId);

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
