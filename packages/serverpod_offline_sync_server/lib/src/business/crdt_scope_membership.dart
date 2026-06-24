import 'package:serverpod/serverpod.dart';

/// Server-side membership helpers for shared CRDT scopes.
///
/// A user's personal scope is implicit and is always included. Explicit rows in
/// `crdt_scope_members` grant access to additional shared scopes.
class CrdtScopeMembership {
  const CrdtScopeMembership._();

  /// Returns the authoritative scope UUIDs the authenticated [userUuid] may sync.
  ///
  /// The returned set includes the implicit personal scope and explicit shared
  /// memberships, de-duplicated and sorted by UUID string so both peers can
  /// iterate deterministically.
  static Future<List<UuidValue>> memberScopes(
    DatabaseSession session,
    UuidValue userUuid, {
    Transaction? transaction,
  }) async {
    final scopesByUuid = <String, UuidValue>{userUuid.uuid: userUuid};
    final scopeIds = await _explicitMemberScopeIds(
      session,
      userUuid,
      transaction: transaction,
    );

    if (scopeIds.isNotEmpty) {
      final scopes = await _scopeUuidsForIds(
        session,
        scopeIds,
        transaction: transaction,
      );
      for (final scopeUuid in scopes) {
        scopesByUuid[scopeUuid.uuid] = scopeUuid;
      }
    }

    return scopesByUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
  }

  /// Returns whether [userUuid] may act in [scopeUuid].
  ///
  /// The implicit personal scope is accepted without a membership row.
  static Future<bool> isMember(
    DatabaseSession session, {
    required UuidValue userUuid,
    required UuidValue scopeUuid,
    Transaction? transaction,
  }) async {
    if (userUuid == scopeUuid) return true;

    final scopeId = await _scopeIdForUuid(
      session,
      scopeUuid,
      transaction: transaction,
    );
    if (scopeId == null) return false;

    final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final result = await session.db.unsafeQuery(
      'SELECT 1 FROM "crdt_scope_members" '
      'WHERE "userUuid" = $encodedUserUuid '
      'AND "scopeId" = $encodedScopeId '
      'LIMIT 1',
      transaction: transaction,
    );
    return result.isNotEmpty;
  }
}

Future<Set<int>> _explicitMemberScopeIds(
  DatabaseSession session,
  UuidValue userUuid, {
  Transaction? transaction,
}) async {
  final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
  final result = await session.db.unsafeQuery(
    'SELECT "scopeId" FROM "crdt_scope_members" '
    'WHERE "userUuid" = $encodedUserUuid',
    transaction: transaction,
  );
  return {
    for (final row in result) row[0] as int,
  };
}

Future<List<UuidValue>> _scopeUuidsForIds(
  DatabaseSession session,
  Set<int> scopeIds, {
  Transaction? transaction,
}) async {
  if (scopeIds.isEmpty) return [];
  final encodedScopeIds = scopeIds.map(ValueEncoder.instance.convert).join(', ');
  final result = await session.db.unsafeQuery(
    'SELECT "uuidScopeId" FROM "crdt_scopes" '
    'WHERE "id" IN ($encodedScopeIds)',
    transaction: transaction,
  );
  return [
    for (final row in result) _uuidValueFromDatabase(row[0]),
  ];
}

Future<int?> _scopeIdForUuid(
  DatabaseSession session,
  UuidValue scopeUuid, {
  Transaction? transaction,
}) async {
  final encodedScopeUuid = ValueEncoder.instance.convert(scopeUuid);
  final result = await session.db.unsafeQuery(
    'SELECT "id" FROM "crdt_scopes" '
    'WHERE "uuidScopeId" = $encodedScopeUuid '
    'LIMIT 1',
    transaction: transaction,
  );
  if (result.isEmpty) return null;
  return result.first[0] as int;
}

UuidValue _uuidValueFromDatabase(Object? value) {
  if (value is UuidValue) return value;
  if (value is String) return UuidValue.withValidation(value);
  return UuidValueJsonExtension.fromJson(value);
}
