import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart';

import '../demo_auth.dart';

/// Passwordless auth endpoint used by the offline-sync demo app.
class DemoAuthEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Creates or reuses a demo auth user and returns its bearer token.
  Future<String> loginOrCreateUser(
    Session session,
    String username,
  ) async {
    final authUser = newDemoAuthUser(username);
    final authUserId = authUser.id!;

    final existing = await AuthUser.db.findById(session, authUserId);
    if (existing == null) {
      try {
        await AuthUser.db.insertRow(session, authUser);
      } on DatabaseQueryException {
        // A concurrent demo login may have created the deterministic row.
      }
    }

    return demoTokenForAuthUserId(authUserId);
  }
}
