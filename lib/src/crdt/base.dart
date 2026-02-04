import 'dart:async';

import 'package:meta/meta.dart';

import '../database/database.dart';
import '../hlc/hlc.dart';
import '../hlc/stateful.dart';

/// Base class for CRDT implementations.
///
/// This class provides the basic functionality for a CRDT implementation.
/// It is not meant to be used directly, but rather to be extended by concrete
/// implementations.
abstract class CrdtBase {
  /// Creates a new instance of [CrdtBase].
  CrdtBase({required this.userId, required this.nodeId});

  /// The user ID for the CRDT system.
  final String userId;

  /// The node ID of the CRDT.
  final String nodeId;

  /// The stateful canonical time of the CRDT.
  late final StatefulHlc _statefulCanonicalTime = StatefulHlc.cached(userId, nodeId);

  /// The canonical time of the CRDT.
  Hlc get canonicalTime => _statefulCanonicalTime.lastHlc;

  /// Returns the last modified timestamp, optionally filtering for or against a
  /// specific node id. Useful to get "modified since" timestamps for executing
  /// synchronization.
  Future<Hlc?> getLastModified({
    String? onlyNodeId,
    String? exceptNodeId,
  });

  /// Get a list of [CrdtDataEntry] with the changes to be merged.
  ///
  /// Set the filtering parameters to to generate subsets:
  /// [onlyNodeId] only records set by the specified node.
  /// [exceptNodeId] only records not set by the specified node.
  /// [modifiedAfter] records modified after the specified [Hlc].
  Future<Iterable<CrdtDataEntry>> getChangeset({
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedAfter,
  });

  /// Save the [changeset] to the database.
  ///
  /// When saving, must be careful to only override values that are older than
  /// the [Hlc] of the changeset entry. If there are any guardrails to be
  /// applied to the saved data, they should be applied here.
  ///
  /// The [receivedHlcs] is a list of HLCs, one for each external node. It must
  /// be saved separately since it will be used to request updates from external
  /// nodes on next syncs.
  ///
  /// It is recommended to use a transaction to ensure the integrity of the
  /// data and allow for rollback in case of errors.
  ///
  /// Note that this method is only meant to be used internally by the [merge]
  /// method and should not be called directly.
  @protected
  Future<void> saveChangeset(
    Iterable<CrdtDataEntry> changeset,
    Iterable<Hlc> receivedHlcs,
  );

  /// Merge [changeset] with the local dataset.
  Future<void> merge(Iterable<CrdtDataEntry> changeset) async {
    if (changeset.isEmpty) return;

    final receivedHlcs = _extractLastReceivedHlcs(changeset);
    await saveChangeset(changeset, receivedHlcs);

    if (receivedHlcs.isEmpty) return;
    _statefulCanonicalTime.merge(receivedHlcs.max);
  }

  /// Extracts the last received HLCs from the changeset.
  Iterable<Hlc> _extractLastReceivedHlcs(Iterable<CrdtDataEntry> changeset) {
    final receivedHlcs = <String, Hlc>{};
    for (final entry in changeset) {
      if (entry.hlcTimestamp.nodeId == nodeId) continue;
      receivedHlcs.addOrUpdate(entry.hlcTimestamp);
    }
    return receivedHlcs.values;
  }
}

extension on Iterable<Hlc> {
  Hlc get max => reduce((a, b) => a > b ? a : b);
}

extension on Map<String, Hlc> {
  void addOrUpdate(Hlc hlc) {
    final registeredHlc = this[hlc.nodeId];
    if (registeredHlc == null) {
      this[hlc.nodeId] = hlc;
    } else if (registeredHlc < hlc) {
      this[hlc.nodeId] = hlc;
    }
  }
}
