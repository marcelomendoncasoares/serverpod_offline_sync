import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'dst_random.dart';
import 'dst_world.dart';

/// One batch of changes waiting to be merged into a replica.
class DstDelivery {
  /// Creates a pending delivery.
  DstDelivery({
    required this.target,
    required this.scopeUuid,
    required this.changes,
  });

  /// The replica that will merge the batch.
  final DstReplica target;

  /// The scope the batch belongs to.
  final UuidValue scopeUuid;

  /// The changes to merge.
  final CrdtMergeSet changes;
}

/// Schedules change delivery between replicas adversarially.
///
/// The adversary reorders, delays, redelivers, and partitions. Two moves are
/// deliberately *not* available, both for the same reason: the merge contract
/// states that each batch arrives as a causally complete snapshot of the
/// sender (`docs/foreign-key-invariants.md`).
///
/// - **Never drops permanently.** Dropping would manufacture failures outside
///   the contract instead of finding real ones.
/// - **Never splits a collected batch.** An earlier version of this harness
///   split batches at a random pivot to vary framing. That delivers, say, a
///   delete without its insert; the engine ignores the orphaned change, the
///   harness marks it delivered, and the fact is lost forever - which then
///   surfaces as a bogus convergence failure. Chunking in the real protocol
///   sits *below* the merge (`chunked()` feeds frames that
///   `collectNextBatch` reassembles until `CrdtSyncEndOfBatch`), so the whole
///   cycle is the causal unit and splitting here models nothing real.
///
/// Delay, reorder, and redelivery are the honest moves; redelivery is how
/// idempotence gets probed.
class DstAdversary {
  /// Creates an adversary over [replicas].
  DstAdversary(this.random, this.replicas);

  /// The simulation's randomness.
  final DstRandom random;

  /// Every replica in the simulation.
  final List<DstReplica> replicas;

  final List<DstDelivery> _pending = [];
  final Map<String, Set<String>> _deliveredKeys = {};
  final Map<String, int> _partitionedUntil = {};
  var _round = 0;

  /// Batches merged so far, for reporting how much work a seed actually did.
  int mergeCount = 0;

  /// Advances the schedule by one round.
  ///
  /// Called after the simulation authors operations, so each round mixes fresh
  /// local writes with whatever the adversary chooses to deliver now.
  Future<void> step(Future<void> Function(DstReplica) onMerged) async {
    _round++;

    if (random.chance(0.2)) _partitionRandomReplica();
    if (random.chance(0.8)) await _collectFromRandomReplica();

    final deliveries = random.between(1, 3);
    for (var index = 0; index < deliveries; index++) {
      await _deliverOne(onMerged);
    }
  }

  /// Delivers everything until no replica has anything new for a peer.
  ///
  /// Convergence properties are only meaningful once the network is quiet, so
  /// every run ends here before the agreement oracle runs.
  Future<void> quiesce(Future<void> Function(DstReplica) onMerged) async {
    _partitionedUntil.clear();

    for (var pass = 0; pass < _maxQuiescePasses; pass++) {
      for (final replica in replicas) {
        for (final scopeUuid in replica.scopeUuids) {
          await _collect(replica, scopeUuid);
        }
      }
      if (_pending.isEmpty) return;
      while (_pending.isNotEmpty) {
        await _deliverOne(onMerged);
      }
    }

    throw StateError(
      'The simulation did not quiesce after $_maxQuiescePasses passes. '
      'Replicas keep producing changes for each other, which means merging a '
      'batch is not idempotent: a merge is re-authoring facts instead of '
      'absorbing them.',
    );
  }

  void _partitionRandomReplica() {
    final replica = random.pick(replicas);
    _partitionedUntil[replica.name] = _round + random.between(1, 3);
  }

  bool _isPartitioned(DstReplica replica) =>
      (_partitionedUntil[replica.name] ?? 0) > _round;

  Future<void> _collectFromRandomReplica() async {
    final source = random.pick(replicas);
    final scopeUuid = random.pickOrNull(source.scopeUuids);
    if (scopeUuid == null) return;
    await _collect(source, scopeUuid);
  }

  /// Collects [source]'s changes for [scopeUuid] and queues them for every
  /// other replica that holds the scope.
  Future<void> _collect(DstReplica source, UuidValue scopeUuid) async {
    final changes = await source.collect(scopeUuid);
    if (changes.isEmpty) return;

    for (final target in replicas) {
      if (identical(target, source)) continue;
      if (!target.scopeUuids.contains(scopeUuid)) continue;

      final delivered = _deliveredKeys.putIfAbsent(target.name, () => {});
      // Occasionally resend what the target already merged. Redelivery must be
      // a no-op, so this is the idempotence probe rather than wasted work.
      final resend = random.chance(0.15);
      final fresh = resend
          ? changes
          : [
              for (final change in changes)
                if (!delivered.contains(dstChangeKey(change))) change,
            ];
      if (fresh.isEmpty) continue;

      _pending.add(
        DstDelivery(target: target, scopeUuid: scopeUuid, changes: fresh),
      );
    }
  }

  Future<void> _deliverOne(Future<void> Function(DstReplica) onMerged) async {
    final deliverable = [
      for (final delivery in _pending)
        if (!_isPartitioned(delivery.target)) delivery,
    ];
    if (deliverable.isEmpty) return;

    // Choosing an arbitrary pending batch - not the oldest - is what makes
    // delivery order adversarial rather than FIFO.
    final delivery = random.pick(deliverable);
    _pending.remove(delivery);

    try {
      await delivery.target.merge(delivery.changes, delivery.scopeUuid);
    } on Exception catch (exception) {
      // As with local operations, database errors arrive without engine
      // frames, so the batch that caused them is described here.
      final keys = delivery.changes.map(dstChangeKey).join('\n  ');
      throw StateError(
        'Merging ${delivery.changes.length} changes for scope '
        '${delivery.scopeUuid} into ${delivery.target} failed: $exception\n'
        'Batch:\n  $keys',
      );
    }
    mergeCount++;
    _trace(delivery);

    _deliveredKeys
        .putIfAbsent(delivery.target.name, () => {})
        .addAll(delivery.changes.map(dstChangeKey));

    await onMerged(delivery.target);
  }

  /// Prints each merge touching the table named by `DST_DEBUG_TABLE`.
  ///
  /// A divergence is usually explained by *which* facts a replica had merged
  /// when it derived its state, and in what order — which the end-of-run
  /// snapshot cannot show. Setting the variable prints that delivery order:
  ///
  /// ```sh
  /// DST_DEBUG_TABLE=unique DST_SEED_BASE=24313 DST_SEEDS=1 dart test -P dst
  /// ```
  void _trace(DstDelivery delivery) {
    final raw = Platform.environment['DST_DEBUG_TABLE'];
    if (raw == null || raw.isEmpty) return;
    final tables = raw.split(',').map((name) => name.trim()).toSet();
    final relevant = [
      for (final change in delivery.changes)
        if (tables.contains(change.tableName)) dstChangeKey(change),
    ];
    if (relevant.isEmpty) return;
    // Printing is the point: this is an opt-in trace read from the test runner
    // output while diagnosing a failing seed.
    // ignore: avoid_print
    print('merge -> ${delivery.target}: ${relevant.join('  ||  ')}');
  }

  static const _maxQuiescePasses = 24;
}
