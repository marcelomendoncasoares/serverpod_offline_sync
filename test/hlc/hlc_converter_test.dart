import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

const _isoTime = '2001-09-09T01:46:40.000Z';
final _dateTime = DateTime.parse(_isoTime);

void main() {
  test('Given an HLC and the HlcConverter '
      'when converting to the database format '
      'then it returns string with padded unix timestamp.', () {
    final hlc = Hlc(_dateTime, 0x17, 'abc');

    expect(
      hlcConverter.toSql(hlc),
      '${_dateTime.millisecondsSinceEpoch.toString().padLeft(15, '0')}-0017-abc',
    );
  });

  test('Given an HLC and the HlcConverter '
      'when converting from the database format '
      'then it returns the equivalent HLC.', () {
    final hlc = Hlc(_dateTime, 0x17, 'abc');
    final databaseHlc = hlcConverter.toSql(hlc);

    expect(hlcConverter.fromSql(databaseHlc), hlc);
  });
}
