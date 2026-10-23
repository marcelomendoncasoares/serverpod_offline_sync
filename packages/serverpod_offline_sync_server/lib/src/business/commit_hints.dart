import 'package:serverpod/serverpod.dart' show UuidValue;

/// Best-effort delivery of committed space revisions between server processes.
///
/// A transport belongs to the Serverpod instance that initializes it. Delivery
/// may be lost, duplicated or reordered: durable recovery remains required.
/// Payloads contain revision identities, never row data or checkpoint authority.
abstract interface class OfflineSyncCommitHints {
  /// Committed revisions received from other processes, keyed by space UUID.
  Stream<Map<UuidValue, UuidValue>> get changes;

  /// Enqueues revisions without awaiting network work or throwing on failure.
  void publish(Map<UuidValue, UuidValue> revisions);

  /// Stops delivery and releases all transport resources.
  Future<void> close();
}
