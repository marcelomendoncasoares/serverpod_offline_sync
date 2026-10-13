import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

void main() {
  initTestClientSession();

  group(
    'Given a user-deleted cascade root kept visible by a restrict descendant,',
    () {
      // Root
      //   │ CASCADE
      //   ▼
      // blocking middle  ←── NO ACTION ── restrict blocker
      //
      // retargeted middle (rootId null)
      //
      // The merged root delete cannot hide the blocking middle while the
      // restrict row references it, so the root stays visible. A later batch
      // may detach that chain and point the other middle at the same root.
      late FkChainRoot root;
      late FkChainCascadeMiddle blockingMiddle;
      late FkChainCascadeMiddle retargetedMiddle;
      late FkChainRestrictBlocker blocker;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          root = await FkChainRoot.db.insertRow(
            session,
            FkChainRoot(id: const Uuid().v7obj(), name: 'blocked root'),
            transaction: tx,
          );
          blockingMiddle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'blocking middle',
              rootId: root.id,
            ),
            transaction: tx,
          );
          retargetedMiddle = await FkChainCascadeMiddle.db.insertRow(
            session,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'retargeted middle',
            ),
            transaction: tx,
          );
          blocker = await FkChainRestrictBlocker.db.insertRow(
            session,
            FkChainRestrictBlocker(
              id: const Uuid().v7obj(),
              name: 'restrict blocker',
              cascadeMiddleId: blockingMiddle.id,
            ),
            transaction: tx,
          );
        });

        final rootHlc = await rowHlc(root.id!);
        await session.db.mergeChanges(
          [
            CrdtMergeDelete(
              uuidSpaceId: testCrdtUserId,
              tableName: FkChainRoot.t.tableName,
              uuidRowId: root.id!,
              uuidNodeId: const Uuid().v7obj(),
              hlcDatetime: rootHlc.datetime.add(const Duration(milliseconds: 1)),
              hlcCounter: 0,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
          spaceId: testCrdtUserId,
        );
      });

      test('then the root and both middles are visible.', () async {
        expect(await FkChainRoot.db.findById(session, root.id!), isNotNull);
        expect(
          await FkChainCascadeMiddle.db.findById(session, blockingMiddle.id!),
          isNotNull,
        );
        expect(
          await FkChainCascadeMiddle.db.findById(session, retargetedMiddle.id!),
          isNotNull,
        );
      });

      test(
        'when one batch detaches the blocking middle and points the other '
        'middle at that root, then the delete takes effect and the retargeted '
        'middle stays cascade-hidden with the authored root.',
        () async {
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            await FkChainCascadeMiddle.db.update(
              session,
              [
                retargetedMiddle.copyWith(rootId: root.id),
                blockingMiddle.copyWith(rootId: null),
              ],
              columns: (t) => [t.rootId],
              transaction: tx,
            );
          });

          expect(await FkChainRoot.db.findById(session, root.id!), isNull);
          expect(
            await FkChainCascadeMiddle.db.findById(session, retargetedMiddle.id!),
            isNull,
          );
          final hiddenMiddle = await FkChainCascadeMiddle.db.findFirstRow(
            session,
            where: (t) => t.id.equals(retargetedMiddle.id) & t.includeHiddenRows,
          );
          expect(hiddenMiddle, isNotNull);
          expect(hiddenMiddle!.rootId, root.id);

          final detached = await FkChainCascadeMiddle.db.findById(
            session,
            blockingMiddle.id!,
          );
          expect(detached, isNotNull);
          expect(detached!.rootId, isNull);
          expect(
            await FkChainRestrictBlocker.db.findById(session, blocker.id!),
            isNotNull,
          );
        },
      );
    },
  );
}
