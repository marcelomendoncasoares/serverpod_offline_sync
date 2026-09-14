import 'package:meta/meta.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../generated/protocol.dart';
import '../hlc/hlc.dart';

/// Base type for CRDT sync session failures.
sealed class OfflineSyncException implements Exception {
  const OfflineSyncException();
}

/// Thrown when the inbound sync stream closes before an expected event arrives.
final class OfflineSyncStreamClosedException extends OfflineSyncException {
  /// Creates a [OfflineSyncStreamClosedException].
  const OfflineSyncStreamClosedException({required this.phase});

  /// The protocol phase that was interrupted.
  final String phase;

  @override
  String toString() =>
      'OfflineSyncStreamClosedException: sync stream closed before $phase event.';
}

/// Thrown when the inbound sync stream delivers an event of the wrong type.
final class OfflineSyncUnexpectedEventException<T extends OfflineSyncStreamEvent>
    extends OfflineSyncException {
  /// Creates a [OfflineSyncUnexpectedEventException].
  const OfflineSyncUnexpectedEventException({
    required this.expected,
    required this.received,
  });

  /// A description of the expected event type or types.
  final String expected;

  /// The event that was received instead.
  final OfflineSyncStreamEvent received;

  @override
  String toString() =>
      'OfflineSyncUnexpectedEventException: expected $expected, but '
      'received "${received.runtimeType.className}" instead.';
}

/// Thrown when the sync tables hash sent by a peer does not match locally.
final class OfflineSyncTablesHashMismatchException extends OfflineSyncException {
  /// Creates a [OfflineSyncTablesHashMismatchException].
  const OfflineSyncTablesHashMismatchException({
    required this.received,
    required this.expected,
  });

  /// The hash received from the remote peer.
  final String received;

  /// The hash computed locally from the configured sync tables.
  final String expected;

  @override
  String toString() =>
      'OfflineSyncTablesHashMismatchException: schema hash mismatch. Received '
      '"$received", expected "$expected". Ensure both sides are on the same '
      'schema version before syncing.';
}

/// Thrown when sync observes terminal CRDT metadata/domain-row inconsistency.
final class OfflineSyncIntegrityViolationException extends OfflineSyncException {
  /// Creates a [OfflineSyncIntegrityViolationException].
  const OfflineSyncIntegrityViolationException(this.violation);

  /// The integrity violation that caused sync to stop.
  final OfflineSyncIntegrityViolation violation;

  @override
  String toString() {
    final persisted = violation.id == null
        ? ''
        : ' Persisted violation id: ${violation.id}.';
    final row = '${violation.domainTableName}.${violation.uuidRowId}';
    return switch (violation.type) {
      OfflineSyncViolationType.ownershipCollision =>
        'OfflineSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} for $row '
            'belongs to space ${violation.ownerSpaceUuid}, but sync attempted '
            'space ${violation.incomingSpaceUuid}.$persisted',
      OfflineSyncViolationType.missingDomainRow =>
        'OfflineSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} references '
            'missing domain row $row for space '
            '${violation.incomingSpaceUuid}.$persisted',
      OfflineSyncViolationType.unauthorizedWrite =>
        'OfflineSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} rejected '
            'write to $row in space ${violation.incomingSpaceUuid}.$persisted',
    };
  }
}

/// Thrown when a user attempts to act in a space they are not a member of.
final class OfflineSyncSpaceMembershipException implements Exception {
  /// Creates a [OfflineSyncSpaceMembershipException].
  const OfflineSyncSpaceMembershipException({
    required this.userId,
    required this.spaceId,
  });

  /// The authenticated user id supplied to `transactionForUser`.
  final UuidValue userId;

  /// The space id the transaction attempted to act in.
  final UuidValue spaceId;

  @override
  String toString() =>
      'OfflineSyncSpaceMembershipException: user "$userId" is not a member of '
      'space "$spaceId".';
}

/// Thrown when a user attempts to write in a space with a non-writable role.
final class OfflineSyncSpaceRoleException implements Exception {
  /// Creates a [OfflineSyncSpaceRoleException].
  const OfflineSyncSpaceRoleException({
    required this.userId,
    required this.spaceId,
    this.role,
  });

  /// The authenticated user id supplied to `transactionForUser`.
  final UuidValue userId;

  /// The space id the transaction attempted to write in.
  final UuidValue spaceId;

  /// The role that does not allow writes.
  final OfflineSyncSpaceRole? role;

  @override
  String toString() =>
      'OfflineSyncSpaceRoleException: user "$userId" with role "$role" cannot write '
      'in space "$spaceId".';
}

@internal
final class PendingOutboundIntegrityViolation implements Exception {
  const PendingOutboundIntegrityViolation({
    required this.crdtDataRowId,
    required this.type,
    required this.operation,
    required this.tableName,
    required this.rowId,
    required this.ownerSpaceId,
    required this.incomingSpaceUuid,
    required this.uuidNodeId,
    this.hlc,
  });

  final int? crdtDataRowId;
  final OfflineSyncViolationType type;
  final OfflineSyncViolationOperation operation;
  final String tableName;
  final UuidValue rowId;
  final int? ownerSpaceId;
  final UuidValue incomingSpaceUuid;
  final UuidValue uuidNodeId;
  final Hlc? hlc;
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
