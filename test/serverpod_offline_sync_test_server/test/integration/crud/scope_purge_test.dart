import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a purged scope and a surviving scope, each owning domain rows and '
    'CRDT metadata, plus an orphan row with no scope,',
    () {
      late UuidValue purgedUserId;
      late UuidValue survivingUserId;
      late CrdtScope purgedScope;
      late CrdtScope survivingScope;
      // Row kept until purge (also updated, to record field metadata).
      late Person purgedKeptPerson;
      // Row soft-deleted before purge, to record a tombstone.
      late Person purgedDeletedPerson;
      // Row owned by the surviving scope.
      late Person survivingPerson;
      // Row written outside CRDT (scopeId stays null).
      late Person orphanPerson;

      setUp(() async {
        purgedUserId = const Uuid().v7obj();
        survivingUserId = const Uuid().v7obj();

        // Purged scope: two inserts, one update (field metadata) and one delete
        // (tombstone), so every metadata kind is exercised by the cascade.
        purgedKeptPerson = await session.db.transactionForUser(
          purgedUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'purged-keep'),
            transaction: tx,
          ),
        );
        purgedDeletedPerson = await session.db.transactionForUser(
          purgedUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'purged-delete'),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          purgedUserId,
          (tx) => Person.db.updateRow(
            session,
            purgedKeptPerson.copyWith(name: 'purged-keep-renamed'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          purgedUserId,
          (tx) => Person.db.deleteRow(session, purgedDeletedPerson, transaction: tx),
        );

        // Surviving scope: one insert that must outlive the purge.
        survivingPerson = await session.db.transactionForUser(
          survivingUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'surviving'),
            transaction: tx,
          ),
        );

        // Orphan/admin row written outside CRDT, so scopeId stays null.
        orphanPerson = await Person.db.insertRow(
          testSession,
          Person(id: const Uuid().v7obj(), name: 'orphan'),
        );

        purgedScope = await CrdtScopeManager(session).getOrCreate(purgedUserId);
        survivingScope = await CrdtScopeManager(session).getOrCreate(survivingUserId);
      });

      test(
        'when inspecting state before the purge, '
        'then the purged scope owns domain rows and every metadata kind.',
        () async {
          expect(
            await Person.db.count(
              testSession,
              where: (t) => t.scopeId.equals(purgedScope.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtNode.db.count(
              session,
              where: (t) => t.scopeId.equals(purgedScope.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.scopeId.equals(purgedScope.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataField.db.count(
              session,
              where: (t) => t.row.scopeId.equals(purgedScope.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataDeleted.db.count(
              session,
              where: (t) => t.row.scopeId.equals(purgedScope.id),
            ),
            greaterThan(0),
          );
        },
      );

      group('when the scope is purged by deleting its crdt_scopes row,', () {
        setUp(() async {
          await CrdtScope.db.deleteWhere(
            session,
            where: (t) => t.id.equals(purgedScope.id),
          );
        });

        test(
          'then the scope-owned domain rows are physically removed.',
          () async {
            expect(
              await Person.db.findById(testSession, purgedKeptPerson.id!),
              isNull,
            );
            expect(
              await Person.db.findById(testSession, purgedDeletedPerson.id!),
              isNull,
            );
            expect(
              await Person.db.count(
                testSession,
                where: (t) => t.scopeId.equals(purgedScope.id),
              ),
              0,
            );
          },
        );

        test('then the scope and all its CRDT metadata are removed.', () async {
          expect(await CrdtScope.db.findById(session, purgedScope.id!), isNull);
          expect(
            await CrdtNode.db.count(
              session,
              where: (t) => t.scopeId.equals(purgedScope.id),
            ),
            0,
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.scopeId.equals(purgedScope.id),
            ),
            0,
          );
          expect(
            await CrdtDataField.db.count(
              session,
              where: (t) => t.row.scopeId.equals(purgedScope.id),
            ),
            0,
          );
          expect(
            await CrdtDataDeleted.db.count(
              session,
              where: (t) => t.row.scopeId.equals(purgedScope.id),
            ),
            0,
          );
        });

        test(
          'then the surviving scope keeps its domain rows and metadata.',
          () async {
            expect(
              await Person.db.findById(testSession, survivingPerson.id!),
              isNotNull,
            );
            expect(
              await CrdtScope.db.findById(session, survivingScope.id!),
              isNotNull,
            );
            expect(
              await CrdtNode.db.count(
                session,
                where: (t) => t.scopeId.equals(survivingScope.id),
              ),
              greaterThan(0),
            );
            expect(
              await CrdtDataRow.db.count(
                session,
                where: (t) => t.scopeId.equals(survivingScope.id),
              ),
              greaterThan(0),
            );
          },
        );

        test('then orphan rows with a null scope are preserved.', () async {
          final orphan = await Person.db.findById(testSession, orphanPerson.id!);
          expect(orphan, isNotNull);
          expect(orphan!.scopeId, isNull);
        });
      });
    },
  );
}
