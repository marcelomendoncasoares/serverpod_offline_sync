import 'package:flutter/material.dart' as material;
import 'package:serverpod_database/serverpod_database.dart'
    show ClientDatabaseSession;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'models.dart';

/// A domain row together with its computed visibility for one replica.
class RowEntry<T> {
  RowEntry({required this.id, required this.row, required this.visible});

  final protocol.UuidValue id;
  final T row;
  final bool visible;
}

/// A row from one of the FK-chain tables, tagged with its table name.
class ChainEntry {
  ChainEntry({
    required this.tableName,
    required this.id,
    required this.name,
    required this.visible,
  });

  final String tableName;
  final protocol.UuidValue id;
  final String name;
  final bool visible;
}

/// The data shown in one tree node.
class DemoTreeItem {
  DemoTreeItem._({
    required this.title,
    required this.icon,
    this.detail,
    this.ref,
    this.hidden = false,
    this.hiddenReason,
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
    String? hiddenReason,
  }) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      ref: ref,
      icon: hidden ? material.Icons.visibility_off : material.Icons.table_rows,
      hidden: hidden,
      hiddenReason: hiddenReason,
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
  final bool hidden;
  final String? hiddenReason;
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
    required this.people,
    required this.addresses,
    required this.cities,
    required this.towns,
    required this.uniques,
    required this.uniqueUuids,
    required this.restrictChildren,
    required this.types,
    required this.chain,
    required this.foreignKeys,
    required this.tombstones,
  });

  final List<RowEntry<protocol.Person>> people;
  final List<RowEntry<protocol.Address>> addresses;
  final List<RowEntry<protocol.City>> cities;
  final List<RowEntry<protocol.Town>> towns;
  final List<RowEntry<protocol.Unique>> uniques;
  final List<RowEntry<protocol.UniqueUuid>> uniqueUuids;
  final List<RowEntry<protocol.RestrictChild>> restrictChildren;
  final List<RowEntry<protocol.Types>> types;
  final List<ChainEntry> chain;
  final List<offline.CrdtDataForeignKey> foreignKeys;
  final List<offline.CrdtDataDeleted> tombstones;

  /// Loads visible rows (CRDT session) and the full physical set (raw session)
  /// and classifies every row's visibility.
  static Future<DemoSnapshot> load(
    offline.CrdtDatabaseSession crdt,
    ClientDatabaseSession raw,
  ) async {
    final chain = <ChainEntry>[
      ..._classifyChain(
        'fk_chain_root',
        await protocol.FkChainRoot.db.find(crdt),
        await protocol.FkChainRoot.db.find(raw),
        (r) => r.id,
        (r) => r.name,
      ),
      ..._classifyChain(
        'fk_chain_cascade_middle',
        await protocol.FkChainCascadeMiddle.db.find(crdt),
        await protocol.FkChainCascadeMiddle.db.find(raw),
        (r) => r.id,
        (r) => r.name,
      ),
      ..._classifyChain(
        'fk_chain_restrict_blocker',
        await protocol.FkChainRestrictBlocker.db.find(crdt),
        await protocol.FkChainRestrictBlocker.db.find(raw),
        (r) => r.id,
        (r) => r.name,
      ),
      ..._classifyChain(
        'fk_chain_middle_set_null_child',
        await protocol.FkChainMiddleSetNullChild.db.find(crdt),
        await protocol.FkChainMiddleSetNullChild.db.find(raw),
        (r) => r.id,
        (r) => r.name,
      ),
      ..._classifyChain(
        'fk_chain_middle_cascade_child',
        await protocol.FkChainMiddleCascadeChild.db.find(crdt),
        await protocol.FkChainMiddleCascadeChild.db.find(raw),
        (r) => r.id,
        (r) => r.name,
      ),
    ];

    return DemoSnapshot(
      people: _classify(
        await protocol.Person.db.find(crdt),
        await protocol.Person.db.find(raw),
        (r) => r.id,
      ),
      addresses: _classify(
        await protocol.Address.db.find(crdt),
        await protocol.Address.db.find(raw),
        (r) => r.id,
      ),
      cities: _classify(
        await protocol.City.db.find(crdt),
        await protocol.City.db.find(raw),
        (r) => r.id,
      ),
      towns: _classify(
        await protocol.Town.db.find(crdt),
        await protocol.Town.db.find(raw),
        (r) => r.id,
      ),
      uniques: _classify(
        await protocol.Unique.db.find(crdt),
        await protocol.Unique.db.find(raw),
        (r) => r.id,
      ),
      uniqueUuids: _classify(
        await protocol.UniqueUuid.db.find(crdt),
        await protocol.UniqueUuid.db.find(raw),
        (r) => r.id,
      ),
      restrictChildren: _classify(
        await protocol.RestrictChild.db.find(crdt),
        await protocol.RestrictChild.db.find(raw),
        (r) => r.id,
      ),
      types: _classify(
        await protocol.Types.db.find(crdt),
        await protocol.Types.db.find(raw),
        (r) => r.id,
      ),
      chain: chain,
      foreignKeys: await offline.CrdtDataForeignKey.db.find(crdt),
      tombstones: await offline.CrdtDataDeleted.db.find(crdt),
    );
  }

  int get visibleRowCount => _countVisible(true);
  int get hiddenRowCount => _countVisible(false);

  int _countVisible(bool visible) {
    var total = 0;
    void add(Iterable<bool> visibilities) {
      total += visibilities.where((v) => v == visible).length;
    }

    add(people.map((e) => e.visible));
    add(addresses.map((e) => e.visible));
    add(cities.map((e) => e.visible));
    add(towns.map((e) => e.visible));
    add(uniques.map((e) => e.visible));
    add(uniqueUuids.map((e) => e.visible));
    add(restrictChildren.map((e) => e.visible));
    add(types.map((e) => e.visible));
    add(chain.map((e) => e.visible));
    return total;
  }

  /// Builds the tree for this snapshot. When [showHidden] is false only visible
  /// rows are shown (the "user view"); otherwise hidden rows are included and
  /// flagged.
  DemoProjection project({required bool showHidden}) {
    bool include(bool visible) => visible || showHidden;

    final domainChildren = <TreeNode<DemoTreeItem>>[
      for (final city in cities)
        if (include(city.visible))
          _rowNode(
            'city',
            city.id,
            city.row.name,
            'id ${shortId(city.id)}',
            visible: city.visible,
            children: [
              for (final town in towns)
                if (town.row.cityId == city.id && include(town.visible))
                  _townNode(town),
            ],
          ),
      for (final person in people)
        if (include(person.visible)) _personNode(person, include),
      for (final town in towns)
        if (town.row.cityId == null && include(town.visible)) _townNode(town),
    ];

    final uniqueChildren = <TreeNode<DemoTreeItem>>[
      for (final entry in uniques)
        if (include(entry.visible))
          _rowNode(
            'unique',
            entry.id,
            entry.row.name,
            _uniqueDetail(entry.row.name),
            visible: entry.visible,
          ),
      for (final entry in uniqueUuids)
        if (include(entry.visible))
          _rowNode(
            'unique_uuid',
            entry.id,
            shortId(entry.row.value),
            'value ${entry.row.value.uuid}',
            visible: entry.visible,
          ),
    ];

    final fkChildren = <TreeNode<DemoTreeItem>>[
      for (final entry in restrictChildren)
        if (include(entry.visible))
          _rowNode(
            'restrict_child',
            entry.id,
            entry.row.name,
            'parent ${shortId(entry.row.parentId)}',
            visible: entry.visible,
          ),
      for (final entry in chain)
        if (include(entry.visible))
          _rowNode(
            entry.tableName,
            entry.id,
            entry.name,
            'id ${shortId(entry.id)}',
            visible: entry.visible,
          ),
    ];

    final typeChildren = <TreeNode<DemoTreeItem>>[
      for (final entry in types)
        if (include(entry.visible))
          _rowNode(
            'types',
            entry.id,
            entry.row.aText,
            '${entry.row.anEnum?.name ?? 'no enum'}, '
                'int64 ${entry.row.anInt64}, '
                'uuid ${shortId(entry.row.optionalUuid)}',
            visible: entry.visible,
          ),
    ];

    final nodes = <TreeNode<DemoTreeItem>>[
      _groupNode('Domain graph', _groupSummary(domainChildren), domainChildren),
      _groupNode(
        'Unique conflicts',
        _groupSummary(uniqueChildren),
        uniqueChildren,
      ),
      _groupNode('Foreign keys', _groupSummary(fkChildren), fkChildren),
      _groupNode('Typed values', _groupSummary(typeChildren), typeChildren),
      _groupNode(
        'CRDT metadata',
        '${foreignKeys.length} FK projections · ${tombstones.length} tombstones',
        [
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

  TreeNode<DemoTreeItem> _personNode(
    RowEntry<protocol.Person> person,
    bool Function(bool) include,
  ) {
    return _rowNode(
      'person',
      person.id,
      '${person.row.name} ${person.row.surname ?? ''}'.trim(),
      'org ${shortId(person.row.organizationId)} '
          'company ${shortId(person.row.oldCompanyId)}',
      visible: person.visible,
      children: [
        for (final address in addresses)
          if (address.row.inhabitantId == person.id && include(address.visible))
            _rowNode(
              'address',
              address.id,
              address.row.street,
              'inhabitant ${shortId(address.row.inhabitantId)}',
              visible: address.visible,
            ),
      ],
    );
  }

  TreeNode<DemoTreeItem> _townNode(RowEntry<protocol.Town> town) {
    return _rowNode(
      'town',
      town.id,
      town.row.name,
      'city ${shortId(town.row.cityId)} mayor ${shortId(town.row.mayorId)}',
      visible: town.visible,
    );
  }

  static String _uniqueDetail(String name) {
    if (name.startsWith('__conflict__')) {
      return 'conflict loser · materialized $name';
    }
    return 'name $name';
  }

  static String _groupSummary(List<TreeNode<DemoTreeItem>> children) {
    final hidden = children
        .whereType<TreeItem<DemoTreeItem>>()
        .where((c) => c.data.hidden)
        .length;
    final visible = children.length - hidden;
    if (hidden == 0) return '$visible rows';
    return '$visible visible · $hidden hidden';
  }

  static TreeNode<DemoTreeItem> _groupNode(
    String title,
    String detail,
    List<TreeNode<DemoTreeItem>> children,
  ) {
    return TreeItem(
      data: DemoTreeItem.group(title, detail),
      expanded: true,
      children: children,
    );
  }

  static TreeNode<DemoTreeItem> _rowNode(
    String tableName,
    protocol.UuidValue id,
    String title,
    String detail, {
    required bool visible,
    List<TreeNode<DemoTreeItem>> children = const [],
  }) {
    return TreeItem(
      data: DemoTreeItem.row(
        title,
        detail,
        DemoRowRef(tableName: tableName, id: id),
        hidden: !visible,
        hiddenReason: visible ? null : 'hidden',
      ),
      expanded: true,
      children: children,
    );
  }

  static List<RowEntry<T>> _classify<T>(
    List<T> visible,
    List<T> full,
    protocol.UuidValue? Function(T) idOf,
  ) {
    final visibleIds = <String>{
      for (final row in visible)
        if (idOf(row) != null) idOf(row)!.uuid,
    };
    final entries = <RowEntry<T>>[];
    for (final row in full) {
      final id = idOf(row);
      if (id == null) continue;
      entries.add(
        RowEntry<T>(id: id, row: row, visible: visibleIds.contains(id.uuid)),
      );
    }
    return entries;
  }

  static List<ChainEntry> _classifyChain<T>(
    String tableName,
    List<T> visible,
    List<T> full,
    protocol.UuidValue? Function(T) idOf,
    String Function(T) nameOf,
  ) {
    final classified = _classify(visible, full, idOf);
    return [
      for (final entry in classified)
        ChainEntry(
          tableName: tableName,
          id: entry.id,
          name: nameOf(entry.row),
          visible: entry.visible,
        ),
    ];
  }
}
