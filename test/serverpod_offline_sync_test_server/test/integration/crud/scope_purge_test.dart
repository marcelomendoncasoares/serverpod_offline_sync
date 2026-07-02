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
              session,
              where: (t) => t.scopeId.equals(purgedScope.id) & t.includeHiddenRows,
            ),
            greaterThan(0),
          );
          expect(
            await CrdtScopeNode.db.count(
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
              await Person.db.findById(session, purgedKeptPerson.id!),
              isNull,
            );
            expect(
              await Person.db.findById(session, purgedDeletedPerson.id!),
              isNull,
            );
            expect(
              await Person.db.count(
                session,
                where: (t) => t.scopeId.equals(purgedScope.id) & t.includeHiddenRows,
              ),
              0,
            );
          },
        );

        test('then the scope and all its CRDT metadata are removed.', () async {
          expect(await CrdtScope.db.findById(session, purgedScope.id!), isNull);
          expect(
            await CrdtScopeNode.db.count(
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
              await Person.db.findById(session, survivingPerson.id!),
              isNotNull,
            );
            expect(
              await CrdtScope.db.findById(session, survivingScope.id!),
              isNotNull,
            );
            expect(
              await CrdtScopeNode.db.count(
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

  group(
    'Given a scope whose graph spans the CRDT metadata diamond — domain rows '
    'plus the crdt_data_rows / crdt_data_fields / crdt_data_tombstone metadata '
    'that reference crdt_nodes,',
    () {
      late UuidValue userId;
      late CrdtScope scope;

      setUp(() async {
        userId = const Uuid().v7obj();

        // A graph wide enough to generate many CRDT metadata rows: a cascade
        // chain (city -> town), a RESTRICT relation (person <- address), and the
        // mixed FK chain. Every insert records crdt_data_rows / crdt_data_fields
        // rows that reference crdt_nodes.
        await session.db.transactionForUser(userId, (tx) async {
          final city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'City'),
            transaction: tx,
          );
          await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'Town', cityId: city.id),
            transaction: tx,
          );
          final person = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'Person'),
            transaction: tx,
          );
          await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'Street',
              inhabitantId: person.id,
            ),
            transaction: tx,
          );
          final root = await FkChainRoot.db.insertRow(
            session,
            FkChainRoot(id: const Uuid().v7obj(), name: 'Root'),
            transaction: tx,
          );
          final middle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'Cascade middle',
              rootId: root.id,
            ),
            transaction: tx,
          );
          final blocker = await FkChainRestrictBlocker.db.insertRow(
            session,
            FkChainRestrictBlocker(
              id: const Uuid().v7obj(),
              name: 'Restrict blocker',
              cascadeMiddleId: middle.id,
            ),
            transaction: tx,
          );
          await FkChainMiddleSetNullChild.db.insertRow(
            session,
            FkChainMiddleSetNullChild(
              id: const Uuid().v7obj(),
              name: 'Set-null child',
              restrictBlockerId: blocker.id,
            ),
            transaction: tx,
          );
          await FkChainMiddleCascadeChild.db.insertRow(
            session,
            FkChainMiddleCascadeChild(
              id: const Uuid().v7obj(),
              name: 'Cascade child',
              restrictBlockerId: blocker.id,
            ),
            transaction: tx,
          );
        });

        // An extra insert + delete records a tombstone in the scope, exercising
        // the crdt_data_tombstone.nodeId -> crdt_nodes edge of the diamond.
        final disposable = await session.db.transactionForUser(
          userId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'Disposable'),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          userId,
          (tx) => Person.db.deleteRow(session, disposable, transaction: tx),
        );

        scope = await CrdtScopeManager(session).getOrCreate(userId);
      });

      test(
        'when the scope is purged by deleting its crdt_scopes row, '
        'then all domain rows and CRDT metadata are removed.',
        () async {
          await CrdtScope.db.deleteWhere(
            session,
            where: (t) => t.id.equals(scope.id),
          );

          expect(await CrdtScope.db.findById(session, scope.id!), isNull);
          expect(
            await Person.db.count(
              session,
              where: (t) => t.scopeId.equals(scope.id) & t.includeHiddenRows,
            ),
            0,
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.scopeId.equals(scope.id),
            ),
            0,
          );
        },
        skip:
            'Purging this scope by deleting its crdt_scopes row currently fails '
            'with "FOREIGN KEY constraint failed". The scopeId cascade fans out '
            'across the CRDT metadata diamond: crdt_data_rows / crdt_data_fields '
            '/ crdt_data_tombstone reference crdt_nodes with ON DELETE NO ACTION '
            'while both those tables and crdt_nodes cascade off crdt_scopes, so '
            'SQLite enforces the immediate NO ACTION checks mid-cascade before the '
            'referencing rows are themselves deleted. The fix is to generate '
            'those foreign keys as DEFERRABLE INITIALLY DEFERRED, which depends on '
            'upstream Serverpod support for emitting deferrable constraints in '
            'migrations. Until that lands, callers must wrap the purge in a '
            'transaction with "PRAGMA defer_foreign_keys = ON".',
      );
    },
  );
}
