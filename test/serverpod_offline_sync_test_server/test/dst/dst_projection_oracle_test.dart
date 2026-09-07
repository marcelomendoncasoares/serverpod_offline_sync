import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';
import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession();

  test(
    'Given a deleted company in a scope with no default town, '
    'when its former town is deleted and the whole scope is merged, '
    'then the oracle accepts both hidden rows with the unchanged reference.',
    () async {
      final ids = DstIds(DstRandom(114));
      final clock = DstClock();
      final scope = ids.next();
      final source = await DstReplica.create(
        name: 'source',
        scopeUuids: [scope],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      final target = await DstReplica.create(
        name: 'target',
        scopeUuids: [scope],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      final town = Town(id: ids.next(), name: 'town');
      final company = Company(id: ids.next(), name: 'company', townId: town.id);
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(scope, (tx) async {
          await Town.db.insertRow(source.session, town, transaction: tx);
          await Company.db.insertRow(source.session, company, transaction: tx);
        }),
      );
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(scope, (tx) async {
          await Company.db.deleteRow(source.session, company, transaction: tx);
        }),
      );

      await source.withReplicaClock(
        () => source.session.db.transactionForUser(scope, (tx) async {
          await Town.db.deleteRow(source.session, town, transaction: tx);
        }),
      );
      await target.merge(await source.collect(scope), scope);

      final snapshot = await DstSnapshot.capture(target);
      expect(snapshot.rows['company']![company.id]!.visible, isFalse);
      expect(snapshot.rows['town']![town.id]!.visible, isFalse);
      expect(
        snapshot.rows['company']![company.id]!.columns['townId'],
        town.id.toString(),
      );
      expect(snapshot.projections, isEmpty);
      expect(DstOracle.foreignKeyClosure(snapshot), isEmpty);
      expect(DstOracle.projectionPurity(snapshot), isEmpty);
    },
  );

  test(
    'Given a visible company referencing a hidden town without a legal default, '
    'when its unrepaired snapshot is checked, '
    'then the oracle rejects the dangling reference.',
    () {
      final ids = DstIds(DstRandom(115));
      final scope = ids.next();
      final townId = ids.next();
      final companyId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'town': {townId: (scopeUuid: scope, columns: {}, visible: false)},
          'company': {
            companyId: (
              scopeUuid: scope,
              columns: {'townId': townId},
              visible: true,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.projectionPurity(snapshot);

      expect(violations, hasLength(1));
      expect(violations.single.property, 'projectionPurity');
    },
  );

  test(
    'Given a hidden company referencing a hidden town and an available default, '
    'when its unrepaired snapshot is checked, '
    'then the oracle rejects the missing set-default repair.',
    () {
      final ids = DstIds(DstRandom(116));
      final scope = ids.next();
      final townId = ids.next();
      final companyId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'town': {
            townId: (scopeUuid: scope, columns: {}, visible: false),
            dstDefaultTownId: (scopeUuid: scope, columns: {}, visible: true),
          },
          'company': {
            companyId: (
              scopeUuid: scope,
              columns: {'townId': townId},
              visible: false,
            ),
          },
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.projectionPurity(snapshot);

      expect(violations, hasLength(1));
      expect(violations.single.property, 'projectionPurity');
    },
  );
}
