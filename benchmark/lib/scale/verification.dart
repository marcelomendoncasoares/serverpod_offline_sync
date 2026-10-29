// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:convert';

import 'common.dart';

/// Domain columns compared against the write journal. Other columns are still
/// covered by the full replica digest.
const personFields = [
  'id',
  'name',
  'surname',
  'organizationId',
  'oldCompanyId',
  'cityId',
];
const townFields = ['id', 'name', 'cityId', 'mayorId'];

String projectionDigest(Iterable<Map<String, dynamic>> rows, List<String> fields) =>
    digestStrings(rows.map((row) => jsonEncode([for (final f in fields) row[f]])));

/// Domain values only: spaceId is a database-local surrogate, not synced data.
Map<String, dynamic> snapshotOf(Map<String, List<Map<String, dynamic>>> tables) {
  final canonical = <String>[];
  final counts = <String, int>{};
  for (final entry in tables.entries) {
    counts[entry.key] = entry.value.length;
    for (final row in entry.value) {
      final keys =
          row.keys.where((k) => k != 'spaceId' && k != '__className__').toList()
            ..sort();
      canonical.add(
        jsonEncode([
          entry.key,
          {for (final key in keys) key: row[key]},
        ]),
      );
    }
  }
  return {
    'digest': digestStrings(canonical),
    'rows': counts,
    'receiptsDigest': projectionDigest(tables['person']!, personFields),
    'townsDigest': projectionDigest(tables['town']!, townFields),
  };
}

/// What one user's replicas must contain, derived only from the devices' own
/// write journals.
///
/// Receipts and towns are exact: each device is the sole author of its rows.
/// Concurrently edited city names cannot be predicted without HLCs, but every
/// device's hybrid clock is monotonic and advances past everything it has
/// seen, so the last-writer-wins result must be the final edit of some device
/// that edited the city (or the seed name when nobody did).
class UserExpectation {
  UserExpectation({
    required this.receipts,
    required this.towns,
    required this.seedCities,
    required this.cityEdits,
  });

  /// Receipt id to `{name, surname}`.
  final Map<String, Map<String, Object?>> receipts;

  /// Town id to `{name, cityId}`.
  final Map<String, Map<String, Object?>> towns;

  /// City id to its seeded name.
  final Map<String, String> seedCities;

  /// City id to the final name each editing device wrote.
  final Map<String, Set<String>> cityEdits;

  Map<String, int> get rows => {
    'person': receipts.length,
    'city': seedCities.length,
    'town': towns.length,
  };

  String get receiptsDigest => projectionDigest([
    for (final entry in receipts.entries) {'id': entry.key, ...entry.value},
  ], personFields);

  String get townsDigest => projectionDigest([
    for (final entry in towns.entries) {'id': entry.key, ...entry.value},
  ], townFields);

  Set<String> allowedCityNames(String id) {
    final edits = cityEdits[id];
    return edits == null || edits.isEmpty ? {seedCities[id]!} : edits;
  }

  /// Every reason the server snapshot, replica snapshots and one replica's
  /// city rows disagree with the journal. Empty means converged.
  ///
  /// Replica digests must equal the server digest, so checking city names on
  /// one replica checks them everywhere.
  List<String> mismatches({
    required Map<String, dynamic> server,
    required List<Map<String, dynamic>> replicas,
    required List<Map<String, dynamic>> replicaCities,
  }) {
    final problems = <String>[];
    if (jsonEncode(server['rows']) != jsonEncode(rows)) {
      problems.add(
        'server row counts ${jsonEncode(server['rows'])} != ${jsonEncode(rows)}',
      );
    }
    if (server['receiptsDigest'] != receiptsDigest) {
      problems.add('server receipts differ from the write journal');
    }
    if (server['townsDigest'] != townsDigest) {
      problems.add('server town ids or fields differ from the write journal');
    }
    for (var i = 0; i < replicas.length; i++) {
      if (replicas[i]['digest'] != server['digest']) {
        problems.add('replica $i differs from the server');
      }
    }
    final names = {
      for (final city in replicaCities) city['id'] as String: city['name'] as String,
    };
    if (!_sameKeys(names.keys, seedCities.keys)) {
      problems.add('city ids ${names.keys.toList()..sort()} != seeded ids');
    }
    for (final entry in names.entries) {
      if (!seedCities.containsKey(entry.key)) continue;
      if (!allowedCityNames(entry.key).contains(entry.value)) {
        problems.add(
          'city ${entry.key} is "${entry.value}", not a final edit '
          '${allowedCityNames(entry.key).toList()..sort()}',
        );
      }
    }
    return problems;
  }

  /// Bounded human-readable diff of towns, for failure reports.
  Map<String, dynamic> townDiff(List<Map<String, dynamic>> actual) {
    final byId = {for (final row in actual) row['id'] as String: row};
    List<String> first(Iterable<String> ids) =>
        (ids.toList()..sort()).take(10).toList();
    return {
      'missing': first(towns.keys.where((id) => !byId.containsKey(id))),
      'unexpected': first(byId.keys.where((id) => !towns.containsKey(id))),
      'changed': first(
        towns.entries
            .where(
              (e) =>
                  byId.containsKey(e.key) &&
                  (byId[e.key]!['name'] != e.value['name'] ||
                      byId[e.key]!['cityId'] != e.value['cityId'] ||
                      byId[e.key]!['mayorId'] != null),
            )
            .map((e) => e.key),
      ),
    };
  }
}

bool _sameKeys(Iterable<String> left, Iterable<String> right) {
  final a = left.toSet();
  final b = right.toSet();
  return a.length == b.length && a.containsAll(b);
}
