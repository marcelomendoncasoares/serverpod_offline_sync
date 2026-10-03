import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given two local writes committed within the same clock millisecond,', () {
    final ids = DstIds(DstRandom(426));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica author;
    late DstReplica peer;
    late Hlc latestAuthored;

    setUpAll(() async {
      author = await DstReplica.create(
        name: 'author',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      peer = await DstReplica.create(
        name: 'peer',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      for (final name in ['first', 'second']) {
        await author.withReplicaClock(
          () => author.session.db.transactionForUser(space, (tx) async {
            await City.db.insertRow(
              author.session,
              City(id: ids.next(), name: name),
              transaction: tx,
            );
          }),
        );
      }
      final changes = await author.collect(space);
      latestAuthored = changes.maxHlc!;
      await peer.merge(changes, space);
    });

    group(
      'when the author reconnects before its wall clock advances and after it moves backward,',
      () {
        late Hlc sameMillisecond;
        late Hlc backwardClock;
        late CrdtMergeSet sameMillisecondEcho;
        late CrdtMergeSet backwardClockEcho;

        setUpAll(() async {
          var checkpoints = await author.checkpoints(space);
          sameMillisecond = checkpoints.singleWhere(
            (hlc) => hlc.nodeId == author.nodeUuid,
          );
          sameMillisecondEcho = await peer.collect(space, checkpoints: checkpoints);
          clock.advance(const Duration(seconds: -1));
          checkpoints = await author.checkpoints(space);
          backwardClock = checkpoints.singleWhere(
            (hlc) => hlc.nodeId == author.nodeUuid,
          );
          backwardClockEcho = await peer.collect(space, checkpoints: checkpoints);
        });

        test('then both resume vectors cover the persisted logical counter.', () {
          expect(latestAuthored.counter, greaterThan(0));
          expect(sameMillisecond, greaterThanOrEqualTo(latestAuthored));
          expect(backwardClock, greaterThanOrEqualTo(latestAuthored));
        });

        test("then neither resume causes the peer to echo the author's own facts.", () {
          expect(sameMillisecondEcho, isEmpty);
          expect(backwardClockEcho, isEmpty);
        });
      },
    );
  });
}
