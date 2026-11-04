@TestOn('browser')
library;

import 'dart:async';

import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  late OfflineSyncDatabaseSession session;

  setUp(() async {
    final user = const Uuid().v7obj();
    session = await Client('http://localhost:8081/').createSyncSession(
      'watch-$user.db',
      persistentUserId: user,
    );
    await session.db.initialize();
  });

  tearDown(() async {
    await session.close();
  });

  test(
    'Given a web watch subscribed inside a write transaction, '
    'when the city and its citizen commit, '
    'then the included rows are read outside the transaction lock.',
    () async {
      late StreamIterator<List<City>> events;
      late Future<List<City>> first;
      late City city;

      await session.db.transaction((tx) async {
        city = await City.db.insertRow(session, City(name: 'City'), transaction: tx);
        await Person.db.insertRow(
          session,
          Person(name: 'Citizen', cityId: city.id),
          transaction: tx,
        );
        events = StreamIterator(
          City.db.watch(
            session,
            include: City.include(citizens: Person.includeList()),
            throttle: null,
          ),
        );
        addTearDown(events.cancel);
        first = _next(events);
      });
      var result = await first;
      if (result.isEmpty) result = await _next(events);

      expect(result.single.id, city.id);
      expect(result.single.citizens!.single.name, 'Citizen');
    },
  );

  test(
    'Given a web watch of a person, '
    'when an unrelated city commits followed by a person deletion, '
    'then only the deletion refreshes the watch.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Person'));
      final events = <List<Person>>[];
      final initial = Completer<void>();
      final deleted = Completer<void>();
      final subscription = Person.db.watch(session, throttle: null).listen((rows) {
        events.add(rows);
        if (!initial.isCompleted) initial.complete();
        if (rows.isEmpty && !deleted.isCompleted) deleted.complete();
      });
      addTearDown(subscription.cancel);
      await initial.future.timeout(const Duration(seconds: 10));

      await City.db.insertRow(session, City(name: 'Unrelated'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final afterCity = List.of(events);
      await Person.db.deleteRow(session, person);
      await deleted.future.timeout(const Duration(seconds: 10));

      expect(afterCity, hasLength(1));
      expect(events, hasLength(2));
      expect(events.first.single.id, person.id);
      expect(events.last, isEmpty);
    },
  );
}

Future<T> _next<T>(StreamIterator<T> events) async {
  if (!await events.moveNext().timeout(const Duration(seconds: 10))) {
    throw StateError('Watch ended before its expected emission.');
  }
  return events.current;
}
