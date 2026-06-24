import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:serverpod_database/serverpod_database.dart'
    show ColumnDefinition, ColumnType, TableDefinition, TableRow;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;

import 'models.dart';
import 'offline_replica.dart';
import 'relationships.dart';
import 'snapshot.dart';
import 'table_ops.dart';

part 'scenarios.dart';

/// Lifecycle state of a replica's sync transport.
enum SyncPhase {
  offline('Offline'),
  idle('Idle'),
  syncing('Syncing once'),
  streaming('Streaming'),
  failed('Failed');

  const SyncPhase(this.label);

  final String label;
}

/// A candidate parent row, offered by the re-parent picker.
class ParentOption {
  ParentOption({required this.ref, required this.label, required this.visible});

  final DemoRowRef ref;
  final String label;
  final bool visible;
}

/// Per-replica view and sync state held side by side by [DemoController].
class ReplicaState extends ChangeNotifier {
  ReplicaState(this.slot);

  final ReplicaSlot slot;
  OfflineReplica? session;
  DemoSnapshot? snapshot;
  DemoProjection projection = DemoProjection.empty();
  SyncPhase phase = SyncPhase.idle;
  String? lastSyncedLabel;
  String? error;
  offline.CrdtSyncSession? stream;
  bool busy = false;
  bool _disposed = false;

  bool get streaming => stream != null;

  void changed() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// State of the "Server" panel that mirrors the merged server truth.
class ServerPanelState extends ChangeNotifier {
  DemoProjection projection = DemoProjection.empty();
  bool loading = false;
  bool busy = false;
  String? error;
  String? lastFetchedLabel;
  bool _disposed = false;

  void changed() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Drives the whole demo: users, replicas, connectivity, sync, and editing.
class DemoController extends ChangeNotifier {
  DemoController({required this.serverUrl});

  final String serverUrl;
  final authKeyProvider = DemoAuthKeyProvider();

  late final RelationshipCatalog catalog = RelationshipCatalog.build({
    for (final table in demoSyncTables) table.tableName,
  });

  final users = <DemoUser>[];
  final replicas = <ReplicaSlot, ReplicaState>{
    ReplicaSlot.a: ReplicaState(ReplicaSlot.a),
    ReplicaSlot.b: ReplicaState(ReplicaSlot.b),
  };
  final server = ServerPanelState();
  final _sessions = <String, OfflineReplica>{};
  final _counter = ScenarioCounter();

  protocol.Client? _client;
  DemoUser? selectedUser;

  bool online = true;
  bool showHidden = true;
  bool busy = false;

  /// True until the first [initialize] finishes opening the local databases.
  /// While set, the replica and server panels show a loading indicator.
  bool initializing = true;
  String status = 'Opening local demo databases...';
  bool _disposed = false;

  // Active guided scenario, if any.
  Scenario? activeScenario;
  List<ScenarioStep> _activeSteps = const [];
  int scenarioStepIndex = 0;
  bool scenarioAutoPlaying = false;
  Timer? _scenarioAutoPlayTimer;

  static const _scenarioAutoPlayDelay = Duration(milliseconds: 500);

  bool get anyBusy =>
      busy || server.busy || replicas.values.any((state) => state.busy);

  /// Static explanation shown by the replica-isolation info button.
  String get replicaIsolationMessage {
    final user = selectedUser?.username ?? '<user>';
    return 'Replica A and B are independent local SQLite stores '
        '($user-a.db, $user-b.db), each with its own CRDT node id but the '
        'same sync scope. They share nothing locally and only exchange data '
        'by syncing through the server — exactly like two phones on one '
        'account.';
  }

  protocol.Client get client => _client ??= _createClient();

  ReplicaState replica(ReplicaSlot slot) => replicas[slot]!;

  bool replicaBusy(ReplicaSlot slot) => busy || replicas[slot]!.busy;

  /// Visible rows of [parentTable] on [slot], offered as re-parent targets.
  List<ParentOption> parentOptions(ReplicaSlot slot, String parentTable) {
    final snapshot = replicas[slot]!.snapshot;
    if (snapshot == null) return const [];
    return [
      for (final row in snapshot.rows)
        if (row.table == parentTable && (row.visible || showHidden))
          ParentOption(
            ref: DemoRowRef(tableName: row.table, id: row.id),
            label: catalog.displayLabel(row.model),
            visible: row.visible,
          ),
    ];
  }

  // --- Lifecycle ----------------------------------------------------------

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
      _resetReplicaPhases();
      await _refreshReplicas(notify: false);
      unawaited(_ensureRemoteAuth(alice));
    });
    initializing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopScenarioAutoPlay();
    unawaited(_stopAllStreams());
    for (final replica in _sessions.values) {
      unawaited(replica.close());
    }
    for (final state in replicas.values) {
      state.dispose();
    }
    server.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // --- Users --------------------------------------------------------------

  Future<void> createOrSwitchUser(String username) async {
    final normalized = normalizeUsername(username);
    if (normalized.isEmpty) return;

    var user = _findUser(normalized);
    user ??= _localUser(normalized);
    if (!users.contains(user)) users.add(user);

    await switchUser(user);
  }

  Future<void> switchUser(DemoUser user) async {
    if (identical(user, selectedUser)) return;
    await _run('Switched to ${user.username}.', () async {
      await _stopAllStreams();
      stopScenario();
      selectedUser = user;
      authKeyProvider.token = user.token;
      _rebuildClient();
      await _openSessionsFor(user);
      _resetReplicaPhases();
      await _refreshReplicas(notify: false);
      if (online) {
        await _ensureRemoteAuth(user);
      } else {
        await _fetchServer(notify: false);
      }
    });
  }

  // --- Controls -----------------------------------------------------------

  Future<void> setShowHidden(bool value) async {
    if (showHidden == value) return;
    showHidden = value;
    notifyListeners();
    _projectFromSnapshots();
    if (online) {
      await _fetchServer(notify: false);
    }
    _notifyEverything();
  }

  Future<void> setOnline(bool value) async {
    await _run(
      value ? 'Connectivity enabled.' : 'Connectivity disabled.',
      () async {
        if (!value) {
          await _stopAllStreams();
        }
        online = value;
        _rebuildClient();
        _resetReplicaPhases();
        if (online && selectedUser != null) {
          await _ensureRemoteAuth(selectedUser!);
        } else {
          await _fetchServer(notify: false);
        }
      },
    );
  }

  // --- Sync (per replica) -------------------------------------------------

  Future<void> syncReplica(ReplicaSlot slot) async {
    final state = replicas[slot]!;
    final session = state.session;
    if (session == null || !online || state.streaming || state.busy) return;

    await _runReplica(slot, 'Synced ${slot.label} with the server.', () async {
      state.phase = SyncPhase.syncing;
      state.error = null;
      state.changed();
      try {
        await session.syncOnce(
          client,
          onMergeSuccess: (hlc) => _handleReplicaMerge(slot, hlc),
        );
        state.phase = SyncPhase.idle;
        state.lastSyncedLabel = 'synced ${_timeLabel()}';
      } catch (error) {
        state.phase = SyncPhase.failed;
        state.error = '$error';
        rethrow;
      } finally {
        await _refreshReplica(slot, notify: false);
        state.changed();
      }
    });
  }

  Future<void> setReplicaStreaming(ReplicaSlot slot, bool value) async {
    final state = replicas[slot]!;
    if (value) {
      final session = state.session;
      if (session == null || !online || state.streaming || state.busy) return;
      await _runReplica(
        slot,
        'Streaming ${slot.label} with the server.',
        () async {
          final stream = session.syncContinuously(
            client,
            onMergeSuccess: (hlc) => unawaited(_handleReplicaMerge(slot, hlc)),
          );
          state.stream = stream;
          state.phase = SyncPhase.streaming;
          state.error = null;
          unawaited(
            stream.done
                .then((_) {
                  if (!identical(state.stream, stream)) return;
                  state.stream = null;
                  if (state.phase == SyncPhase.streaming) {
                    state.phase = SyncPhase.idle;
                  }
                  state.changed();
                  notifyListeners();
                })
                .catchError((Object error) {
                  if (!identical(state.stream, stream)) return;
                  state.stream = null;
                  state.phase = SyncPhase.failed;
                  state.error = '$error';
                  state.changed();
                  notifyListeners();
                }),
          );
        },
      );
      return;
    }

    await _runReplica(
      slot,
      'Stopped streaming ${slot.label}.',
      () => _stopReplicaStream(slot),
    );
  }

  // --- Refresh ------------------------------------------------------------

  Future<void> refreshAll() async {
    await _refreshReplicas(notify: false);
    await _fetchServer(notify: false);
    _notifyEverything();
  }

  /// Re-fetches just the server "merged truth" panel.
  Future<void> refreshServer() => _fetchServer();

  Future<void> _refreshReplicas({bool notify = true}) async {
    for (final slot in ReplicaSlot.values) {
      await _refreshReplica(slot, notify: false);
    }
    if (notify) {
      _notifyReplicas();
    }
  }

  Future<void> _fetchServer({bool notify = true}) async {
    if (!online) {
      server
        ..projection = DemoProjection.empty()
        ..error = null
        ..lastFetchedLabel = null;
      if (notify) server.changed();
      return;
    }
    server.loading = true;
    if (notify) server.changed();
    try {
      final rows = await client.demoDebug.fetchScopeSnapshot(
        includeHidden: showHidden,
      );
      // The server returns a flat list of row models. To flag CRDT-hidden rows
      // we diff against a visible-only fetch (the same two reads the endpoint
      // used to do internally); skipped entirely when hidden rows aren't shown.
      final hiddenIds = <String>{};
      if (showHidden) {
        final visible = await client.demoDebug.fetchScopeSnapshot(
          includeHidden: false,
        );
        final visibleIds = {
          for (final row in visible) '${(row as dynamic).id}',
        };
        for (final row in rows) {
          final id = '${(row as dynamic).id}';
          if (!visibleIds.contains(id)) hiddenIds.add(id);
        }
      }
      server
        ..projection = DemoSnapshot.fromServer(
          catalog,
          rows,
          hiddenIds: hiddenIds,
        ).project(showHidden: showHidden)
        ..error = null
        ..lastFetchedLabel = 'fetched ${_timeLabel()}';
    } catch (error) {
      server
        ..projection = DemoProjection.empty()
        ..error = '$error';
    } finally {
      server.loading = false;
      if (notify) server.changed();
    }
  }

  Future<void> _handleReplicaMerge(ReplicaSlot slot, Object hlc) async {
    replicas[slot]!.lastSyncedLabel = 'merged $hlc';
    await _refreshReplica(slot, notify: false);
    await _fetchServer(notify: false);
    replicas[slot]!.changed();
    server.changed();
  }

  Future<void> _refreshReplica(ReplicaSlot slot, {bool notify = true}) async {
    final state = replicas[slot]!;
    final session = state.session;
    if (session == null) {
      state.snapshot = null;
      state.projection = DemoProjection.empty();
    } else {
      // Reading the view must never turn a successful sync/seed into a reported
      // failure. Surface the error in the panel and keep the last projection.
      try {
        final snapshot = await DemoSnapshot.load(catalog, session.session);
        state.snapshot = snapshot;
        state.projection = snapshot.project(showHidden: showHidden);
        state.error = null;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Snapshot load failed for ${slot.label}: $error');
          debugPrint('$stackTrace');
        }
        state.error = 'view error: $error';
      }
    }
    if (notify) state.changed();
  }

  // --- Reset --------------------------------------------------------------

  /// Wipes one replica's local database (a fresh device). Syncing afterwards
  /// re-pulls whatever the server still holds.
  Future<void> resetReplica(ReplicaSlot slot) async {
    await _runReplica(
      slot,
      'Reset ${slot.label} (wiped local database).',
      () => _resetReplicaStorage(slot),
    );
  }

  /// Wipes both replicas and the server scope at once, concurrently.
  Future<void> resetAll() async {
    await _stopAllStreams();
    await Future.wait([
      resetReplica(ReplicaSlot.a),
      resetReplica(ReplicaSlot.b),
      if (online) resetServer(),
    ]);
  }

  /// Hard-clears the caller's server scope, including synced rows and CRDT
  /// metadata.
  Future<void> resetServer() async {
    if (!online) return;
    await _runServer('Reset the server scope.', () async {
      await _stopAllStreams();
      _notifyReplicas();
      try {
        await client.demoDebug.resetScope();
      } catch (error) {
        server.error = 'reset failed: $error';
        rethrow;
      }
      await _fetchServer(notify: false);
      server.changed();
    });
  }

  // --- Free-form row construction (the primary workflow) ------------------

  /// Creates a root row of [table] on [slot] and returns its reference.
  Future<DemoRowRef?> createRoot(
    ReplicaSlot slot,
    String table, {
    String? label,
  }) async {
    final row = catalog.buildRow(
      table,
      label: label ?? '${_friendly(table)} ${_counter.next(table)}',
    );
    if (row == null) {
      status = 'Cannot create $table without more fields.';
      notifyListeners();
      return null;
    }
    return _insertRow(slot, row, 'Created $table on ${slot.label}.');
  }

  /// Creates a child of [parent] on [slot] using [relation], attaching its
  /// foreign key to the parent. Returns the new child's reference.
  Future<DemoRowRef?> createChildFor(
    ReplicaSlot slot,
    DemoRowRef parent,
    Relationship relation,
  ) async {
    final childLabel =
        '${_friendly(relation.childTable)} ${_counter.next(relation.childTable)}';
    final row = catalog.buildRow(
      relation.childTable,
      fkColumn: relation.fkColumn,
      fkValue: parent.id,
      label: childLabel,
    );
    if (row == null) {
      status = 'Cannot create ${relation.childTable} here.';
      notifyListeners();
      return null;
    }
    return _insertRow(
      slot,
      row,
      'Attached ${relation.childTable} to ${parent.tableName} on ${slot.label}.',
    );
  }

  /// Re-points [ref]'s [fkColumn] at [newParentId], or detaches it when null.
  Future<void> reParent(
    ReplicaSlot slot,
    DemoRowRef ref,
    String fkColumn,
    protocol.UuidValue? newParentId,
  ) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return;

    final verb = newParentId == null ? 'Detached' : 'Re-parented';
    await _runReplica(
      slot,
      '$verb ${ref.tableName} on ${slot.label}.',
      () async {
        final crdt = session.session;
        final row =
            await ops.findById(crdt, ref.id) ??
            await _findHiddenRow(ops, crdt, ref.id);
        if (row == null) return;
        await ops.updateFields(crdt, row, {fkColumn: newParentId});
        await _refreshReplica(slot, notify: false);
        replicas[slot]!.changed();
      },
    );
  }

  Future<DemoRowRef?> _insertRow(
    ReplicaSlot slot,
    TableRow<protocol.UuidValue?> row,
    String success,
  ) async {
    final table = row.table.tableName;
    final ops = demoTableOps[table];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return null;
    final id = row.id;
    if (id == null) return null;
    final ok = await _runReplica(slot, success, () async {
      await ops.insertRow(session.session, row);
      await _refreshReplica(slot, notify: false);
      replicas[slot]!.changed();
    });
    return ok ? DemoRowRef(tableName: table, id: id) : null;
  }

  /// Restores a soft-deleted row by inserting it again with the same id.
  Future<DemoRowRef?> reinsertRow(DemoRowRef ref, ReplicaSlot slot) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return null;

    final ok = await _runReplica(
      slot,
      'Reinserted ${ref.tableName} on ${slot.label}.',
      () async {
        final crdt = session.session;
        final hidden = await _findHiddenRow(ops, crdt, ref.id);
        if (hidden == null) return;
        await ops.insertRow(crdt, hidden);
        await _refreshReplica(slot, notify: false);
        replicas[slot]!.changed();
      },
    );
    return ok ? ref : null;
  }

  /// Applies [fields] to a visible row on [slot].
  Future<void> updateRowFields(
    DemoRowRef ref,
    ReplicaSlot slot,
    Map<String, dynamic> fields,
  ) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return;

    await _runReplica(
      slot,
      'Updated ${ref.tableName} on ${slot.label}.',
      () async {
        final crdt = session.session;
        final row = await ops.findById(crdt, ref.id);
        if (row == null) return;
        await ops.updateFields(crdt, row, fields);
        await _refreshReplica(slot, notify: false);
        replicas[slot]!.changed();
      },
    );
  }

  // --- Seeds (quick-starts, used by menus and scenarios) ------------------

  Future<void> seedBasicGraph(ReplicaSlot slot) {
    return _seedLocal(
      slot,
      'Seeded a city/person/address/town graph on ${slot.label}.',
      (session) async {
        final suffix = _counter.next('basic');
        final city = await protocol.City.db.insertRow(
          session.session,
          protocol.City(id: newId(), name: 'City $suffix'),
        );
        final person = await protocol.Person.db.insertRow(
          session.session,
          protocol.Person(
            id: newId(),
            name: 'Person $suffix',
            surname: 'Local',
          ),
        );
        await protocol.Address.db.insertRow(
          session.session,
          protocol.Address(
            id: newId(),
            street: 'Main Street $suffix',
            inhabitantId: person.id,
          ),
        );
        await protocol.Town.db.insertRow(
          session.session,
          protocol.Town(id: newId(), name: 'Town $suffix', cityId: city.id),
        );
      },
    );
  }

  Future<void> seedTypedRow(ReplicaSlot slot) {
    return _seedLocal(slot, 'Seeded a typed row on ${slot.label}.', (
      session,
    ) async {
      final suffix = _counter.next('types');
      await protocol.Types.db.insertRow(
        session.session,
        protocol.Types(
          id: newId(),
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
          optionalUuid: newId(),
        ),
      );
    });
  }

  Future<void> seedForeignKeyChain(ReplicaSlot slot) {
    return _seedLocal(slot, 'Seeded a mixed FK chain on ${slot.label}.', (
      session,
    ) async {
      final suffix = _counter.next('chain');
      final root = await protocol.FkChainRoot.db.insertRow(
        session.session,
        protocol.FkChainRoot(id: newId(), name: 'Root $suffix'),
      );
      final middle = await protocol.FkChainCascadeMiddle.db.insertRow(
        session.session,
        protocol.FkChainCascadeMiddle(
          id: newId(),
          name: 'Cascade middle $suffix',
          rootId: root.id,
        ),
      );
      final blocker = await protocol.FkChainRestrictBlocker.db.insertRow(
        session.session,
        protocol.FkChainRestrictBlocker(
          id: newId(),
          name: 'Restrict blocker $suffix',
          cascadeMiddleId: middle.id,
        ),
      );
      await protocol.FkChainMiddleSetNullChild.db.insertRow(
        session.session,
        protocol.FkChainMiddleSetNullChild(
          id: newId(),
          name: 'Set-null child $suffix',
          restrictBlockerId: blocker.id,
        ),
      );
      await protocol.FkChainMiddleCascadeChild.db.insertRow(
        session.session,
        protocol.FkChainMiddleCascadeChild(
          id: newId(),
          name: 'Cascade child $suffix',
          restrictBlockerId: blocker.id,
        ),
      );
    });
  }

  /// Inserts a Unique row with a fixed [name] (for concurrent-insert conflicts).
  Future<DemoRowRef?> createUnique(ReplicaSlot slot, String name) {
    return createRoot(slot, 'unique', label: name);
  }

  /// Inserts a Town, optionally with a fixed [id] (used for SetDefault targets).
  Future<DemoRowRef?> createTown(
    ReplicaSlot slot, {
    protocol.UuidValue? id,
    String? label,
  }) async {
    final row = protocol.Town(
      id: id ?? newId(),
      name: label ?? 'Town ${_counter.next('town')}',
    );
    return _insertRow(slot, row, 'Created town on ${slot.label}.');
  }

  /// Inserts a Company referencing [town].
  Future<DemoRowRef?> createCompanyForTown(
    ReplicaSlot slot,
    DemoRowRef town, {
    String? label,
  }) async {
    final row = protocol.Company(
      id: newId(),
      name: label ?? 'Company ${_counter.next('company')}',
      townId: town.id,
    );
    return _insertRow(slot, row, 'Created company on ${slot.label}.');
  }

  Future<void> _seedLocal(
    ReplicaSlot slot,
    String success,
    Future<void> Function(OfflineReplica session) local,
  ) async {
    final session = replicas[slot]!.session;
    if (session == null) return;
    await _runReplica(slot, success, () async {
      await local(session);
      await _refreshReplica(slot, notify: false);
      replicas[slot]!.changed();
    });
  }

  /// Seeds a graph directly on the server (fetch-from-scratch scenarios).
  Future<void> seedServer(String kind, [String? text]) async {
    if (!online) {
      status = 'Connect to seed the server.';
      notifyListeners();
      return;
    }
    await _runServer('Seeded the server scope ($kind).', () async {
      try {
        await client.demoDebug.seedScope(kind, text);
      } catch (error) {
        server.error = 'seed failed: $error';
        rethrow;
      }
      await _fetchServer(notify: false);
      server.changed();
    });
  }

  // --- Scenarios ----------------------------------------------------------

  late final List<Scenario> scenarios = _buildScenarios();

  List<ScenarioStep> get activeSteps => _activeSteps;

  void startScenario(Scenario scenario) {
    stopScenarioAutoPlay();
    activeScenario = scenario;
    _activeSteps = scenario.build(this);
    scenarioStepIndex = 0;
    status = 'Scenario "${scenario.title}" ready — run the steps in order.';
    notifyListeners();
  }

  void stopScenario() {
    if (activeScenario == null) return;
    stopScenarioAutoPlay();
    activeScenario = null;
    _activeSteps = const [];
    scenarioStepIndex = 0;
    notifyListeners();
  }

  bool get scenarioComplete =>
      activeScenario != null && scenarioStepIndex >= _activeSteps.length;

  void toggleScenarioAutoPlay() {
    if (scenarioAutoPlaying) {
      stopScenarioAutoPlay();
    } else {
      startScenarioAutoPlay();
    }
  }

  void startScenarioAutoPlay() {
    if (activeScenario == null || scenarioComplete || scenarioAutoPlaying) {
      return;
    }
    scenarioAutoPlaying = true;
    notifyListeners();
    _kickScenarioAutoPlay();
  }

  void stopScenarioAutoPlay() {
    if (!scenarioAutoPlaying && _scenarioAutoPlayTimer == null) return;
    scenarioAutoPlaying = false;
    _scenarioAutoPlayTimer?.cancel();
    _scenarioAutoPlayTimer = null;
    notifyListeners();
  }

  void _kickScenarioAutoPlay() {
    if (!scenarioAutoPlaying || scenarioComplete || activeScenario == null) {
      return;
    }
    if (anyBusy) {
      _scheduleScenarioAutoPlayStep(delay: const Duration(milliseconds: 100));
      return;
    }
    unawaited(_runScenarioAutoPlayStep());
  }

  void _scheduleScenarioAutoPlayStep({
    Duration delay = _scenarioAutoPlayDelay,
  }) {
    _scenarioAutoPlayTimer?.cancel();
    if (!scenarioAutoPlaying || scenarioComplete || activeScenario == null) {
      return;
    }
    _scenarioAutoPlayTimer = Timer(delay, _kickScenarioAutoPlay);
  }

  Future<void> _runScenarioAutoPlayStep() async {
    if (!scenarioAutoPlaying || scenarioComplete || activeScenario == null) {
      return;
    }
    if (anyBusy) {
      _scheduleScenarioAutoPlayStep(delay: const Duration(milliseconds: 100));
      return;
    }
    await runNextScenarioStep();
  }

  Future<void> runNextScenarioStep() async {
    if (activeScenario == null) return;
    if (scenarioStepIndex >= _activeSteps.length) return;
    final step = _activeSteps[scenarioStepIndex];
    await step.run();
    scenarioStepIndex++;
    if (scenarioStepIndex >= _activeSteps.length) {
      status = 'Scenario "${activeScenario!.title}" complete.';
      stopScenarioAutoPlay();
    } else if (scenarioAutoPlaying) {
      _scheduleScenarioAutoPlayStep();
    }
    notifyListeners();
  }

  // --- Row detail, editing & deletion -------------------------------------

  /// Finds a row by id including CRDT-hidden rows (via `includeHidden`),
  /// since a plain findById only returns visible rows.
  Future<TableRow<protocol.UuidValue?>?> _findHiddenRow(
    TableOps ops,
    offline.CrdtDatabaseSession crdt,
    protocol.UuidValue id,
  ) async {
    final all = await ops.findAll(crdt, includeHidden: true);
    for (final row in all) {
      if (row.id == id) return row;
    }
    return null;
  }

  /// Loads the full record for [ref] on [slot], reading hidden rows through the
  /// includeHidden expression when needed.
  Future<RowDetail?> loadDetail(DemoRowRef ref, ReplicaSlot slot) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return null;

    final visibleRow = await ops.findById(session.session, ref.id);
    final row =
        visibleRow ?? await _findHiddenRow(ops, session.session, ref.id);
    if (row == null) return null;

    final json = row.toJson() as Map<String, dynamic>;
    final fields = _modelFields(ref.tableName, json);
    return RowDetail(
      slot: slot,
      tableName: ref.tableName,
      uuid: ref.id.uuid,
      visible: visibleRow != null,
      fields: fields,
      editable: _editableFields(ref.tableName, fields),
    );
  }

  /// Applies [values] (keyed by [EditableField.key]) to the row on [slot].
  Future<bool> applyEdit(
    DemoRowRef ref,
    ReplicaSlot slot,
    Map<String, String> values,
  ) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return false;

    return _runReplica(
      slot,
      'Updated ${ref.tableName} on ${slot.label}.',
      () async {
        final crdt = session.session;
        final row = await ops.findById(crdt, ref.id);
        if (row == null) return;
        final fields = _decodeEditedValues(ref.tableName, values);
        await ops.updateFields(crdt, row, fields);
        await _refreshReplica(slot, notify: false);
        replicas[slot]!.changed();
      },
    );
  }

  Future<void> deleteRow(DemoRowRef ref, ReplicaSlot slot) async {
    final ops = demoTableOps[ref.tableName];
    final session = replicas[slot]!.session;
    if (ops == null || session == null) return;

    await _runReplica(
      slot,
      'Deleted ${ref.tableName} on ${slot.label}.',
      () async {
        await ops.deleteById(session.session, ref.id);
        await _refreshReplica(slot, notify: false);
        replicas[slot]!.changed();
      },
    );
  }

  // --- Internals ----------------------------------------------------------

  String _friendly(String table) {
    final words = tableLabel(table).split(' ');
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<OfflineReplica> _openSession(DemoUser user, ReplicaSlot slot) async {
    final key = _sessionKey(user, slot);
    final existing = _sessions[key];
    if (existing != null) {
      replicas[slot]!.session = existing;
      return existing;
    }

    // The demo chooses where each replica's database lives (one file per
    // user+slot); opening and CRDT-wrapping it is OfflineReplica's job.
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'serverpod_offline_sync_demo'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final replica = await OfflineReplica.open(
      client: client,
      databasePath: p.join(dbDir.path, '${user.username}-${slot.name}.db'),
      persistentUserId: user.authUserId,
    );
    _sessions[key] = replica;
    replicas[slot]!.session = replica;
    return replica;
  }

  Future<void> _openSessionsFor(DemoUser user) async {
    for (final slot in ReplicaSlot.values) {
      await _openSession(user, slot);
    }
  }

  Future<void> _ensureRemoteAuth(DemoUser user) async {
    if (!online) return;
    try {
      final token = await client.demoAuth.loginOrCreateUser(user.username);
      user.token = token;
      user.authUserId = authUserIdFromToken(token);
      if (identical(selectedUser, user)) {
        authKeyProvider.token = token;
      }
      status = 'Authenticated ${user.username} on the demo server.';
      if (identical(selectedUser, user)) {
        await _fetchServer(notify: false);
        server.changed();
      }
      notifyListeners();
    } catch (error) {
      status = 'Using local ${user.username}; server auth unavailable: $error';
      notifyListeners();
    }
  }

  Future<void> _stopReplicaStream(ReplicaSlot slot) async {
    final state = replicas[slot]!;
    final stream = state.stream;
    state.stream = null;
    if (state.phase == SyncPhase.streaming) state.phase = SyncPhase.idle;
    await stream?.cancel();
  }

  Future<void> _stopAllStreams() async {
    for (final slot in ReplicaSlot.values) {
      await _stopReplicaStream(slot);
    }
  }

  /// Wipes a replica's local database (via [OfflineReplica.reset]) and resets
  /// its sync phase. Syncing afterwards re-pulls whatever the server still
  /// holds.
  Future<void> _resetReplicaStorage(ReplicaSlot slot) async {
    await _stopReplicaStream(slot);
    await replicas[slot]!.session?.reset();

    replicas[slot]!
      ..phase = online ? SyncPhase.idle : SyncPhase.offline
      ..lastSyncedLabel = null
      ..error = null;
    await _refreshReplica(slot, notify: false);
  }

  void _resetReplicaPhases() {
    for (final state in replicas.values) {
      if (state.streaming) continue;
      state.phase = online ? SyncPhase.idle : SyncPhase.offline;
    }
  }

  void _rebuildClient() => _client = _createClient();

  protocol.Client _createClient() {
    return protocol.Client(
      serverUrl,
      httpClientOverride: online ? null : OfflineHttpClient(),
    )..authKeyProvider = authKeyProvider;
  }

  DemoUser _localUser(String username) {
    final normalized = normalizeUsername(username);
    final authUserId = demoAuthUserIdForUsername(normalized);
    return DemoUser(
      username: normalized,
      authUserId: authUserId,
      token: demoTokenForAuthUserId(authUserId),
    );
  }

  DemoUser? _findUser(String username) {
    for (final user in users) {
      if (user.username == username) return user;
    }
    return null;
  }

  Future<bool> _run(String success, Future<void> Function() action) async {
    busy = true;
    _notifyEverything();
    try {
      await action();
      status = success;
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
      status = 'Failed: $error';
      return false;
    } finally {
      busy = false;
      _notifyEverything();
    }
  }

  Future<bool> _runReplica(
    ReplicaSlot slot,
    String success,
    Future<void> Function() action,
  ) async {
    final state = replicas[slot]!;
    if (busy || state.busy) return false;

    state
      ..busy = true
      ..error = null;
    state.changed();
    notifyListeners();

    try {
      await action();
      status = success;
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
      state.error ??= '$error';
      status = 'Failed: $error';
      return false;
    } finally {
      state.busy = false;
      state.changed();
      notifyListeners();
    }
  }

  Future<bool> _runServer(
    String success,
    Future<void> Function() action,
  ) async {
    if (busy || server.busy) return false;

    server
      ..busy = true
      ..error = null;
    server.changed();
    notifyListeners();

    try {
      await action();
      status = success;
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
      server.error ??= '$error';
      status = 'Failed: $error';
      return false;
    } finally {
      server.busy = false;
      server.changed();
      notifyListeners();
    }
  }

  void _projectFromSnapshots() {
    for (final state in replicas.values) {
      final snapshot = state.snapshot;
      if (snapshot != null) {
        state.projection = snapshot.project(showHidden: showHidden);
      }
    }
  }

  void _notifyReplicas() {
    for (final state in replicas.values) {
      state.changed();
    }
  }

  void _notifyEverything() {
    _notifyReplicas();
    server.changed();
    notifyListeners();
  }

  String _sessionKey(DemoUser user, ReplicaSlot slot) {
    return '${user.authUserId.uuid}:${slot.name}';
  }

  String _timeLabel() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }
}

/// A single editable field of a row detail.
class EditableField {
  EditableField(this.key, this.value);

  final String key;
  final String value;
}

/// The complete record behind a tree row, plus its CRDT visibility status.
class RowDetail {
  RowDetail({
    required this.slot,
    required this.tableName,
    required this.uuid,
    required this.visible,
    required this.fields,
    required this.editable,
  });

  final ReplicaSlot slot;
  final String tableName;
  final String uuid;
  final bool visible;
  final Map<String, dynamic> fields;
  final List<EditableField> editable;

  /// The CRDT scope id stored on the row, if any.
  String? get scopeId => fields['scopeId']?.toString();
}

final _tableDefinitionsByName = <String, TableDefinition>{
  for (final table in protocol.Protocol.targetTableDefinitions)
    table.name: table,
};

Map<String, dynamic> _modelFields(String tableName, Map<String, dynamic> json) {
  final fields = <String, dynamic>{};
  final table = _tableDefinition(tableName);

  for (final column in table.columns) {
    fields[column.name] = json[column.name];
  }

  for (final entry in json.entries) {
    if (_isPublicField(entry.key)) {
      fields.putIfAbsent(entry.key, () => entry.value);
    }
  }

  return fields;
}

List<EditableField> _editableFields(
  String tableName,
  Map<String, dynamic> fields,
) {
  final table = _tableDefinition(tableName);

  return [
    for (final column in table.columns)
      if (_isEditableColumn(column))
        EditableField(column.name, fields[column.name]?.toString() ?? ''),
  ];
}

Map<String, dynamic> _decodeEditedValues(
  String tableName,
  Map<String, String> values,
) {
  final edited = <String, dynamic>{};
  final table = _tableDefinition(tableName);

  for (final column in table.columns) {
    final value = values[column.name];
    if (value == null || !_isEditableColumn(column)) continue;
    edited[column.name] = _parseFieldText(value, column);
  }

  return edited;
}

bool _isPublicField(String key) {
  return !key.startsWith('__') && !key.startsWith('_');
}

bool _isEditableField(String key) {
  return _isPublicField(key) && key != 'id' && key != 'scopeId';
}

bool _isEditableColumn(ColumnDefinition column) {
  return _isEditableField(column.name);
}

TableDefinition _tableDefinition(String tableName) {
  return _tableDefinitionsByName[tableName] ??
      (throw StateError('No table definition registered for $tableName.'));
}

/// Parses editable text into the JSON shape consumed by [protocol.Protocol].
dynamic _parseFieldText(String raw, ColumnDefinition column) {
  if (raw.isEmpty && column.isNullable) return null;

  return switch (column.columnType) {
    ColumnType.boolean => _parseBool(raw),
    ColumnType.bigint => _parseBigIntColumn(raw, column),
    ColumnType.integer => int.parse(raw),
    ColumnType.doublePrecision => double.parse(raw),
    ColumnType.uuid ||
    ColumnType.timestampWithoutTimeZone ||
    ColumnType.text ||
    ColumnType.bytea => raw,
    _ => raw,
  };
}

dynamic _parseBigIntColumn(String raw, ColumnDefinition column) {
  final dartType = column.dartType;
  if (dartType?.startsWith('protocol:') ?? false) return int.parse(raw);
  if (dartType == 'int' || dartType == 'int?') return int.parse(raw);
  return raw;
}

bool _parseBool(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'true' || '1' || 'yes' => true,
    'false' || '0' || 'no' => false,
    _ => throw FormatException('Expected a boolean value.'),
  };
}
