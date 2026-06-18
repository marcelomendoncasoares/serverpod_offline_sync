import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart';

const _demoScopeName = 'offline-sync-demo';
const _demoTokenPrefix = 'offline-sync-demo:';

/// Normalizes a demo username for deterministic auth user creation.
String normalizeDemoUsername(String username) {
  final normalized = username.trim().toLowerCase();
  if (normalized.isEmpty) {
    throw ArgumentError.value(username, 'username', 'Must not be empty.');
  }
  return normalized;
}

/// Returns the deterministic auth user id used by the demo username.
UuidValue demoAuthUserIdForUsername(String username) {
  final normalized = normalizeDemoUsername(username);
  final id = const Uuid().v5(
    Namespace.url.value,
    'serverpod-offline-sync/demo-user/$normalized',
  );
  return UuidValue.withValidation(id);
}

/// Creates the bearer token accepted by [demoAuthenticationHandler].
String demoTokenForAuthUserId(UuidValue authUserId) {
  return '$_demoTokenPrefix${authUserId.uuid}';
}

/// Extracts the deterministic auth user id from a demo bearer token.
UuidValue? demoAuthUserIdFromToken(String token) {
  if (!token.startsWith(_demoTokenPrefix)) return null;
  final value = token.substring(_demoTokenPrefix.length);
  try {
    return UuidValue.withValidation(value);
  } on FormatException {
    return null;
  }
}

/// Authentication handler for the passwordless offline-sync demo users.
Future<AuthenticationInfo?> demoAuthenticationHandler(
  Session session,
  String token,
) async {
  final authUserId = demoAuthUserIdFromToken(token);
  if (authUserId == null) return null;

  final authUser = await AuthUser.db.findById(session, authUserId);
  if (authUser == null || authUser.blocked) return null;

  return AuthenticationInfo(
    authUserId.uuid,
    authUser.scopeNames.map(Scope.new).toSet(),
    authId: authUserId.uuid,
  );
}

/// Creates a new auth user row for the passwordless offline-sync demo.
AuthUser newDemoAuthUser(String username) {
  final normalized = normalizeDemoUsername(username);
  return AuthUser(
    id: demoAuthUserIdForUsername(normalized),
    scopeNames: {
      _demoScopeName,
      '$_demoScopeName:$normalized',
    },
  );
}
