// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'common.dart';
import 'round_options.dart';
import 'verification.dart';

String roundTable(RoundOptions options) => switch (options.values['workload']) {
  'city' => 'city',
  'town' || 'town-linked' => 'town',
  _ => 'person',
};

List<String> roundFields(String table) => switch (table) {
  'city' => ['id', 'name'],
  'person' => personFields,
  'town' => townFields,
  _ => throw ArgumentError.value(table, 'table'),
};

List<TableRow<UuidValue?>> makeRoundRows(
  RoundOptions options,
  int user,
  int sequence,
  int writer,
  int count,
) {
  final table = roundTable(options);
  final linked = (options.values['workload'] as String? ?? '').endsWith('-linked');
  return [
    for (var index = 0; index < count; index++)
      () {
        final id = benchmarkId(
          options.updates
              ? '${options.scale.runId}/$user/update/$index'
              : '${options.scale.runId}/$user/round/$sequence/$index',
        );
        final marker = 'round:$sequence/row:$index/writer:$writer';
        final payload = seededPayload(
          mixSeed([user, sequence, index]),
          options.number('payload-bytes'),
          '',
        );
        final city = linked
            ? benchmarkId('${options.scale.runId}/$user/parent-city')
            : null;
        return switch (table) {
          'city' => City(id: id, name: '$marker/$payload'),
          'person' => Person(id: id, name: payload, surname: marker, cityId: city),
          'town' => Town(
            id: id,
            name: '$marker/$payload',
            cityId: city,
            mayorId: linked
                ? benchmarkId('${options.scale.runId}/$user/parent-person')
                : null,
          ),
          _ => throw StateError('Unknown table $table'),
        };
      }(),
  ];
}

Map<String, List<TableRow<UuidValue?>>> roundParents(RoundOptions options, int user) {
  if (!(options.values['workload'] as String? ?? '').endsWith('-linked')) return {};
  final city = benchmarkId('${options.scale.runId}/$user/parent-city');
  return {
    'city': [City(id: city, name: 'parent-city')],
    if (roundTable(options) == 'town')
      'person': [
        Person(
          id: benchmarkId('${options.scale.runId}/$user/parent-person'),
          name: 'parent-person',
          cityId: city,
        ),
      ],
  };
}

Stream<List<TableRow<UuidValue?>>> watchRoundRows(
  OfflineSyncDatabaseSession session,
  String table,
  Set<UuidValue> ids,
) => switch (table) {
  'city' => City.db.watch(session, where: (t) => t.id.inSet(ids), throttle: null),
  'person' => Person.db.watch(session, where: (t) => t.id.inSet(ids), throttle: null),
  'town' => Town.db.watch(session, where: (t) => t.id.inSet(ids), throttle: null),
  _ => throw ArgumentError.value(table, 'table'),
};

Future<void> writeRoundRows(
  OfflineSyncDatabaseSession session,
  Transaction tx,
  String table,
  List<TableRow<UuidValue?>> rows, {
  required bool insert,
}) async {
  switch (table) {
    case 'city':
      if (insert) {
        await City.db.insert(session, rows.cast<City>(), transaction: tx);
      } else {
        await City.db.update(
          session,
          rows.cast<City>(),
          columns: (t) => [t.name],
          transaction: tx,
        );
      }
    case 'person':
      if (insert) {
        await Person.db.insert(session, rows.cast<Person>(), transaction: tx);
      } else {
        await Person.db.update(
          session,
          rows.cast<Person>(),
          columns: (t) => [t.name, t.surname],
          transaction: tx,
        );
      }
    case 'town':
      if (insert) {
        await Town.db.insert(session, rows.cast<Town>(), transaction: tx);
      } else {
        await Town.db.update(
          session,
          rows.cast<Town>(),
          columns: (t) => [t.name],
          transaction: tx,
        );
      }
    default:
      throw ArgumentError.value(table, 'table');
  }
}
