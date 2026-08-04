import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';

import 'hlc_fixtures.dart';

final _isoTime = hlcTime.toIso8601String();

void main() {
  test('Given an HLC built with dateTime, counter and nodeId '
      'when reading properties '
      'then dateTime, counter and nodeId match.', () {
    final hlc = Hlc(hlcTime, 0x17, hlcNodeId);

    expect(hlc.datetime, hlcTime);
    expect(hlc.counter, 0x17);
    expect(hlc.nodeId, hlcNodeId);
  });

  test('Given Hlc.zero '
      'when building for a nodeId '
      'then it equals epoch with zero counter.', () {
    final zero = Hlc.zero(hlcNodeId);

    expect(zero.unixTimestamp, 0);
    expect(zero.counter, 0);
    expect(zero.nodeId, hlcNodeId);
  });

  test('Given an ISO HLC string '
      'when parsing '
      'then it returns the equivalent Hlc.', () {
    final hlc = Hlc(hlcTime, 0x17, hlcNodeId);

    expect(Hlc.parse('${hlcTime.toIso8601String()}-0017-$hlcNodeId'), hlc);
  });

  test('Given a Unix timestamp HLC string '
      'when parsing '
      'then it returns the equivalent Hlc.', () {
    final hlc = Hlc(hlcTime, 0x17, hlcNodeId);

    expect(Hlc.parse('${hlcTime.millisecondsSinceEpoch}-0017-$hlcNodeId'), hlc);
  });

  test('Given legacy string with :worker suffix '
      'when parsing '
      'then node id is the uuid only.', () {
    final hlc = Hlc.parse('$_isoTime-0017-$hlcNodeId:7');
    expect(hlc.nodeId, hlcNodeId);
    expect(hlc.counter, 0x17);
    expect(hlc.datetime, hlcTime);
  });

  test('Given a parsed Hlc '
      'when calling toString '
      'then it returns the ISO HLC string.', () {
    final hlc = Hlc.parse('$_isoTime-0017-$hlcNodeId');

    expect(hlc.toString(), '$_isoTime-0017-$hlcNodeId');
  });

  test('Given an HLC '
      'when converting to JSON '
      'then it returns the equivalent string.', () {
    final hlc = Hlc(hlcTime, 0x17, hlcNodeId);

    expect(hlc.toJson(), {
      'datetime': hlcTime.toIso8601String(),
      'counter': '0017',
      'node': hlcNodeId.toString(),
    });
  });
}
