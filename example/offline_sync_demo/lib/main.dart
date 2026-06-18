import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:serverpod_database/serverpod_database.dart' hide Column;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:uuid/uuid.dart' as uuid;

const _defaultServerUrl = String.fromEnvironment(
  'SERVERPOD_URL',
  defaultValue: 'http://localhost:8080/',
);

final _syncTables = [
  protocol.Address.t,
  protocol.City.t,
  protocol.Company.t,
  protocol.FkChainCascadeMiddle.t,
  protocol.FkChainMiddleCascadeChild.t,
  protocol.FkChainMiddleSetNullChild.t,
  protocol.FkChainRestrictBlocker.t,
  protocol.FkChainRoot.t,
  protocol.FkChainSetNullCascadeChild.t,
  protocol.FkChainSetNullMiddle.t,
  protocol.FkChainSetNullRestrictChild.t,
  protocol.FkChainSetNullSetNullChild.t,
  protocol.Organization.t,
  protocol.Person.t,
  protocol.RequiredSetNullChild.t,
  protocol.RestrictChild.t,
  protocol.Town.t,
  protocol.Types.t,
  protocol.Unique.t,
  protocol.UniqueComposite.t,
  protocol.UniqueSetNullChild.t,
  protocol.UniqueUuid.t,
];

void main() {
  runApp(const ShadcnApp(title: 'Offline Sync Demo', home: DemoApp()));
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final DemoController controller;

  @override
  void initState() {
    super.initState();
    controller = DemoController(serverUrl: _defaultServerUrl);
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Serverpod Offline Sync Demo'),
          subtitle: Text(_defaultServerUrl),
        ),
        const Divider(),
      ],
      child: material.Material(
        color: material.Colors.transparent,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => DemoDashboard(controller: controller),
        ),
      ),
    );
  }
}

class DemoDashboard extends StatelessWidget {
  const DemoDashboard({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DemoToolbar(controller: controller),
          const Gap(12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 330,
                  child: DemoPresetPanel(controller: controller),
                ),
                const Gap(12),
                Expanded(child: DemoTreePanel(controller: controller)),
              ],
            ),
          ),
          const Gap(12),
          DemoStatusBar(controller: controller),
        ],
      ),
    );
  }
}

class DemoToolbar extends StatefulWidget {
  const DemoToolbar({super.key, required this.controller});

  final DemoController controller;

  @override
  State<DemoToolbar> createState() => _DemoToolbarState();
}

class _DemoToolbarState extends State<DemoToolbar> {
  final usernameController = material.TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final users = controller.users;
    final selected = controller.selectedUser;

    return OutlinedContainer(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: material.DropdownButtonFormField<DemoUser>(
              initialValue: selected,
              decoration: const material.InputDecoration(
                labelText: 'User',
                isDense: true,
                border: material.OutlineInputBorder(),
              ),
              items: [
                for (final user in users)
                  material.DropdownMenuItem(
                    value: user,
                    child: Text(user.username),
                  ),
              ],
              onChanged: controller.busy
                  ? null
                  : (user) {
                      if (user != null) {
                        unawaited(controller.switchUser(user));
                      }
                    },
            ),
          ),
          SizedBox(
            width: 180,
            child: material.TextField(
              controller: usernameController,
              decoration: const material.InputDecoration(
                labelText: 'New user',
                isDense: true,
                border: material.OutlineInputBorder(),
              ),
              onSubmitted: (_) => _createUser(),
            ),
          ),
          PrimaryButton(
            onPressed: controller.busy ? null : _createUser,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                material.Icon(material.Icons.person_add, size: 16),
                Gap(6),
                Text('Create'),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            child: material.SegmentedButton<DemoDeviceSlot>(
              segments: const [
                material.ButtonSegment(
                  value: DemoDeviceSlot.a,
                  icon: material.Icon(material.Icons.computer, size: 16),
                  label: Text('Device A'),
                ),
                material.ButtonSegment(
                  value: DemoDeviceSlot.b,
                  icon: material.Icon(material.Icons.laptop, size: 16),
                  label: Text('Device B'),
                ),
              ],
              selected: {controller.activeDeviceSlot},
              onSelectionChanged: controller.busy
                  ? null
                  : (selection) =>
                        unawaited(controller.switchDevice(selection.single)),
            ),
          ),
          Checkbox(
            state: controller.online
                ? CheckboxState.checked
                : CheckboxState.unchecked,
            onChanged: controller.busy
                ? null
                : (value) => unawaited(
                    controller.setOnline(value == CheckboxState.checked),
                  ),
            trailing: const Text('Connectivity'),
          ),
          Checkbox(
            state: controller.streaming
                ? CheckboxState.checked
                : CheckboxState.unchecked,
            onChanged: (!controller.online || controller.busy)
                ? null
                : (value) => unawaited(
                    controller.setStreaming(value == CheckboxState.checked),
                  ),
            trailing: const Text('Streaming sync'),
          ),
          PrimaryButton(
            onPressed: controller.canSyncOnce
                ? () => unawaited(controller.syncOnce())
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                material.Icon(material.Icons.sync, size: 16),
                Gap(6),
                Text('Sync once'),
              ],
            ),
          ),
          OutlineButton(
            onPressed: controller.busy
                ? null
                : () => unawaited(controller.refresh()),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                material.Icon(material.Icons.refresh, size: 16),
                Gap(6),
                Text('Refresh'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createUser() {
    final username = usernameController.text;
    usernameController.clear();
    unawaited(widget.controller.createOrSwitchUser(username));
  }
}

class DemoPresetPanel extends StatelessWidget {
  const DemoPresetPanel({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tabs(
            index: controller.presetTab,
            onChanged: controller.setPresetTab,
            children: const [
              TabItem(child: Text('CRUD')),
              TabItem(child: Text('Unique')),
              TabItem(child: Text('FK')),
            ],
          ),
          const Gap(12),
          Expanded(
            child: SingleChildScrollView(
              child: switch (controller.presetTab) {
                0 => _CrudPresets(controller: controller),
                1 => _UniquePresets(controller: controller),
                _ => _ForeignKeyPresets(controller: controller),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CrudPresets extends StatelessWidget {
  const _CrudPresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.account_tree,
          title: 'Seed city/person/address/town',
          detail: 'Creates an ordinary editable graph on the active device.',
          onPressed: () => controller.seedBasicGraph(),
        ),
        _PresetButton(
          icon: material.Icons.data_object,
          title: 'Seed typed row',
          detail:
              'Exercises bool, DateTime, int64, blob, enum, and UUID values.',
          onPressed: () => controller.seedTypedRow(),
        ),
        _PresetButton(
          icon: material.Icons.person_add_alt,
          title: 'Add person',
          detail: 'Creates one simple row in the selected user scope.',
          onPressed: () => controller.addPerson(),
        ),
      ],
    );
  }
}

class _UniquePresets extends StatelessWidget {
  const _UniquePresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.call_split,
          title: 'Concurrent unique insert',
          detail: 'Device A and B insert the same Unique.name before sync.',
          onPressed: () => controller.createConcurrentUniqueInserts(),
        ),
        _PresetButton(
          icon: material.Icons.merge_type,
          title: 'Sync both devices',
          detail: 'Runs A, B, A sync so the conflict rewrite is visible.',
          onPressed: controller.canRunNetworkPreset
              ? () => controller.syncBothDevices()
              : null,
        ),
        _PresetButton(
          icon: material.Icons.key,
          title: 'UUID unique conflict',
          detail: 'Creates two UniqueUuid rows with the same unique UUID.',
          onPressed: () => controller.createUuidUniqueConflict(),
        ),
      ],
    );
  }
}

class _ForeignKeyPresets extends StatelessWidget {
  const _ForeignKeyPresets({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _PresetGroup(
      children: [
        _PresetButton(
          icon: material.Icons.block,
          title: 'Restrict blocks delete',
          detail: 'A deletes a parent while B inserts a restrict child.',
          onPressed: controller.canRunNetworkPreset
              ? () => controller.createRestrictMergeScenario()
              : null,
        ),
        _PresetButton(
          icon: material.Icons.link_off,
          title: 'Set-null projection',
          detail: 'A deletes a parent while B inserts a Town mayor reference.',
          onPressed: controller.canRunNetworkPreset
              ? () => controller.createSetNullProjectionScenario()
              : null,
        ),
        _PresetButton(
          icon: material.Icons.hub,
          title: 'FK chain sketch',
          detail: 'Creates a root, cascade middle, blocker, and grandchildren.',
          onPressed: () => controller.seedForeignKeyChain(),
        ),
      ],
    );
  }
}

class _PresetGroup extends StatelessWidget {
  const _PresetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children).gap(10);
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onPressed,
  });

  final material.IconData icon;
  final String title;
  final String detail;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          material.Icon(icon, size: 18),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const Gap(2),
                Text(detail).small().muted(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DemoTreePanel extends StatelessWidget {
  const DemoTreePanel({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(controller.treeTitle).semiBold(),
              const Spacer(),
              Text(
                '${controller.visibleRowCount} visible rows',
              ).muted().small(),
            ],
          ),
          const Gap(10),
          Expanded(
            child: DemoTreeView(
              nodes: controller.treeNodes,
              onNodesChanged: controller.replaceTreeNodes,
              onEdit: controller.editRow,
              onDelete: controller.deleteRow,
            ),
          ),
        ],
      ),
    );
  }
}

class DemoTreeView extends StatefulWidget {
  const DemoTreeView({
    super.key,
    required this.nodes,
    required this.onNodesChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TreeNode<DemoTreeItem>> nodes;
  final ValueChanged<List<TreeNode<DemoTreeItem>>> onNodesChanged;
  final Future<void> Function(DemoRowRef ref) onEdit;
  final Future<void> Function(DemoRowRef ref) onDelete;

  @override
  State<DemoTreeView> createState() => _DemoTreeViewState();
}

class _DemoTreeViewState extends State<DemoTreeView> {
  late List<TreeNode<DemoTreeItem>> nodes;

  @override
  void initState() {
    super.initState();
    nodes = widget.nodes;
  }

  @override
  void didUpdateWidget(covariant DemoTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nodes, widget.nodes)) {
      nodes = widget.nodes;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('No rows yet.'));
    }

    return TreeView(
      nodes: nodes,
      expandIcon: true,
      branchLine: BranchLine.path,
      builder: (context, node) {
        final item = node.data;
        return TreeItemView(
          leading: material.Icon(item.icon, size: 18),
          trailing: item.ref == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GhostButton(
                      onPressed: () => unawaited(widget.onEdit(item.ref!)),
                      child: const material.Icon(material.Icons.edit, size: 16),
                    ),
                    GhostButton(
                      onPressed: () => unawaited(widget.onDelete(item.ref!)),
                      child: const material.Icon(
                        material.Icons.delete,
                        size: 16,
                      ),
                    ),
                  ],
                ),
          onExpand: TreeView.defaultItemExpandHandler(nodes, node, (value) {
            setState(() => nodes = value);
            widget.onNodesChanged(value);
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title),
              if (item.detail != null) Text(item.detail!).small().muted(),
            ],
          ),
        );
      },
    );
  }
}

class DemoStatusBar extends StatelessWidget {
  const DemoStatusBar({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          material.Icon(
            controller.online ? material.Icons.wifi : material.Icons.wifi_off,
            size: 18,
          ),
          const Gap(8),
          Expanded(child: Text(controller.status)),
          if (controller.busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class DemoController extends ChangeNotifier {
  DemoController({required this.serverUrl});

  final String serverUrl;
  final authKeyProvider = DemoAuthKeyProvider();

  final users = <DemoUser>[];
  final _sessions = <String, DemoDeviceSession>{};
  final _counter = _ScenarioCounter();

  protocol.Client? _client;
  DemoUser? selectedUser;
  DemoDeviceSlot activeDeviceSlot = DemoDeviceSlot.a;
  List<TreeNode<DemoTreeItem>> treeNodes = const [];
  int visibleRowCount = 0;
  int presetTab = 0;
  bool online = true;
  bool streaming = false;
  bool busy = false;
  String status = 'Opening local demo databases...';

  offline.CrdtSyncSession? _streamingSession;

  String get treeTitle {
    final user = selectedUser?.username ?? 'no user';
    return '$user / ${activeDeviceSlot.label}';
  }

  bool get canSyncOnce =>
      online && !streaming && !busy && activeSession != null;

  bool get canRunNetworkPreset => online && !busy && selectedUser != null;

  protocol.Client get client {
    return _client ??= _createClient();
  }

  DemoDeviceSession? get activeSession {
    final user = selectedUser;
    if (user == null) return null;
    return _sessions[_sessionKey(user, activeDeviceSlot)];
  }

  Future<void> initialize() async {
    await _run('Opened local demo databases.', () async {
      final alice = _localUser('alice');
      final bob = _localUser('bob');
      users
        ..add(alice)
        ..add(bob);
      selectedUser = alice;
      authKeyProvider.token = alice.token;
      await _openSessionsFor(alice);
      await refresh(notify: false);
      unawaited(_ensureRemoteAuth(alice));
    });
  }

  Future<void> createOrSwitchUser(String username) async {
    final normalized = _normalizeUsername(username);
    if (normalized.isEmpty) return;

    var user = _findUser(normalized);
    user ??= _localUser(normalized);
    if (!users.contains(user)) users.add(user);

    await switchUser(user);
    if (online) {
      await _ensureRemoteAuth(user);
    }
  }

  Future<void> switchUser(DemoUser user) async {
    await _run('Switched to ${user.username}.', () async {
      await _stopStreaming();
      selectedUser = user;
      authKeyProvider.token = user.token;
      _rebuildClient();
      await _openSessionsFor(user);
      await refresh(notify: false);
    });
  }

  Future<void> switchDevice(DemoDeviceSlot slot) async {
    await _run('Switched to ${slot.label}.', () async {
      await _stopStreaming();
      activeDeviceSlot = slot;
      await refresh(notify: false);
    });
  }

  Future<void> setOnline(bool value) async {
    await _run(
      value ? 'Connectivity enabled.' : 'Connectivity disabled.',
      () async {
        if (!value) {
          await _stopStreaming();
        }
        online = value;
        _rebuildClient();
        if (online && selectedUser != null) {
          await _ensureRemoteAuth(selectedUser!);
        }
      },
    );
  }

  Future<void> setStreaming(bool value) async {
    if (value) {
      await _run('Streaming sync started.', () async {
        final session = activeSession;
        if (session == null || !online) return;
        streaming = true;
        _streamingSession = client.crdt.syncContinuously(
          session.crdtSession,
          onMergeSuccess: (_) => refresh(),
        );
        unawaited(
          _streamingSession!.done.catchError((Object error) {
            status = 'Streaming sync stopped: $error';
            streaming = false;
            notifyListeners();
          }),
        );
      });
      return;
    }

    await _run('Streaming sync stopped.', _stopStreaming);
  }

  Future<void> syncOnce() async {
    final session = activeSession;
    if (session == null || !canSyncOnce) return;

    await _run('One-time sync completed.', () async {
      await client.crdt.syncOnce(session.crdtSession);
      await refresh(notify: false);
    });
  }

  Future<void> syncBothDevices() async {
    final user = selectedUser;
    if (user == null || !online) return;
    await _run('Both devices converged through A, B, A sync.', () async {
      final a = await _openSession(user, DemoDeviceSlot.a);
      final b = await _openSession(user, DemoDeviceSlot.b);
      await client.crdt.syncOnce(a.crdtSession);
      await client.crdt.syncOnce(b.crdtSession);
      await client.crdt.syncOnce(a.crdtSession);
      await refresh(notify: false);
    });
  }

  Future<void> refresh({bool notify = true}) async {
    final session = activeSession;
    if (session == null) return;

    final snapshot = await DemoSnapshot.load(session.crdtSession);
    treeNodes = snapshot.toTree();
    visibleRowCount = snapshot.visibleRowCount;
    if (notify) notifyListeners();
  }

  void replaceTreeNodes(List<TreeNode<DemoTreeItem>> nodes) {
    treeNodes = nodes;
  }

  void setPresetTab(int value) {
    presetTab = value;
    notifyListeners();
  }

  Future<void> seedBasicGraph() async {
    final session = activeSession;
    if (session == null) return;
    final suffix = _counter.next('basic');

    await _run('Seeded an editable city/person/address/town graph.', () async {
      final city = await protocol.City.db.insertRow(
        session.crdtSession,
        protocol.City(id: _newId(), name: 'City $suffix'),
      );
      final person = await protocol.Person.db.insertRow(
        session.crdtSession,
        protocol.Person(id: _newId(), name: 'Person $suffix', surname: 'Local'),
      );
      await protocol.Address.db.insertRow(
        session.crdtSession,
        protocol.Address(
          id: _newId(),
          street: 'Main Street $suffix',
          inhabitantId: person.id,
        ),
      );
      await protocol.Town.db.insertRow(
        session.crdtSession,
        protocol.Town(id: _newId(), name: 'Town $suffix', cityId: city.id),
      );
      await refresh(notify: false);
    });
  }

  Future<void> seedTypedRow() async {
    final session = activeSession;
    if (session == null) return;
    final suffix = _counter.next('types');

    await _run(
      'Seeded a typed row with scalar, enum, UUID, and blob values.',
      () async {
        await protocol.Types.db.insertRow(
          session.crdtSession,
          protocol.Types(
            id: _newId(),
            aBool: suffix.isOdd,
            aDateTime: DateTime.utc(2026, 6, ((suffix - 1) % 28) + 1, 12),
            aText: 'typed-$suffix',
            anInt: suffix,
            anInt64: BigInt.parse('9007199254740993') + BigInt.from(suffix),
            aReal: suffix + 0.25,
            aBlob: ByteData.sublistView(Uint8List.fromList([suffix, 2, 3])),
            anEnum: protocol
                .TypesEnum
                .values[suffix % protocol.TypesEnum.values.length],
            optionalText: 'optional-$suffix',
            optionalUuid: _newId(),
          ),
        );
        await refresh(notify: false);
      },
    );
  }

  Future<void> addPerson() async {
    final session = activeSession;
    if (session == null) return;
    final suffix = _counter.next('person');

    await _run('Added Person $suffix on ${activeDeviceSlot.label}.', () async {
      await protocol.Person.db.insertRow(
        session.crdtSession,
        protocol.Person(id: _newId(), name: 'Person $suffix'),
      );
      await refresh(notify: false);
    });
  }

  Future<void> createConcurrentUniqueInserts() async {
    final user = selectedUser;
    if (user == null) return;
    final suffix = _counter.next('unique');
    final name = 'shared-name-$suffix';

    await _run('Created matching Unique.name rows on both devices.', () async {
      final a = await _openSession(user, DemoDeviceSlot.a);
      final b = await _openSession(user, DemoDeviceSlot.b);
      await protocol.Unique.db.insertRow(
        a.crdtSession,
        protocol.Unique(id: _newId(), name: name),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await protocol.Unique.db.insertRow(
        b.crdtSession,
        protocol.Unique(id: _newId(), name: name),
      );
      await refresh(notify: false);
    });
  }

  Future<void> createUuidUniqueConflict() async {
    final user = selectedUser;
    if (user == null) return;
    final sharedValue = _newId();

    await _run(
      'Created matching UniqueUuid.value rows on both devices.',
      () async {
        final a = await _openSession(user, DemoDeviceSlot.a);
        final b = await _openSession(user, DemoDeviceSlot.b);
        await protocol.UniqueUuid.db.insertRow(
          a.crdtSession,
          protocol.UniqueUuid(id: _newId(), value: sharedValue),
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await protocol.UniqueUuid.db.insertRow(
          b.crdtSession,
          protocol.UniqueUuid(id: _newId(), value: sharedValue),
        );
        await refresh(notify: false);
      },
    );
  }

  Future<void> createRestrictMergeScenario() async {
    final user = selectedUser;
    if (user == null) return;
    final suffix = _counter.next('restrict');

    await _run(
      'Created restrict merge scenario and synchronized it.',
      () async {
        final a = await _openSession(user, DemoDeviceSlot.a);
        final b = await _openSession(user, DemoDeviceSlot.b);

        final parent = await protocol.Person.db.insertRow(
          a.crdtSession,
          protocol.Person(id: _newId(), name: 'Restricted parent $suffix'),
        );
        await client.crdt.syncOnce(a.crdtSession);
        await client.crdt.syncOnce(b.crdtSession);

        await protocol.Person.db.deleteRow(a.crdtSession, parent);
        await protocol.RestrictChild.db.insertRow(
          b.crdtSession,
          protocol.RestrictChild(
            id: _newId(),
            name: 'Blocking child $suffix',
            parentId: parent.id,
          ),
        );

        await client.crdt.syncOnce(a.crdtSession);
        await client.crdt.syncOnce(b.crdtSession);
        await client.crdt.syncOnce(a.crdtSession);
        await refresh(notify: false);
      },
    );
  }

  Future<void> createSetNullProjectionScenario() async {
    final user = selectedUser;
    if (user == null) return;
    final suffix = _counter.next('setnull');

    await _run(
      'Created set-null merge projection scenario and synchronized it.',
      () async {
        final a = await _openSession(user, DemoDeviceSlot.a);
        final b = await _openSession(user, DemoDeviceSlot.b);

        final parent = await protocol.Person.db.insertRow(
          a.crdtSession,
          protocol.Person(id: _newId(), name: 'Attempted mayor $suffix'),
        );
        await client.crdt.syncOnce(a.crdtSession);
        await client.crdt.syncOnce(b.crdtSession);

        await protocol.Person.db.deleteRow(a.crdtSession, parent);
        await protocol.Town.db.insertRow(
          b.crdtSession,
          protocol.Town(
            id: _newId(),
            name: 'Projected town $suffix',
            mayorId: parent.id,
          ),
        );

        await client.crdt.syncOnce(a.crdtSession);
        await client.crdt.syncOnce(b.crdtSession);
        await client.crdt.syncOnce(a.crdtSession);
        await refresh(notify: false);
      },
    );
  }

  Future<void> seedForeignKeyChain() async {
    final session = activeSession;
    if (session == null) return;
    final suffix = _counter.next('chain');

    await _run('Seeded a mixed FK chain graph.', () async {
      final root = await protocol.FkChainRoot.db.insertRow(
        session.crdtSession,
        protocol.FkChainRoot(id: _newId(), name: 'Root $suffix'),
      );
      final middle = await protocol.FkChainCascadeMiddle.db.insertRow(
        session.crdtSession,
        protocol.FkChainCascadeMiddle(
          id: _newId(),
          name: 'Cascade middle $suffix',
          rootId: root.id,
        ),
      );
      final blocker = await protocol.FkChainRestrictBlocker.db.insertRow(
        session.crdtSession,
        protocol.FkChainRestrictBlocker(
          id: _newId(),
          name: 'Restrict blocker $suffix',
          cascadeMiddleId: middle.id,
        ),
      );
      await protocol.FkChainMiddleSetNullChild.db.insertRow(
        session.crdtSession,
        protocol.FkChainMiddleSetNullChild(
          id: _newId(),
          name: 'Set-null child $suffix',
          restrictBlockerId: blocker.id,
        ),
      );
      await protocol.FkChainMiddleCascadeChild.db.insertRow(
        session.crdtSession,
        protocol.FkChainMiddleCascadeChild(
          id: _newId(),
          name: 'Cascade child $suffix',
          restrictBlockerId: blocker.id,
        ),
      );
      await refresh(notify: false);
    });
  }

  Future<void> editRow(DemoRowRef ref) async {
    final session = activeSession;
    if (session == null) return;

    await _run('Updated ${ref.tableName}.', () async {
      switch (ref.tableName) {
        case 'person':
          final row = await protocol.Person.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Person.db.updateRow(
              session.crdtSession,
              row.copyWith(name: '${row.name}*'),
            );
          }
        case 'unique':
          final row = await protocol.Unique.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Unique.db.updateRow(
              session.crdtSession,
              row.copyWith(name: '${row.name}-edit'),
            );
          }
        case 'town':
          final row = await protocol.Town.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Town.db.updateRow(
              session.crdtSession,
              row.copyWith(name: '${row.name}*'),
            );
          }
        case 'restrict_child':
          final row = await protocol.RestrictChild.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.RestrictChild.db.updateRow(
              session.crdtSession,
              row.copyWith(name: '${row.name}*'),
            );
          }
        default:
          status = 'No quick edit is wired for ${ref.tableName}.';
      }
      await refresh(notify: false);
    });
  }

  Future<void> deleteRow(DemoRowRef ref) async {
    final session = activeSession;
    if (session == null) return;

    await _run('Deleted ${ref.tableName}.', () async {
      switch (ref.tableName) {
        case 'person':
          final row = await protocol.Person.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Person.db.deleteRow(session.crdtSession, row);
          }
        case 'unique':
          final row = await protocol.Unique.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Unique.db.deleteRow(session.crdtSession, row);
          }
        case 'unique_uuid':
          final row = await protocol.UniqueUuid.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.UniqueUuid.db.deleteRow(session.crdtSession, row);
          }
        case 'town':
          final row = await protocol.Town.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.Town.db.deleteRow(session.crdtSession, row);
          }
        case 'restrict_child':
          final row = await protocol.RestrictChild.db.findById(
            session.crdtSession,
            ref.id,
          );
          if (row != null) {
            await protocol.RestrictChild.db.deleteRow(session.crdtSession, row);
          }
        default:
          status = 'No quick delete is wired for ${ref.tableName}.';
      }
      await refresh(notify: false);
    });
  }

  Future<DemoDeviceSession> _openSession(
    DemoUser user,
    DemoDeviceSlot slot,
  ) async {
    final key = _sessionKey(user, slot);
    final existing = _sessions[key];
    if (existing != null) return existing;

    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'serverpod_offline_sync_demo'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final rawSession = await client.createSession(
      p.join(dbDir.path, '${user.username}-${slot.name}.db'),
      isDebugMode: kDebugMode,
    );
    final crdtSession = offline.CrdtDatabaseSession.wraps(
      rawSession,
      syncTables: _syncTables,
      persistentUserId: user.authUserId,
    );
    await crdtSession.db.initialize();
    final session = DemoDeviceSession(
      user: user,
      slot: slot,
      rawSession: rawSession,
      crdtSession: crdtSession,
    );
    _sessions[key] = session;
    return session;
  }

  Future<void> _openSessionsFor(DemoUser user) async {
    await _openSession(user, DemoDeviceSlot.a);
    await _openSession(user, DemoDeviceSlot.b);
  }

  Future<void> _ensureRemoteAuth(DemoUser user) async {
    if (!online) return;
    try {
      final token = await client.demoAuth.loginOrCreateUser(user.username);
      user.token = token;
      user.authUserId = _authUserIdFromToken(token);
      if (identical(selectedUser, user)) {
        authKeyProvider.token = token;
      }
      status = 'Authenticated ${user.username} on the demo server.';
      notifyListeners();
    } catch (error) {
      status = 'Using local ${user.username}; server auth unavailable: $error';
      notifyListeners();
    }
  }

  Future<void> _stopStreaming() async {
    final session = _streamingSession;
    _streamingSession = null;
    streaming = false;
    await session?.cancel();
  }

  void _rebuildClient() {
    _client = _createClient();
  }

  protocol.Client _createClient() {
    return protocol.Client(
      serverUrl,
      httpClientOverride: online ? null : OfflineHttpClient(),
    )..authKeyProvider = authKeyProvider;
  }

  DemoUser _localUser(String username) {
    final normalized = _normalizeUsername(username);
    final authUserId = _demoAuthUserIdForUsername(normalized);
    return DemoUser(
      username: normalized,
      authUserId: authUserId,
      token: _demoTokenForAuthUserId(authUserId),
    );
  }

  DemoUser? _findUser(String username) {
    for (final user in users) {
      if (user.username == username) return user;
    }
    return null;
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
      status = success;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print(stackTrace);
      }
      status = 'Failed: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _sessionKey(DemoUser user, DemoDeviceSlot slot) {
    return '${user.authUserId.uuid}:${slot.name}';
  }

  @override
  void dispose() {
    unawaited(_stopStreaming());
    for (final session in _sessions.values) {
      unawaited(session.rawSession.close());
    }
    super.dispose();
  }
}

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
    required this.chainRows,
    required this.foreignKeys,
    required this.tombstones,
  });

  final List<protocol.Person> people;
  final List<protocol.Address> addresses;
  final List<protocol.City> cities;
  final List<protocol.Town> towns;
  final List<protocol.Unique> uniques;
  final List<protocol.UniqueUuid> uniqueUuids;
  final List<protocol.RestrictChild> restrictChildren;
  final List<protocol.Types> types;
  final List<NamedRow> chainRows;
  final List<offline.CrdtDataForeignKey> foreignKeys;
  final List<offline.CrdtDataDeleted> tombstones;

  int get visibleRowCount {
    return people.length +
        addresses.length +
        cities.length +
        towns.length +
        uniques.length +
        uniqueUuids.length +
        restrictChildren.length +
        types.length +
        chainRows.length;
  }

  static Future<DemoSnapshot> load(offline.CrdtDatabaseSession session) async {
    final chainRows = <NamedRow>[
      for (final row in await protocol.FkChainRoot.db.find(session))
        NamedRow('fk_chain_root', row.id!, row.name),
      for (final row in await protocol.FkChainCascadeMiddle.db.find(session))
        NamedRow('fk_chain_cascade_middle', row.id!, row.name),
      for (final row in await protocol.FkChainRestrictBlocker.db.find(session))
        NamedRow('fk_chain_restrict_blocker', row.id!, row.name),
      for (final row in await protocol.FkChainMiddleSetNullChild.db.find(
        session,
      ))
        NamedRow('fk_chain_middle_set_null_child', row.id!, row.name),
      for (final row in await protocol.FkChainMiddleCascadeChild.db.find(
        session,
      ))
        NamedRow('fk_chain_middle_cascade_child', row.id!, row.name),
    ];

    return DemoSnapshot(
      people: await protocol.Person.db.find(session),
      addresses: await protocol.Address.db.find(session),
      cities: await protocol.City.db.find(session),
      towns: await protocol.Town.db.find(session),
      uniques: await protocol.Unique.db.find(session),
      uniqueUuids: await protocol.UniqueUuid.db.find(session),
      restrictChildren: await protocol.RestrictChild.db.find(session),
      types: await protocol.Types.db.find(session),
      chainRows: chainRows,
      foreignKeys: await offline.CrdtDataForeignKey.db.find(session),
      tombstones: await offline.CrdtDataDeleted.db.find(session),
    );
  }

  List<TreeNode<DemoTreeItem>> toTree() {
    return [
      _group(
        'Domain graph',
        '${people.length + addresses.length + cities.length + towns.length} rows',
        [
          for (final city in cities)
            _row(
              'city',
              city.id!,
              city.name,
              'id ${_short(city.id)}',
              children: [
                for (final town in towns.where((t) => t.cityId == city.id))
                  _row(
                    'town',
                    town.id!,
                    town.name,
                    'city ${_short(town.cityId)} mayor ${_short(town.mayorId)}',
                  ),
              ],
            ),
          for (final person in people) _personNode(person),
          for (final town in towns.where((t) => t.cityId == null))
            _row('town', town.id!, town.name, 'mayor ${_short(town.mayorId)}'),
        ],
      ),
      _group(
        'Unique conflicts',
        '${uniques.length + uniqueUuids.length} rows',
        [
          for (final row in uniques)
            _row('unique', row.id!, row.name, 'name ${row.name}'),
          for (final row in uniqueUuids)
            _row(
              'unique_uuid',
              row.id!,
              _short(row.value),
              'value ${row.value.uuid}',
            ),
        ],
      ),
      _group(
        'Foreign keys',
        '${restrictChildren.length + chainRows.length} rows',
        [
          for (final row in restrictChildren)
            _row(
              'restrict_child',
              row.id!,
              row.name,
              'parent ${_short(row.parentId)}',
            ),
          for (final row in chainRows)
            _row(row.tableName, row.id, row.name, 'id ${_short(row.id)}'),
        ],
      ),
      _group('Typed values', '${types.length} rows', [
        for (final row in types)
          _row(
            'types',
            row.id!,
            row.aText,
            '${row.anEnum?.name ?? 'no enum'}, int64 ${row.anInt64}, uuid ${_short(row.optionalUuid)}',
          ),
      ]),
      _group(
        'CRDT metadata',
        '${foreignKeys.length} FK projections, ${tombstones.length} tombstones',
        [
          for (final fk in foreignKeys)
            TreeItem(
              data: DemoTreeItem.metadata(
                'field ${fk.fieldId}',
                'attempted ${_short(fk.attemptedValue)} visible ${_short(fk.visibleValue)} reason ${fk.overrideReason?.name ?? 'none'}',
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
  }

  TreeNode<DemoTreeItem> _personNode(protocol.Person person) {
    return _row(
      'person',
      person.id!,
      '${person.name} ${person.surname ?? ''}'.trim(),
      'org ${_short(person.organizationId)} company ${_short(person.oldCompanyId)}',
      children: [
        for (final address in addresses.where(
          (a) => a.inhabitantId == person.id,
        ))
          _row(
            'address',
            address.id!,
            address.street,
            'inhabitant ${_short(address.inhabitantId)}',
          ),
      ],
    );
  }

  TreeNode<DemoTreeItem> _group(
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

  TreeNode<DemoTreeItem> _row(
    String tableName,
    protocol.UuidValue id,
    String title,
    String detail, {
    List<TreeNode<DemoTreeItem>> children = const [],
  }) {
    return TreeItem(
      data: DemoTreeItem.row(
        title,
        detail,
        DemoRowRef(tableName: tableName, id: id),
      ),
      expanded: true,
      children: children,
    );
  }
}

class DemoTreeItem {
  DemoTreeItem._({
    required this.title,
    required this.icon,
    this.detail,
    this.ref,
  });

  factory DemoTreeItem.group(String title, String detail) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      icon: material.Icons.folder_open,
    );
  }

  factory DemoTreeItem.row(String title, String detail, DemoRowRef ref) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      ref: ref,
      icon: material.Icons.table_rows,
    );
  }

  factory DemoTreeItem.metadata(String title, String detail) {
    return DemoTreeItem._(
      title: title,
      detail: detail,
      icon: material.Icons.info_outline,
    );
  }

  final String title;
  final String? detail;
  final material.IconData icon;
  final DemoRowRef? ref;
}

class DemoRowRef {
  const DemoRowRef({required this.tableName, required this.id});

  final String tableName;
  final protocol.UuidValue id;
}

class DemoUser {
  DemoUser({
    required this.username,
    required this.authUserId,
    required this.token,
  });

  final String username;
  protocol.UuidValue authUserId;
  String token;
}

class DemoDeviceSession {
  DemoDeviceSession({
    required this.user,
    required this.slot,
    required this.rawSession,
    required this.crdtSession,
  });

  final DemoUser user;
  final DemoDeviceSlot slot;
  final ClientDatabaseSession rawSession;
  final offline.CrdtDatabaseSession crdtSession;
}

enum DemoDeviceSlot {
  a('Device A'),
  b('Device B');

  const DemoDeviceSlot(this.label);

  final String label;
}

class DemoAuthKeyProvider implements protocol.ClientAuthKeyProvider {
  String? token;

  @override
  Future<String?> get authHeaderValue async {
    final value = token;
    if (value == null) return null;
    return 'Bearer $value';
  }
}

class OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException(
      'Connectivity is disabled by the demo httpClientOverride.',
      request.url,
    );
  }
}

class NamedRow {
  const NamedRow(this.tableName, this.id, this.name);

  final String tableName;
  final protocol.UuidValue id;
  final String name;
}

class _ScenarioCounter {
  final _values = <String, int>{};

  int next(String key) {
    final value = (_values[key] ?? 0) + 1;
    _values[key] = value;
    return value;
  }
}

String _normalizeUsername(String username) {
  return username.trim().toLowerCase();
}

protocol.UuidValue _demoAuthUserIdForUsername(String username) {
  final id = const uuid.Uuid().v5(
    uuid.Namespace.url.value,
    'serverpod-offline-sync/demo-user/${_normalizeUsername(username)}',
  );
  return protocol.UuidValue.withValidation(id);
}

String _demoTokenForAuthUserId(protocol.UuidValue authUserId) {
  return 'offline-sync-demo:${authUserId.uuid}';
}

protocol.UuidValue _authUserIdFromToken(String token) {
  const prefix = 'offline-sync-demo:';
  if (!token.startsWith(prefix)) {
    throw FormatException('Unexpected demo auth token.', token);
  }
  return protocol.UuidValue.withValidation(token.substring(prefix.length));
}

protocol.UuidValue _newId() {
  return const protocol.Uuid().v7obj();
}

String _short(protocol.UuidValue? value) {
  if (value == null) return 'null';
  return value.uuid.substring(0, 8);
}
