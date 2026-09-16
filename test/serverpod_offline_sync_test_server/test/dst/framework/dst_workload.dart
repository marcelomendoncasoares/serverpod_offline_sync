import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'dst_random.dart';
import 'dst_world.dart';

/// A per-space production-valid graph, followed by concrete transitions before
/// random scheduling begins. Every write uses the same evidence/rejection path
/// as random operations. No direct metadata writes or fabricated merge facts.
Future<void> populateDstSpace({
  required DstReplica replica,
  required UuidValue space,
  required DstOperations operations,
  required DstIds ids,
  required int width,
}) async {
  final rows = <DstTable, List<TableRow<UuidValue?>>>{};
  final order = [
    DstTable.city,
    DstTable.organization,
    DstTable.person,
    DstTable.town,
    DstTable.company,
    ...DstTable.values.where(
      (table) => !{
        DstTable.city,
        DstTable.organization,
        DstTable.person,
        DstTable.town,
        DstTable.company,
      }.contains(table),
    ),
  ];
  for (final table in order) {
    final batch = <TableRow<UuidValue?>>[];
    for (var slot = 0; slot < width; slot++) {
      final data = <String, dynamic>{'id': ids.next().toJson()};
      for (final column in table.definition.columns) {
        if (column.name == 'id' || column.name == 'spaceId') continue;
        final edge = dstForeignKeys
            .where((edge) => edge.child == table && edge.column == column.name)
            .firstOrNull;
        if (edge != null) {
          final parents = rows[edge.parent];
          if (parents == null && !edge.nullable) {
            throw StateError(
              'Populated profile orders ${table.tableName} before required ${edge.parent.tableName}',
            );
          }
          data[column.name] = parents?[slot].id!.toJson();
        } else if ((column.dartType ?? '').startsWith('String')) {
          data[column.name] = 'graph-${table.tableName}-${column.name}-$slot';
        } else if ((column.dartType ?? '').startsWith('UuidValue')) {
          data[column.name] = ids.next().toJson();
        } else if ((column.dartType ?? '').startsWith('int')) {
          data[column.name] = slot;
        } else {
          throw StateError('No populated value for ${table.tableName}.${column.name}');
        }
      }
      batch.add(table.model.fromJson(data));
    }
    await _write(replica, space, operations, table, batch, DstAction.insertBatch);
    rows[table] = batch;
  }

  // Close every person/company/town cycle after the nullable forward edge's
  // target exists. The initial graph observes all 28 declared FK edges.
  await _write(
    replica,
    space,
    operations,
    DstTable.person,
    [
      for (var slot = 0; slot < width; slot++)
        DstTable.person.model.fromJson({
          ...rows[DstTable.person]![slot].toJson() as Map<String, dynamic>,
          'oldCompanyId': rows[DstTable.company]![slot].id!.toJson(),
        }),
    ],
    DstAction.updateBatch,
    columns: {'oldCompanyId'},
  );

  // Author a supported competing non-FK claim, then exercise unique tuple
  // swapping and the same identity's delete/restore/redelete lifecycle.
  await _write(
    replica,
    space,
    operations,
    DstTable.unique,
    [
      for (final row in rows[DstTable.unique]!) Unique(id: row.id, name: 'contested'),
    ],
    DstAction.updateBatch,
    columns: {'name'},
  );
  await operations.apply(
    replica,
    space,
    table: DstTable.unique,
    action: DstAction.swapUnique,
  );
  final identity = rows[DstTable.unique]!.first.id!;
  final current = await Unique.db.findById(replica.session, identity);
  await _write(replica, space, operations, DstTable.unique, [
    current!,
  ], DstAction.delete);
  final hidden = (await DstTable.unique.model.find(
    replica.session,
    includeHidden: true,
    spaceUuid: space,
  )).singleWhere((row) => row.id == identity);
  await _write(replica, space, operations, DstTable.unique, [
    hidden,
  ], DstAction.restore);
  final restored = await Unique.db.findById(replica.session, identity);
  await _write(replica, space, operations, DstTable.unique, [
    restored!,
  ], DstAction.delete);

  // Retarget and explicitly detach a real edge, retaining another intact cycle.
  final town = rows[DstTable.town]!.first as Town;
  await _write(
    replica,
    space,
    operations,
    DstTable.town,
    [town.copyWith(mayorId: rows[DstTable.person]![1].id)],
    DstAction.updateBatch,
    columns: {'mayorId'},
  );
  await _write(
    replica,
    space,
    operations,
    DstTable.town,
    [town.copyWith(mayorId: null)],
    DstAction.updateBatch,
    columns: {'mayorId'},
  );

  // Every seeded person has real required SET NULL/no-action descendants.
  // This must refuse and the shared operation boundary checks full rollback.
  final rejected = await operations.apply(
    replica,
    space,
    table: DstTable.person,
    action: DstAction.delete,
  );
  if (rejected != DstOperationOutcome.rejected) {
    throw StateError('Populated profile did not exercise its blocked person delete');
  }
}

Future<void> _write(
  DstReplica replica,
  UuidValue space,
  DstOperations operations,
  DstTable table,
  List<TableRow<UuidValue?>> rows,
  DstAction action, {
  Set<String>? columns,
}) async {
  final outcome = await operations.perform(
    replica,
    space,
    table: table,
    action: action,
    body: (tx, evidence, refusal) async {
      if (action == DstAction.delete) {
        final ids = rows.map((row) => row.id!);
        refusal.delete(table, ids);
        evidence.visibility(table.tableName, ids, deleted: true);
        await table.model.deleteBatch(replica.session, rows, tx);
      } else {
        for (final row in rows) {
          evidence.write(
            table.tableName,
            row.toJson() as Map<String, dynamic>,
            columns: columns,
            insertDefaults: action == DstAction.insertBatch,
          );
        }
        if (action == DstAction.restore) {
          evidence.visibility(
            table.tableName,
            rows.map((row) => row.id!),
            deleted: false,
          );
          await table.model.insert(replica.session, rows.single, tx);
        } else if (action == DstAction.insertBatch) {
          await table.model.insertBatch(replica.session, rows, tx);
        } else {
          await table.model.updateBatch(replica.session, rows, columns!, tx);
        }
      }
      return DstOperationOutcome.applied;
    },
  );
  if (outcome != DstOperationOutcome.applied) {
    throw StateError(
      'Populated ${table.tableName}.${action.name} did not commit: $outcome',
    );
  }
}
