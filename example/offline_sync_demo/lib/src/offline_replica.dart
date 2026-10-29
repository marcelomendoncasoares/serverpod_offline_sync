import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:serverpod_offline_sync_test_shared/demo_reset.dart';

/// One local replica: a Serverpod client database wrapped with the
/// `serverpod_offline_sync` CRDT layer, plus the calls that synchronize it.
///
/// This class is the entire surface a real integration needs — read it first to
/// understand the package. The four steps are:
///
///   1. [open] uses [Client.createSyncSession] to open and initialize a local
///      SQLite database as an [OfflineSyncDatabaseSession]. Use
///      [openOrReset] when the file may predate the shipped
///      schema. The rest of the app reads and writes generated models through
///      [session].
///   2. CRUD happens against [session] with the generated model APIs (see
///      the `seed*` methods in `DemoController` for the plain, recommended form,
///      e.g. `Person.db.insertRow(offlineSyncSession, person)`).
///   3. [syncOnce] / [syncContinuously] push local changes and merge remote
///      ones through a Serverpod [Client].
///   4. [reset] clears local data; [close] releases the database connection.
///
/// It deliberately holds **no UI state**: the demo's `DemoController` layers
/// busy/error/projection bookkeeping on top of these calls so that this file
/// stays a clean reference for the package itself.
class OfflineReplica {
  OfflineReplica._(this.session, this.persistentUserId);

  /// CRDT-aware session used for every model read and write. By default it only
  /// exposes visible (non-tombstoned) rows; queries opt into hidden rows with
  /// the `includeHiddenRows` where-clause.
  final OfflineSyncDatabaseSession session;

  /// The signed-in user every local write on this replica is attributed to.
  final UuidValue persistentUserId;

  /// Opens [databasePath] through [client] and wraps it for CRDT sync.
  ///
  /// [Client.createSyncSession] runs client migrations, wraps the database for
  /// the generated sync tables, and initializes CRDT tracking for this user.
  static Future<OfflineReplica> open({
    required Client client,
    required String databasePath,
    required UuidValue persistentUserId,
  }) async {
    final session = await client.createSyncSession(
      databasePath,
      isDebugMode: kDebugMode,
      persistentUserId: persistentUserId,
    );
    return OfflineReplica._(session, persistentUserId);
  }

  /// Like [open], but deletes [databasePath] and retries once when opening
  /// fails — for example when migrations were regenerated during development
  /// and a leftover file records a version this build no longer ships.
  ///
  /// A replica is a disposable local cache; syncing re-pulls server state.
  static Future<OfflineReplica> openOrReset({
    required Client client,
    required String databasePath,
    required UuidValue persistentUserId,
  }) async {
    var retry = true;
    while (true) {
      try {
        return await open(
          client: client,
          databasePath: databasePath,
          persistentUserId: persistentUserId,
        );
      } catch (_) {
        if (!retry) rethrow;
        retry = false;
        for (final suffix in const ['', '-wal', '-shm']) {
          final file = File('$databasePath$suffix');
          if (file.existsSync()) file.deleteSync();
        }
        if (kDebugMode) {
          debugPrint(
            'offline_sync_demo: discarded stale replica '
            '${p.basename(databasePath)}.',
          );
        }
      }
    }
  }

  /// Pushes local pending changes through [client] and merges remote ones once.
  ///
  /// Connectivity is expressed entirely by [client]: pass an online client to
  /// reach the server, an offline one (failing transport) to simulate no
  /// network. The replica's local database is the same either way.
  Future<void> syncOnce(
    Client client, {
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return client.offlineSync.syncOnce(session, onMergeSuccess: onMergeSuccess);
  }

  /// Streams changes through [client] until the returned session is cancelled
  /// (via [OfflineSyncSubscription.cancel]) or the remote stream closes.
  OfflineSyncSubscription syncContinuously(
    Client client, {
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return client.offlineSync.syncContinuously(
      session,
      onMergeSuccess: onMergeSuccess,
    );
  }

  /// Clears the personal space and rotates this user's replica epoch atomically.
  ///
  /// Stop sync streams and writes first. Other spaces keep their data and
  /// historical author UUIDs; later writes use the fresh local clock.
  Future<void> reset() => resetDemoSpace(session, persistentUserId);

  /// Closes the underlying database connection.
  Future<void> close() => session.close();
}
