import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;

import 'models.dart';
import 'snapshot.dart';

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

/// Where preset/seed actions write: one of the replicas or the server.
enum SeedTarget {
  replicaA('Replica A'),
  replicaB('Replica B'),
  server('Server');

  const SeedTarget(this.label);

  final String label;
}

/// Per-replica view and sync state held side by side by [DemoController].
class ReplicaState {
  ReplicaState(this.slot);

  final ReplicaSlot slot;
  ReplicaSession? session;
  DemoProjection projection = DemoProjection.empty();
  SyncPhase phase = SyncPhase.idle;
  String? lastSyncedLabel;
  String? error;
  offline.CrdtSyncSession? stream;

  bool get streaming => stream != null;
}

/// State of the "Server" panel that mirrors the merged server truth.
class ServerPanelState {
  DemoProjection projection = DemoProjection.empty();
  bool loading = false;
  String? error;
  String? lastFetchedLabel;
}

/// Drives the whole demo: users, replicas, connectivity, sync, and seeding.
class DemoController extends ChangeNotifier {
  DemoController({required this.serverUrl});

  final String serverUrl;
  final authKeyProvider = DemoAuthKeyProvider();

  final users = <DemoUser>[];
  final replicas = <ReplicaSlot, ReplicaState>{
    ReplicaSlot.a: ReplicaState(ReplicaSlot.a),
    ReplicaSlot.b: ReplicaState(ReplicaSlot.b),
  };
  final server = ServerPanelState();
  final _sessions = <String, ReplicaSession>{};
  final _counter = ScenarioCounter();

  protocol.Client? _client;
  DemoUser? selectedUser;

  /// Where preset/seed actions write: a replica or the server.
  SeedTarget focusedTarget = SeedTarget.replicaA;
  int presetTab = 0;
  bool online = true;
  bool showHidden = false;
  bool busy = false;
  String status = 'Opening local demo databases...';

  String? _pendingUniqueName;
  protocol.UuidValue? _pendingUniqueUuid;

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

  /// The replica the seed target maps to, or null when targeting the server.
  ReplicaSlot? get _focusedSlot => switch (focusedTarget) {
    SeedTarget.replicaA => ReplicaSlot.a,
    SeedTarget.replicaB => ReplicaSlot.b,
    SeedTarget.server => null,
  };

  /// Human label for the current seed target.
  String get focusedTargetLabel => focusedTarget.label;

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
      await _refreshAll(notify: false);
      unawaited(_ensureRemoteAuth(alice));
    });
  }

  @override
  void dispose() {
    unawaited(_stopAllStreams());
    for (final session in _sessions.values) {
      unawaited(session.rawSession.close());
    }
    super.dispose();
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
      selectedUser = user;
      authKeyProvider.token = user.token;
      _rebuildClient();
      await _openSessionsFor(user);
      _resetReplicaPhases();
      await _refreshAll(notify: false);
      if (online) {
        await _ensureRemoteAuth(user);
      } else {
        await _fetchServer(notify: false);
      }
    });
  }

  // --- Controls -----------------------------------------------------------

  void setFocusedTarget(SeedTarget target) {
    focusedTarget = target;
    notifyListeners();
  }

  void setPresetTab(int value) {
    presetTab = value;
    notifyListeners();
  }

  Future<void> setShowHidden(bool value) async {
    showHidden = value;
    await _refreshAll();
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
    if (session == null || !online || state.streaming) return;

    await _run('Synced ${slot.label} with the server.', () async {
      state.phase = SyncPhase.syncing;
      state.error = null;
      notifyListeners();
      try {
        await client.crdt.syncOnce(session.crdtSession);
        state.phase = SyncPhase.idle;
        state.lastSyncedLabel = 'synced ${_timeLabel()}';
        _pendingUniqueName = null;
        _pendingUniqueUuid = null;
      } catch (error) {
        state.phase = SyncPhase.failed;
        state.error = '$error';
        rethrow;
      } finally {
        await _refreshReplica(slot, notify: false);
        await _fetchServer(notify: false);
      }
    });
  }

  Future<void> setReplicaStreaming(ReplicaSlot slot, bool value) async {
    final state = replicas[slot]!;
    if (value) {
      final session = state.session;
      if (session == null || !online || state.streaming) return;
      await _run('Streaming ${slot.label} with the server.', () async {
        final stream = client.crdt.syncContinuously(
          session.crdtSession,
          onMergeSuccess: (hlc) {
            state.lastSyncedLabel = 'merged $hlc';
            unawaited(_refreshReplica(slot));
          },
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
                notifyListeners();
              })
              .catchError((Object error) {
                if (!identical(state.stream, stream)) return;
                state.stream = null;
                state.phase = SyncPhase.failed;
                state.error = '$error';
                notifyListeners();
              }),
        );
      });
      return;
    }

    await _run(
      'Stopped streaming ${slot.label}.',
      () => _stopReplicaStream(slot),
    );
  }

  // --- Refresh ------------------------------------------------------------

  Future<void> refreshAll() async {
    await _refreshAll(notify: false);
    await _fetchServer(notify: false);
    notifyListeners();
  }

  /// Re-fetches just the server "merged truth" panel.
  Future<void> refreshServer() => _fetchServer();

  Future<void> _refreshAll({bool notify = true}) async {
    for (final slot in ReplicaSlot.values) {
      await _refreshReplica(slot, notify: false);
    }
    if (notify) notifyListeners();
  }

  Future<void> _fetchServer({bool notify = true}) async {
    if (!online) {
      server
        ..projection = DemoProjection.empty()
        ..error = null
        ..lastFetchedLabel = null;
      if (notify) notifyListeners();
      return;
    }
    server.loading = true;
    if (notify) notifyListeners();
    try {
      final snapshot = await client.demoDebug.fetchScopeSnapshot();
      server
        ..projection = DemoSnapshot.fromServer(
          snapshot,
        ).project(showHidden: showHidden)
        ..error = null
        ..lastFetchedLabel = 'fetched ${_timeLabel()}';
    } catch (error) {
      server
        ..projection = DemoProjection.empty()
        ..error = '$error';
    } finally {
      server.loading = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> _refreshReplica(ReplicaSlot slot, {bool notify = true}) async {
    final state = replicas[slot]!;
    final session = state.session;
    if (session == null) {
      state.projection = DemoProjection.empty();
    } else {
      // Reading the view must never turn a successful sync/seed into a reported
      // failure. Surface the error in the panel and keep the last projection.
      try {
        final snapshot = await DemoSnapshot.load(
          session.crdtSession,
          session.rawSession,
        );
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
    if (notify) notifyListeners();
  }

  // --- Reset --------------------------------------------------------------

  /// Wipes one replica's local database (a fresh device). Syncing afterwards
  /// re-pulls whatever the server still holds. Other replicas and the server
  /// are untouched.
  Future<void> resetReplica(ReplicaSlot slot) async {
    final user = selectedUser;
    if (user == null) return;

    await _run('Reset ${slot.label} (wiped local database).', () async {
      await _resetReplicaStorage(user, slot);
    });
  }

  /// Hard-clears the caller's server scope, including synced rows and CRDT
  /// metadata. Other replicas keep their local data until they are reset or
  /// sync back into the empty server scope.
  Future<void> resetServer() async {
    if (!online) return;
    await _run('Reset the server scope.', () async {
      await _stopAllStreams();
      try {
        await client.demoDebug.resetScope();
      } catch (error) {
        // Surface the reason in the panel, not just the status bar (e.g. a stale
        // server process without the resetScope endpoint).
        server.error = 'reset failed: $error';
        rethrow;
      }
      await _fetchServer(notify: false);
    });
  }

  // --- Presets / seeding (focused target) ---------------------------------

  /// Routes a seed to the focused target: a server endpoint call when the
  /// server is selected, otherwise local inserts on the focused replica.
  Future<void> _runSeed({
    required String success,
    required String serverKind,
    String? serverText,
    required Future<void> Function(ReplicaSession session) local,
  }) async {
    if (focusedTarget == SeedTarget.server) {
      if (!online) {
        status = 'Connect to seed the server.';
        notifyListeners();
        return;
      }
      await _run(success, () async {
        try {
          await client.demoDebug.seedScope(serverKind, serverText);
        } catch (error) {
          server.error = 'seed failed: $error';
          rethrow;
        }
        await _fetchServer(notify: false);
      });
      return;
    }

    final slot = _focusedSlot!;
    final session = replicas[slot]!.session;
    if (session == null) return;
    await _run(success, () async {
      await local(session);
      await _refreshReplica(slot, notify: false);
    });
  }

  Future<void> seedBasicGraph() {
    return _runSeed(
      success:
          'Seeded a city/person/address/town graph on '
          '$focusedTargetLabel.',
      serverKind: 'basicGraph',
      local: (session) async {
        final suffix = _counter.next('basic');
        final city = await protocol.City.db.insertRow(
          session.crdtSession,
          protocol.City(id: newId(), name: 'City $suffix'),
        );
        final person = await protocol.Person.db.insertRow(
          session.crdtSession,
          protocol.Person(
            id: newId(),
            name: 'Person $suffix',
            surname: 'Local',
          ),
        );
        await protocol.Address.db.insertRow(
          session.crdtSession,
          protocol.Address(
            id: newId(),
            street: 'Main Street $suffix',
            inhabitantId: person.id,
          ),
        );
        await protocol.Town.db.insertRow(
          session.crdtSession,
          protocol.Town(id: newId(), name: 'Town $suffix', cityId: city.id),
        );
      },
    );
  }

  Future<void> seedTypedRow() {
    return _runSeed(
      success: 'Seeded a typed row on $focusedTargetLabel.',
      serverKind: 'typedRow',
      local: (session) async {
        final suffix = _counter.next('types');
        await protocol.Types.db.insertRow(
          session.crdtSession,
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
      },
    );
  }

  Future<void> addPerson() {
    return _runSeed(
      success: 'Added a person on $focusedTargetLabel.',
      serverKind: 'person',
      local: (session) async {
        final suffix = _counter.next('person');
        await protocol.Person.db.insertRow(
          session.crdtSession,
          protocol.Person(id: newId(), name: 'Person $suffix'),
        );
      },
    );
  }

  Future<void> createConcurrentUniqueInserts() {
    final name = _pendingUniqueName ??=
        'shared-name-${_counter.next('unique')}';
    return _runSeed(
      success: 'Inserted Unique.name "$name" on $focusedTargetLabel.',
      serverKind: 'unique',
      serverText: name,
      local: (session) async {
        await protocol.Unique.db.insertRow(
          session.crdtSession,
          protocol.Unique(id: newId(), name: name),
        );
      },
    );
  }

  Future<void> createUuidUniqueConflict() {
    final sharedValue = _pendingUniqueUuid ??= newId();
    return _runSeed(
      success: 'Inserted UniqueUuid on $focusedTargetLabel.',
      serverKind: 'uniqueUuid',
      serverText: sharedValue.uuid,
      local: (session) async {
        await protocol.UniqueUuid.db.insertRow(
          session.crdtSession,
          protocol.UniqueUuid(id: newId(), value: sharedValue),
        );
      },
    );
  }

  Future<void> createRestrictMergeScenario() {
    return _runSeed(
      success: 'Seeded a restrict parent on $focusedTargetLabel.',
      serverKind: 'person',
      serverText: 'Restricted parent',
      local: (session) async {
        final suffix = _counter.next('restrict');
        await protocol.Person.db.insertRow(
          session.crdtSession,
          protocol.Person(id: newId(), name: 'Restricted parent $suffix'),
        );
      },
    );
  }

  Future<void> createSetNullProjectionScenario() {
    return _runSeed(
      success: 'Seeded a set-null mayor candidate on $focusedTargetLabel.',
      serverKind: 'person',
      serverText: 'Attempted mayor',
      local: (session) async {
        final suffix = _counter.next('setnull');
        await protocol.Person.db.insertRow(
          session.crdtSession,
          protocol.Person(id: newId(), name: 'Attempted mayor $suffix'),
        );
      },
    );
  }

  Future<void> seedForeignKeyChain() {
    return _runSeed(
      success: 'Seeded a mixed FK chain on $focusedTargetLabel.',
      serverKind: 'fkChain',
      local: (session) async {
        final suffix = _counter.next('chain');
        final root = await protocol.FkChainRoot.db.insertRow(
          session.crdtSession,
          protocol.FkChainRoot(id: newId(), name: 'Root $suffix'),
        );
        final middle = await protocol.FkChainCascadeMiddle.db.insertRow(
          session.crdtSession,
          protocol.FkChainCascadeMiddle(
            id: newId(),
            name: 'Cascade middle $suffix',
            rootId: root.id,
          ),
        );
        final blocker = await protocol.FkChainRestrictBlocker.db.insertRow(
          session.crdtSession,
          protocol.FkChainRestrictBlocker(
            id: newId(),
            name: 'Restrict blocker $suffix',
            cascadeMiddleId: middle.id,
          ),
        );
        await protocol.FkChainMiddleSetNullChild.db.insertRow(
          session.crdtSession,
          protocol.FkChainMiddleSetNullChild(
            id: newId(),
            name: 'Set-null child $suffix',
            restrictBlockerId: blocker.id,
          ),
        );
        await protocol.FkChainMiddleCascadeChild.db.insertRow(
          session.crdtSession,
          protocol.FkChainMiddleCascadeChild(
            id: newId(),
            name: 'Cascade child $suffix',
            restrictBlockerId: blocker.id,
          ),
        );
      },
    );
  }

  // --- Row detail & editing -----------------------------------------------

  /// Loads the full record for [ref] on [slot], reading hidden rows through the
  /// raw session when needed.
  Future<RowDetail?> loadDetail(DemoRowRef ref, ReplicaSlot slot) async {
    final session = replicas[slot]!.session;
    if (session == null) return null;

    Future<RowDetail?> build<T extends Object>(
      Future<T?> Function(DatabaseSession) find,
      Map<String, dynamic> Function(T) json,
      List<EditableField> Function(T) editable,
    ) async {
      final visibleRow = await find(session.crdtSession);
      final row = visibleRow ?? await find(session.rawSession);
      if (row == null) return null;
      return RowDetail(
        ref: ref,
        slot: slot,
        tableName: ref.tableName,
        uuid: ref.id.uuid,
        visible: visibleRow != null,
        fields: json(row),
        editable: editable(row),
      );
    }

    switch (ref.tableName) {
      case 'person':
        return build<protocol.Person>(
          (s) => protocol.Person.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [
            EditableField('name', 'Name', r.name),
            EditableField('surname', 'Surname', r.surname ?? ''),
          ],
        );
      case 'address':
        return build<protocol.Address>(
          (s) => protocol.Address.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('street', 'Street', r.street)],
        );
      case 'city':
        return build<protocol.City>(
          (s) => protocol.City.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'town':
        return build<protocol.Town>(
          (s) => protocol.Town.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'unique':
        return build<protocol.Unique>(
          (s) => protocol.Unique.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'unique_uuid':
        return build<protocol.UniqueUuid>(
          (s) => protocol.UniqueUuid.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => const [],
        );
      case 'restrict_child':
        return build<protocol.RestrictChild>(
          (s) => protocol.RestrictChild.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'types':
        return build<protocol.Types>(
          (s) => protocol.Types.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('aText', 'Text', r.aText)],
        );
      case 'fk_chain_root':
        return build<protocol.FkChainRoot>(
          (s) => protocol.FkChainRoot.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'fk_chain_cascade_middle':
        return build<protocol.FkChainCascadeMiddle>(
          (s) => protocol.FkChainCascadeMiddle.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'fk_chain_restrict_blocker':
        return build<protocol.FkChainRestrictBlocker>(
          (s) => protocol.FkChainRestrictBlocker.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'fk_chain_middle_set_null_child':
        return build<protocol.FkChainMiddleSetNullChild>(
          (s) => protocol.FkChainMiddleSetNullChild.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      case 'fk_chain_middle_cascade_child':
        return build<protocol.FkChainMiddleCascadeChild>(
          (s) => protocol.FkChainMiddleCascadeChild.db.findById(s, ref.id),
          (r) => r.toJson(),
          (r) => [EditableField('name', 'Name', r.name)],
        );
      default:
        return null;
    }
  }

  /// Applies [values] (keyed by [EditableField.key]) to the row on [slot].
  Future<void> applyEdit(
    DemoRowRef ref,
    ReplicaSlot slot,
    Map<String, String> values,
  ) async {
    final session = replicas[slot]!.session;
    if (session == null) return;

    String? nullable(String key) {
      final value = values[key];
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }

    await _run('Updated ${ref.tableName} on ${slot.label}.', () async {
      final crdt = session.crdtSession;
      switch (ref.tableName) {
        case 'person':
          final row = await protocol.Person.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.Person.db.updateRow(
              crdt,
              row.copyWith(
                name: values['name'] ?? row.name,
                surname: nullable('surname'),
              ),
            );
          }
        case 'address':
          final row = await protocol.Address.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.Address.db.updateRow(
              crdt,
              row.copyWith(street: values['street'] ?? row.street),
            );
          }
        case 'city':
          final row = await protocol.City.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.City.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'town':
          final row = await protocol.Town.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.Town.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'unique':
          final row = await protocol.Unique.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.Unique.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'restrict_child':
          final row = await protocol.RestrictChild.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.RestrictChild.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'types':
          final row = await protocol.Types.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.Types.db.updateRow(
              crdt,
              row.copyWith(aText: values['aText'] ?? row.aText),
            );
          }
        case 'fk_chain_root':
          final row = await protocol.FkChainRoot.db.findById(crdt, ref.id);
          if (row != null) {
            await protocol.FkChainRoot.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'fk_chain_cascade_middle':
          final row = await protocol.FkChainCascadeMiddle.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainCascadeMiddle.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'fk_chain_restrict_blocker':
          final row = await protocol.FkChainRestrictBlocker.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainRestrictBlocker.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'fk_chain_middle_set_null_child':
          final row = await protocol.FkChainMiddleSetNullChild.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainMiddleSetNullChild.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        case 'fk_chain_middle_cascade_child':
          final row = await protocol.FkChainMiddleCascadeChild.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainMiddleCascadeChild.db.updateRow(
              crdt,
              row.copyWith(name: values['name'] ?? row.name),
            );
          }
        default:
          status = 'No editor is wired for ${ref.tableName}.';
      }
      await _refreshReplica(slot, notify: false);
    });
  }

  Future<void> deleteRow(DemoRowRef ref, ReplicaSlot slot) async {
    final session = replicas[slot]!.session;
    if (session == null) return;

    await _run('Deleted ${ref.tableName} on ${slot.label}.', () async {
      final crdt = session.crdtSession;
      switch (ref.tableName) {
        case 'person':
          final row = await protocol.Person.db.findById(crdt, ref.id);
          if (row != null) await protocol.Person.db.deleteRow(crdt, row);
        case 'address':
          final row = await protocol.Address.db.findById(crdt, ref.id);
          if (row != null) await protocol.Address.db.deleteRow(crdt, row);
        case 'city':
          final row = await protocol.City.db.findById(crdt, ref.id);
          if (row != null) await protocol.City.db.deleteRow(crdt, row);
        case 'town':
          final row = await protocol.Town.db.findById(crdt, ref.id);
          if (row != null) await protocol.Town.db.deleteRow(crdt, row);
        case 'unique':
          final row = await protocol.Unique.db.findById(crdt, ref.id);
          if (row != null) await protocol.Unique.db.deleteRow(crdt, row);
        case 'unique_uuid':
          final row = await protocol.UniqueUuid.db.findById(crdt, ref.id);
          if (row != null) await protocol.UniqueUuid.db.deleteRow(crdt, row);
        case 'restrict_child':
          final row = await protocol.RestrictChild.db.findById(crdt, ref.id);
          if (row != null) await protocol.RestrictChild.db.deleteRow(crdt, row);
        case 'types':
          final row = await protocol.Types.db.findById(crdt, ref.id);
          if (row != null) await protocol.Types.db.deleteRow(crdt, row);
        case 'fk_chain_root':
          final row = await protocol.FkChainRoot.db.findById(crdt, ref.id);
          if (row != null) await protocol.FkChainRoot.db.deleteRow(crdt, row);
        case 'fk_chain_cascade_middle':
          final row = await protocol.FkChainCascadeMiddle.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainCascadeMiddle.db.deleteRow(crdt, row);
          }
        case 'fk_chain_restrict_blocker':
          final row = await protocol.FkChainRestrictBlocker.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainRestrictBlocker.db.deleteRow(crdt, row);
          }
        case 'fk_chain_middle_set_null_child':
          final row = await protocol.FkChainMiddleSetNullChild.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainMiddleSetNullChild.db.deleteRow(crdt, row);
          }
        case 'fk_chain_middle_cascade_child':
          final row = await protocol.FkChainMiddleCascadeChild.db.findById(
            crdt,
            ref.id,
          );
          if (row != null) {
            await protocol.FkChainMiddleCascadeChild.db.deleteRow(crdt, row);
          }
        default:
          status = 'No delete is wired for ${ref.tableName}.';
      }
      await _refreshReplica(slot, notify: false);
    });
  }

  // --- Internals ----------------------------------------------------------

  Future<ReplicaSession> _openSession(DemoUser user, ReplicaSlot slot) async {
    final key = _sessionKey(user, slot);
    final existing = _sessions[key];
    if (existing != null) {
      replicas[slot]!.session = existing;
      return existing;
    }

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
      syncTables: demoSyncTables,
      persistentUserId: user.authUserId,
    );
    await crdtSession.db.initialize();
    final session = ReplicaSession(
      user: user,
      slot: slot,
      rawSession: rawSession,
      crdtSession: crdtSession,
    );
    _sessions[key] = session;
    replicas[slot]!.session = session;
    return session;
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

  Future<void> _resetReplicaStorage(DemoUser user, ReplicaSlot slot) async {
    await _stopReplicaStream(slot);

    final sessionsToClose = <ReplicaSession>[];
    _sessions.removeWhere((_, session) {
      final shouldRemove =
          session.slot == slot && session.user.username == user.username;
      if (shouldRemove) sessionsToClose.add(session);
      return shouldRemove;
    });

    replicas[slot]!.session = null;
    for (final session in sessionsToClose) {
      await session.rawSession.close();
    }

    final dir = await getApplicationSupportDirectory();
    final base = p.join(
      dir.path,
      'serverpod_offline_sync_demo',
      '${user.username}-${slot.name}.db',
    );
    for (final path in [base, '$base-wal', '$base-shm']) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _openSession(user, slot);
    replicas[slot]!
      ..phase = online ? SyncPhase.idle : SyncPhase.offline
      ..lastSyncedLabel = null
      ..error = null;
    _pendingUniqueName = null;
    _pendingUniqueUuid = null;
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

  Future<void> _run(String success, Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
      status = success;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
      status = 'Failed: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
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
  EditableField(this.key, this.label, this.value);

  final String key;
  final String label;
  final String value;
}

/// The complete record behind a tree row, plus its CRDT visibility status.
class RowDetail {
  RowDetail({
    required this.ref,
    required this.slot,
    required this.tableName,
    required this.uuid,
    required this.visible,
    required this.fields,
    required this.editable,
  });

  final DemoRowRef ref;
  final ReplicaSlot slot;
  final String tableName;
  final String uuid;
  final bool visible;
  final Map<String, dynamic> fields;
  final List<EditableField> editable;

  /// The CRDT scope id stored on the row, if any.
  String? get scopeId => fields['scopeId']?.toString();
}
