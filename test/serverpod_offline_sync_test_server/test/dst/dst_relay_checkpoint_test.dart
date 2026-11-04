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
    late DstBatch initial;

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
      late DstCheckpoint vector;
      late CrdtMergeSet pending;

      setUp(() async {
        vector = await receiver.checkpoints(space);
        pending = await relay.collect(space, checkpoints: vector);
      });

      test(
        'then the immediate relay has one durable receipt and nothing to resend.',
        () {
          expect(initial, hasLength(2));
          expect(initial.maxHlc!.nodeId, author.nodeUuidFor(space));
          expect(vector, hasLength(1));
          expect(vector.single.uuidNodeId, relay.nodeUuidFor(space));
          expect(vector.single.revision, initial.revision);
          expect(pending, isEmpty);
        },
      );
    });

    group('when a stale session echoes a receiver fact before another local write,', () {
      late CrdtMergeSet echo;
      late CrdtMergeSet pending;
      late DstCheckpoint vector;

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
          expect(echo, isEmpty);
          expect(vector, hasLength(1));
          expect(vector.single.uuidNodeId, relay.nodeUuidFor(space));
          expect(pending, isEmpty);
        },
      );
    });
  });
}
