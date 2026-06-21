import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a person table with a live and a tombstoned row,', () {
    late Person liveRow;
    late Person deletedRow;

    setUp(() async {
      liveRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'live'), transaction: tx),
      );

      deletedRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'deleted'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, deletedRow, transaction: tx),
      );
    });

    test(
      'when using find with includeHiddenRows, '
      'then both the live and tombstoned rows are returned.',
      () async {
        final result = await Person.db.find(
          session,
          where: (t) => t.includeHiddenRows,
        );

        expect(
          result.map((r) => r.id).toSet(),
          {liveRow.id, deletedRow.id},
        );
      },
    );

    test(
      'when using findFirstRow with includeHiddenRows and a name filter, '
      'then the tombstoned row is returned.',
      () async {
        final result = await Person.db.findFirstRow(
          session,
          where: (t) => t.name.equals('deleted') & t.includeHiddenRows,
        );

        expect(result, isNotNull);
        expect(result!.id, deletedRow.id);
      },
    );

    test(
      'when using find with ID filter and includeHiddenRows,'
      ' then the tombstoned row is returned.',
      () async {
        final result = await Person.db.find(
          session,
          where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
        );

        expect(result, hasLength(1));
        expect(result.single.id, deletedRow.id);
      },
    );

    test(
      'when using find without includeHiddenRows, '
      'then only the live row is returned.',
      () async {
        final result = await Person.db.find(session);

        expect(result.map((r) => r.id).toSet(), {liveRow.id});
      },
    );
  });

  group(
    'Given a city with a live citizen and a tombstoned citizen,',
    () {
      late City city;
      late Person liveCitizen;
      late Person deletedCitizen;

      setUp(() async {
        city = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              City.db.insertRow(session, City(name: 'Springfield'), transaction: tx),
        );

        liveCitizen = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, Person(name: 'live'), transaction: tx),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              City.db.attachRow.citizens(session, city, liveCitizen, transaction: tx),
        );

        deletedCitizen = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'deleted'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => City.db.attachRow.citizens(
            session,
            city,
            deletedCitizen,
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, deletedCitizen, transaction: tx),
        );
      });

      test(
        'when fetching the city with default citizens include, '
        'then only the live citizen is returned.',
        () async {
          final result = await City.db.findById(
            session,
            city.id!,
            include: City.include(citizens: Person.includeList()),
          );

          expect(result, isNotNull);
          expect(result!.citizens?.map((c) => c.id).toSet(), {liveCitizen.id});
        },
      );

      test(
        'when fetching the city with includeHiddenRows in citizens list where, '
        'then both live and tombstoned citizens are returned.',
        () async {
          final result = await City.db.findById(
            session,
            city.id!,
            include: City.include(
              citizens: Person.includeList(
                where: (t) => t.includeHiddenRows,
              ),
            ),
          );

          expect(result, isNotNull);
          expect(
            result!.citizens?.map((c) => c.id).toSet(),
            {liveCitizen.id, deletedCitizen.id},
          );
        },
      );

      test(
        'when fetching the city with a name filter and includeHiddenRows in '
        'citizens list where, then only the matching tombstoned citizen is returned.',
        () async {
          final result = await City.db.findById(
            session,
            city.id!,
            include: City.include(
              citizens: Person.includeList(
                where: (t) => t.name.equals('deleted') & t.includeHiddenRows,
              ),
            ),
          );

          expect(result, isNotNull);
          expect(
            result!.citizens?.map((c) => c.id).toSet(),
            {deletedCitizen.id},
          );
        },
      );
    },
  );
}
