import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a parent with a visible restrict child and a child update, ',
    () {
      late Person parent;
      late Address child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'restricted parent'),
            transaction: tx,
          );
          child = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'original street',
              inhabitantId: parent.id,
            ),
            transaction: tx,
          );
          child = await Address.db.updateRow(
            session,
            child.copyWith(street: 'updated street'),
            columns: (t) => [t.street],
            transaction: tx,
          );
        });
      });

      group('when a concurrent remote parent delete is merged, ', () {
        setUp(() async {
          remoteParentDelete = _deleteChange(
            tableName: Person.t.tableName,
            rowId: parent.id!,
            after: await _rowHlc(parent.id!),
          );

          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the parent remains visible and no visible restrict child references a hidden parent.',
          () async {
            final visibleParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await Address.db.findById(session, child.id!);

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.inhabitantId, parent.id);
            expect(visibleChild.street, 'updated street');
          },
        );

        test(
          'then the parent tombstone records the user delete.',
          () async {
            final tombstone = await CrdtDataDeleted.db.findFirstRow(
              session,
              where: (t) => t.row.uuidRowId.equals(parent.id),
              include: CrdtDataDeleted.include(node: CrdtNode.include()),
            );

            expect(tombstone, isNotNull);
            expect(tombstone!.isDeleted, isTrue);
            expect(tombstone.reason, CrdtDataDeletedReason.userDelete);
            expect(tombstone.hlc, remoteParentDelete.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a parent with a restrict child insert, ',
    () {
      late Person parent;
      late RestrictChild child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'multi restrict parent'),
            transaction: tx,
          );
          child = await RestrictChild.db.insertRow(
            session,
            RestrictChild(
              id: const Uuid().v7obj(),
              name: 'first restrict child',
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });
      });

      group('when a concurrent remote parent delete is merged, ', () {
        setUp(() async {
          remoteParentDelete = _deleteChange(
            tableName: Person.t.tableName,
            rowId: parent.id!,
            after: await _rowHlc(parent.id!),
          );

          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the visible restrict child keeps the parent visible.',
          () async {
            final visibleParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await RestrictChild.db.findById(
              session,
              child.id!,
            );

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.parentId, parent.id);
          },
        );

        test(
          'then the parent tombstone records the user delete.',
          () async {
            final tombstone = await CrdtDataDeleted.db.findFirstRow(
              session,
              where: (t) => t.row.uuidRowId.equals(parent.id),
              include: CrdtDataDeleted.include(node: CrdtNode.include()),
            );

            expect(tombstone, isNotNull);
            expect(tombstone!.isDeleted, isTrue);
            expect(tombstone.reason, CrdtDataDeletedReason.userDelete);
            expect(tombstone.hlc, remoteParentDelete.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a merged parent delete kept visible by a concurrent update to a restrict child, ',
    () {
      late Person parent;
      late Address child;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'blocked parent'),
            transaction: tx,
          );
          child = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'blocking child',
              inhabitantId: parent.id,
            ),
            transaction: tx,
          );
        });

        final remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: parent.id!,
          after: await _rowHlc(parent.id!),
        );

        await session.db.mergeChanges(
          [remoteParentDelete],
          userId: testCrdtUserId,
        );

        final visibleParent = await Person.db.findById(session, parent.id!);
        expect(visibleParent, isNotNull);
        expect(visibleParent!.name, 'blocked parent');
      });

      group('when the restrict child is detached, ', () {
        setUp(() async {
          final visibleChild = await Address.db.findById(session, child.id!);
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Address.db.updateRow(
              session,
              visibleChild!.copyWith(inhabitantId: null),
              columns: (t) => [t.inhabitantId],
              transaction: tx,
            );
          });
        });

        test(
          'then the parent is hidden by the preserved base delete fact.',
          () async {
            final hiddenParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await Address.db.findById(session, child.id!);

            expect(hiddenParent, isNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.inhabitantId, isNull);
          },
        );
      });
    },
  );

  group(
    'Given a parent with a visible no-action child, ',
    () {
      late Town town;
      late Company company;
      late Person child;
      late CrdtMergeDelete remoteCompanyDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          town = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'company town'),
            transaction: tx,
          );
          company = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'no action company',
              townId: town.id,
            ),
            transaction: tx,
          );
          child = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'no action child',
              oldCompanyId: company.id,
            ),
            transaction: tx,
          );
          child = await Person.db.updateRow(
            session,
            child.copyWith(surname: 'updated child'),
            columns: (t) => [t.surname],
            transaction: tx,
          );
        });
      });

      group('when a concurrent remote parent delete is merged, ', () {
        setUp(() async {
          remoteCompanyDelete = _deleteChange(
            tableName: Company.t.tableName,
            rowId: company.id!,
            after: await _rowHlc(company.id!),
          );

          await session.db.mergeChanges(
            [remoteCompanyDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the visible no-action child keeps the parent visible.',
          () async {
            final visibleCompany = await Company.db.findById(
              session,
              company.id!,
            );
            final visibleChild = await Person.db.findById(session, child.id!);

            expect(visibleCompany, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.oldCompanyId, company.id);
            expect(visibleChild.surname, 'updated child');
          },
        );
      });
    },
  );

  group(
    'Given a parent with a required (non-nullable) set-null child insert, ',
    () {
      late Person parent;
      late RequiredSetNullChild child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'required set-null parent'),
            transaction: tx,
          );
          child = await RequiredSetNullChild.db.insertRow(
            session,
            RequiredSetNullChild(
              id: const Uuid().v7obj(),
              name: 'required set-null child',
              parentId: parent.id!,
            ),
            transaction: tx,
          );
        });
      });

      group('when a concurrent remote parent delete is merged, ', () {
        setUp(() async {
          remoteParentDelete = _deleteChange(
            tableName: Person.t.tableName,
            rowId: parent.id!,
            after: await _rowHlc(parent.id!),
          );

          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the parent remains visible because set-null cannot repair the child.',
          () async {
            final visibleParent = await Person.db.findById(session, parent.id!);
            final visibleChild = await RequiredSetNullChild.db.findById(
              session,
              child.id!,
            );

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.parentId, parent.id);
          },
        );
      });
    },
  );

  group(
    'Given a parent with a nullable set-null foreign key whose attempted value was stored on update, ',
    () {
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;
      late Hlc childMayorFieldHlc;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'attempted mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
          child = await Town.db.updateRow(
            session,
            child.copyWith(mayorId: attemptedParent.id),
            columns: (t) => [t.mayorId],
            transaction: tx,
          );
        });

        final childMayorField = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(child.id) &
              t.column.name.equals(Town.t.mayorId.columnName),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );
        childMayorFieldHlc = childMayorField!.hlc;

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child remains visible with a materialized null foreign key.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
          },
        );

        test(
          'then the attempted foreign key value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );

        test(
          'then the child foreign key field metadata is not advanced by projection.',
          () async {
            final childMayorField = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(child.id) &
                  t.column.name.equals(Town.t.mayorId.columnName),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(childMayorField, isNotNull);
            expect(childMayorField!.hlc, childMayorFieldHlc);
          },
        );
      });
    },
  );

  group(
    'Given a unique nullable set-null foreign key, ',
    () {
      late Person parent;
      late UniqueSetNullChild child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'unique set-null parent'),
            transaction: tx,
          );
          child = await UniqueSetNullChild.db.insertRow(
            session,
            UniqueSetNullChild(
              id: const Uuid().v7obj(),
              name: 'unique set-null child',
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(parent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: parent.id!,
          after: parentHlc,
        );
      });

      group('when the remote parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the unique foreign key repair leaves the child visible with null.',
          () async {
            final visibleChild = await UniqueSetNullChild.db.findById(
              session,
              child.id!,
            );

            expect(visibleChild, isNotNull);
            expect(visibleChild!.parentId, isNull);
          },
        );

        test(
          'then the attempted unique foreign key value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: UniqueSetNullChild.t.parentId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, parent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-null projection is active after a merged parent delete, ',
    () {
      late Person attemptedParent;
      late Person newParent;
      late Town child;
      late Town projectedChild;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'deleted mayor'),
            transaction: tx,
          );
          newParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'new mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
          child = await Town.db.updateRow(
            session,
            child.copyWith(mayorId: attemptedParent.id),
            columns: (t) => [t.mayorId],
            transaction: tx,
          );
        });

        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: await _rowHlc(attemptedParent.id!),
        );

        await session.db.mergeChanges(
          [remoteParentDelete],
          userId: testCrdtUserId,
        );

        projectedChild = (await Town.db.findById(session, child.id!))!;
        expect(projectedChild.mayorId, isNull);
      });

      group('when the user changes the foreign key to a visible parent, ', () {
        late CrdtDataForeignKey projection;

        setUp(() async {
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Town.db.updateRow(
              session,
              projectedChild.copyWith(mayorId: newParent.id),
              columns: (t) => [t.mayorId],
              transaction: tx,
            );
          });

          projection = (await _findForeignKeyProjection(
            rowId: child.id!,
            columnName: Town.t.mayorId.columnName,
          ))!;
        });

        test('then the child foreign key uses the new visible parent.', () async {
          final visibleChild = await Town.db.findById(session, child.id!);

          expect(visibleChild, isNotNull);
          expect(visibleChild!.mayorId, newParent.id);
        });

        test(
          'then foreign key tracking records the new visible user value without an active override.',
          () async {
            expect(projection.attemptedValue, newParent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );
      });

      group('when a later merge restores the attempted parent, ', () {
        setUp(() async {
          final remoteParentRestore = _restoreChange(
            tableName: Person.t.tableName,
            rowId: attemptedParent.id!,
            after: remoteParentDelete.hlc,
          );

          await session.db.mergeChanges(
            [remoteParentRestore],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child foreign key is restored and projection metadata records the visible attempted value.',
          () async {
            final visibleParent = await Person.db.findById(
              session,
              attemptedParent.id!,
            );
            final visibleChild = await Town.db.findById(session, child.id!);
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, attemptedParent.id);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );
      });

      group('when the row is updated without narrowing columns, ', () {
        setUp(() async {
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Town.db.updateRow(
              session,
              projectedChild.copyWith(name: 'renamed projected town'),
              transaction: tx,
            );
          });
        });

        test(
          'then the non-foreign-key update does not promote the materialized repair to an attempted value.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(visibleChild, isNotNull);
            expect(visibleChild!.name, 'renamed projected town');
            expect(visibleChild.mayorId, isNull);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a nullable foreign key with set-null whose attempted value only exists on insert, ',
    () {
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'insert attempted mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'insert set null town',
              mayorId: attemptedParent.id,
            ),
            transaction: tx,
          );
        });

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteParentDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the inserted child remains visible with a materialized null foreign key.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
          },
        );

        test(
          'then the inserted attempted value is preserved in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedParent.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a remote insert with a set-null foreign key that points to a missing parent, ',
    () {
      late UuidValue missingParentId;
      late Town child;

      setUp(() {
        missingParentId = const Uuid().v7obj();
        child = Town(
          id: const Uuid().v7obj(),
          name: 'missing set-null parent child',
          mayorId: missingParentId,
        );
      });

      group('when the remote insert is merged, ', () {
        setUp(() async {
          final remoteNodeId = const Uuid().v7obj();
          final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
          await session.db.mergeChanges(
            [
              CrdtMergeInsert(
                tableName: Town.t.tableName,
                uuidRowId: child.id!,
                uuidNodeId: remoteNodeId,
                hlcDatetime: hlc.datetime,
                hlcCounter: hlc.counter,
                data: child,
              ),
            ],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child is visible with a materialized null foreign key.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
          },
        );

        test(
          'then the missing attempted parent value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, missingParentId);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a visible child and a remote update with a set-null foreign key that points to a missing parent, ',
    () {
      late UuidValue missingParentId;
      late Town child;
      late CrdtMergeUpdate remoteMissingParentUpdate;

      setUp(() async {
        missingParentId = const Uuid().v7obj();
        child = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'missing update parent child'),
            transaction: tx,
          ),
        );

        final childHlc = await _rowHlc(child.id!);
        remoteMissingParentUpdate = CrdtMergeUpdate(
          tableName: Town.t.tableName,
          uuidRowId: child.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: childHlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Town.t.mayorId.columnName,
          value: missingParentId,
        );
      });

      group('when the remote update is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteMissingParentUpdate],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child remains visible with a materialized null foreign key.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, isNull);
          },
        );

        test(
          'then the missing attempted parent value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, missingParentId);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key with a visible default target and a stored attempted parent value, ',
    () {
      late Town defaultTown;
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        defaultTown = Town(
          id: _defaultTownId,
          name: 'default town',
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          defaultTown = await Town.db.insertRow(
            session,
            defaultTown,
            transaction: tx,
          );
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'set default company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child remains visible with the default foreign key materialized.',
          () async {
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, defaultTown.id);
          },
        );

        test(
          'then the attempted set-default foreign key value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Company.t.townId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedTown.id);
            expect(projection.visibleValue, defaultTown.id);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a remote insert with a set-default foreign key that points to a missing parent and a visible default target, ',
    () {
      late Town defaultTown;
      late UuidValue missingTownId;
      late Company child;

      setUp(() async {
        defaultTown = Town(id: _defaultTownId, name: 'visible default town');
        missingTownId = const Uuid().v7obj();
        child = Company(
          id: const Uuid().v7obj(),
          name: 'missing set-default parent child',
          townId: missingTownId,
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(session, defaultTown, transaction: tx),
        );
      });

      group('when the remote insert is merged, ', () {
        setUp(() async {
          final remoteNodeId = const Uuid().v7obj();
          final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
          await session.db.mergeChanges(
            [
              CrdtMergeInsert(
                tableName: Company.t.tableName,
                uuidRowId: child.id!,
                uuidNodeId: remoteNodeId,
                hlcDatetime: hlc.datetime,
                hlcCounter: hlc.counter,
                data: child,
              ),
            ],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child is visible with the default foreign key materialized.',
          () async {
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, defaultTown.id);
          },
        );

        test(
          'then the missing attempted parent value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Company.t.townId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, missingTownId);
            expect(projection.visibleValue, defaultTown.id);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key whose default target is missing, ',
    () {
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'set default company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc,
        );
      });

      group('when the attempted parent delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the attempted parent remains visible because the default cannot repair the child.',
          () async {
            final visibleParent = await Town.db.findById(
              session,
              attemptedTown.id!,
            );
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(visibleParent, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, attemptedTown.id);
          },
        );

        test(
          'then no set-default projection override is materialized for the unrepairable delete.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Company.t.townId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, attemptedTown.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );
      });
    },
  );

  group(
    'Given a remote insert with a restrict foreign key that points to a missing parent, ',
    () {
      late UuidValue missingParentId;
      late Address child;

      setUp(() {
        missingParentId = const Uuid().v7obj();
        child = Address(
          id: const Uuid().v7obj(),
          street: 'missing restrict parent child',
          inhabitantId: missingParentId,
        );
      });

      group('when the remote insert is merged, ', () {
        setUp(() async {
          final remoteNodeId = const Uuid().v7obj();
          final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
          await session.db.mergeChanges(
            [
              CrdtMergeInsert(
                tableName: Address.t.tableName,
                uuidRowId: child.id!,
                uuidNodeId: remoteNodeId,
                hlcDatetime: hlc.datetime,
                hlcCounter: hlc.counter,
                data: child,
              ),
            ],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the child is hidden so no visible orphan remains.',
          () async {
            final visibleChild = await Address.db.findById(session, child.id!);
            final hiddenChild = await Address.db.findById(testSession, child.id!);
            final crdtRow = await CrdtDataRow.db.findFirstRow(
              session,
              where: (t) => t.uuidRowId.equals(child.id),
            );

            expect(visibleChild, isNull);
            expect(hiddenChild, isNotNull);
            expect(hiddenChild!.inhabitantId, isNull);
            expect(crdtRow, isNotNull);
            expect(crdtRow!.visibility, CrdtDataRowVisibility.foreignKeyCascade);
          },
        );

        test(
          'then the missing attempted parent value remains recorded in projection metadata.',
          () async {
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Address.t.inhabitantId.columnName,
            );

            expect(projection, isNotNull);
            expect(projection!.attemptedValue, missingParentId);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key whose default target is cascade-attached to another parent and a concurrent delete that hides the default target first, ',
    () {
      late City city;
      late Town defaultTown;
      late Town attemptedTown;
      late Company child;
      late CrdtMergeDelete remoteCityDelete;
      late CrdtMergeDelete remoteAttemptedTownDelete;

      setUp(() async {
        defaultTown = Town(
          id: _defaultTownId,
          name: 'cascade-hidden default town',
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'default target city'),
            transaction: tx,
          );
          defaultTown = await Town.db.insertRow(
            session,
            defaultTown.copyWith(cityId: city.id),
            transaction: tx,
          );
          attemptedTown = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'attempted town'),
            transaction: tx,
          );
          child = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'fixed point company',
              townId: attemptedTown.id,
            ),
            transaction: tx,
          );
          child = await Company.db.updateRow(
            session,
            child.copyWith(townId: attemptedTown.id),
            columns: (t) => [t.townId],
            transaction: tx,
          );
        });

        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: await _rowHlc(city.id!),
        );

        final attemptedTownHlc = await _rowHlc(attemptedTown.id!);
        remoteAttemptedTownDelete = _deleteChange(
          tableName: Town.t.tableName,
          rowId: attemptedTown.id!,
          after: attemptedTownHlc.maxBetween(remoteCityDelete.hlc),
        );
      });

      group('when both root deletes are merged in the same batch, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete, remoteAttemptedTownDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the attempted parent remains visible because the full hidden fixed point hides the default target.',
          () async {
            final hiddenCity = await City.db.findById(session, city.id!);
            final hiddenDefaultTown = await Town.db.findById(
              session,
              defaultTown.id!,
            );
            final visibleAttemptedTown = await Town.db.findById(
              session,
              attemptedTown.id!,
            );
            final visibleChild = await Company.db.findById(session, child.id!);

            expect(hiddenCity, isNull);
            expect(hiddenDefaultTown, isNull);
            expect(visibleAttemptedTown, isNotNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.townId, attemptedTown.id);
          },
        );
      });
    },
  );

  group(
    'Given a valid cascade closure with three levels and a concurrent delete that hides the root before the children inserts, ',
    () {
      // City
      //   │ CASCADE
      //   ▼
      // Organization
      //   │ CASCADE
      //   ▼
      // Person
      late City city;
      late Organization organization;
      late Person person;
      late CrdtMergeDelete remoteCityDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'cascade city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'cascade organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'cascade person',
              organizationId: organization.id,
            ),
            transaction: tx,
          );
        });

        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: await _rowHlc(city.id!),
        );
      });

      group('when the root delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then all cascade descendants are hidden and no visible descendant references a hidden ancestor.',
          () async {
            expect(await City.db.findById(session, city.id!), isNull);
            expect(await Organization.db.findById(session, organization.id!), isNull);
            expect(await Person.db.findById(session, person.id!), isNull);
          },
        );
      });

      group('when the root delete replayed after merged, ', () {
        late List<String> visibilityAfterMerge;
        late List<String> visibilityAfterReplay;
        late List<String> foreignKeyProjectionAfterMerge;
        late List<String> foreignKeyProjectionAfterReplay;

        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );
          visibilityAfterMerge = await _visibilitySnapshot();
          foreignKeyProjectionAfterMerge = await _foreignKeyProjectionSnapshot();

          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );
          visibilityAfterReplay = await _visibilitySnapshot();
          foreignKeyProjectionAfterReplay = await _foreignKeyProjectionSnapshot();
        });

        test(
          'then the projected visibility metadata does not change.',
          () async {
            expect(visibilityAfterMerge, hasLength(3));
            expect(visibilityAfterReplay, visibilityAfterMerge);
          },
        );

        test(
          'then the foreign key projection metadata does not change.',
          () async {
            expect(foreignKeyProjectionAfterReplay, foreignKeyProjectionAfterMerge);
          },
        );
      });

      group('when a root restore is merged after the root delete, ', () {
        late CrdtMergeDelete remoteCityRestore;

        setUp(() async {
          await session.db.mergeChanges(
            [remoteCityDelete],
            userId: testCrdtUserId,
          );

          remoteCityRestore = _restoreChange(
            tableName: City.t.tableName,
            rowId: city.id!,
            after: remoteCityDelete.hlc,
          );
          await session.db.mergeChanges(
            [remoteCityRestore],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the cascade-derived descendant visibility is restored.',
          () async {
            final visibleCity = await City.db.findById(session, city.id!);
            final visibleOrganization = await Organization.db.findById(
              session,
              organization.id!,
            );
            final visiblePerson = await Person.db.findById(session, person.id!);

            expect(visibleCity, isNotNull);
            expect(visibleOrganization, isNotNull);
            expect(visibleOrganization!.cityId, city.id);
            expect(visiblePerson, isNotNull);
            expect(visiblePerson!.organizationId, organization.id);
          },
        );
      });
    },
  );

  group(
    'Given a cascade to restrict chain whose restrict row has set-null and cascade grandchildren and a concurrent delete that hides the root before the children inserts, ',
    () {
      // Root
      //   │ CASCADE
      //   ▼
      // CascadeMiddle
      //   │ RESTRICT
      //   ▼
      // RestrictBlocker
      //   ├─ SET NULL  → MiddleSetNullChild
      //   └─ CASCADE   → MiddleCascadeChild
      late FkChainRoot root;
      late FkChainCascadeMiddle cascadeMiddle;
      late FkChainRestrictBlocker restrictBlocker;
      late FkChainMiddleSetNullChild setNullGrandchild;
      late FkChainMiddleCascadeChild cascadeGrandchild;
      late CrdtMergeDelete remoteRootDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          root = await FkChainRoot.db.insertRow(
            session,
            FkChainRoot(id: const Uuid().v7obj(), name: 'cascade restrict root'),
            transaction: tx,
          );
          cascadeMiddle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'cascade middle',
              rootId: root.id,
            ),
            transaction: tx,
          );
          restrictBlocker = await FkChainRestrictBlocker.db.insertRow(
            session,
            FkChainRestrictBlocker(
              id: const Uuid().v7obj(),
              name: 'restrict blocker',
              cascadeMiddleId: cascadeMiddle.id,
            ),
            transaction: tx,
          );
          setNullGrandchild = await FkChainMiddleSetNullChild.db.insertRow(
            session,
            FkChainMiddleSetNullChild(
              id: const Uuid().v7obj(),
              name: 'set-null grandchild',
              restrictBlockerId: restrictBlocker.id,
            ),
            transaction: tx,
          );
          cascadeGrandchild = await FkChainMiddleCascadeChild.db.insertRow(
            session,
            FkChainMiddleCascadeChild(
              id: const Uuid().v7obj(),
              name: 'cascade grandchild',
              restrictBlockerId: restrictBlocker.id,
            ),
            transaction: tx,
          );
        });

        remoteRootDelete = _deleteChange(
          tableName: FkChainRoot.t.tableName,
          rowId: root.id!,
          after: await _rowHlc(root.id!),
        );
      });

      group('when the root delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteRootDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the restrict row and its cascade parent remain visible while the restrict block is in place.',
          () async {
            expect(await FkChainRoot.db.findById(session, root.id!), isNotNull);
            final visibleCascadeMiddle = await FkChainCascadeMiddle.db.findById(
              session,
              cascadeMiddle.id!,
            );
            final visibleRestrictBlocker = await FkChainRestrictBlocker.db.findById(
              session,
              restrictBlocker.id!,
            );

            expect(visibleCascadeMiddle, isNotNull);
            expect(visibleCascadeMiddle!.rootId, root.id);
            expect(visibleRestrictBlocker, isNotNull);
            expect(visibleRestrictBlocker!.cascadeMiddleId, cascadeMiddle.id);
          },
        );

        test(
          'then the set-null grandchild keeps the attempted restrict foreign key without an active override.',
          () async {
            final visibleSetNullGrandchild = await FkChainMiddleSetNullChild.db
                .findById(session, setNullGrandchild.id!);
            final projection = await _findForeignKeyProjection(
              rowId: setNullGrandchild.id!,
              columnName: FkChainMiddleSetNullChild.t.restrictBlockerId.columnName,
            );

            expect(visibleSetNullGrandchild, isNotNull);
            expect(visibleSetNullGrandchild!.restrictBlockerId, restrictBlocker.id);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, restrictBlocker.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );

        test(
          'then the cascade grandchild remains visible with the attempted restrict foreign key.',
          () async {
            final visibleCascadeGrandchild = await FkChainMiddleCascadeChild.db
                .findById(session, cascadeGrandchild.id!);

            expect(visibleCascadeGrandchild, isNotNull);
            expect(visibleCascadeGrandchild!.restrictBlockerId, restrictBlocker.id);
          },
        );
      });

      group(
        'when a restrict blocker delete is merged after the root delete, ',
        () {
          late CrdtMergeDelete remoteRestrictBlockerDelete;

          setUp(() async {
            await session.db.mergeChanges(
              [remoteRootDelete],
              userId: testCrdtUserId,
            );

            final restrictBlockerHlc = await _rowHlc(restrictBlocker.id!);
            remoteRestrictBlockerDelete = _deleteChange(
              tableName: FkChainRestrictBlocker.t.tableName,
              rowId: restrictBlocker.id!,
              after: restrictBlockerHlc.maxBetween(remoteRootDelete.hlc),
            );
            await session.db.mergeChanges(
              [remoteRestrictBlockerDelete],
              userId: testCrdtUserId,
            );
          });

          test(
            'then the root, cascade middle, restrict grandchild, and cascade grandchild are hidden.',
            () async {
              expect(await FkChainRoot.db.findById(session, root.id!), isNull);
              expect(
                await FkChainCascadeMiddle.db.findById(session, cascadeMiddle.id!),
                isNull,
              );
              expect(
                await FkChainRestrictBlocker.db.findById(session, restrictBlocker.id!),
                isNull,
              );
              expect(
                await FkChainMiddleCascadeChild.db.findById(
                  session,
                  cascadeGrandchild.id!,
                ),
                isNull,
              );
            },
          );

          test(
            'then the set-null grandchild remains visible with a materialized null foreign key.',
            () async {
              final visibleSetNullGrandchild = await FkChainMiddleSetNullChild.db
                  .findById(session, setNullGrandchild.id!);
              final projection = await _findForeignKeyProjection(
                rowId: setNullGrandchild.id!,
                columnName: FkChainMiddleSetNullChild.t.restrictBlockerId.columnName,
              );

              expect(visibleSetNullGrandchild, isNotNull);
              expect(visibleSetNullGrandchild!.restrictBlockerId, isNull);
              expect(projection, isNotNull);
              expect(projection!.attemptedValue, restrictBlocker.id);
              expect(projection.visibleValue, isNull);
              expect(projection.hasOverride, isTrue);
            },
          );
        },
      );
    },
  );

  group(
    'Given a cascade to set-null chain whose middle row has restrict, set-null, and cascade grandchildren and a concurrent delete that hides the root before the children inserts, ',
    () {
      // Root
      //   │ CASCADE
      //   ▼
      // CascadeMiddle
      //   │ SET NULL
      //   ▼
      // SetNullMiddle
      //   ├─ RESTRICT  → SetNullRestrictChild
      //   ├─ SET NULL  → SetNullSetNullChild
      //   └─ CASCADE   → SetNullCascadeChild
      late FkChainRoot root;
      late FkChainCascadeMiddle cascadeMiddle;
      late FkChainSetNullMiddle setNullMiddle;
      late FkChainSetNullRestrictChild restrictGrandchild;
      late FkChainSetNullSetNullChild setNullGrandchild;
      late FkChainSetNullCascadeChild cascadeGrandchild;
      late CrdtMergeDelete remoteRootDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          root = await FkChainRoot.db.insertRow(
            session,
            FkChainRoot(id: const Uuid().v7obj(), name: 'cascade set-null root'),
            transaction: tx,
          );
          cascadeMiddle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'cascade middle',
              rootId: root.id,
            ),
            transaction: tx,
          );
          setNullMiddle = await FkChainSetNullMiddle.db.insertRow(
            session,
            FkChainSetNullMiddle(
              id: const Uuid().v7obj(),
              name: 'set-null middle',
              cascadeMiddleId: cascadeMiddle.id,
            ),
            transaction: tx,
          );
          restrictGrandchild = await FkChainSetNullRestrictChild.db.insertRow(
            session,
            FkChainSetNullRestrictChild(
              id: const Uuid().v7obj(),
              name: 'restrict grandchild',
              setNullMiddleId: setNullMiddle.id,
            ),
            transaction: tx,
          );
          setNullGrandchild = await FkChainSetNullSetNullChild.db.insertRow(
            session,
            FkChainSetNullSetNullChild(
              id: const Uuid().v7obj(),
              name: 'set-null grandchild',
              setNullMiddleId: setNullMiddle.id,
            ),
            transaction: tx,
          );
          cascadeGrandchild = await FkChainSetNullCascadeChild.db.insertRow(
            session,
            FkChainSetNullCascadeChild(
              id: const Uuid().v7obj(),
              name: 'cascade grandchild',
              setNullMiddleId: setNullMiddle.id,
            ),
            transaction: tx,
          );
        });

        remoteRootDelete = _deleteChange(
          tableName: FkChainRoot.t.tableName,
          rowId: root.id!,
          after: await _rowHlc(root.id!),
        );
      });

      group('when the root delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteRootDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the root and cascade middle are hidden while the set-null middle remains visible because of the restrict grandchild.',
          () async {
            expect(await FkChainRoot.db.findById(session, root.id!), isNull);
            expect(
              await FkChainCascadeMiddle.db.findById(session, cascadeMiddle.id!),
              isNull,
            );
            final visibleSetNullMiddle = await FkChainSetNullMiddle.db.findById(
              session,
              setNullMiddle.id!,
            );
            final middleProjection = await _findForeignKeyProjection(
              rowId: setNullMiddle.id!,
              columnName: FkChainSetNullMiddle.t.cascadeMiddleId.columnName,
            );

            expect(visibleSetNullMiddle, isNotNull);
            expect(visibleSetNullMiddle!.cascadeMiddleId, isNull);
            expect(middleProjection, isNotNull);
            expect(middleProjection!.attemptedValue, cascadeMiddle.id);
            expect(middleProjection.visibleValue, isNull);
            expect(middleProjection.hasOverride, isTrue);
          },
        );

        test(
          'then the restrict grandchild keeps the attempted set-null middle foreign key.',
          () async {
            final visibleRestrictGrandchild = await FkChainSetNullRestrictChild.db
                .findById(session, restrictGrandchild.id!);

            expect(visibleRestrictGrandchild, isNotNull);
            expect(visibleRestrictGrandchild!.setNullMiddleId, setNullMiddle.id);
          },
        );

        test(
          'then the set-null grandchild keeps the attempted middle foreign key without an active override.',
          () async {
            final visibleSetNullGrandchild = await FkChainSetNullSetNullChild.db
                .findById(session, setNullGrandchild.id!);
            final projection = await _findForeignKeyProjection(
              rowId: setNullGrandchild.id!,
              columnName: FkChainSetNullSetNullChild.t.setNullMiddleId.columnName,
            );

            expect(visibleSetNullGrandchild, isNotNull);
            expect(visibleSetNullGrandchild!.setNullMiddleId, setNullMiddle.id);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, setNullMiddle.id);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );

        test(
          'then the cascade grandchild remains visible with the attempted set-null middle foreign key.',
          () async {
            final visibleCascadeGrandchild = await FkChainSetNullCascadeChild.db
                .findById(session, cascadeGrandchild.id!);

            expect(visibleCascadeGrandchild, isNotNull);
            expect(visibleCascadeGrandchild!.setNullMiddleId, setNullMiddle.id);
          },
        );
      });

      group(
        'when a restrict grandchild delete is merged after the root delete, ',
        () {
          late CrdtMergeDelete remoteRestrictGrandchildDelete;

          setUp(() async {
            await session.db.mergeChanges(
              [remoteRootDelete],
              userId: testCrdtUserId,
            );

            final restrictGrandchildHlc = await _rowHlc(restrictGrandchild.id!);
            remoteRestrictGrandchildDelete = _deleteChange(
              tableName: FkChainSetNullRestrictChild.t.tableName,
              rowId: restrictGrandchild.id!,
              after: restrictGrandchildHlc.maxBetween(remoteRootDelete.hlc),
            );
            await session.db.mergeChanges(
              [remoteRestrictGrandchildDelete],
              userId: testCrdtUserId,
            );
          });

          test(
            'then the root, cascade middle, and restrict grandchild are hidden.',
            () async {
              expect(await FkChainRoot.db.findById(session, root.id!), isNull);
              expect(
                await FkChainCascadeMiddle.db.findById(session, cascadeMiddle.id!),
                isNull,
              );
              expect(
                await FkChainSetNullRestrictChild.db.findById(
                  session,
                  restrictGrandchild.id!,
                ),
                isNull,
              );
            },
          );

          test(
            'then the set-null middle and its remaining grandchildren stay visible with their foreign keys.',
            () async {
              final visibleSetNullMiddle = await FkChainSetNullMiddle.db.findById(
                session,
                setNullMiddle.id!,
              );
              final visibleSetNullGrandchild = await FkChainSetNullSetNullChild.db
                  .findById(session, setNullGrandchild.id!);
              final visibleCascadeGrandchild = await FkChainSetNullCascadeChild.db
                  .findById(session, cascadeGrandchild.id!);

              expect(visibleSetNullMiddle, isNotNull);
              expect(visibleSetNullMiddle!.cascadeMiddleId, isNull);
              expect(visibleSetNullGrandchild, isNotNull);
              expect(visibleSetNullGrandchild!.setNullMiddleId, setNullMiddle.id);
              expect(visibleCascadeGrandchild, isNotNull);
              expect(visibleCascadeGrandchild!.setNullMiddleId, setNullMiddle.id);
            },
          );
        },
      );
    },
  );

  group(
    'Given a foreign-key cycle person -> company -> town -> person and a concurrent delete that hides the person first and then the company before the town inserts,',
    () {
      // Person
      //   │ CASCADE
      //   ▼
      // Company
      //   │ CASCADE
      //   ▼
      // Town
      //   │ CASCADE
      //   ▼
      // Person (cycle root)
      late Town defaultTown;
      late Town town;
      late Company company;
      late Person person;
      late CrdtMergeDelete remotePersonDelete;
      late CrdtMergeDelete remoteCompanyDelete;

      setUp(() async {
        defaultTown = Town(id: _defaultTownId, name: 'cycle default town');

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          defaultTown = await Town.db.insertRow(
            session,
            defaultTown,
            transaction: tx,
          );
          town = await Town.db.insertRow(
            session,
            Town(id: const Uuid().v7obj(), name: 'cycle town'),
            transaction: tx,
          );
          company = await Company.db.insertRow(
            session,
            Company(
              id: const Uuid().v7obj(),
              name: 'cycle company',
              townId: town.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'cycle person',
              oldCompanyId: company.id,
            ),
            transaction: tx,
          );
          town = await Town.db.updateRow(
            session,
            town.copyWith(mayorId: person.id),
            columns: (t) => [t.mayorId],
            transaction: tx,
          );
        });

        remotePersonDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: person.id!,
          after: await _rowHlc(person.id!),
        );
        final companyHlc = await _rowHlc(company.id!);
        remoteCompanyDelete = _deleteChange(
          tableName: Company.t.tableName,
          rowId: company.id!,
          after: companyHlc.maxBetween(remotePersonDelete.hlc),
        );
      });

      group(
        'when the person and company concurrent deletes are merged in the same batch, ',
        () {
          setUp(() async {
            await session.db.mergeChanges(
              [remotePersonDelete, remoteCompanyDelete],
              userId: testCrdtUserId,
            );
          });

          test(
            'then fixed-point projection terminates and converges to visible rows without foreign-key violations.',
            () async {
              final hiddenPerson = await Person.db.findById(session, person.id!);
              final hiddenCompany = await Company.db.findById(session, company.id!);
              final visibleTown = await Town.db.findById(session, town.id!);

              final projection = await _findForeignKeyProjection(
                rowId: town.id!,
                columnName: Town.t.mayorId.columnName,
              );

              expect(hiddenPerson, isNull);
              expect(hiddenCompany, isNull);
              expect(visibleTown, isNotNull);
              expect(visibleTown!.mayorId, isNull);
              expect(projection, isNotNull);
              expect(projection!.attemptedValue, person.id);
              expect(projection.visibleValue, isNull);
              expect(projection.hasOverride, isTrue);
            },
          );
        },
      );
    },
  );

  group(
    'Given two databases with the same set-null graph and the same remote operations, ',
    () {
      late CrdtDatabaseSession singleBatchSession;
      late CrdtDatabaseSession splitBatchSession;
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentDelete;
      late CrdtMergeUpdate remoteChildUpdate;

      setUp(() async {
        singleBatchSession = session;
        splitBatchSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: [
            Person.t,
            Town.t,
          ],
        );
        await splitBatchSession.db.initialize();

        attemptedParent = Person(
          id: const Uuid().v7obj(),
          name: 'batching parent',
        );
        child = Town(
          id: const Uuid().v7obj(),
          name: 'batching town',
          mayorId: attemptedParent.id,
        );

        for (final databaseSession in [singleBatchSession, splitBatchSession]) {
          await databaseSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(
              databaseSession,
              attemptedParent,
              transaction: tx,
            );
            await Town.db.insertRow(
              databaseSession,
              child,
              transaction: tx,
            );
            await Town.db.updateRow(
              databaseSession,
              child,
              columns: (t) => [t.mayorId],
              transaction: tx,
            );
          });
        }

        final singleBatchParentHlc = await _rowHlc(
          attemptedParent.id!,
          databaseSession: singleBatchSession,
        );
        final splitBatchParentHlc = await _rowHlc(
          attemptedParent.id!,
          databaseSession: splitBatchSession,
        );
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: singleBatchParentHlc.maxBetween(splitBatchParentHlc),
        );
        final singleBatchChildHlc = await _rowHlc(
          child.id!,
          databaseSession: singleBatchSession,
        );
        final splitBatchChildHlc = await _rowHlc(
          child.id!,
          databaseSession: splitBatchSession,
        );
        final childUpdateBaseHlc = remoteParentDelete.hlc
            .maxBetween(singleBatchChildHlc)
            .maxBetween(splitBatchChildHlc);
        remoteChildUpdate = CrdtMergeUpdate(
          tableName: Town.t.tableName,
          uuidRowId: child.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: childUpdateBaseHlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Town.t.name.columnName,
          value: 'updated batching town',
        );
      });

      group(
        'when one database merges one batch and the other merges split batches, ',
        () {
          setUp(() async {
            await singleBatchSession.db.mergeChanges(
              [remoteParentDelete, remoteChildUpdate],
              userId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [remoteParentDelete],
              userId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [remoteChildUpdate],
              userId: testCrdtUserId,
            );
          });

          test(
            'then both databases converge to the same repaired visible rows and foreign key projection.',
            () async {
              final singleBatchChild = await Town.db.findById(
                singleBatchSession,
                child.id!,
              );
              final splitBatchChild = await Town.db.findById(
                splitBatchSession,
                child.id!,
              );

              final singleBatch = await _findForeignKeyProjection(
                rowId: child.id!,
                columnName: Town.t.mayorId.columnName,
                databaseSession: singleBatchSession,
              );
              final splitBatch = await _findForeignKeyProjection(
                rowId: child.id!,
                columnName: Town.t.mayorId.columnName,
                databaseSession: splitBatchSession,
              );

              expect(singleBatchChild?.name, splitBatchChild?.name);
              expect(singleBatchChild?.mayorId?.uuid, splitBatchChild?.mayorId?.uuid);
              expect(singleBatch?.attemptedValue, splitBatch?.attemptedValue);
              expect(singleBatch?.visibleValue, splitBatch?.visibleValue);
              expect(singleBatch?.hasOverride, splitBatch?.hasOverride);
              expect(singleBatchChild?.name, 'updated batching town');
              expect(singleBatchChild?.mayorId, isNull);
              expect(singleBatch?.attemptedValue, attemptedParent.id);
              expect(singleBatch?.hasOverride, isTrue);
            },
          );
        },
      );
    },
  );
}

final _defaultTownId = UuidValue.withValidation(
  '550e8400-e29b-41d4-a716-446655440000',
);

CrdtMergeDelete _deleteChange({
  required String tableName,
  required UuidValue rowId,
  required Hlc after,
}) {
  return CrdtMergeDelete(
    tableName: tableName,
    uuidRowId: rowId,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: after.datetime.advance(),
    hlcCounter: 0,
    clFlag: 2,
    reason: CrdtDataDeletedReason.userDelete,
  );
}

CrdtMergeDelete _restoreChange({
  required String tableName,
  required UuidValue rowId,
  required Hlc after,
}) {
  return CrdtMergeDelete(
    tableName: tableName,
    uuidRowId: rowId,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: after.datetime.advance(),
    hlcCounter: 0,
    clFlag: 3,
    reason: CrdtDataDeletedReason.userReinsert,
  );
}

Future<Hlc> _rowHlc(
  UuidValue rowId, {
  CrdtDatabaseSession? databaseSession,
}) async {
  final crdtRow = await CrdtDataRow.db.findFirstRow(
    databaseSession ?? session,
    where: (t) => t.uuidRowId.equals(rowId),
    include: CrdtDataRow.include(node: CrdtNode.include()),
  );

  return crdtRow!.hlc;
}

Future<CrdtDataForeignKey?> _findForeignKeyProjection({
  required UuidValue rowId,
  required String columnName,
  CrdtDatabaseSession? databaseSession,
}) {
  return CrdtDataForeignKey.db.findFirstRow(
    databaseSession ?? session,
    where: (t) =>
        t.field.row.uuidRowId.equals(rowId) & t.field.column.name.equals(columnName),
  );
}

Future<List<String>> _visibilitySnapshot() async {
  final rows = await CrdtDataRow.db.find(
    session,
    where: (t) => t.visibility.inSet({
      CrdtDataRowVisibility.userDelete,
      CrdtDataRowVisibility.foreignKeyCascade,
    }),
    orderBy: (t) => t.uuidRowId,
  );

  return [
    for (final row in rows)
      [
        row.uuidRowId.uuid,
        row.visibility.toJson(),
      ].join('|'),
  ];
}

Future<List<String>> _foreignKeyProjectionSnapshot() async {
  final projections = await CrdtDataForeignKey.db.find(
    session,
    include: CrdtDataForeignKey.include(
      field: CrdtDataField.include(
        row: CrdtDataRow.include(),
        column: CrdtSchemaColumn.include(),
      ),
    ),
  );

  return [
    for (final projection in projections)
      [
        projection.field!.row!.uuidRowId.uuid,
        projection.field!.column!.name,
        projection.attemptedValue?.uuid,
        projection.visibleValue?.uuid,
        projection.hasOverride,
        projection.overrideReason?.toJson(),
      ].join('|'),
  ]..sort();
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
}
