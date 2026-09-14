import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import '../business/offline_sync.dart';

/// Endpoint for CRDT-based offline-first synchronization.
class OfflineSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Opens a bidirectional CRDT sync session with the authenticated client.
  Stream<OfflineSyncStreamEvent> sync(
    Session session, {
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
  }) async* {
    yield* session.offlineSync.sync(
      userId: UuidValue.withValidation(session.authenticated!.userIdentifier),
      inbound: changes,
      once: once,
      mode: OfflineSyncPeerMode.authoritative,
    );
  }
}
