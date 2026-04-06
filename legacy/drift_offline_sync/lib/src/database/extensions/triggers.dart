import 'package:drift/drift.dart';

import '../database.dart';

/// Extensions for [CrdtDatabase] to manage triggers.
extension CrdtDatabaseTriggersExtensions on CrdtDatabase {
  /// Disables the CRDT triggers for the current node.
  Future<void> disableTriggers() async {
    await _updateTriggersStatus(false);
  }

  /// Enables the CRDT triggers for the current node.
  Future<void> enableTriggers() async {
    await _updateTriggersStatus(true);
  }

  /// Disables the CRDT triggers for the duration of the [operation].
  Future<T> withTriggersDisabled<T>(Future<T> Function() operation) async {
    await disableTriggers();
    try {
      return await operation();
    } finally {
      await enableTriggers();
    }
  }

  Future<void> _updateTriggersStatus(bool enabled) async {
    await managers.crdtControlTable
        .filter((t) => t.userId.equals(userId) & t.nodeId.equals(nodeId))
        .update((t) => t(crdtTriggersOn: Value(enabled)));
  }
}
