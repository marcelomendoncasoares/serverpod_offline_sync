import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a purged space and a surviving space, each owning domain rows and '
    'CRDT metadata, plus an orphan row with no space,',
    () {
      late UuidValue purgedUserId;
      late UuidValue survivingUserId;
      late OfflineSyncSpace purgedSpace;
      late OfflineSyncSpace survivingSpace;
      // Row kept until purge (also updated, to record field metadata).
      late Person purgedKeptPerson;
      // Row soft-deleted before purge, to record a tombstone.
      late Person purgedDeletedPerson;
      // Row owned by the surviving space.
      late Person survivingPerson;
      // Row written outside CRDT (spaceId stays null).
      late Person orphanPerson;

      setUp(() async {
        purgedUserId = const Uuid().v7obj();
        survivingUserId = const Uuid().v7obj();

        // Purged space: two inserts, one update (field metadata) and one delete
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

        // Surviving space: one insert that must outlive the purge.
        survivingPerson = await session.db.transactionForUser(
          survivingUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'surviving'),
            transaction: tx,
          ),
        );

        // Orphan/admin row written outside CRDT, so spaceId stays null.
        orphanPerson = await Person.db.insertRow(
          testSession,
          Person(id: const Uuid().v7obj(), name: 'orphan'),
        );

        purgedSpace = await OfflineSyncSpaceManager(session).getOrCreate(purgedUserId);
        survivingSpace = await OfflineSyncSpaceManager(
          session,
        ).getOrCreate(survivingUserId);
      });

      test(
        'when inspecting state before the purge, '
        'then the purged space owns domain rows and every metadata kind.',
        () async {
          expect(
            await Person.db.count(
              session,
              where: (t) => t.spaceId.equals(purgedSpace.id) & t.includeHiddenRows,
            ),
            greaterThan(0),
          );
          expect(
            await OfflineSyncSpaceNode.db.count(
              session,
              where: (t) => t.spaceId.equals(purgedSpace.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.spaceId.equals(purgedSpace.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataField.db.count(
              session,
              where: (t) => t.row.spaceId.equals(purgedSpace.id),
            ),
            greaterThan(0),
          );
          expect(
            await CrdtDataDeleted.db.count(
              session,
              where: (t) => t.row.spaceId.equals(purgedSpace.id),
            ),
            greaterThan(0),
          );
        },
      );

      group('when the space is purged by deleting its offline_sync_spaces row,', () {
        setUp(() async {
          await OfflineSyncSpace.db.deleteWhere(
            session,
            where: (t) => t.id.equals(purgedSpace.id),
          );
        });

        test(
          'then the space-owned domain rows are physically removed.',
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
                where: (t) => t.spaceId.equals(purgedSpace.id) & t.includeHiddenRows,
              ),
              0,
            );
          },
        );

        test('then the space and all its CRDT metadata are removed.', () async {
          expect(await OfflineSyncSpace.db.findById(session, purgedSpace.id!), isNull);
          expect(
            await OfflineSyncSpaceNode.db.count(
              session,
              where: (t) => t.spaceId.equals(purgedSpace.id),
            ),
            0,
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.spaceId.equals(purgedSpace.id),
            ),
            0,
          );
          expect(
            await CrdtDataField.db.count(
              session,
              where: (t) => t.row.spaceId.equals(purgedSpace.id),
            ),
            0,
          );
          expect(
            await CrdtDataDeleted.db.count(
              session,
              where: (t) => t.row.spaceId.equals(purgedSpace.id),
            ),
            0,
          );
        });

        test(
          'then the surviving space keeps its domain rows and metadata.',
          () async {
            expect(
              await Person.db.findById(session, survivingPerson.id!),
              isNotNull,
            );
            expect(
              await OfflineSyncSpace.db.findById(session, survivingSpace.id!),
              isNotNull,
            );
            expect(
              await OfflineSyncSpaceNode.db.count(
                session,
                where: (t) => t.spaceId.equals(survivingSpace.id),
              ),
              greaterThan(0),
            );
            expect(
              await CrdtDataRow.db.count(
                session,
                where: (t) => t.spaceId.equals(survivingSpace.id),
              ),
              greaterThan(0),
            );
          },
        );

        test('then orphan rows with a null space are preserved.', () async {
          final orphan = await Person.db.findById(testSession, orphanPerson.id!);
          expect(orphan, isNotNull);
          expect(orphan!.spaceId, isNull);
        });
      });
    },
  );

  group(
    'Given a space whose graph spans the CRDT metadata diamond — domain rows '
    'plus the crdt_data_rows / crdt_data_fields / crdt_data_tombstone metadata '
    'that reference crdt_nodes,',
    () {
      late UuidValue userId;
      late OfflineSyncSpace space;

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

        // An extra insert + delete records a tombstone in the space, exercising
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

        space = await OfflineSyncSpaceManager(session).getOrCreate(userId);
      });

      test(
        'when the space is purged by deleting its offline_sync_spaces row, '
        'then all domain rows and CRDT metadata are removed.',
        () async {
          await session.db.transaction((tx) async {
            await OfflineSyncSpace.db.deleteWhere(
              session,
              where: (t) => t.id.equals(space.id),
              transaction: tx,
            );
          });

          expect(await OfflineSyncSpace.db.findById(session, space.id!), isNull);
          expect(
            await Person.db.count(
              session,
              where: (t) => t.spaceId.equals(space.id) & t.includeHiddenRows,
            ),
            0,
          );
          expect(
            await CrdtDataRow.db.count(
              session,
              where: (t) => t.spaceId.equals(space.id),
            ),
            0,
          );
        },
      );
    },
  );
}
