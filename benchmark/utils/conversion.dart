import 'package:intl/intl.dart';

final formatter0 = NumberFormat.decimalPatternDigits(decimalDigits: 0);
final formatter2 = NumberFormat.decimalPatternDigits(decimalDigits: 2);
final formatter3 = NumberFormat.decimalPatternDigits(decimalDigits: 3);

extension FormattedStorageSize on num {
  String toFormattedDuration() {
    var time = this;
    var unit = 1;

    while (time.abs() > 1000 && unit < Duration.microsecondsPerSecond) {
      time /= 1000;
      unit *= 1000;
    }
    while (unit > Duration.microsecondsPerMinute && time.abs() > 60) {
      time /= 60;
      unit *= 60;
    }
    return '${formatter2.format(time)} ${switch (unit) {
      1 => 'μs',
      Duration.millisecondsPerSecond => 'ms',
      Duration.microsecondsPerSecond => 's',
      Duration.microsecondsPerMinute => 'min',
      Duration.microsecondsPerHour => 'h',
      _ => throw Exception('Unexpected time unit: $unit'),
    }}';
  }

  String toFormattedStorageSize() {
    var storageIncrease = toDouble();
    var storageUnit = 1;

    while (storageIncrease > 1024) {
      storageIncrease /= 1024;
      storageUnit *= 1024;
    }

    final storageUnitString = switch (storageUnit) {
      1 => 'B',
      1024 => 'KB',
      const (1024 * 1024) => 'MB',
      _ => throw Exception('Unexpected storage unit: $storageUnit'),
    };

    return '${formatter2.format(storageIncrease)} $storageUnitString';
  }
}
