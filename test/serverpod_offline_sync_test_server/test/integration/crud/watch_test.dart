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
    'Given a watch configured for metadata writers outside Offline Sync, '
    'when metadata alone hides and restores it, '
    'then the same subscription follows both visibility transitions.',
    () async {
      final externalWriterSession = OfflineSyncDatabaseSession.wraps(
        testSession,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
        context: OfflineSyncDatabaseContext(
          syncTables: testSyncTables,
          serializationManager: testSession.db.serializationManager,
          filterMetadataChanges: false,
        ),
      );
      final person = await Person.db.insertRow(session, Person(name: 'merged'));
      final metadata = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(person.id),
      ))!;
      final before = (await Person.db.findById(testSession, person.id!))!.toJson();
      final events = _watch(Person.db.watch(externalWriterSession, throttle: null));
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
        final theirs = await _record(
          City.db.watch(outsider, include: include, throttle: null),
        );
        await _next(ours);
        final before = await City.db.find(session, include: include);

        await _grant(sharedSpace);
        final joined = await _until(ours, (rows) => rows.isNotEmpty);
        await _settle();
        final outsiderRows = theirs.last;
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
        session,
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
  test(
    'Given a person watch, '
    'when another table is inserted updated and deleted, '
    'then its CRDT metadata and space clock do not reemit the person query.',
    () async {
      await Person.db.insertRow(session, Person(name: 'Watched'));
      final events = await _record(Person.db.watch(session, throttle: null));

      await _settle();
      final beforeCity = events.length;

      final city = await City.db.insertRow(session, City(name: 'Unrelated'));
      await City.db.updateRow(session, city.copyWith(name: 'Renamed'));
      await City.db.deleteRow(session, city);
      await _settle();

      expect(events, hasLength(beforeCity));
      expect(events.every((rows) => rows.single.name == 'Watched'), isTrue);
    },
  );

  test(
    'Given a watched person and a newer inbound rename, '
    'when the rename is merged and replayed, '
    'then only the first merge reemits the query.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Before'));
      final row = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(person.id),
      ))!;
      final rename = CrdtMergeUpdate(
        uuidSpaceId: testCrdtUserId,
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: const Uuid().v7obj(),
        hlcDatetime: row.hlcDatetime.add(const Duration(seconds: 1)),
        hlcCounter: 0,
        columnName: 'name',
        value: 'After',
      );
      final events = await _record(Person.db.watch(session, throttle: null));

      await session.db.mergeChanges([rename]);
      await _waitFor(() => events.last.single.name == 'After');
      await _settle();
      final beforeReplay = events.length;
      await session.db.mergeChanges([rename]);
      await _settle();

      expect(events.first.single.name, 'Before');
      expect(events.last.single.name, 'After');
      expect(events, hasLength(beforeReplay));
    },
  );

  test(
    'Given a person watch and a shared space containing only cities, '
    'when that space is granted and revoked, '
    'then the person watch never exposes rows from that space.',
    () async {
      final owner = const Uuid().v7obj();
      await session.db.transactionForUser(
        owner,
        (tx) => City.db.insertRow(session, City(name: 'Shared'), transaction: tx),
      );
      final events = await _record(Person.db.watch(session, throttle: null));

      await _projectMembership([
        OfflineSyncSpaceGrant(uuidSpaceId: owner, role: OfflineSyncSpaceRole.readOnly),
      ]);
      await _projectMembership([]);
      await _settle();

      expect(events, everyElement(isEmpty));
    },
  );

  test(
    'Given a granted shared person and an active watch, '
    'when the same grants are announced and their role changes, '
    'then unchanged read access does not reemit the query.',
    () async {
      final owner = const Uuid().v7obj();
      await session.db.transactionForUser(
        owner,
        (tx) => Person.db.insertRow(session, Person(name: 'Shared'), transaction: tx),
      );
      final grants = [
        OfflineSyncSpaceGrant(uuidSpaceId: owner, role: OfflineSyncSpaceRole.readOnly),
      ];
      await _projectMembership(grants);
      final events = await _record(Person.db.watch(session, throttle: null));

      await _settle();
      final beforeAnnouncement = events.length;

      await session.db.mergeChanges([]);
      await _projectMembership(grants);
      await _projectMembership([
        OfflineSyncSpaceGrant(uuidSpaceId: owner, role: OfflineSyncSpaceRole.readWrite),
      ]);
      await _settle();

      expect(events, hasLength(beforeAnnouncement));
      expect(events.every((rows) => rows.single.name == 'Shared'), isTrue);
    },
  );

  group('Given a watched person under a cascading organization and city,', () {
    late City city;
    late Person person;
    late CrdtMergeDelete deleted;
    late Map<String, dynamic> before;
    late StreamIterator<List<Person>> events;
    late List<Person> initial;

    setUp(() async {
      city = await City.db.insertRow(session, City(name: 'Parent'));
      final organization = await Organization.db.insertRow(
        session,
        Organization(name: 'Child', cityId: city.id),
      );
      person = await Person.db.insertRow(
        session,
        Person(name: 'Grandchild', organizationId: organization.id),
      );
      final metadata = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(city.id),
      ))!;
      before = (await Person.db.findById(testSession, person.id!))!.toJson();
      events = _watch(Person.db.watch(session, throttle: null));
      initial = await _next(events);
      deleted = CrdtMergeDelete(
        uuidSpaceId: testCrdtUserId,
        tableName: City.t.tableName,
        uuidRowId: city.id!,
        uuidNodeId: const Uuid().v7obj(),
        hlcDatetime: metadata.hlcDatetime.add(const Duration(seconds: 1)),
        hlcCounter: 0,
        clFlag: 2,
        reason: CrdtDataDeletedReason.userDelete,
      );
    });

    test(
      'when an inbound city deletion and restoration are merged, '
      'then the person disappears and returns without a domain write.',
      () async {
        final hiddenTables = await session.db.mergeChanges([deleted]);
        final hidden = await _until(events, (rows) => rows.isEmpty);
        final restoredTables = await session.db.mergeChanges([
          deleted.copyWith(
            hlcCounter: 1,
            clFlag: 3,
            reason: CrdtDataDeletedReason.userInsert,
          ),
        ]);
        final restored = await _until(events, (rows) => rows.isNotEmpty);
        final after = (await Person.db.findById(testSession, person.id!))!.toJson();

        expect(initial.single.id, person.id);
        expect(hidden, isEmpty);
        expect(restored.single.id, person.id);
        expect(after, before);
        expect(hiddenTables, {
          City.t.tableName,
          Organization.t.tableName,
          Person.t.tableName,
        });
        expect(restoredTables, hiddenTables);
      },
    );
  });

  test(
    'Given a person watch and a caller-owned transaction, '
    'when a person insert is rolled back to a savepoint before a city commits, '
    'then the person stays absent while the city is committed.',
    () async {
      final events = await _record(Person.db.watch(session, throttle: null));

      await testSession.db.transaction((tx) async {
        final savepoint = await tx.createSavepoint();
        await Person.db.insertRow(
          session,
          Person(name: 'Rolled back'),
          transaction: tx,
        );
        await savepoint.rollback();
        await savepoint.release();
        await City.db.insertRow(session, City(name: 'Committed'), transaction: tx);
      });
      await _settle();
      final persons = await Person.db.find(session);
      final cities = await City.db.find(session);

      expect(events, everyElement(isEmpty));
      expect(persons, isEmpty);
      expect(cities.single.name, 'Committed');
    },
  );

  test(
    'Given an active person watch, '
    'when a transaction inserts a person and cancels, '
    'then no uncommitted or rolled back result is emitted.',
    () async {
      final events = await _record(Person.db.watch(session, throttle: null));
      late List<List<Person>> duringTransaction;

      await testSession.db.transaction((tx) async {
        await Person.db.insertRow(session, Person(name: 'Cancelled'), transaction: tx);
        await _settle();
        duringTransaction = List.of(events);
        await tx.cancel();
      });
      await _settle();

      expect(duringTransaction, [isEmpty]);
      expect(events, [isEmpty]);
    },
  );

  test(
    'Given a city watch with citizens and their organizations, '
    'when only a nested organization is renamed, '
    'then the included object refreshes.',
    () async {
      final city = await City.db.insertRow(session, City(name: 'Home'));
      final organization = await Organization.db.insertRow(
        session,
        Organization(name: 'Before'),
      );
      await Person.db.insertRow(
        session,
        Person(name: 'Citizen', cityId: city.id, organizationId: organization.id),
      );
      final events = _watch(
        City.db.watch(
          session,
          include: City.include(
            citizens: Person.includeList(
              include: Person.include(organization: Organization.include()),
            ),
          ),
          throttle: null,
        ),
      );
      await _next(events);

      await Organization.db.updateRow(session, organization.copyWith(name: 'After'));
      final result = await _until(
        events,
        (rows) => rows.single.citizens!.single.organization!.name == 'After',
      );

      expect(result.single.id, city.id);
      expect(result.single.citizens!.single.organization!.name, 'After');
    },
  );

  test(
    'Given a person watch with an explicit untracked space dependency, '
    'when that metadata table changes, '
    'then ordinary SQLite notifications still refresh the query.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Person'));
      final space = const Uuid().v7obj();
      final events = _watch(
        Person.db.watch(
          session,
          where: (t) => Expression(
            'EXISTS (SELECT 1 FROM "${OfflineSyncSpace.t.tableName}" '
            'WHERE ${OfflineSyncSpace.t.uuidSpaceId.equals(space)})',
          ),
          alsoTriggerOnTables: [OfflineSyncSpace.t],
          throttle: null,
        ),
      );
      final initial = await _next(events);

      await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: space),
      );
      final result = await _until(events, (rows) => rows.isNotEmpty);

      expect(initial, isEmpty);
      expect(result.single.id, person.id);
    },
  );

  test(
    'Given a person watch with a one second throttle, '
    'when several writes commit within that interval, '
    'then the next emission contains the latest committed state.',
    () async {
      final events = await _record(
        Person.db.watch(
          session,
          throttle: const Duration(seconds: 1),
        ),
      );
      final elapsed = Stopwatch()..start();

      final person = await Person.db.insertRow(session, Person(name: 'First'));
      await Person.db.updateRow(session, person.copyWith(name: 'Second'));
      await Person.db.updateRow(session, person.copyWith(name: 'Last'));
      await _waitFor(() => events.length >= 2);
      final emissionTime = elapsed.elapsed;
      await _settle();

      expect(events, hasLength(2));
      expect(events.first, isEmpty);
      expect(events.last.single.name, 'Last');
      expect(emissionTime, greaterThanOrEqualTo(const Duration(milliseconds: 850)));
    },
  );
  test(
    'Given a follower that already synced a granted shared person, '
    'when another complete sync round exchanges no changes, '
    'then the existing watch does not reemit.',
    () async {
      final peerRaw = await createAdditionalTestSession();
      final peer = OfflineSyncDatabaseSession.wraps(
        peerRaw,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await peer.db.initialize();
      final owner = const Uuid().v7obj();
      await peer.db.transactionForUser(
        owner,
        (tx) => Person.db.insertRow(
          peer,
          Person(name: 'Shared'),
          transaction: tx,
        ),
      );
      final space = (await OfflineSyncSpace.db.findFirstRow(
        peerRaw,
        where: (t) => t.uuidSpaceId.equals(owner),
      ))!;
      await OfflineSyncSpaceMember.db.insertRow(
        peerRaw,
        OfflineSyncSpaceMember(
          userUuid: testCrdtUserId,
          spaceId: space.id!,
          role: OfflineSyncSpaceRole.readOnly,
        ),
      );
      await _syncOnce(peer, session);
      final events = await _record(Person.db.watch(session, throttle: null));

      await _settle();
      // A prior commit's native event may arrive after the initial read.
      // Measure this round after those earlier notifications have settled.
      final beforeSync = events.length;
      final changes = await _syncOnce(peer, session);
      await _settle();

      expect(changes, isEmpty);
      expect(events, hasLength(beforeSync));
      expect(events.every((rows) => rows.single.name == 'Shared'), isTrue);
    },
  );

  test(
    'Given a city and a person with newer remote deletions, '
    'when both deletions are merged and replayed, '
    'then only the first merge reports affected tables.',
    () async {
      final city = await City.db.insertRow(session, City(name: 'City'));
      final person = await Person.db.insertRow(session, Person(name: 'Person'));
      final rows = await CrdtDataRow.db.find(
        testSession,
        where: (t) => t.uuidRowId.inSet({city.id!, person.id!}),
      );
      final node = const Uuid().v7obj();
      final changes = [
        for (final row in rows)
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: row.uuidRowId == city.id ? City.t.tableName : Person.t.tableName,
            uuidRowId: row.uuidRowId,
            uuidNodeId: node,
            hlcDatetime: row.hlcDatetime.add(const Duration(seconds: 1)),
            hlcCounter: 0,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
      ];

      final affected = await session.db.mergeChanges(changes);
      final replayed = await session.db.mergeChanges(changes);

      expect(affected, {City.t.tableName, Person.t.tableName});
      expect(replayed, isEmpty);
    },
  );

  test(
    'Given a paused person watch, '
    'when a person is inserted and renamed before resuming, '
    'then resuming reads the latest committed result.',
    () async {
      final events = <List<Person>>[];
      final subscription = Person.db.watch(session, throttle: null).listen(events.add);
      addTearDown(subscription.cancel);
      await _waitFor(() => events.isNotEmpty);
      subscription.pause();

      final person = await Person.db.insertRow(session, Person(name: 'Before'));
      await Person.db.updateRow(session, person.copyWith(name: 'After'));
      await _settle();
      final pausedEvents = List.of(events);
      subscription.resume();
      await _waitFor(() => events.length == 2);

      expect(pausedEvents, [isEmpty]);
      expect(events.last.single.name, 'After');
    },
  );
  test(
    'Given an empty watched follower and a person on another replica, '
    'when a complete sync round delivers that person, '
    'then the existing subscription emits the inbound row.',
    () async {
      final peer = OfflineSyncDatabaseSession.wraps(
        await createAdditionalTestSession(),
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      final person = await Person.db.insertRow(peer, Person(name: 'Arrived'));
      final events = await _record(Person.db.watch(session, throttle: null));

      final affected = <Set<String>>[];
      final changes = await _syncOnce(
        peer,
        session,
        onMergeSuccess: (_, _, tables) => affected.add(tables),
      );
      await _waitFor(() => events.any((rows) => rows.isNotEmpty));

      expect(changes.whereType<CrdtMergeInsert>().single.uuidRowId, person.id);
      expect(events.first, isEmpty);
      expect(events.last.single.id, person.id);
      expect(events.last.single.name, 'Arrived');
      expect(affected, contains(equals({Person.t.tableName})));
    },
  );

  test(
    'Given a person watch, '
    'when a local update writes the same values and advances only its clock, '
    'then native domain notifications may reemit the unchanged row.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Unchanged'));
      final events = await _record(Person.db.watch(session, throttle: null));

      await Person.db.updateRow(session, person);
      await _waitFor(() => events.length > 1);

      expect(events, hasLength(greaterThan(1)));
      expect(events.every((rows) => rows.single.name == 'Unchanged'), isTrue);
    },
  );
  test(
    'Given a watch and an independently initialized wrapper on the same database, '
    'when the other wrapper inserts a person, '
    'then the existing watch receives the committed row.',
    () async {
      final writer = OfflineSyncDatabaseSession.wraps(
        testSession,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await writer.db.initialize();
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      final person = await Person.db.insertRow(writer, Person(name: 'Other wrapper'));
      final result = await _until(events, (rows) => rows.isNotEmpty);

      expect(initial, isEmpty);
      expect(result.single.id, person.id);
    },
  );
  test(
    'Given a deletion inside a transaction owned by the underlying database, '
    'when a watch reads before that transaction commits, '
    'then the later native metadata event still hides the row.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Borrowed'));
      final written = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final transaction = testSession.db.transaction((tx) async {
        await Person.db.deleteRow(session, person, transaction: tx);
        written.complete();
        await release.future;
      });
      await written.future.timeout(const Duration(seconds: 10));
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      release.complete();
      await transaction;
      final hidden = await _until(events, (rows) => rows.isEmpty);

      expect(initial.single.id, person.id);
      expect(hidden, isEmpty);
    },
  );

  test(
    'Given an observed application transaction containing a city insert, '
    'when it also changes person visibility directly through the delegate, '
    'then its unclassified metadata change refreshes the person watch.',
    () async {
      final person = await Person.db.insertRow(session, Person(name: 'Visible'));
      final row = (await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(person.id),
      ))!;
      final events = _watch(Person.db.watch(session, throttle: null));
      final initial = await _next(events);

      await session.db.transaction((tx) async {
        await City.db.insertRow(session, City(name: 'Known'), transaction: tx);
        await CrdtDataRow.db.updateRow(
          testSession,
          row.copyWith(visibility: CrdtDataRowVisibility.userDelete),
          columns: (t) => [t.visibility],
          transaction: tx,
        );
      });
      final hidden = await _until(events, (rows) => rows.isEmpty);

      expect(initial.single.id, person.id);
      expect(hidden, isEmpty);
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

Future<List<T>> _record<T>(Stream<T> stream) async {
  final events = <T>[];
  final ready = Completer<void>();
  final subscription = stream.listen(
    (event) {
      events.add(event);
      if (!ready.isCompleted) ready.complete();
    },
    onError: (Object error, StackTrace stack) {
      if (!ready.isCompleted) {
        ready.completeError(error, stack);
      } else {
        Error.throwWithStackTrace(error, stack);
      }
    },
  );
  addTearDown(subscription.cancel);
  await ready.future.timeout(const Duration(seconds: 10));
  return events;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 150));

Future<void> _waitFor(bool Function() condition) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed > const Duration(seconds: 10)) {
      throw StateError('Expected watch emission did not arrive.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<List<CrdtMergeChange>> _syncOnce(
  OfflineSyncDatabaseSession authoritative,
  OfflineSyncDatabaseSession follower, {
  OfflineSyncOnMergeSuccess? onMergeSuccess,
}) async {
  final toServer = StreamController<OfflineSyncStreamEvent>();
  final toClient = StreamController<OfflineSyncStreamEvent>();
  final serverDone = Completer<void>();
  final clientDone = Completer<void>();
  final changes = <CrdtMergeChange>[];

  void relay(
    OfflineSyncStreamEvent event,
    StreamController<OfflineSyncStreamEvent> target,
  ) {
    if (event is OfflineSyncMergeChunk) changes.addAll(event.changes);
    if (!target.isClosed) target.add(event);
  }

  final server = authoritative.db
      .sync(
        inbound: toServer.stream,
        mode: OfflineSyncPeerMode.authoritative,
        once: true,
      )
      .listen(
        (event) => relay(event, toClient),
        onError: serverDone.completeError,
        onDone: serverDone.complete,
      );
  final client = follower.db
      .sync(
        inbound: toClient.stream,
        mode: OfflineSyncPeerMode.follower,
        once: true,
        onMergeSuccess: onMergeSuccess,
      )
      .listen(
        (event) => relay(event, toServer),
        onError: clientDone.completeError,
        onDone: clientDone.complete,
      );

  try {
    await Future.wait([
      serverDone.future,
      clientDone.future,
    ]).timeout(const Duration(seconds: 10));
    return changes;
  } finally {
    await server.cancel();
    await client.cancel();
    unawaited(toServer.close());
    unawaited(toClient.close());
  }
}
