part of 'recorder.dart';

/// A live sync's interest in committed changes. Hints carry no cursor authority.
@internal
class OfflineSyncRecoverySubscription {
  OfflineSyncRecoverySubscription._(
    this._recovery,
    this._session,
    this._userId,
    Iterable<UuidValue> spaces,
    this._onChanged,
  ) : _spaces = spaces.toSet(),
      _zone = Zone.current;

  final _SyncRecovery _recovery;
  final DatabaseSession _session;
  final UuidValue _userId;
  final void Function() _onChanged;
  final Zone _zone;
  Set<UuidValue> _spaces;

  /// Replaces the spaces covered by this stream after grant reconciliation.
  void updateSpaces(Iterable<UuidValue> spaces) {
    _spaces = spaces.toSet();
  }

  /// Unsubscribes and joins any database work borrowing this stream's session.
  Future<void> close() => _recovery.remove(this);
}

/// Recovery for missed local hints, caller-owned commits and other processes.
/// A scan reads two indexed sets, regardless of how many streams share them.
/// It never opens a transaction or overlaps another recovery scan.
class _SyncRecovery {
  static const _interval = Duration(milliseconds: 1200);

  final _subscriptions = <OfflineSyncRecoverySubscription>{};
  final _versions = <UuidValue, int?>{};
  final _memberships = <UuidValue, String>{};
  Timer? _timer;
  Future<void>? _pending;
  OfflineSyncRecoverySubscription? _owner;

  /// These revisions have already woken this context's listeners after commitment.
  /// Recovery still compares durable revisions, so a later external commit
  /// cannot be hidden by a locally delivered hint. A scan racing a commit may
  /// conservatively wake again; revisions never authorize cursor progress.
  void recordDeliveredCommit(UuidValue space, int revision) {
    // Preserve the first unknown-baseline wakeup and retain only spaces
    // already tracked by recovery. This lookup is independent of stream count.
    if (_versions.containsKey(space)) {
      _versions[space] = revision;
    }
  }

  OfflineSyncRecoverySubscription subscribe(
    DatabaseSession session,
    UuidValue user,
    Iterable<UuidValue> spaces,
    void Function() onChanged,
  ) {
    final subscription = OfflineSyncRecoverySubscription._(
      this,
      session,
      user,
      spaces,
      onChanged,
    );
    _subscriptions.add(subscription);
    _schedule();
    return subscription;
  }

  Future<void> remove(OfflineSyncRecoverySubscription subscription) async {
    if (!_subscriptions.remove(subscription)) return;
    if (_subscriptions.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
    _prune();
    OfflineSyncDiagnostics.event('sync.recoveryDetached', {
      'waitingForScan': identical(_owner, subscription),
      'remainingSubscriptions': _subscriptions.length,
    });
    if (identical(_owner, subscription)) await _pending;
  }

  void _schedule() {
    if (_subscriptions.isEmpty || _timer != null || _pending != null) return;
    // Do not retain the first subscriber's zone after that stream closes.
    _timer = Zone.root.run(() => Timer(_interval, _start));
  }

  void _start() {
    _timer = null;
    if (_subscriptions.isEmpty) return;
    final owner = _owner = _subscriptions.first;
    _pending = owner._zone.run(() => _scan(owner._session)).whenComplete(() {
      _owner = null;
      _pending = null;
      _prune();
      _schedule();
    });
  }

  void _prune() {
    final spaces = {for (final s in _subscriptions) ...s._spaces};
    final users = {for (final s in _subscriptions) s._userId};
    _versions.removeWhere((space, _) => !spaces.contains(space));
    _memberships.removeWhere((user, _) => !users.contains(user));
  }

  Future<void> _scan(DatabaseSession session) async {
    final spaces = {for (final s in _subscriptions) ...s._spaces};
    final users = {for (final s in _subscriptions) s._userId};
    try {
      await OfflineSyncDiagnostics.measure(
        'sync.recoveryScan',
        () async {
          final versions = <UuidValue, int?>{for (final id in spaces) id: null};
          if (spaces.isNotEmpty) {
            for (final row in await OfflineSyncSpace.db.find(
              session,
              where: (t) => t.uuidSpaceId.inSet(spaces),
            )) {
              versions[row.uuidSpaceId] = row.syncRevision;
            }
          }

          final grants = <UuidValue, List<String>>{for (final id in users) id: []};
          for (final row in await OfflineSyncSpaceMember.db.find(
            session,
            where: (t) => t.userUuid.inSet(users),
          )) {
            grants[row.userUuid]!.add('${row.spaceId}:${row.role.name}');
          }
          final memberships = {
            for (final entry in grants.entries)
              entry.key: (entry.value..sort()).join(','),
          };

          // An unknown version must wake its subscribers. Otherwise a commit
          // between initial capture and this first baseline could be missed.
          final changedSpaces = {
            for (final entry in versions.entries)
              if (!_versions.containsKey(entry.key) ||
                  _versions[entry.key] != entry.value)
                entry.key,
          };
          final changedUsers = {
            for (final entry in memberships.entries)
              if (_memberships[entry.key] != entry.value) entry.key,
          };
          _versions.addAll(versions);
          _memberships.addAll(memberships);

          var notified = 0;
          for (final subscription in _subscriptions.toList()) {
            if (!changedUsers.contains(subscription._userId) &&
                !subscription._spaces.any(changedSpaces.contains)) {
              continue;
            }
            subscription._zone.run(() {
              OfflineSyncDiagnostics.event('sync.recoveryWakeup');
              subscription._onChanged();
            });
            notified++;
          }
          OfflineSyncDiagnostics.event('sync.recoveryResult', {
            'changedSpaces': changedSpaces.length,
            'changedUsers': changedUsers.length,
            'notified': notified,
          });
        },
        data: {
          'spaces': spaces.length,
          'users': users.length,
          'subscriptions': _subscriptions.length,
        },
      );
    } on Object catch (error) {
      // Retry durable inspection on the next scan. A failed recovery read must
      // not terminate otherwise healthy streams or publish guessed versions.
      OfflineSyncDiagnostics.event('sync.recoveryFailed', {
        'type': error.runtimeType.toString(),
      });
    }
  }
}
