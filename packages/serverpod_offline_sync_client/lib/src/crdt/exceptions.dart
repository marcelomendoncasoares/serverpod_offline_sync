import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../protocol/protocol.dart';

/// Base type for CRDT sync session failures.
sealed class CrdtSyncException implements Exception {
  const CrdtSyncException();
}

/// Thrown when the inbound sync stream closes before an expected event arrives.
final class CrdtSyncStreamClosedException extends CrdtSyncException {
  /// Creates a [CrdtSyncStreamClosedException].
  const CrdtSyncStreamClosedException({required this.phase});

  /// The protocol phase that was interrupted.
  final String phase;

  @override
  String toString() =>
      'CrdtSyncStreamClosedException: sync stream closed before $phase event.';
}

/// Thrown when the inbound sync stream delivers an event of the wrong type.
final class CrdtSyncUnexpectedEventException<T extends CrdtSyncStreamEvent>
    extends CrdtSyncException {
  /// Creates a [CrdtSyncUnexpectedEventException].
  const CrdtSyncUnexpectedEventException({
    required this.expected,
    required this.received,
  });

  /// A description of the expected event type or types.
  final String expected;

  /// The event that was received instead.
  final CrdtSyncStreamEvent received;

  @override
  String toString() =>
      'CrdtSyncUnexpectedEventException: expected $expected, but '
      'received "${received.runtimeType.className}" instead.';
}

/// Thrown when a peer's since-HLC frame does not reference the local node id.
final class CrdtSyncInvalidSinceHlcException extends CrdtSyncException {
  /// Creates a [CrdtSyncInvalidSinceHlcException].
  const CrdtSyncInvalidSinceHlcException({
    required this.receivedNodeId,
    required this.expectedNodeId,
  });

  /// The node id carried by the peer's since-HLC frame.
  final UuidValue receivedNodeId;

  /// The local node id that was expected.
  final UuidValue expectedNodeId;

  @override
  String toString() =>
      'CrdtSyncInvalidSinceHlcException: peer since HLC node id '
      '"$receivedNodeId" does not match local node id "$expectedNodeId".';
}

/// Thrown when the sync tables hash sent by a peer does not match locally.
final class SyncTablesHashMismatchException extends CrdtSyncException {
  /// Creates a [SyncTablesHashMismatchException].
  const SyncTablesHashMismatchException({
    required this.received,
    required this.expected,
  });

  /// The hash received from the remote peer.
  final String received;

  /// The hash computed locally from the configured sync tables.
  final String expected;

  @override
  String toString() =>
      'SyncTablesHashMismatchException: schema hash mismatch. Received '
      '"$received", expected "$expected". Ensure both sides are on the same '
      'schema version before syncing.';
}

extension on Type {
  /// The name of the class without the leading underscore and without the 'Impl' suffix.
  String get className {
    final name = toString();
    if (name.startsWith('_') && name.endsWith('Impl')) {
      return name.substring(1, name.length - 4);
    }
    return name;
  }
}
