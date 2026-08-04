import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import '../business/crdt_sync.dart';

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
    yield* session.crdt.sync(
      userId: UuidValue.withValidation(session.authenticated!.userIdentifier),
      inbound: changes,
      once: once,
      mode: CrdtSyncPeerMode.authoritative,
    );
  }
}
