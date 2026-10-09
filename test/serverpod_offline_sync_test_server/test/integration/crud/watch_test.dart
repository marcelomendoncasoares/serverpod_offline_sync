import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  test(
    'Given a fresh wrapper without initialized recorder state, '
    'when a personal row is inserted after subscribing, '
    'then the existing watch discovers the new personal space.',
    () async {
      final fresh = OfflineSyncDatabaseSession.wraps(
        testSession,
        syncTables: testSyncTables,
        persistentUserId: const Uuid().v7obj(),
      );
      final events = _watch(Person.db.watch(fresh, throttle: null));
      final initial = await _next(events);

      final inserted = await Person.db.insertRow(fresh, Person(name: 'first'));
      final result = await _until(events, (rows) => rows.isNotEmpty);
      final found = await Person.db.find(fresh);

      expect(initial, isEmpty);
      expect(result.map((row) => row.id), [inserted.id]);
      expect(result.map((row) => row.toJson()), found.map((row) => row.toJson()));
    },
  );

  test(
    'Given a watch of an empty person table, '
    'when a row is inserted and renamed, '
    'then the same subscription emits both committed changes.',
    () async {
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      final person = await Person.db.insertRow(session, Person(name: 'before'));
      final inserted = await _until(events, (rows) => rows.isNotEmpty);
      await Person.db.updateRow(session, person.copyWith(name: 'after'));
      final updated = await _until(events, (rows) => rows.single.name == 'after');

      expect(initial, isEmpty);
      expect(inserted.single.name, 'before');
      expect(updated.single.id, person.id);
      expect(updated.single.name, 'after');
      expect(updated.single.spaceId, isNull);
    },
  );

  test(
    'Given a watched live row, '
    'when deletion changes only its CRDT visibility, '
    'then the watch hides it while the domain row remains unchanged.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'retained'));
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);
      final before = (await Person.db.findById(testSession, person.id!))!.toJson();

      await Person.db.deleteRow(session, person);
      final deleted = await _until(events, (rows) => rows.isEmpty);
      final after = (await Person.db.findById(testSession, person.id!))!.toJson();
      final found = await Person.db.find(session);

      expect(initial.single.id, person.id);
      expect(deleted, isEmpty);
      expect(found, isEmpty);
      expect(after, before);
    },
  );

  test(
    'Given a watched live row with a local CRDT clock, '
    'when a newer remote delete is merged, '
    'then the subscription hides it while its raw domain row stays unchanged.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Remote delete'));
      final metadata = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
      final before = (await Person.db.findById(testSession, person.id!))!.toJson();
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      await session.db.mergeChanges([
        CrdtMergeDelete(
          uuidSpaceId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: metadata.hlc.datetime.add(const Duration(seconds: 1)),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        ),
      ]);
      final merged = await _until(events, (rows) => rows.isEmpty);
      final found = await Person.db.find(session);
      final after = (await Person.db.findById(testSession, person.id!))!.toJson();

      expect(initial.single.id, person.id);
      expect(merged, isEmpty);
      expect(found, isEmpty);
      expect(after, before);
    },
  );

  test(
    'Given a watched row with a materialized merge visibility record, '
    'when metadata alone hides and restores it, '
    'then the same subscription follows both visibility transitions.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'merged'));
      final metadata = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(person.id),
      ))!;
      final before = (await Person.db.findById(testSession, person.id!))!.toJson();
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      await CrdtDataRow.db.updateRow(
        testSession,
        metadata.copyWith(visibility: CrdtDataRowVisibility.foreignKeyCascade),
      );
      final hidden = await _until(events, (rows) => rows.isEmpty);
      await CrdtDataRow.db.updateRow(
        testSession,
        metadata.copyWith(visibility: CrdtDataRowVisibility.foreignKeyRestrictRestore),
      );
      final restored = await _until(events, (rows) => rows.isNotEmpty);
      final after = (await Person.db.findById(testSession, person.id!))!.toJson();

      expect(initial.single.id, person.id);
      expect(hidden, isEmpty);
      expect(restored.single.id, person.id);
      expect(after, before);
    },
  );

  test(
    'Given visible, deleted, and inaccessible persons, '
    'when a filtered ordered paginated watch starts, '
    'then its rows equal find with the same arguments.',
    () async {
      await Person.db.insert(session, [
        Person(name: 'Alice'),
        Person(name: 'Bob'),
        Person(name: 'Carol'),
      ]);
      final deleted = await Person.db.insertRow(session, Person(name: 'Beatrice'));
      await Person.db.deleteRow(session, deleted);
      await session.db.transactionForUser(
        const Uuid().v7obj(),
        (tx) => Person.db.insertRow(session, Person(name: 'Berta'), transaction: tx),
      );
      final events = _watch(
        Person.db.watch(
          session,
          where: (t) => t.name.notEquals('Alice'),
          orderBy: (t) => t.name,
          limit: 1,
          offset: 1,
        ),
      );

      final result = await _next(events);
      final found = await Person.db.find(
        session,
        where: (t) => t.name.notEquals('Alice'),
        orderBy: (t) => t.name,
        limit: 1,
        offset: 1,
      );

      expect(result.single.name, 'Carol');
      expect(result.map((row) => row.toJson()), found.map((row) => row.toJson()));
    },
  );

  group('Given a shared city with nested citizens and organization members,', () {
    late City city;
    late Person alice;
    late OfflineSyncSpace sharedSpace;
    late CityInclude include;
    late String callerWhere;

    setUp(() async {
      final owner = const Uuid().v7obj();
      await session.db.transactionForUser(owner, (tx) async {
        city = await City.db.insertRow(session, City(name: 'Shared'), transaction: tx);
        final organization = await Organization.db.insertRow(
          session,
          Organization(name: 'Team', cityId: city.id),
          transaction: tx,
        );
        alice = await Person.db.insertRow(
          session,
          Person(name: 'Alice', cityId: city.id, organizationId: organization.id),
          transaction: tx,
        );
        await Person.db.insertRow(
          session,
          Person(name: 'Bob', cityId: city.id, organizationId: organization.id),
          transaction: tx,
        );
      });
      sharedSpace = (await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(owner),
      ))!;
      final citizens = Person.includeList(
        where: (t) => t.name.equals('Alice'),
        include: Person.include(
          organization: Organization.include(
            people: Person.includeList(orderBy: (t) => t.name, limit: 1, offset: 1),
          ),
        ),
      );
      callerWhere = citizens.where.toString();
      include = City.include(citizens: citizens);
    });

    test(
      'when follower membership is projected, revoked, and projected again, '
      'then one subscription refreshes every nested filter without accumulating predicates.',
      () async {
        final events = _watch(City.db.watch(session, include: include, throttle: null));
        final initial = await _next(events);

        final grants = [
          OfflineSyncSpaceGrant(
            uuidSpaceId: sharedSpace.uuidSpaceId,
            role: OfflineSyncSpaceRole.readOnly,
          ),
        ];
        await _projectMembership(grants);
        final joined = await _until(events, (rows) => rows.isNotEmpty);
        final found = await City.db.find(session, include: include);
        await _projectMembership([]);
        final left = await _until(events, (rows) => rows.isEmpty);
        await _projectMembership(grants);
        final rejoined = await _until(events, (rows) => rows.isNotEmpty);

        expect(initial, isEmpty);
        expect(joined.single.id, city.id);
        expect(joined.single.citizens!.single.id, alice.id);
        expect(joined.single.citizens!.single.organization!.people!.single.name, 'Bob');
        expect(joined.map((row) => row.toJson()), found.map((row) => row.toJson()));
        expect(left, isEmpty);
        expect(rejoined.map((row) => row.toJson()), joined.map((row) => row.toJson()));
        expect(
          (include.includes['citizens']! as IncludeList).where.toString(),
          callerWhere,
        );
      },
    );

    test(
      'when two users reuse the include graph and only one receives membership, '
      'then their subscriptions and repeated find calls remain isolated.',
      () async {
        final outsider = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: testSyncTables,
          persistentUserId: const Uuid().v7obj(),
        );
        final ours = _watch(City.db.watch(session, include: include, throttle: null));
        final theirs = _watch(
          City.db.watch(outsider, include: include, throttle: null),
        );
        await _next(ours);
        await _next(theirs);
        final before = await City.db.find(session, include: include);

        await _grant(sharedSpace);
        final joined = await _until(ours, (rows) => rows.isNotEmpty);
        final outsiderRows = await _next(theirs);
        final after = await City.db.find(session, include: include);
        final byId = await City.db.findById(session, city.id!, include: include);
        final first = await City.db.findFirstRow(session, include: include);

        expect(before, isEmpty);
        expect(outsiderRows, isEmpty);
        expect(joined.single.citizens!.single.id, alice.id);
        expect(after.single.citizens!.single.id, alice.id);
        expect(byId!.citizens!.single.id, alice.id);
        expect(first!.citizens!.single.id, alice.id);
        expect(
          (include.includes['citizens']! as IncludeList).where.toString(),
          callerWhere,
        );
      },
    );
  });

  test(
    'Given a watch including a city citizen, '
    'when only the citizen visibility metadata changes, '
    'then the parent remains and its included list becomes empty.',
    () async {
      final city = await City.db.insertRow(session, City(name: 'City'));
      final person = await Person.db.insertRow(
        session,
        Person(name: 'Citizen', cityId: city.id),
      );
      final events = _watch(
        City.db.watch(
          session,
          include: City.include(citizens: Person.includeList()),
          throttle: null,
        ),
      );
      final initial = await _next(events);

      await Person.db.deleteRow(session, person);
      final result = await _until(events, (rows) => rows.single.citizens!.isEmpty);

      expect(initial.single.citizens!.single.id, person.id);
      expect(result.single.id, city.id);
      expect(result.single.citizens, isEmpty);
    },
  );

  test(
    'Given an included citizen whose organization belongs to another city in the same space, '
    'when that organization city becomes merge-hidden, '
    'then nested object predicates filter the citizen without hiding its parent city.',
    () async {
      final home = await City.db.insertRow(session, City(name: 'Home'));
      final office = await City.db.insertRow(session, City(name: 'Office'));
      final organization = await Organization.db.insertRow(
        session,
        Organization(name: 'Team', cityId: office.id),
      );
      await Person.db.insertRow(
        session,
        Person(name: 'Citizen', cityId: home.id, organizationId: organization.id),
      );
      final include = City.include(
        citizens: Person.includeList(
          include: Person.include(
            organization: Organization.include(city: City.include()),
          ),
        ),
      );
      final metadata = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(office.id),
      ))!;
      final events = _watch(
        City.db.watch(
          session,
          where: (t) => t.id.equals(home.id),
          include: include,
          throttle: null,
        ),
      );
      final initial = await _next(events);
      final foundBefore = await City.db.findById(session, home.id!, include: include);

      await CrdtDataRow.db.updateRow(
        testSession,
        metadata.copyWith(visibility: CrdtDataRowVisibility.foreignKeyCascade),
      );
      final result = await _until(events, (rows) => rows.single.citizens!.isEmpty);
      final foundAfter = await City.db.findById(session, home.id!, include: include);

      expect(initial.single.citizens!.single.organization!.city!.id, office.id);
      expect(foundBefore!.toJson(), initial.single.toJson());
      expect(result.single.id, home.id);
      expect(result.single.citizens, isEmpty);
      expect(foundAfter!.toJson(), result.single.toJson());
    },
  );

  test(
    'Given a tombstoned citizen and an explicit includeHiddenRows filter, '
    'when watching the city with that included list, '
    'then the tombstoned citizen is returned just as with find.',
    () async {
      final city = await City.db.insertRow(session, City(name: 'City'));
      final person = await Person.db.insertRow(
        session,
        Person(name: 'Deleted', cityId: city.id),
      );
      await Person.db.deleteRow(session, person);
      final include = City.include(
        citizens: Person.includeList(where: (t) => t.includeHiddenRows),
      );
      final events = _watch(City.db.watch(session, include: include));

      final result = await _next(events);
      final found = await City.db.find(session, include: include);

      expect(result.single.citizens!.single.id, person.id);
      expect(result.map((row) => row.toJson()), found.map((row) => row.toJson()));
    },
  );

  test(
    'Given a watch created and subscribed inside a write transaction, '
    'when that transaction commits, '
    'then included rows are read outside the transaction lock.',
    () async {
      late StreamIterator<List<City>> events;
      late Future<List<City>> first;
      late City city;

      await session.db.transaction((tx) async {
        city = await City.db.insertRow(
          session,
          City(name: 'Committed'),
          transaction: tx,
        );
        await Person.db.insertRow(
          session,
          Person(name: 'Citizen', cityId: city.id),
          transaction: tx,
        );
        events = _watch(
          City.db.watch(
            session,
            include: City.include(citizens: Person.includeList()),
            throttle: null,
          ),
        );
        first = _next(events);
      });
      var result = await first;
      if (result.isEmpty) result = await _until(events, (rows) => rows.isNotEmpty);

      expect(result.single.id, city.id);
      expect(result.single.citizens!.single.name, 'Citizen');
    },
  );

  test(
    'Given a watch subscribed inside a transaction that rolls back, '
    'when a later transaction inserts a different row, '
    'then the watch never exposes the rolled back row and remains usable.',
    () async {
      late StreamIterator<List<Person>> events;
      late Future<List<Person>> first;
      Object? failure;

      try {
        await session.db.transaction((tx) async {
          await Person.db.insertRow(
            session,
            Person(name: 'Rolled back'),
            transaction: tx,
          );
          events = _watch(Person.db.watch(session, throttle: null));
          first = _next(events);
          throw Exception('rollback');
        });
      } on Exception catch (error) {
        failure = error;
      }
      final initial = await first;
      await Person.db.insertRow(session, Person(name: 'Committed'));
      final result = await _until(events, (rows) => rows.isNotEmpty);

      expect(failure, isA<Exception>());
      expect(initial, isEmpty);
      expect(result.map((row) => row.name), ['Committed']);
    },
  );

  test(
    'Given a caller SQL predicate depending on an explicitly declared city table, '
    'when only that city table changes, '
    'then the typed watch reevaluates the caller predicate.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Person'));
      final city = await City.db.insertRow(session, City(name: 'disabled'));
      final rawCity = (await City.db.findById(testSession, city.id!))!;
      final events = _watch(
        Person.db.watch(
          session,
          where: (t) =>
              const Expression("EXISTS (SELECT 1 FROM city WHERE name = 'enabled')"),
          alsoTriggerOnTables: [City.t],
          throttle: null,
        ),
      );
      final initial = await _next(events);

      await City.db.updateRow(testSession, rawCity.copyWith(name: 'enabled'));
      final result = await _until(events, (rows) => rows.isNotEmpty);

      expect(initial, isEmpty);
      expect(result.single.id, person.id);
    },
  );

  test(
    'Given a watch on unsynced space metadata, '
    'when a space is inserted, '
    'then the watch emits the metadata row without CRDT filtering.',
    () async {
      final spaceUuid = const Uuid().v7obj();
      final events = _watch(
        OfflineSyncSpace.db.watch(
          session,
          where: (t) => t.uuidSpaceId.equals(spaceUuid),
          throttle: null,
        ),
      );
      final initial = await _next(events);

      final space = await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: spaceUuid),
      );
      final result = await _until(events, (rows) => rows.isNotEmpty);

      expect(initial, isEmpty);
      expect(result.single.id, space.id);
    },
  );

  test(
    'Given a typed watch with invalid caller SQL, '
    'when SQLite executes the query, '
    'then the database error reaches the subscriber.',
    () async {
      final events = _watch(
        Person.db.watch(
          session,
          where: (t) => const Expression('nonexistent_column = 1'),
        ),
      );
      Object? failure;

      try {
        await _next(events);
      } on DatabaseQueryException catch (error) {
        failure = error;
      }

      expect(failure, isA<DatabaseQueryException>());
    },
  );

  test(
    'Given a raw watch with parameters and explicit table dependencies, '
    'when a matching row is renamed and then tombstoned, '
    'then it preserves raw SQL semantics without filtering tombstones.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'before'));
      final events = _watch(
        session.db.unsafeWatch(
          'SELECT name FROM person WHERE id = @id',
          parameters: QueryParameters.named({'id': person.id!.toBytes()}),
          triggerOnTables: [Person.t.tableName, CrdtDataRow.t.tableName],
          throttle: null,
        ),
      );
      final initial = await _next(events);

      final renamed = await Person.db.updateRow(
        session,
        person.copyWith(name: 'after'),
      );
      final updated = await _next(events);
      await Person.db.deleteRow(session, renamed);
      final deleted = await _next(events);

      expect(initial.single.single, 'before');
      expect(updated.single.single, 'after');
      expect(deleted.single.single, 'after');
    },
  );

  test(
    'Given a wrapper without a persistent user and rows in multiple spaces, '
    'when an admin watch starts, '
    'then its visible rows and space IDs equal an admin find.',
    () async {
      final admin = OfflineSyncDatabaseSession.wraps(
        testSession,
        syncTables: testSyncTables,
      );
      await Person.db.insertRow(session, Person(name: 'Personal'));
      await session.db.transactionForUser(
        const Uuid().v7obj(),
        (tx) => Person.db.insertRow(session, Person(name: 'Other'), transaction: tx),
      );
      final events = _watch(Person.db.watch(admin, orderBy: (t) => t.name));

      final result = await _next(events);
      final found = await Person.db.find(admin, orderBy: (t) => t.name);

      expect(result, hasLength(2));
      expect(result.every((row) => row.spaceId != null), isTrue);
      expect(result.map((row) => row.toJson()), found.map((row) => row.toJson()));
    },
  );
}

StreamIterator<T> _watch<T>(Stream<T> stream) {
  final iterator = StreamIterator(stream);
  addTearDown(iterator.cancel);
  return iterator;
}

Future<T> _next<T>(StreamIterator<T> events) async {
  if (!await events.moveNext().timeout(const Duration(seconds: 10))) {
    throw StateError('Watch ended before the expected emission.');
  }
  return events.current;
}

Future<T> _until<T>(StreamIterator<T> events, bool Function(T) matches) async {
  while (true) {
    final event = await _next(events);
    if (matches(event)) return event;
  }
}

Future<OfflineSyncSpaceMember> _grant(OfflineSyncSpace space) =>
    OfflineSyncSpaceMember.db.insertRow(
      testSession,
      OfflineSyncSpaceMember(
        userUuid: testCrdtUserId,
        spaceId: space.id!,
        role: OfflineSyncSpaceRole.readOnly,
      ),
    );

Future<void> _projectMembership(List<OfflineSyncSpaceGrant> grants) =>
    // Exercise the same authoritative announcement projection used by sync.
    // ignore: invalid_use_of_internal_member
    OfflineSyncSpaceMembership.projectFollowerMembership(
      testSession,
      userUuid: testCrdtUserId,
      grants: grants,
    );
