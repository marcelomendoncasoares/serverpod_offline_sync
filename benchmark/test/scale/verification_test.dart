import 'package:serverpod_offline_sync_benchmark/scale/verification.dart';
import 'package:test/test.dart';

/// Journal for one user with two devices: device 0 kept town t1 and deleted
/// t2; device 1 kept t3. City c1 was edited by both devices, c2 by nobody.
UserExpectation journal() => UserExpectation(
  receipts: {
    'r1': {'name': 'receipt:0:0:1', 'surname': 'insert'},
    'r2': {'name': 'receipt:0:0:2', 'surname': 'delete'},
    'r3': {'name': 'receipt:0:1:1', 'surname': 'insert'},
    'r4': {'name': 'receipt:0:1:2', 'surname': 'updateShared'},
  },
  towns: {
    't1': {'name': 'payload-1', 'cityId': 'c1', 'mayorId': null},
    't3': {'name': 'payload-3', 'cityId': 'c2', 'mayorId': null},
  },
  seedCities: {'c1': 'City 0/0', 'c2': 'City 0/1'},
  cityEdits: {
    'c1': {'Edited 0/7', 'Edited 1/2'},
  },
);

List<Map<String, dynamic>> receipts() => [
  {'id': 'r1', 'name': 'receipt:0:0:1', 'surname': 'insert'},
  {'id': 'r2', 'name': 'receipt:0:0:2', 'surname': 'delete'},
  {'id': 'r3', 'name': 'receipt:0:1:1', 'surname': 'insert'},
  {'id': 'r4', 'name': 'receipt:0:1:2', 'surname': 'updateShared'},
];

List<Map<String, dynamic>> cities({String c1 = 'Edited 1/2'}) => [
  {'id': 'c1', 'name': c1},
  {'id': 'c2', 'name': 'City 0/1'},
];

List<Map<String, dynamic>> towns() => [
  {'id': 't1', 'name': 'payload-1', 'cityId': 'c1'},
  {'id': 't3', 'name': 'payload-3', 'cityId': 'c2'},
];

/// Every replica and the server agree on the given tables; only the journal can tell
/// whether that shared state is right.
List<String> agreedOn({
  List<Map<String, dynamic>>? person,
  List<Map<String, dynamic>>? city,
  List<Map<String, dynamic>>? town,
}) {
  final tables = {
    'person': person ?? receipts(),
    'city': city ?? cities(),
    'town': town ?? towns(),
  };
  final snapshot = snapshotOf(tables);
  return journal().mismatches(
    server: snapshot,
    replicas: [snapshot, snapshot],
    replicaCities: tables['city']!,
  );
}

void main() {
  test('Given replicas holding exactly the journaled rows, '
      'when verified, '
      'then they converge.', () {
    expect(agreedOn(), isEmpty);
    expect(agreedOn(city: cities(c1: 'Edited 0/7')), isEmpty);
  });

  test('Given a dropped town insert offset by a resurrected deleted town, '
      'when every replica agrees and the row count still matches, '
      'then verification reports the town difference.', () {
    final problems = agreedOn(
      town: [
        {'id': 't1', 'name': 'payload-1', 'cityId': 'c1'},
        {'id': 't2', 'name': 'payload-2', 'cityId': 'c1'},
      ],
    );

    expect(problems, contains(contains('town ids or fields differ')));
    expect(problems.join(), isNot(contains('row counts')));
    expect(
      journal().townDiff([
        {'id': 't1', 'name': 'payload-1', 'cityId': 'c1'},
        {'id': 't2', 'name': 'payload-2', 'cityId': 'c1'},
      ]),
      {
        'missing': ['t3'],
        'unexpected': ['t2'],
        'changed': <String>[],
      },
    );
  });

  test('Given a lost town move that every replica agrees on, '
      'when verified, '
      'then the stale field is reported.', () {
    final problems = agreedOn(
      town: [
        {'id': 't1', 'name': 'payload-1', 'cityId': 'c1'},
        {'id': 't3', 'name': 'payload-3', 'cityId': 'c1'},
      ],
    );

    expect(problems, [contains('town ids or fields differ')]);
  });

  test('Given a city name that is not any device final edit, '
      'when verified, '
      'then last-writer-wins violations are reported.', () {
    expect(agreedOn(city: cities(c1: 'Edited 0/3')), [contains('city c1')]);
    expect(agreedOn(city: cities(c1: 'City 0/0')), [contains('city c1')]);
    expect(
      agreedOn(
        city: [
          {'id': 'c1', 'name': 'Edited 1/2'},
          {'id': 'c2', 'name': 'Edited 1/2'},
        ],
      ),
      [contains('city c2')],
    );
  });

  test('Given a receipt whose content changed, '
      'when verified, '
      'then the receipt difference is reported.', () {
    final changed = receipts()..[3] = {...receipts()[3], 'surname': 'insert'};

    expect(agreedOn(person: changed), [contains('receipts differ')]);
  });

  test('Given one replica that differs from the server, '
      'when verified, '
      'then that replica is reported.', () {
    final server = snapshotOf({
      'person': receipts(),
      'city': cities(),
      'town': towns(),
    });
    final stale = snapshotOf({'person': receipts(), 'city': cities(), 'town': []});

    final problems = journal().mismatches(
      server: server,
      replicas: [server, stale],
      replicaCities: cities(),
    );

    expect(problems, ['replica 1 differs from the server']);
  });
}
