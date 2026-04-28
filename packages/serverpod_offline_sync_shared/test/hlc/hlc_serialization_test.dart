import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _isoTime = '2001-09-09T01:46:40.000Z';
final _dateTime = DateTime.parse(_isoTime);
final _nodeId = const Uuid().v4obj();

void main() {
  test('Given an HLC built with dateTime, counter and nodeId '
      'when reading properties '
      'then dateTime, counter and nodeId match.', () {
    final hlc = Hlc(_dateTime, 0x17, _nodeId);

    expect(hlc.datetime, _dateTime);
    expect(hlc.counter, 0x17);
    expect(hlc.nodeId, _nodeId);
  });

  test('Given Hlc.zero '
      'when building for a nodeId '
      'then it equals epoch with zero counter.', () {
    final zero = Hlc.zero(_nodeId);

    expect(zero.unixTimestamp, 0);
    expect(zero.counter, 0);
    expect(zero.nodeId, _nodeId);
  });

  test('Given an ISO HLC string '
      'when parsing '
      'then it returns the equivalent Hlc.', () {
    final hlc = Hlc(_dateTime, 0x17, _nodeId);

    expect(Hlc.parse('${_dateTime.toIso8601String()}-0017-$_nodeId'), hlc);
  });

  test('Given a Unix timestamp HLC string '
      'when parsing '
      'then it returns the equivalent Hlc.', () {
    final hlc = Hlc(_dateTime, 0x17, _nodeId);

    expect(Hlc.parse('${_dateTime.millisecondsSinceEpoch}-0017-$_nodeId'), hlc);
  });

  test('Given legacy string with :worker suffix '
      'when parsing '
      'then node id is the uuid only.', () {
    final hlc = Hlc.parse('$_isoTime-0017-$_nodeId:7');
    expect(hlc.nodeId, _nodeId);
    expect(hlc.counter, 0x17);
    expect(hlc.datetime, _dateTime);
  });

  test('Given a parsed Hlc '
      'when calling toString '
      'then it returns the ISO HLC string.', () {
    final hlc = Hlc.parse('$_isoTime-0017-$_nodeId');

    expect(hlc.toString(), '$_isoTime-0017-$_nodeId');
  });

  test('Given an HLC '
      'when converting to JSON '
      'then it returns the equivalent string.', () {
    final hlc = Hlc(_dateTime, 0x17, _nodeId);

    expect(hlc.toJson(), {
      'datetime': _dateTime.toIso8601String(),
      'counter': '0017',
      'node': _nodeId.toString(),
    });
  });
}
