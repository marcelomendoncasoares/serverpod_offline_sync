import 'package:meta/meta.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
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

/// Thrown when sync observes terminal CRDT metadata/domain-row inconsistency.
final class CrdtSyncIntegrityViolationException extends CrdtSyncException {
  /// Creates a [CrdtSyncIntegrityViolationException].
  const CrdtSyncIntegrityViolationException(this.violation);

  /// The integrity violation that caused sync to stop.
  final CrdtSyncIntegrityViolation violation;

  @override
  String toString() {
    final persisted = violation.id == null
        ? ''
        : ' Persisted violation id: ${violation.id}.';
    final row = '${violation.domainTableName}.${violation.uuidRowId}';
    return switch (violation.type) {
      CrdtSyncViolationType.ownershipCollision =>
        'CrdtSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} for $row '
            'belongs to scope ${violation.ownerScopeUuid}, but sync attempted '
            'scope ${violation.incomingScopeUuid}.$persisted',
      CrdtSyncViolationType.missingDomainRow =>
        'CrdtSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} references '
            'missing domain row $row for scope '
            '${violation.incomingScopeUuid}.$persisted',
      CrdtSyncViolationType.unauthorizedWrite =>
        'CrdtSyncIntegrityViolationException: '
            '${violation.type.name}/${violation.operation.name} rejected '
            'write to $row in scope ${violation.incomingScopeUuid}.$persisted',
    };
  }
}

/// Thrown when a user attempts to act in a scope they are not a member of.
final class CrdtScopeMembershipException implements Exception {
  /// Creates a [CrdtScopeMembershipException].
  const CrdtScopeMembershipException({
    required this.userId,
    required this.scopeId,
  });

  /// The authenticated user id supplied to `transactionForUser`.
  final UuidValue userId;

  /// The scope id the transaction attempted to act in.
  final UuidValue scopeId;

  @override
  String toString() =>
      'CrdtScopeMembershipException: user "$userId" is not a member of '
      'scope "$scopeId".';
}

/// Thrown when a user attempts to write in a scope with a non-writable role.
final class CrdtScopeRoleException implements Exception {
  /// Creates a [CrdtScopeRoleException].
  const CrdtScopeRoleException({
    required this.userId,
    required this.scopeId,
    this.role,
  });

  /// The authenticated user id supplied to `transactionForUser`.
  final UuidValue userId;

  /// The scope id the transaction attempted to write in.
  final UuidValue scopeId;

  /// The role that does not allow writes.
  final CrdtScopeRole? role;

  @override
  String toString() =>
      'CrdtScopeRoleException: user "$userId" with role "$role" cannot write '
      'in scope "$scopeId".';
}

@internal
final class PendingOutboundIntegrityViolation implements Exception {
  const PendingOutboundIntegrityViolation({
    required this.crdtDataRowId,
    required this.type,
    required this.operation,
    required this.tableName,
    required this.rowId,
    required this.ownerScopeId,
    required this.incomingScopeUuid,
    required this.uuidNodeId,
    this.hlc,
  });

  final int? crdtDataRowId;
  final CrdtSyncViolationType type;
  final CrdtSyncViolationOperation operation;
  final String tableName;
  final UuidValue rowId;
  final int? ownerScopeId;
  final UuidValue incomingScopeUuid;
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
