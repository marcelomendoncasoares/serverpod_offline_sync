import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

import '../business/crdt_scope_membership.dart';

/// Endpoint for CRDT-based offline-first synchronization.
class CrdtSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Opens a bidirectional CRDT sync session with the authenticated client.
  Stream<CrdtSyncStreamEvent> sync(
    Session session, {
    required Stream<CrdtSyncStreamEvent> changes,
    bool once = false,
  }) async* {
    yield* CrdtSync.instance.sync(
      session,
      userId: UuidValue.withValidation(session.authenticated!.userIdentifier),
      inbound: changes,
      once: once,
      scopeResolver: CrdtSyncScopeResolver.authoritative(
        (_, userId) => CrdtScopeMembership.memberScopes(session, userId),
      ),
    );
  }
}
