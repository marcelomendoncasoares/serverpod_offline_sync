import 'package:http/http.dart' as http;
import 'package:serverpod_database/serverpod_database.dart'
    show ClientDatabaseSession;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as offline;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as protocol;
import 'package:uuid/uuid.dart' as uuid;

/// One of the two independent local replicas held side by side.
enum ReplicaSlot {
  a('Replica A'),
  b('Replica B');

  const ReplicaSlot(this.label);

  /// Human readable name shown in the UI.
  final String label;
}

/// A demo user backed by a deterministic auth-user id.
class DemoUser {
  DemoUser({
    required this.username,
    required this.authUserId,
    required this.token,
  });

  final String username;
  protocol.UuidValue authUserId;
  String token;

  /// Up to two uppercase initials for the avatar.
  String get initials {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

/// A single local replica's database sessions.
class ReplicaSession {
  ReplicaSession({required this.rawSession, required this.crdtSession});

  /// Owns the underlying SQLite connection and is closed with the controller.
  final ClientDatabaseSession rawSession;

  /// CRDT-aware session that only exposes visible rows.
  final offline.CrdtDatabaseSession crdtSession;
}

/// Identifies a domain row by its demo table name and UUID.
class DemoRowRef {
  const DemoRowRef({required this.tableName, required this.id});

  final String tableName;
  final protocol.UuidValue id;
}

/// Stores the current demo bearer token for outgoing requests.
class DemoAuthKeyProvider implements protocol.ClientAuthKeyProvider {
  String? token;

  @override
  Future<String?> get authHeaderValue async {
    final value = token;
    if (value == null) return null;
    return 'Bearer $value';
  }
}

/// HTTP client that fails every request, simulating an offline device.
class OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException(
      'Connectivity is disabled by the demo httpClientOverride.',
      request.url,
    );
  }
}

/// Monotonic counter used to label seeded rows per scenario.
class ScenarioCounter {
  final _values = <String, int>{};

  int next(String key) {
    final value = (_values[key] ?? 0) + 1;
    _values[key] = value;
    return value;
  }
}

/// Normalizes a demo username so the same person maps to one scope.
String normalizeUsername(String username) {
  return username.trim().toLowerCase();
}

/// Deterministic auth-user id for [username], matching the server algorithm.
protocol.UuidValue demoAuthUserIdForUsername(String username) {
  final id = const uuid.Uuid().v5(
    uuid.Namespace.url.value,
    'serverpod-offline-sync/demo-user/${normalizeUsername(username)}',
  );
  return protocol.UuidValue.withValidation(id);
}

/// Bearer token accepted by the demo authentication handler.
String demoTokenForAuthUserId(protocol.UuidValue authUserId) {
  return 'offline-sync-demo:${authUserId.uuid}';
}

/// Extracts the auth-user id from a demo bearer [token].
protocol.UuidValue authUserIdFromToken(String token) {
  const prefix = 'offline-sync-demo:';
  if (!token.startsWith(prefix)) {
    throw FormatException('Unexpected demo auth token.', token);
  }
  return protocol.UuidValue.withValidation(token.substring(prefix.length));
}

/// Builds a fresh time-ordered UUID for a new row.
protocol.UuidValue newId() {
  return const protocol.Uuid().v7obj();
}

/// Short 8-character form of a UUID for compact display.
///
/// Uses the last 8 characters so v7 UUIDs show the random suffix rather than
/// the timestamp prefix.
String shortId(protocol.UuidValue? value) {
  if (value == null) return 'null';
  final uuid = value.uuid;
  if (uuid.length <= 8) return uuid;
  return uuid.substring(uuid.length - 8);
}
