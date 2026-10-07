import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group("Given a relay with its own older fact and another author's newer fact,", () {
    late DstIds ids;
    late DstClock clock;
    late UuidValue space;
    late DstReplica author;
    late DstReplica relay;
    late DstReplica receiver;
    late CrdtMergeSet initial;

    Future<void> insert(DstReplica replica, String name) => replica.withReplicaClock(
      () => replica.session.db.transactionForUser(space, (tx) async {
        await City.db.insertRow(
          replica.session,
          City(id: ids.next(), name: name),
          transaction: tx,
        );
      }),
    );

    setUp(() async {
      ids = DstIds(DstRandom(990));
      clock = DstClock();
      space = ids.next();
      author = await DstReplica.create(
        name: 'author',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      relay = await DstReplica.create(
        name: 'relay',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      receiver = await DstReplica.create(
        name: 'receiver',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      await insert(relay, 'relay fact');
      clock.advance(const Duration(seconds: 1));
      await insert(author, 'author fact');
      await relay.merge(await author.collect(space), space);
      initial = await relay.collect(space);
      await receiver.merge(initial, space);
    });

    group('when the receiver reconnects after the production inbound merge,', () {
      late List<Hlc> vector;
      late CrdtMergeSet pending;

      setUp(() async {
        vector = await receiver.checkpoints(space);
        pending = await relay.collect(space, checkpoints: vector);
      });

      test(
        'then each author has its own checkpoint and the relay has nothing to resend.',
        () {
          expect(initial, hasLength(2));
          expect(initial.maxHlc!.nodeId, author.nodeUuid);
          expect(vector.map((hlc) => hlc.nodeId).toSet(), hasLength(3));
          expect(vector, hasLength(3));
          expect(
            vector.singleWhere((hlc) => hlc.nodeId == relay.nodeUuid),
            initial.singleWhere((change) => change.uuidNodeId == relay.nodeUuid).hlc,
          );
          expect(pending, isEmpty);
        },
      );
    });

    group('when a stale session echoes a receiver fact before another local write,', () {
      late CrdtMergeSet echo;
      late CrdtMergeSet pending;
      late List<Hlc> vector;

      setUp(() async {
        final stale = await receiver.checkpoints(space);
        clock.advance(const Duration(seconds: 1));
        await insert(receiver, 'receiver fact one');
        await relay.merge(
          await receiver.collect(space, checkpoints: await relay.checkpoints(space)),
          space,
        );
        echo = await relay.collect(space, checkpoints: stale);
        await receiver.merge(echo, space);
        clock.advance(const Duration(seconds: 1));
        await insert(receiver, 'receiver fact two');
        await relay.merge(
          await receiver.collect(space, checkpoints: await relay.checkpoints(space)),
          space,
        );
        vector = await receiver.checkpoints(space);
        pending = await relay.collect(space, checkpoints: vector);
      });

      test(
        'then reconnecting neither resends the relay fact nor echoes either local fact.',
        () {
          expect(echo, hasLength(1));
          expect(echo.single.uuidNodeId, receiver.nodeUuid);
          expect(vector, hasLength(3));
          expect(vector.map((hlc) => hlc.nodeId).toSet(), hasLength(3));
          expect(pending, isEmpty);
        },
      );
    });

    group("when the checkpoint API is given a relayed author under the peer's id,", () {
      late Object failure;
      late List<Hlc> before;
      late List<Hlc> after;

      setUp(() async {
        before = await receiver.checkpoints(space);
        failure = await receiver.session.db
            .recordSyncCheckpoint(relay.nodeUuid, initial.maxHlc!, userId: space)
            .then<Object>(
              (_) => 'unexpected success',
              onError: (Object error) => error,
            );
        after = await receiver.checkpoints(space);
      });

      test('then the invalid checkpoint is rejected without changing progress.', () {
        expect(initial.maxHlc!.nodeId, author.nodeUuid);
        expect(failure, isA<ArgumentError>());
        expect(after, before);
      });
    });

    group(
      'when a stored relay checkpoint carries the wrong author from older bookkeeping,',
      () {
        late List<Hlc> beforeRepair;
        late List<Hlc> afterRepair;
        late CrdtMergeSet repair;
        late CrdtMergeSet pending;
        late Hlc? persisted;

        setUp(() async {
          final nodes = await OfflineSyncSpaceNode.db.find(
            receiver.rawSession,
            include: OfflineSyncSpaceNode.include(node: CrdtNode.include()),
          );
          final relayNode = nodes.singleWhere(
            (node) => node.node!.uuidNodeId == relay.nodeUuid,
          );
          await OfflineSyncSpaceNode.db.updateRow(
            receiver.rawSession,
            relayNode.copyWith(lastReceivedHlc: initial.maxHlc),
            columns: (t) => [t.lastReceivedHlc],
          );
          beforeRepair = await receiver.checkpoints(space);
          repair = await relay.collect(space, checkpoints: beforeRepair);
          await receiver.merge(repair, space);
          afterRepair = await receiver.checkpoints(space);
          persisted = (await OfflineSyncSpaceNode.db.findById(
            receiver.rawSession,
            relayNode.id!,
          ))!.lastReceivedHlc;
          pending = await relay.collect(space, checkpoints: afterRepair);
        });

        test(
          'then one safe retransmission repairs the persisted author tag and settles.',
          () {
            final relayHlc = initial
                .singleWhere((change) => change.uuidNodeId == relay.nodeUuid)
                .hlc;
            expect(initial.maxHlc, greaterThan(relayHlc));
            expect(beforeRepair, hasLength(3));
            expect(
              beforeRepair.singleWhere((hlc) => hlc.nodeId == relay.nodeUuid),
              Hlc.zero(relay.nodeUuid),
            );
            expect(repair, hasLength(1));
            expect(repair.single.uuidNodeId, relay.nodeUuid);
            expect(persisted, relayHlc);
            expect(
              afterRepair.singleWhere((hlc) => hlc.nodeId == relay.nodeUuid),
              relayHlc,
            );
            expect(pending, isEmpty);
          },
        );
      },
    );
  });
}
