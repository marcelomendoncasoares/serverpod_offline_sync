import 'dart:typed_data';

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

  group('Given two deleted people with earlier field edits known to a peer, ', () {
    late DstReplica source;
    late DstReplica peer;
    late DstReplica fresh;
    late UuidValue space;
    late List<Person> people;
    late DstBatch deleted;
    late DstSnapshot before;

    setUpAll(() async {
      final ids = DstIds(DstRandom(142));
      space = ids.next();
      source = await _replica(ids, space);
      peer = await _replica(ids, space);
      fresh = await _replica(ids, space);
      people = [
        Person(id: ids.next(), name: 'first', surname: 'before'),
        Person(id: ids.next(), name: 'second', surname: 'before'),
      ];
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Person.db.insert(source.session, people, transaction: tx);
          await Person.db.update(
            source.session,
            people.map((person) => person.copyWith(surname: 'edited')).toList(),
            columns: (t) => [t.surname],
            transaction: tx,
          );
          await Person.db.delete(source.session, people, transaction: tx);
        }),
      );
      deleted = await source.collect(space);
      await peer.merge(deleted, space);
      before = await DstSnapshot.capture(source);
      expect(before.fieldHlcs, isNotEmpty);
    });

    group(
      'when a batch upsert reinserts them and sync resumes after the deletion, ',
      () {
        late DstSnapshot after;
        late DstSnapshot resumed;
        late DstSnapshot bootstrapped;
        late CrdtMergeSet pending;

        setUpAll(() async {
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(
              space,
              (tx) => Person.db.upsert(
                source.session,
                people.map((person) => person.copyWith(surname: 'restored')).toList(),
                conflictColumns: (t) => [t.id],
                updateColumns: (t) => [t.name],
                noReturn: true,
                transaction: tx,
              ),
            ),
          );
          after = await DstSnapshot.capture(source);
          pending = await source.sync
              .collectPendingChanges(
                source.rawSession,
                checkpointsBySpaceUuid: {
                  space: deleted.revision,
                },
              )
              .toList();
          await peer.merge(pending, space);
          await peer.merge(deleted, space);
          await peer.merge(pending.reversed.toList(), space);
          resumed = await DstSnapshot.capture(peer);
          await fresh.merge(await source.collect(space), space);
          bootstrapped = await DstSnapshot.capture(fresh);
        });

        test('then all fields inherit their own new insertion timestamp.', () {
          expect(after.fieldHlcs, isEmpty);
          expect(after.rowHlcs.values.toSet(), hasLength(2));
          for (final person in people) {
            final rowKey = 'person/${person.id}';
            expect(after.rowHlcs[rowKey], greaterThan(before.rowHlcs[rowKey]!));
            expect(after.authoredValue(('person', person.id!, 'surname')), 'restored');
            expect(
              after.fieldHlc(('person', person.id!, 'surname')),
              after.rowHlcs[rowKey],
            );
          }
        });

        test(
          'then incremental sync carries full rows without redundant field updates.',
          () {
            expect(pending.inserts, hasLength(2));
            expect(pending.updates, isEmpty);
            expect(pending.deletes.map((change) => change.clFlag), everyElement(3));
          },
        );

        test('then replay and the older deletion leave the restored state intact.', () {
          expect(resumed.renderSpace(space), after.renderSpace(space));
          expect(
            resumed.tombstones.values.map((value) => value.clFlag),
            everyElement(3),
          );
        });

        test('then a fresh device reconstructs the same values and timestamps.', () {
          expect(bootstrapped.renderSpace(space), after.renderSpace(space));
        });
      },
    );
  });

  group(
    'Given a unique record deleted, restored from its hidden model, and deleted again, ',
    () {
      late DstReplica source;
      late DstReplica target;
      late UuidValue space;
      late Unique row;
      late DstSnapshot before;

      setUpAll(() async {
        final ids = DstIds(DstRandom(42));
        space = ids.next();
        source = await _replica(ids, space);
        target = await _replica(ids, space);
        row = Unique(id: ids.next(), name: 'ordinary');
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Unique.db.insertRow(source.session, row, transaction: tx);
            await Unique.db.deleteRow(source.session, row, transaction: tx);
          }),
        );
        final hidden = (await DstTable.unique.model.find(
          source.session,
          includeHidden: true,
          spaceUuid: space,
        )).single;
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await source.session.db.insertRow(hidden, transaction: tx);
            await Unique.db.deleteRow(source.session, row, transaction: tx);
          }),
        );
        before = await DstSnapshot.capture(source);
      });

      group('when its complete export is merged into an empty peer, ', () {
        late DstSnapshot after;
        setUpAll(() async {
          await target.merge(await source.collect(space), space);
          after = await DstSnapshot.capture(target);
        });

        test(
          'then the preserved name has the same renewed claim age on both devices.',
          () {
            final key = ('unique', row.id!, 'name');
            expect(before.fieldHlc(key), before.rowHlcs['unique/${row.id}']);
            expect(after.fieldHlc(key), before.fieldHlc(key));
            expect(after.authoredValue(key), 'ordinary');
            expect(after.renderSpace(space), before.renderSpace(space));
          },
        );

        test('then the final deletion retains its causal generation.', () {
          expect(after.tombstones['unique/${row.id}']!.clFlag, 4);
          expect(after.lookupVisible(DstTable.unique, row.id!), isNull);
        });
      });
    },
  );

  group(
    'Given a deleted town whose missing mayor is preserved behind a null reference, ',
    () {
      late DstReplica source;
      late DstReplica target;
      late UuidValue space;
      late Person mayor;
      late Town town;
      late Town hidden;

      setUpAll(() async {
        final ids = DstIds(DstRandom(43));
        space = ids.next();
        source = await _replica(ids, space);
        target = await _replica(ids, space);
        mayor = Person(id: ids.next(), name: 'mayor');
        town = Town(id: ids.next(), name: 'town', mayorId: mayor.id);
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Person.db.insertRow(source.session, mayor, transaction: tx);
          }),
        );
        await target.merge(await source.collect(space), space);
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(
            space,
            (tx) => Town.db.insertRow(source.session, town, transaction: tx),
          ),
        );
        await target.withReplicaClock(
          () => target.session.db.transactionForUser(
            space,
            (tx) => Person.db.deleteRow(target.session, mayor, transaction: tx),
          ),
        );
        await source.merge(await target.collect(space), space);
        hidden = (await Town.db.findById(source.session, town.id!))!;
        expect(hidden.mayorId, isNull);
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(
            space,
            (tx) => Town.db.deleteRow(source.session, hidden, transaction: tx),
          ),
        );
      });

      group('when the town is reinserted and a fresh device downloads it, ', () {
        late DstSnapshot after;
        late DstSnapshot downloaded;
        late CrdtMergeSet exported;
        setUpAll(() async {
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(
              space,
              (tx) => Town.db.insertRow(source.session, hidden, transaction: tx),
            ),
          );
          after = await DstSnapshot.capture(source);
          exported = await source.collect(space);
          final fresh = await _replica(DstIds(DstRandom(44)), space);
          await fresh.merge(exported, space);
          downloaded = await DstSnapshot.capture(fresh);
        });

        test(
          'then its original mayor is preserved at the new insertion timestamp.',
          () {
            final key = ('town', town.id!, 'mayorId');
            expect(after.authoredValue(key), mayor.id);
            expect(after.rows['town']![town.id!]!.columns['mayorId'], isNull);
            expect(after.fieldHlcs.keys.where((key) => key.$1 == 'town'), [key]);
            expect(after.fieldHlc(key), after.rowHlcs['town/${town.id}']);
            expect(
              exported.updates.where((change) => change.uuidRowId == town.id),
              isEmpty,
            );
          },
        );

        test(
          'then the fresh device reconstructs the preserved reference and its age.',
          () {
            expect(downloaded.renderSpace(space), after.renderSpace(space));
          },
        );
      });
    },
  );

  group(
    'Given a deleted name claim and a competing claim authored before its restoration, ',
    () {
      late DstReplica source;
      late DstReplica competitor;
      late UuidValue space;
      late Unique original;
      late Unique other;
      late Unique hidden;

      setUpAll(() async {
        final ids = DstIds(DstRandom(45));
        space = ids.next();
        final clock = DstClock();
        source = await _replica(ids, space, clock: clock);
        competitor = await _replica(ids, space, clock: clock);
        original = Unique(id: ids.next(), name: 'shared');
        other = Unique(id: ids.next(), name: 'shared');
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Unique.db.insertRow(source.session, original, transaction: tx);
            await Unique.db.deleteRow(source.session, original, transaction: tx);
          }),
        );
        hidden = (await Unique.db.find(
          source.session,
          where: (t) => t.includeHiddenRows,
        )).single;
        await competitor.merge(await source.collect(space), space);
        clock.advance(const Duration(milliseconds: 1));
        await competitor.withReplicaClock(
          () => competitor.session.db.transactionForUser(
            space,
            (tx) => Unique.db.insertRow(competitor.session, other, transaction: tx),
          ),
        );
        clock.advance(const Duration(milliseconds: 1));
      });

      group(
        'when the original identity is reinserted offline and both devices synchronize, ',
        () {
          late DstSnapshot restored;
          late DstSnapshot merged;
          late DstSnapshot peer;
          setUpAll(() async {
            await source.withReplicaClock(
              () => source.session.db.transactionForUser(
                space,
                (tx) => Unique.db.insertRow(source.session, hidden, transaction: tx),
              ),
            );
            restored = await DstSnapshot.capture(source);
            final competitorFacts = await competitor.collect(space);
            await competitor.merge(await source.collect(space), space);
            await source.merge(competitorFacts, space);
            merged = await DstSnapshot.capture(source);
            peer = await DstSnapshot.capture(competitor);
          });

          test(
            'then restoration drops the obsolete field record after reclaiming its value.',
            () {
              expect(restored.fieldHlcs, isEmpty);
              expect(restored.projections, isEmpty);
              expect(
                restored.authoredValue(('unique', original.id!, 'name')),
                'shared',
              );
            },
          );

          test(
            'then the earlier competing claim wins and the restored claim keeps its new age.',
            () {
              final key = ('unique', original.id!, 'name');
              expect(merged.rows['unique']![other.id!]!.columns['name'], 'shared');
              expect(
                merged.rows['unique']![original.id!]!.columns['name'],
                'shared__conflict__${original.id}',
              );
              expect(merged.authoredValue(key), 'shared');
              expect(merged.fieldHlc(key), restored.rowHlcs['unique/${original.id}']);
              expect(peer.renderSpace(space), merged.renderSpace(space));
            },
          );
        },
      );
    },
  );

  group('Given a restored person and a later name edit made by an offline peer, ', () {
    late DstReplica source;
    late DstReplica peer;
    late UuidValue space;
    late Person person;
    late DstSnapshot edited;

    setUpAll(() async {
      final ids = DstIds(DstRandom(46));
      space = ids.next();
      final clock = DstClock();
      source = await _replica(ids, space, clock: clock);
      peer = await _replica(ids, space, clock: clock);
      person = Person(id: ids.next(), name: 'original', surname: 'old');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => Person.db.insertRow(source.session, person, transaction: tx),
        ),
      );
      await peer.merge(await source.collect(space), space);
      clock.advance(const Duration(milliseconds: 1));
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Person.db.deleteRow(source.session, person, transaction: tx);
          await Person.db.insertRow(
            source.session,
            person.copyWith(name: 'restored', surname: 'restored'),
            transaction: tx,
          );
        }),
      );
      clock.advance(const Duration(milliseconds: 1));
      await peer.withReplicaClock(
        () => peer.session.db.transactionForUser(
          space,
          (tx) => Person.db.updateRow(
            peer.session,
            person.copyWith(name: 'later edit'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        ),
      );
      edited = await DstSnapshot.capture(peer);
    });

    group('when the peer receives the restoration and sends its edit back, ', () {
      late DstSnapshot after;
      late DstSnapshot returned;
      setUpAll(() async {
        await peer.merge(await source.collect(space), space);
        after = await DstSnapshot.capture(peer);
        await source.merge(await peer.collect(space), space);
        returned = await DstSnapshot.capture(source);
      });

      test(
        'then the newer name survives while the other values come from the restoration.',
        () {
          final key = ('person', person.id!, 'name');
          expect(after.authoredValue(key), 'later edit');
          expect(after.fieldHlc(key), edited.fieldHlc(key));
          expect(after.authoredValue(('person', person.id!, 'surname')), 'restored');
          expect(after.tombstones['person/${person.id}']!.clFlag, 3);
          expect(returned.renderSpace(space), after.renderSpace(space));
        },
      );
    });
  });

  group('Given a deleted row containing dates, binary data, and other scalar values, ', () {
    late DstReplica source;
    late DstReplica peer;
    late DstReplica fresh;
    late UuidValue space;
    late Types row;
    late Types replacement;

    setUpAll(() async {
      final ids = DstIds(DstRandom(48));
      space = ids.next();
      source = await _replica(ids, space);
      peer = await _replica(ids, space);
      fresh = await _replica(ids, space);
      row = Types(
        id: ids.next(),
        aBool: true,
        aDateTime: DateTime.utc(2025, 1),
        aText: 'before',
        anInt: 1,
        anInt64: BigInt.parse('9223372036854775806'),
        aReal: 1.5,
        aBlob: ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
        anEnum: TypesEnum.alpha,
        optionalText: 'before',
        optionalUuid: ids.next(),
      );
      replacement = row.copyWith(
        aBool: false,
        aDateTime: DateTime.utc(2026, 9, 17, 1, 2, 3, 456),
        aText: 'restored',
        anInt: -2,
        anInt64: BigInt.parse('-9223372036854775807'),
        aReal: 2.75,
        aBlob: ByteData.sublistView(Uint8List.fromList([0, 255, 128, 39])),
        anEnum: TypesEnum.gamma,
        optionalText: null,
        optionalUuid: ids.next(),
      );
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Types.db.insertRow(source.session, row, transaction: tx);
          await Types.db.deleteRow(source.session, row, transaction: tx);
        }),
      );
      await peer.merge(await source.collect(space), space);
    });

    group(
      'when it is reinserted with new values and downloaded by existing and fresh peers, ',
      () {
        late DstSnapshot after;
        late DstSnapshot resumed;
        late DstSnapshot downloaded;
        late Types onPeer;
        late CrdtMergeSet exported;
        setUpAll(() async {
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(
              space,
              (tx) => Types.db.insertRow(source.session, replacement, transaction: tx),
            ),
          );
          after = await DstSnapshot.capture(source);
          exported = await source.collect(space);
          await peer.merge(exported, space);
          await fresh.merge(exported, space);
          resumed = await DstSnapshot.capture(peer);
          downloaded = await DstSnapshot.capture(fresh);
          onPeer = (await Types.db.findById(peer.session, row.id!))!;
        });

        test(
          'then every value is reconstructed with its correct type from the row snapshot.',
          () {
            expect(exported.updates, isEmpty);
            final expected = replacement.toJson()..remove('spaceId');
            expect(onPeer.toJson()..remove('spaceId'), expected);
            expect(resumed.renderSpace(space), after.renderSpace(space));
            expect(downloaded.renderSpace(space), after.renderSpace(space));
          },
        );
      },
    );
  });

  group('Given a deleted unique record with retained authored metadata, ', () {
    late DstReplica source;
    late UuidValue space;
    late Unique row;
    late Unique hidden;
    late DstSnapshot before;

    setUpAll(() async {
      final ids = DstIds(DstRandom(47));
      space = ids.next();
      source = await _replica(ids, space);
      row = Unique(id: ids.next(), name: 'claim');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Unique.db.insertRow(source.session, row, transaction: tx);
          await Unique.db.deleteRow(source.session, row, transaction: tx);
        }),
      );
      hidden = (await Unique.db.find(
        source.session,
        where: (t) => t.includeHiddenRows,
      )).single;
      before = await DstSnapshot.capture(source);
    });

    group(
      'when a later unique violation aborts the transaction that reinserted it, ',
      () {
        late DstSnapshot after;
        Object? failure;
        setUpAll(() async {
          try {
            await source.withReplicaClock(
              () => source.session.db.transactionForUser(space, (tx) async {
                await Unique.db.insertRow(source.session, hidden, transaction: tx);
                await Unique.db.insertRow(
                  source.session,
                  Unique(name: 'claim'),
                  transaction: tx,
                );
              }),
            );
          } on Object catch (error) {
            failure = error;
          }
          after = await DstSnapshot.capture(source);
        });

        test(
          'then the deleted state, field clocks, and preserved claim are rolled back exactly.',
          () {
            expect(failure, isA<DatabaseUniqueViolationException>());
            expect(after.renderRawMetadata(), before.renderRawMetadata());
            expect(after.renderSpace(space), before.renderSpace(space));
          },
        );
      },
    );
  });
}

Future<DstReplica> _replica(DstIds ids, UuidValue space, {DstClock? clock}) =>
    DstReplica.create(
      name: 'replica',
      spaceUuids: [space],
      nodeUuid: ids.next(),
      clock: (clock ?? DstClock()).clock,
    );
