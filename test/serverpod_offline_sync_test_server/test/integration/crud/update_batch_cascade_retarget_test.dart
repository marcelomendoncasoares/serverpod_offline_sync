import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

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
      late OfflineSyncDatabaseSession scenario;
      late FkChainRoot root;
      late FkChainCascadeMiddle blockingMiddle;
      late FkChainCascadeMiddle retargetedMiddle;
      late FkChainRestrictBlocker blocker;

      late FkChainRoot? rootBeforeBatch;
      late FkChainCascadeMiddle? blockingMiddleBeforeBatch;
      late FkChainCascadeMiddle? retargetedMiddleBeforeBatch;

      setUpAll(() async {
        scenario = OfflineSyncDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: testSyncTables,
        );
        await scenario.db.initialize();

        await scenario.db.transactionForUser(testCrdtUserId, (tx) async {
          root = await FkChainRoot.db.insertRow(
            scenario,
            FkChainRoot(id: const Uuid().v7obj(), name: 'blocked root'),
            transaction: tx,
          );
          blockingMiddle = await FkChainCascadeMiddle.db.insertRow(
            scenario,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'blocking middle',
              rootId: root.id,
            ),
            transaction: tx,
          );
          retargetedMiddle = await FkChainCascadeMiddle.db.insertRow(
            scenario,
            FkChainCascadeMiddle(
              id: const Uuid().v7obj(),
              name: 'retargeted middle',
            ),
            transaction: tx,
          );
          blocker = await FkChainRestrictBlocker.db.insertRow(
            scenario,
            FkChainRestrictBlocker(
              id: const Uuid().v7obj(),
              name: 'restrict blocker',
              cascadeMiddleId: blockingMiddle.id,
            ),
            transaction: tx,
          );
        });

        final rootHlc = await rowHlc(root.id!, databaseSession: scenario);
        await scenario.db.mergeChanges(
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

        rootBeforeBatch = await FkChainRoot.db.findById(scenario, root.id!);
        blockingMiddleBeforeBatch = await FkChainCascadeMiddle.db.findById(
          scenario,
          blockingMiddle.id!,
        );
        retargetedMiddleBeforeBatch = await FkChainCascadeMiddle.db.findById(
          scenario,
          retargetedMiddle.id!,
        );
      });

      group(
        'when one batch detaches the blocking middle and retargets the other to that root,',
        () {
          late FkChainRoot? visibleRoot;
          late FkChainCascadeMiddle? visibleRetargetedMiddle;
          late FkChainCascadeMiddle? hiddenMiddle;
          late FkChainCascadeMiddle? detachedMiddle;
          late FkChainRestrictBlocker? visibleBlocker;

          setUpAll(() async {
            await scenario.db.transactionForUser(testCrdtUserId, (tx) async {
              await FkChainCascadeMiddle.db.update(
                scenario,
                [
                  retargetedMiddle.copyWith(rootId: root.id),
                  blockingMiddle.copyWith(rootId: null),
                ],
                columns: (t) => [t.rootId],
                transaction: tx,
              );
            });

            visibleRoot = await FkChainRoot.db.findById(scenario, root.id!);
            visibleRetargetedMiddle = await FkChainCascadeMiddle.db.findById(
              scenario,
              retargetedMiddle.id!,
            );
            hiddenMiddle = await FkChainCascadeMiddle.db.findFirstRow(
              scenario,
              where: (t) => t.id.equals(retargetedMiddle.id) & t.includeHiddenRows,
            );
            detachedMiddle = await FkChainCascadeMiddle.db.findById(
              scenario,
              blockingMiddle.id!,
            );
            visibleBlocker = await FkChainRestrictBlocker.db.findById(
              scenario,
              blocker.id!,
            );
          });

          test('then the root and both middles were visible before the batch.', () {
            expect(rootBeforeBatch, isNotNull);
            expect(blockingMiddleBeforeBatch, isNotNull);
            expect(retargetedMiddleBeforeBatch, isNotNull);
          });

          test('then the root is hidden.', () {
            expect(visibleRoot, isNull);
          });

          test('then the retargeted middle is hidden with its authored root.', () {
            expect(visibleRetargetedMiddle, isNull);
            expect(hiddenMiddle, isNotNull);
            expect(hiddenMiddle!.rootId, root.id);
          });

          test('then the detached middle stays visible without a root.', () {
            expect(detachedMiddle, isNotNull);
            expect(detachedMiddle!.rootId, isNull);
          });

          test('then the restrict blocker stays visible.', () {
            expect(visibleBlocker, isNotNull);
          });
        },
      );
    },
  );
}
