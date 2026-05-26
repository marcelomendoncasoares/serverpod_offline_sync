import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../database/session.dart';
import '../protocol/protocol.dart';

/// High-level client sync helpers built on top of the generated module caller.
class CrdtSyncClient {
  /// Creates a [CrdtSyncClient] for the provided module caller.
  CrdtSyncClient(this._caller);

  final Caller _caller;

  /// Pushes local pending changes for [session] to the remote peer once.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncOnce(DatabaseSession session) => _sync(session, once: true);

  /// Keeps synchronizing [session] with the remote peer until the stream closes.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncContinuously(DatabaseSession session) => _sync(session, once: false);

  Future<void> _sync(DatabaseSession session, {required bool once}) async {
    final outboundChanges = StreamController<CrdtSyncStreamEvent>();

    try {
      final remoteStream = _caller.crdtSync.sync(
        changes: outboundChanges.stream,
        once: once,
      );

      await session.crdtDb
          .sync(
            inbound: remoteStream,
            once: once,
          )
          .forEach(outboundChanges.add);
    } finally {
      await outboundChanges.close();
    }
  }
}

/// Exposes CRDT sync helpers from a generated client.
extension CrdtSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  CrdtSyncClient get crdt => CrdtSyncClient(Caller(this));
}
