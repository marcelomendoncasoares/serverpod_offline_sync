import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'dst_random.dart';
import 'dst_world.dart';

/// The phase in which a network action actually takes place.
enum DstNetworkPhase { setup, scheduled, drain }

/// An immutable captured batch, including the committed receiver baseline.
///
/// Generated changes and their domain payloads are mutable. Store the wire
/// representation and decode a fresh copy for each merge, so even a merge that
/// mutates its input cannot change a later replay.
class DstDelivery {
  DstDelivery({
    required this.source,
    required this.target,
    required this.spaceUuid,
    required CrdtMergeSet changes,
    List<Hlc> checkpoints = const [],
    this.partial = false,
    this.replay = false,
  }) : payload = jsonEncode(changes),
       checkpoints = List.unmodifiable(checkpoints);

  DstDelivery._replay(DstDelivery original)
    : source = original.source,
      target = original.target,
      spaceUuid = original.spaceUuid,
      payload = original.payload,
      checkpoints = original.checkpoints,
      partial = original.partial,
      replay = true;

  final DstReplica source;
  final DstReplica target;
  final UuidValue spaceUuid;
  final String payload;
  final List<Hlc> checkpoints;
  final bool partial;
  final bool replay;

  CrdtMergeSet get changes => [
    for (final value in jsonDecode(payload) as List)
      target.rawSession.db.serializationManager.deserialize<CrdtMergeChange>(value),
  ];
}

/// Delays, reorders, redelivers and isolates complete collected batches.
///
/// Full mode retains the original convergence experiment. Delta mode always
/// collects against facts already committed at the receiver, never against a
/// pending delivery. Thus pending batches may overlap but do not depend on one
/// another arriving first. Neither mode splits batches or drops them forever.
class DstAdversary {
  DstAdversary(
    this.random,
    this.replicas, {
    this.delivery = DstDeliveryMode.full,
  });

  final DstDeliveryMode delivery;
  DstNetworkPhase phase = DstNetworkPhase.scheduled;

  static const receiveIsolationProbability = 0.2;
  static const collectionProbability = 0.8;
  static const resendProbability = 0.15;

  /// The simulation's randomness.
  final DstRandom random;

  /// Every replica in the simulation.
  final List<DstReplica> replicas;

  final List<DstDelivery> _pending = [];
  final Map<String, Set<String>> _deliveredKeys = {};
  final Map<String, int> _partitionedUntil = {};
  final Map<String, List<DstDelivery>> _replayable = {};
  final Map<String, int> _observations = {};
  var _round = 0;

  void _count(String name, [int amount = 1]) {
    _observations
      ..update(name, (value) => value + amount, ifAbsent: () => amount)
      ..update(
        '${phase.name}.$name',
        (value) => value + amount,
        ifAbsent: () => amount,
      );
  }

  int get scheduledPartialBatches => _observations['scheduled.partialBatches'] ?? 0;

  /// Batches merged so far, for reporting how much work a seed actually did.
  int mergeCount = 0;
  int receiveIsolationEvents = 0;
  int duplicateBatches = 0;
  int maxBatchSize = 0;
  int deliveredChanges = 0;

  Map<String, int> get metrics => {
    ..._observations,
    'merges': mergeCount,
    'receiveIsolationEvents': receiveIsolationEvents,
    'duplicateBatches': duplicateBatches,
    'maxBatchSize': maxBatchSize,
    'deliveredChanges': deliveredChanges,
  };

  /// Advances the schedule by one round.
  ///
  /// Called after the simulation authors operations, so each round mixes fresh
  /// local writes with whatever the adversary chooses to deliver now.
  Future<void> step(Future<void> Function(DstReplica) onMerged) async {
    _round++;

    if (random.chance(receiveIsolationProbability)) _partitionRandomReplica();
    if (random.chance(collectionProbability)) await _collectFromRandomReplica();

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
        for (final spaceUuid in replica.spaceUuids) {
          await _collect(replica, spaceUuid, allowResend: false);
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
      'batch is not idempotent or checkpoint collection cannot settle. '
      'Delivery mode: ${delivery.name}; metrics: $metrics',
    );
  }

  void _partitionRandomReplica() {
    receiveIsolationEvents++;
    _count('receiveIsolationEvents');
    final replica = random.pick(replicas);
    _partitionedUntil[replica.name] = _round + random.between(1, 3);
  }

  bool _isPartitioned(DstReplica replica) =>
      (_partitionedUntil[replica.name] ?? 0) > _round;

  Future<void> _collectFromRandomReplica() async {
    final source = random.pick(replicas);
    final spaceUuid = random.pickOrNull(source.spaceUuids);
    if (spaceUuid == null) return;
    await _collect(source, spaceUuid);
  }

  /// Collects [source]'s changes for [spaceUuid] and queues them for every
  /// other replica that holds the space.
  Future<void> _collect(
    DstReplica source,
    UuidValue spaceUuid, {
    bool allowResend = true,
  }) async {
    final changes = await source.collect(spaceUuid);
    if (changes.isEmpty && delivery == DstDeliveryMode.full) return;

    for (final target in replicas) {
      if (identical(target, source)) continue;
      if (!target.spaceUuids.contains(spaceUuid)) continue;

      if (delivery == DstDeliveryMode.delta) {
        await _collectDelta(source, target, spaceUuid, changes.length, allowResend);
        continue;
      }

      _count('fullCollections');
      final delivered = _deliveredKeys.putIfAbsent(target.name, () => {});
      // Occasionally resend what the target already merged. Redelivery must be
      // a no-op, so this is the idempotence probe rather than wasted work.
      // During quiescence only newly observed facts can keep the network busy;
      // deliberate duplicates must not masquerade as merge-authored changes.
      final resend = allowResend && random.chance(resendProbability);
      final fresh = resend
          ? changes
          : [
              for (final change in changes)
                if (!delivered.contains(dstChangeKey(change))) change,
            ];
      if (fresh.isEmpty) continue;

      _pending.add(
        DstDelivery(
          source: source,
          target: target,
          spaceUuid: spaceUuid,
          changes: changes,
        ),
      );
    }
  }

  Future<void> _collectDelta(
    DstReplica source,
    DstReplica target,
    UuidValue spaceUuid,
    int fullSize,
    bool allowResend,
  ) async {
    final edge = '${source.name}|${target.name}|$spaceUuid';
    final history = _replayable[edge] ?? const <DstDelivery>[];
    if (allowResend && random.chance(resendProbability) && history.isNotEmpty) {
      _pending.add(DstDelivery._replay(random.pick(history)));
    }

    final checkpoints = await target.checkpoints(spaceUuid);
    _count('checkpointCollections');
    final advanced = checkpoints.any(
      (checkpoint) =>
          checkpoint.nodeId != target.nodeUuid &&
          checkpoint > Hlc.zero(checkpoint.nodeId),
    );
    if (advanced) _count('advancedCheckpointCollections');

    // No local writes or merges interleave the full-size observation above
    // and this collection. The full export measures omission only; it is never
    // delivered as a repair in delta mode.
    final changes = await source.collect(spaceUuid, checkpoints: checkpoints);
    if (changes.isEmpty) {
      _count('emptyCollections');
      return;
    }

    _pending.add(
      DstDelivery(
        source: source,
        target: target,
        spaceUuid: spaceUuid,
        changes: changes,
        checkpoints: checkpoints,
        partial: advanced && changes.length < fullSize,
      ),
    );
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

    final changes = delivery.changes;
    try {
      await delivery.target.merge(changes, delivery.spaceUuid);
    } on Exception catch (exception) {
      // As with local operations, database errors arrive without engine
      // frames, so the batch that caused them is described here.
      final keys = changes.map(dstChangeKey).join('\n  ');
      throw StateError(
        'Merging ${changes.length} changes for space '
        '${delivery.spaceUuid} from ${delivery.source} into ${delivery.target} failed: $exception\n'
        'Mode: ${this.delivery.name}; checkpoints: ${delivery.checkpoints}; replay: ${delivery.replay}\n'
        'Batch:\n  $keys',
      );
    }
    final prior = _deliveredKeys[delivery.target.name] ?? {};
    if (changes.any((change) => prior.contains(dstChangeKey(change)))) {
      duplicateBatches++;
      _count('duplicateBatches');
    }
    if (changes.length > maxBatchSize) maxBatchSize = changes.length;
    final phaseMaxKey = '${phase.name}.maxBatchSize';
    _observations.update(
      phaseMaxKey,
      (value) => value > changes.length ? value : changes.length,
      ifAbsent: () => changes.length,
    );
    deliveredChanges += changes.length;
    _count('deliveredChanges', changes.length);
    mergeCount++;
    _count('merges');
    if (delivery.replay) _count('explicitReplays');
    if (delivery.partial && !delivery.replay) _count('partialBatches');
    final repeated = changes
        .where((change) => prior.contains(dstChangeKey(change)))
        .length;
    _count('repeatedChanges', repeated);
    _count('freshChanges', changes.length - repeated);
    if (this.delivery == DstDeliveryMode.delta && !delivery.replay) {
      final edge =
          '${delivery.source.name}|${delivery.target.name}|${delivery.spaceUuid}';
      _replayable.putIfAbsent(edge, () => []).add(delivery);
    }
    _trace(delivery);

    _deliveredKeys
        .putIfAbsent(delivery.target.name, () => {})
        .addAll(changes.map(dstChangeKey));

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
    print(
      'merge ${delivery.source} -> ${delivery.target} '
      'mode=${this.delivery.name} checkpoints=${delivery.checkpoints} '
      'replay=${delivery.replay}: ${relevant.join('  ||  ')}',
    );
  }

  static const _maxQuiescePasses = 24;
}
