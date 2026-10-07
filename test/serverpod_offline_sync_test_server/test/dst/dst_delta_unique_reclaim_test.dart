import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseUniqueViolationException;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given two synchronized UUID claims with one projected conflict,', () {
    late DstIds ids;
    late DstClock clock;
    late UuidValue space;
    late UuidValue contested;
    late UuidValue replacement;
    late DstReplica source;
    late DstReplica peer;
    late UniqueUuid winner;
    late UniqueUuid loser;
    late DstSnapshot before;

    setUp(() async {
      ids = DstIds(DstRandom(427));
      clock = DstClock();
      space = ids.next();
      contested = ids.next();
      replacement = ids.next();
      source = await DstReplica.create(
        name: 'source',
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
      winner = UniqueUuid(id: ids.next(), value: contested);
      loser = UniqueUuid(id: ids.next(), value: contested);
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await UniqueUuid.db.insertRow(source.session, winner, transaction: tx);
        }),
      );
      clock.advance(const Duration(milliseconds: 1));
      await peer.withReplicaClock(
        () => peer.session.db.transactionForUser(space, (tx) async {
          await UniqueUuid.db.insertRow(peer.session, loser, transaction: tx);
        }),
      );
      await source.merge(await peer.collect(space), space);
      await peer.merge(await source.collect(space), space);
      before = await DstSnapshot.capture(source);
    });

    group(
      'when the winner locally changes to an uncontested UUID and sends only its delta,',
      () {
        late DstSnapshot local;
        late DstSnapshot remote;
        late CrdtMergeSet delta;

        setUp(() async {
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(space, (tx) async {
              await UniqueUuid.db.updateRow(
                source.session,
                winner.copyWith(value: replacement),
                columns: (t) => [t.value],
                transaction: tx,
              );
            }),
          );
          local = await DstSnapshot.capture(source);
          delta = await source.collect(
            space,
            checkpoints: await peer.checkpoints(space),
          );
          await peer.merge(delta, space);
          remote = await DstSnapshot.capture(peer);
        });

        test('then the old loser reclaims its authored UUID on both replicas.', () {
          final key = ('unique_uuid', loser.id!, 'value');
          expect(before.projections[key], isNotNull);
          expect(delta, hasLength(1));
          expect(delta.single, isA<CrdtMergeUpdate>());
          expect(local.projections[key], isNull);
          expect(remote.projections[key], isNull);
          expect(local.renderSpace(space), remote.renderSpace(space));
        });
      },
    );

    group('when the winner changes in a batch update without returned rows,', () {
      late DstSnapshot local;
      late DstSnapshot remote;
      late CrdtMergeSet delta;

      setUp(() async {
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await UniqueUuid.db.update(
              source.session,
              [winner.copyWith(value: replacement)],
              columns: (t) => [t.value],
              noReturn: true,
              transaction: tx,
            );
          }),
        );
        local = await DstSnapshot.capture(source);
        delta = await source.collect(space, checkpoints: await peer.checkpoints(space));
        await peer.merge(delta, space);
        remote = await DstSnapshot.capture(peer);
      });

      test('then the released claimant reclaims its value before delta catch-up.', () {
        final key = ('unique_uuid', loser.id!, 'value');
        expect(before.projections[key], isNotNull);
        expect(delta, hasLength(1));
        expect(delta.single.uuidRowId, winner.id);
        expect(local.projections[key], isNull);
        expect(remote.projections[key], isNull);
        expect(dstValue(local.authoredValue(key)), dstValue(before.authoredValue(key)));
        expect(local.fieldHlc(key), before.fieldHlc(key));
        expect(local.renderSpace(space), remote.renderSpace(space));
      });
    });

    group('when a limited predicate update changes only the first claim,', () {
      late DstSnapshot local;
      late DstSnapshot remote;
      late CrdtMergeSet delta;

      setUp(() async {
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await UniqueUuid.db.updateWhere(
              source.session,
              columnValues: (t) => [t.value(replacement)],
              where: (t) => t.id.inSet(<UuidValue>{winner.id!, loser.id!}),
              orderBy: (t) => t.id,
              limit: 1,
              noReturn: true,
              transaction: tx,
            );
          }),
        );
        local = await DstSnapshot.capture(source);
        delta = await source.collect(space, checkpoints: await peer.checkpoints(space));
        await peer.merge(delta, space);
        remote = await DstSnapshot.capture(peer);
      });

      test('then the released claimant reclaims its value before delta catch-up.', () {
        final key = ('unique_uuid', loser.id!, 'value');
        expect(before.projections[key], isNotNull);
        expect(delta, hasLength(1));
        expect(delta.single.uuidRowId, winner.id);
        expect(local.projections[key], isNull);
        expect(remote.projections[key], isNull);
        expect(dstValue(local.authoredValue(key)), dstValue(before.authoredValue(key)));
        expect(local.fieldHlc(key), before.fieldHlc(key));
        expect(local.renderSpace(space), remote.renderSpace(space));
      });
    });

    group('when a predicate update skips the winner and selects the next claim,', () {
      late List<UniqueUuid> updated;
      late DstSnapshot local;
      late DstSnapshot remote;
      late CrdtMergeSet delta;

      setUp(() async {
        updated = await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            return UniqueUuid.db.updateWhere(
              source.session,
              columnValues: (t) => [t.value(replacement)],
              where: (t) => t.id.inSet(<UuidValue>{winner.id!, loser.id!}),
              orderBy: (t) => t.id,
              offset: 1,
              limit: 1,
              transaction: tx,
            );
          }),
        );
        local = await DstSnapshot.capture(source);
        delta = await source.collect(space, checkpoints: await peer.checkpoints(space));
        await peer.merge(delta, space);
        remote = await DstSnapshot.capture(peer);
      });

      test('then exactly the selected loser changes and is returned.', () {
        final loserKey = ('unique_uuid', loser.id!, 'value');
        final winnerKey = ('unique_uuid', winner.id!, 'value');
        expect(before.projections[loserKey], isNotNull);
        expect(updated, hasLength(1));
        expect(updated.single.id, loser.id);
        expect(updated.single.value, replacement);
        expect(delta, hasLength(1));
        expect(delta.single.uuidRowId, loser.id);
        expect(local.projections[loserKey], isNull);
        expect(dstValue(local.authoredValue(winnerKey)), dstValue(contested));
        expect(local.fieldHlc(winnerKey), before.fieldHlc(winnerKey));
        expect(local.renderSpace(space), remote.renderSpace(space));
      });
    });

    group('when an upsert changes the winning claim,', () {
      late DstSnapshot local;
      late DstSnapshot remote;
      late CrdtMergeSet delta;

      setUp(() async {
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await UniqueUuid.db.upsertRow(
              source.session,
              winner.copyWith(value: replacement),
              conflictColumns: (t) => [t.id],
              updateColumns: (t) => [t.value],
              transaction: tx,
            );
          }),
        );
        local = await DstSnapshot.capture(source);
        delta = await source.collect(space, checkpoints: await peer.checkpoints(space));
        await peer.merge(delta, space);
        remote = await DstSnapshot.capture(peer);
      });

      test('then the released claimant reclaims its value before delta catch-up.', () {
        final key = ('unique_uuid', loser.id!, 'value');
        expect(before.projections[key], isNotNull);
        expect(delta, hasLength(1));
        expect(delta.single.uuidRowId, winner.id);
        expect(local.projections[key], isNull);
        expect(remote.projections[key], isNull);
        expect(dstValue(local.authoredValue(key)), dstValue(before.authoredValue(key)));
        expect(local.fieldHlc(key), before.fieldHlc(key));
        expect(local.renderSpace(space), remote.renderSpace(space));
      });
    });

    group('when a predicate update fails its physical unique constraint,', () {
      late Object failure;
      late DstSnapshot after;
      late List<String> checkpointBefore;
      late List<String> checkpointAfter;

      setUp(() async {
        checkpointBefore = (await source.checkpoints(
          space,
        )).map((hlc) => hlc.toString()).toList();
        failure = await source
            .withReplicaClock(
              () => source.session.db.transactionForUser(space, (tx) async {
                await UniqueUuid.db.updateWhere(
                  source.session,
                  columnValues: (t) => [t.value(replacement)],
                  where: (t) => t.id.inSet(<UuidValue>{winner.id!, loser.id!}),
                  transaction: tx,
                );
              }),
            )
            .then<Object>(
              (_) => 'unexpected success',
              onError: (Object error) => error,
            );
        after = await DstSnapshot.capture(source);
        checkpointAfter = (await source.checkpoints(
          space,
        )).map((hlc) => hlc.toString()).toList();
      });

      test(
        'then pre-write closure capture changes no domain, authored metadata, or progress.',
        () {
          expect(before.projections[('unique_uuid', loser.id!, 'value')], isNotNull);
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(after.renderSpace(space), before.renderSpace(space));
          expect(after.renderRawMetadata(), before.renderRawMetadata());
          expect(checkpointAfter, checkpointBefore);
        },
      );
    });
  });
}
