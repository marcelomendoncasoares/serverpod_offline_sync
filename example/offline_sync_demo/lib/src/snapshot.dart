import 'package:flutter/material.dart' as material;
import 'package:serverpod_database/serverpod_database.dart' as db
    show TableRow;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'models.dart';
import 'relationships.dart';
import 'table_ops.dart';

/// A single domain row, as JSON, together with its visibility for one replica.
class RowView {
  RowView({
    required this.table,
    required this.id,
    required this.json,
    required this.visible,
  });

  final String table;
  final protocol.UuidValue id;
  final Map<String, dynamic> json;
  final bool visible;
}

/// The data shown in one tree node.
class DemoTreeItem {
  DemoTreeItem._({
    required this.title,
    required this.icon,
    this.detail,
    this.ref,
    this.relation,
    this.hidden = false,
    this.dangling = false,
    this.metadata = false,
  });

  factory DemoTreeItem.group(String title, String detail) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      icon: material.Icons.folder_open,
    );
  }

  factory DemoTreeItem.row(
    String title,
    String detail,
    DemoRowRef ref, {
    required bool hidden,
    Relationship? relation,
    bool dangling = false,
  }) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      ref: ref,
      icon: iconForTable(ref.tableName, hidden: hidden),
      hidden: hidden,
      relation: relation,
      dangling: dangling,
    );
  }

  factory DemoTreeItem.metadata(String title, String detail) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      icon: material.Icons.info_outline,
      metadata: true,
    );
  }

  final String title;
  final String? detail;
  final material.IconData icon;
  final DemoRowRef? ref;

  /// The foreign-key edge that attaches this node to its parent (null for roots
  /// and groups). Drives the onDelete badge.
  final Relationship? relation;
  final bool hidden;

  /// This row carries a non-null foreign key whose parent is not present here.
  final bool dangling;
  final bool metadata;
}

/// A projected tree plus the visible/hidden row counts behind it.
class DemoProjection {
  DemoProjection({
    required this.nodes,
    required this.visibleRowCount,
    required this.hiddenRowCount,
  });

  factory DemoProjection.empty() {
    return DemoProjection(
      nodes: const [],
      visibleRowCount: 0,
      hiddenRowCount: 0,
    );
  }

  final List<TreeNode<DemoTreeItem>> nodes;
  final int visibleRowCount;
  final int hiddenRowCount;
}

/// An immutable view of one replica's domain rows and CRDT metadata.
class DemoSnapshot {
  DemoSnapshot({
    required this.catalog,
    required this.rows,
    required this.foreignKeys,
    required this.tombstones,
  });

  final RelationshipCatalog catalog;
  final List<RowView> rows;
  final List<offline.CrdtDataForeignKey> foreignKeys;
  final List<offline.CrdtDataDeleted> tombstones;

  /// Loads the visible rows and the full set (visible + CRDT-hidden, via
  /// `includeHidden`) for every synced table through the one CRDT session, and
  /// classifies each row's visibility.
  static Future<DemoSnapshot> load(
    RelationshipCatalog catalog,
    offline.CrdtDatabaseSession crdt,
  ) async {
    final rows = <RowView>[];
    for (final table in catalog.tables) {
      final ops = demoTableOps[table];
      if (ops == null) continue;
      final visible = await ops.findAll(crdt);
      final full = await ops.findAll(crdt, includeHidden: true);
      final visibleIds = {
        for (final row in visible)
          if (row['id'] != null) '${row['id']}',
      };
      for (final row in full) {
        final rawId = row['id'];
        if (rawId == null) continue;
        rows.add(
          RowView(
            table: table,
            id: protocol.UuidValue.withValidation('$rawId'),
            json: row,
            visible: visibleIds.contains('$rawId'),
          ),
        );
      }
    }

    return DemoSnapshot(
      catalog: catalog,
      rows: rows,
      foreignKeys: await offline.CrdtDataForeignKey.db.find(crdt),
      tombstones: await offline.CrdtDataDeleted.db.find(crdt),
    );
  }

  /// Builds a snapshot from the server's merged truth. [serverRows] is the flat
  /// `List<dynamic>` returned by `fetchScopeSnapshot`: each element is a typed
  /// domain model, deserialized by Serverpod from its `__className__` tag, so
  /// the table name and JSON come straight off the model. Rows whose id is in
  /// [hiddenIds] are flagged hidden; there is no local CRDT metadata to show.
  factory DemoSnapshot.fromServer(
    RelationshipCatalog catalog,
    List<dynamic> serverRows, {
    Set<String> hiddenIds = const {},
  }) {
    final rows = <RowView>[];
    for (final row in serverRows) {
      final model = row as db.TableRow<protocol.UuidValue?>;
      final id = model.id;
      if (id == null) continue;
      rows.add(
        RowView(
          table: model.table.tableName,
          id: id,
          json: model.toJson() as Map<String, dynamic>,
          visible: !hiddenIds.contains(id.uuid),
        ),
      );
    }

    return DemoSnapshot(
      catalog: catalog,
      rows: rows,
      foreignKeys: const [],
      tombstones: const [],
    );
  }

  int get visibleRowCount => rows.where((r) => r.visible).length;
  int get hiddenRowCount => rows.where((r) => !r.visible).length;

  /// Builds the FK forest for this snapshot. When [showHidden] is false only
  /// visible rows are shown; otherwise hidden rows are included and flagged.
  DemoProjection project({required bool showHidden}) {
    final included = [
      for (final row in rows)
        if (row.visible || showHidden) row,
    ];
    final byId = {for (final row in included) row.id.uuid: row};

    // Resolve each row's primary parent: the first of its foreign keys that is
    // set and resolves to a row present in this view.
    final childrenOf = <String, List<RowView>>{};
    final edgeOf = <String, Relationship>{};
    final danglingIds = <String>{};
    final roots = <RowView>[];

    for (final row in included) {
      Relationship? parentEdge;
      String? parentId;
      var hasUnresolvedRef = false;
      for (final relation in catalog.parentRelationshipsOf(row.table)) {
        final value = row.json[relation.fkColumn];
        if (value == null) continue;
        final candidate = byId[_normalizeId(value)];
        if (candidate != null && candidate.id.uuid != row.id.uuid) {
          parentEdge = relation;
          parentId = candidate.id.uuid;
          break;
        }
        hasUnresolvedRef = true;
      }

      if (parentEdge != null && parentId != null) {
        childrenOf.putIfAbsent(parentId, () => []).add(row);
        edgeOf[row.id.uuid] = parentEdge;
      } else {
        if (hasUnresolvedRef) danglingIds.add(row.id.uuid);
        roots.add(row);
      }
    }

    TreeNode<DemoTreeItem> nodeFor(RowView row, Set<String> seen) {
      seen.add(row.id.uuid);
      final children = [
        for (final child in childrenOf[row.id.uuid] ?? const <RowView>[])
          if (!seen.contains(child.id.uuid)) nodeFor(child, seen),
      ];
      final relation = edgeOf[row.id.uuid];
      final detail = relation != null
          ? '${relationLabel(relation.fkColumn)} · ${shortId(row.id)}'
          : '${tableLabel(row.table)} · ${shortId(row.id)}';
      return TreeItem(
        data: DemoTreeItem.row(
          catalog.displayLabel(row.table, row.json),
          detail,
          DemoRowRef(tableName: row.table, id: row.id),
          hidden: !row.visible,
          relation: relation,
          dangling: danglingIds.contains(row.id.uuid),
        ),
        expanded: true,
        children: children,
      );
    }

    final seen = <String>{};
    final forest = [for (final root in roots) nodeFor(root, seen)];

    final nodes = <TreeNode<DemoTreeItem>>[
      ...forest,
      if (foreignKeys.isNotEmpty || tombstones.isNotEmpty)
        TreeItem(
          data: DemoTreeItem.group(
            'CRDT metadata',
            '${foreignKeys.length} FK projections · ${tombstones.length} tombstones',
          ),
          expanded: false,
          children: [
            for (final fk in foreignKeys)
              TreeItem(
                data: DemoTreeItem.metadata(
                  'field ${fk.fieldId}',
                  'attempted ${shortId(fk.attemptedValue)} '
                      'visible ${shortId(fk.visibleValue)} '
                      'reason ${fk.overrideReason?.name ?? 'none'}',
                ),
              ),
            for (final tombstone in tombstones)
              TreeItem(
                data: DemoTreeItem.metadata(
                  'tombstone row ${tombstone.rowId}',
                  'clFlag ${tombstone.clFlag}, reason ${tombstone.reason.name}',
                ),
              ),
          ],
        ),
    ].expandAll();

    return DemoProjection(
      nodes: nodes,
      visibleRowCount: visibleRowCount,
      hiddenRowCount: hiddenRowCount,
    );
  }

  static String _normalizeId(Object? value) {
    final text = '$value';
    return text;
  }
}

/// Friendly name for a foreign-key column, e.g. `inhabitantId` → `inhabitant`.
String relationLabel(String fkColumn) {
  if (fkColumn.endsWith('Id')) {
    return fkColumn.substring(0, fkColumn.length - 2);
  }
  return fkColumn;
}

/// Friendly name for a table, e.g. `fk_chain_root` → `fk chain root`.
String tableLabel(String table) => table.replaceAll('_', ' ');

/// A small icon per table family, falling back to a generic row icon.
material.IconData iconForTable(String table, {required bool hidden}) {
  if (hidden) return material.Icons.visibility_off;
  return switch (table) {
    'person' => material.Icons.person,
    'address' => material.Icons.home,
    'city' => material.Icons.location_city,
    'town' => material.Icons.map,
    'organization' => material.Icons.apartment,
    'company' => material.Icons.business,
    'restrict_child' || 'required_set_null_child' => material.Icons.link,
    'unique' || 'unique_uuid' || 'unique_composite' => material.Icons.key,
    'types' => material.Icons.data_object,
    _ when table.startsWith('fk_chain') => material.Icons.account_tree,
    _ => material.Icons.table_rows,
  };
}
