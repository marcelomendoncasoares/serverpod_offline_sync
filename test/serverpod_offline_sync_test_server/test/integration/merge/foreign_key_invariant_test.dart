import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a parent row with a visible restrict child and a concurrent child update, ',
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
      });
    },
  );

  group(
    'Given a blocked restrict parent delete was restored by projection, ',
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

        final parentHlc = await _rowHlc(parent.id!);
        await session.db.mergeChanges(
          [
            _deleteChange(
              tableName: Person.t.tableName,
              rowId: parent.id!,
              after: parentHlc,
            ),
          ],
          userId: testCrdtUserId,
        );
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
    'Given a parent with multiple visible restrict children, ',
    () {
      late Person parent;
      late RestrictChild firstChild;
      late RestrictChild secondChild;
      late CrdtMergeDelete remoteParentDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'multi restrict parent'),
            transaction: tx,
          );
          firstChild = await RestrictChild.db.insertRow(
            session,
            RestrictChild(
              id: const Uuid().v7obj(),
              name: 'first restrict child',
              parentId: parent.id,
            ),
            transaction: tx,
          );
          secondChild = await RestrictChild.db.insertRow(
            session,
            RestrictChild(
              id: const Uuid().v7obj(),
              name: 'second restrict child',
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
          'then any visible restrict child is enough to keep the parent visible.',
          () async {
            final visibleParent = await Person.db.findById(session, parent.id!);
            final visibleFirstChild = await RestrictChild.db.findById(
              session,
              firstChild.id!,
            );
            final visibleSecondChild = await RestrictChild.db.findById(
              session,
              secondChild.id!,
            );

            expect(visibleParent, isNotNull);
            expect(visibleFirstChild, isNotNull);
            expect(visibleFirstChild!.parentId, parent.id);
            expect(visibleSecondChild, isNotNull);
            expect(visibleSecondChild!.parentId, parent.id);
          },
        );
      });
    },
  );

  group(
    'Given a company with a visible no-action child and a concurrent child update, ',
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

        final companyHlc = await _rowHlc(company.id!);
        remoteCompanyDelete = _deleteChange(
          tableName: Company.t.tableName,
          rowId: company.id!,
          after: companyHlc,
        );
      });

      group('when the remote company delete is merged, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteCompanyDelete],
            userId: testCrdtUserId,
          );
        });

        test(
          'then the company remains visible and no visible no-action child references a hidden company.',
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
    'Given a non-nullable set-null child, ',
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
    'Given a nullable foreign key with set-null and a stored attempted parent value, ',
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
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
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
            expect(projection!.attemptedValue, parent.id!.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-null projection has materialized a null foreign key, ',
    () {
      late Person attemptedParent;
      late Person newParent;
      late Town child;
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

        final parentHlc = await _rowHlc(attemptedParent.id!);
        remoteParentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentHlc,
        );

        await session.db.mergeChanges(
          [remoteParentDelete],
          userId: testCrdtUserId,
        );
      });

      group('when the user changes the foreign key to a visible parent, ', () {
        setUp(() async {
          final visibleChild = await Town.db.findById(session, child.id!);
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Town.db.updateRow(
              session,
              visibleChild!.copyWith(mayorId: newParent.id),
              columns: (t) => [t.mayorId],
              transaction: tx,
            );
          });
        });

        test(
          'then the projection override becomes inactive and foreign key tracking records the new visible user value.',
          () async {
            final visibleChild = await Town.db.findById(session, child.id!);
            final projection = await _findForeignKeyProjection(
              rowId: child.id!,
              columnName: Town.t.mayorId.columnName,
            );

            expect(visibleChild, isNotNull);
            expect(visibleChild!.mayorId, newParent.id);
            expect(projection, isNotNull);
            expect(projection!.attemptedValue, newParent.id!.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );
      });
    },
  );

  group(
    'Given a set-null projection has materialized a null foreign key from a merged parent delete, ',
    () {
      late Person attemptedParent;
      late Town child;
      late CrdtMergeDelete remoteParentRestore;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'restored mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'restored set null town',
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

        final parentDelete = _deleteChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: await _rowHlc(attemptedParent.id!),
        );
        remoteParentRestore = _restoreChange(
          tableName: Person.t.tableName,
          rowId: attemptedParent.id!,
          after: parentDelete.hlc,
        );

        await session.db.mergeChanges(
          [parentDelete],
          userId: testCrdtUserId,
        );
      });

      group('when a later merge restores the attempted parent, ', () {
        setUp(() async {
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
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isFalse);
          },
        );
      });
    },
  );

  group(
    'Given a set-null projection is active on a row, ',
    () {
      late Person attemptedParent;
      late Town child;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          attemptedParent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'deleted mayor'),
            transaction: tx,
          );
          child = await Town.db.insertRow(
            session,
            Town(
              id: const Uuid().v7obj(),
              name: 'projected town',
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

        final parentHlc = await _rowHlc(attemptedParent.id!);
        await session.db.mergeChanges(
          [
            _deleteChange(
              tableName: Person.t.tableName,
              rowId: attemptedParent.id!,
              after: parentHlc,
            ),
          ],
          userId: testCrdtUserId,
        );
      });

      group('when the row is updated without narrowing columns, ', () {
        setUp(() async {
          final visibleChild = await Town.db.findById(session, child.id!);
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            child = await Town.db.updateRow(
              session,
              visibleChild!.copyWith(name: 'renamed projected town'),
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
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
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
            expect(projection!.attemptedValue, attemptedParent.id!.uuid);
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
            expect(projection!.attemptedValue, missingParentId.uuid);
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
            expect(projection!.attemptedValue, missingParentId.uuid);
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
            expect(projection!.attemptedValue, attemptedTown.id!.uuid);
            expect(projection.visibleValue, defaultTown.id!.uuid);
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
            expect(projection!.attemptedValue, missingTownId.uuid);
            expect(projection.visibleValue, defaultTown.id!.uuid);
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
            expect(projection!.attemptedValue, attemptedTown.id!.uuid);
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
            expect(projection!.attemptedValue, missingParentId.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
    },
  );

  group(
    'Given a set-default foreign key whose default target is cascade-hidden by another root delete, ',
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

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
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
    'Given a valid cascade closure from city to organization to person, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late CrdtMergeDelete remoteCityDelete;
      late List<String> visibilityAfterMerge;
      late List<String> visibilityAfterReplay;
      late List<String> foreignKeyProjectionAfterMerge;
      late List<String> foreignKeyProjectionAfterReplay;

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

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
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
            expect(
              await Organization.db.findById(session, organization.id!),
              isNull,
            );
            expect(await Person.db.findById(session, person.id!), isNull);
          },
        );
      });

      group('when the root delete is merged and replayed, ', () {
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
    },
  );

  group(
    'Given a cascade projection hid descendants after a remote root delete, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late CrdtMergeDelete remoteCityDelete;
      late CrdtMergeDelete remoteCityRestore;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'restored cascade city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'restored cascade organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'restored cascade person',
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
        remoteCityRestore = _restoreChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: remoteCityDelete.hlc,
        );

        await session.db.mergeChanges(
          [remoteCityDelete],
          userId: testCrdtUserId,
        );
      });

      group('when the root restore is merged, ', () {
        setUp(() async {
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
    'Given a cascade chain that has a restrict descendant, ',
    () {
      late City city;
      late Organization organization;
      late Person person;
      late Address restrictChild;
      late CrdtMergeDelete remoteCityDelete;
      late CrdtMergeDelete remoteRestrictChildDelete;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          city = await City.db.insertRow(
            session,
            City(id: const Uuid().v7obj(), name: 'blocked city'),
            transaction: tx,
          );
          organization = await Organization.db.insertRow(
            session,
            Organization(
              id: const Uuid().v7obj(),
              name: 'blocked organization',
              cityId: city.id,
            ),
            transaction: tx,
          );
          person = await Person.db.insertRow(
            session,
            Person(
              id: const Uuid().v7obj(),
              name: 'blocked person',
              organizationId: organization.id,
            ),
            transaction: tx,
          );
          restrictChild = await Address.db.insertRow(
            session,
            Address(
              id: const Uuid().v7obj(),
              street: 'restrict street',
              inhabitantId: person.id,
            ),
            transaction: tx,
          );
          restrictChild = await Address.db.updateRow(
            session,
            restrictChild.copyWith(street: 'updated restrict street'),
            columns: (t) => [t.street],
            transaction: tx,
          );
        });

        final cityHlc = await _rowHlc(city.id!);
        remoteCityDelete = _deleteChange(
          tableName: City.t.tableName,
          rowId: city.id!,
          after: cityHlc,
        );
        final restrictChildHlc = await _rowHlc(restrictChild.id!);
        remoteRestrictChildDelete = _deleteChange(
          tableName: Address.t.tableName,
          rowId: restrictChild.id!,
          after: restrictChildHlc.maxBetween(remoteCityDelete.hlc),
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
          'then the cascade is blocked and every row in the mixed chain remains visible.',
          () async {
            final visibleCity = await City.db.findById(session, city.id!);
            final visibleOrganization = await Organization.db.findById(
              session,
              organization.id!,
            );
            final visiblePerson = await Person.db.findById(session, person.id!);
            final visibleRestrictChild = await Address.db.findById(
              session,
              restrictChild.id!,
            );

            expect(visibleCity, isNotNull);
            expect(visibleOrganization, isNotNull);
            expect(visibleOrganization!.cityId, city.id);
            expect(visiblePerson, isNotNull);
            expect(visiblePerson!.organizationId, organization.id);
            expect(visibleRestrictChild, isNotNull);
            expect(visibleRestrictChild!.inhabitantId, person.id);
          },
        );
      });

      group(
        'when the root delete is merged and the restrict child delete is merged, ',
        () {
          setUp(() async {
            await session.db.mergeChanges(
              [remoteCityDelete],
              userId: testCrdtUserId,
            );
            await session.db.mergeChanges(
              [remoteRestrictChildDelete],
              userId: testCrdtUserId,
            );
          });

          test(
            'then every row in the mixed chain is hidden.',
            () async {
              expect(await City.db.findById(session, city.id!), isNull);
              expect(
                await Organization.db.findById(session, organization.id!),
                isNull,
              );
              expect(await Person.db.findById(session, person.id!), isNull);
              expect(
                await Address.db.findById(session, restrictChild.id!),
                isNull,
              );
            },
          );
        },
      );
    },
  );

  group(
    'Given a permitted foreign-key cycle across person, company, and town, ',
    () {
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
        remoteCompanyDelete = _deleteChange(
          tableName: Company.t.tableName,
          rowId: company.id!,
          after: (await _rowHlc(company.id!)).maxBetween(remotePersonDelete.hlc),
        );
      });

      group('when concurrent deletes are merged around the cycle, ', () {
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
            final hiddenCompany = await Company.db.findById(
              session,
              company.id!,
            );
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
            expect(projection!.attemptedValue, person.id!.uuid);
            expect(projection.visibleValue, isNull);
            expect(projection.hasOverride, isTrue);
          },
        );
      });
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
              final singleBatchProjection = await _findForeignKeyProjection(
                rowId: child.id!,
                columnName: Town.t.mayorId.columnName,
                databaseSession: singleBatchSession,
              );
              final splitBatchProjection = await _findForeignKeyProjection(
                rowId: child.id!,
                columnName: Town.t.mayorId.columnName,
                databaseSession: splitBatchSession,
              );

              expect(singleBatchChild?.name, splitBatchChild?.name);
              expect(
                singleBatchChild?.mayorId?.uuid,
                splitBatchChild?.mayorId?.uuid,
              );
              expect(singleBatchProjection, splitBatchProjection);
              expect(singleBatchChild?.name, 'updated batching town');
              expect(singleBatchChild?.mayorId, isNull);
              expect(singleBatchProjection?.attemptedValue, attemptedParent.id!.uuid);
              expect(singleBatchProjection?.hasOverride, isTrue);
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

Future<_ForeignKeyProjection?> _findForeignKeyProjection({
  required UuidValue rowId,
  required String columnName,
  CrdtDatabaseSession? databaseSession,
}) async {
  final projection = await CrdtDataForeignKey.db.findFirstRow(
    databaseSession ?? session,
    where: (t) =>
        t.field.row.uuidRowId.equals(rowId) & t.field.column.name.equals(columnName),
  );

  if (projection == null) return null;
  return (
    attemptedValue: projection.attemptedValue?.uuid,
    visibleValue: projection.visibleValue?.uuid,
    hasOverride: projection.hasOverride,
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

typedef _ForeignKeyProjection = ({
  String? attemptedValue,
  String? visibleValue,
  bool hasOverride,
});

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
}
