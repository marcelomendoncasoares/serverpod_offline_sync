import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart'
    show ClientDatabaseSession;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'table_ops.dart' show demoSyncTables;

/// One local replica: a Serverpod client database wrapped with the
/// `serverpod_offline_sync` CRDT layer, plus the calls that synchronize it.
///
/// This class is the entire surface a real integration needs — read it first to
/// understand the package. The four steps are:
///
///   1. [open] opens a local SQLite database ([Client.createSession])
///      and wraps it in a [CrdtDatabaseSession]. Use
///      [openOrReset] when the file may predate the shipped
///      schema. The rest of the app reads and writes generated models through
///      [session].
///   2. CRUD happens against [session] with the generated model APIs (see
///      the `seed*` methods in `DemoController` for the plain, recommended form,
///      e.g. `Person.db.insertRow(crdtSession, person)`).
///   3. [syncOnce] / [syncContinuously] push local changes and merge remote
///      ones through a Serverpod [Client].
///   4. [reset] / [close] tear the replica down.
///
/// It deliberately holds **no UI state**: the demo's `DemoController` layers
/// busy/error/projection bookkeeping on top of these calls so that this file
/// stays a clean reference for the package itself.
class OfflineReplica {
  OfflineReplica._(this._rawSession, this.session, this.persistentUserId);

  /// Owns the underlying SQLite connection; closed by [close].
  final ClientDatabaseSession _rawSession;

  /// CRDT-aware session used for every model read and write. By default it only
  /// exposes visible (non-tombstoned) rows; queries opt into hidden rows with
  /// the `includeHiddenRows` where-clause.
  final CrdtDatabaseSession session;

  /// The signed-in user every local write on this replica is attributed to.
  final UuidValue persistentUserId;

  /// Opens [databasePath] through [client] and wraps it for CRDT sync.
  ///
  /// [Client.createSession] opens the local client database (running
  /// client migrations); [CrdtDatabaseSession.wraps] layers CRDT
  /// tracking over it; and `db.initialize()` establishes this device's CRDT
  /// node so it can take part in sync.
  static Future<OfflineReplica> open({
    required Client client,
    required String databasePath,
    required UuidValue persistentUserId,
  }) async {
    final rawSession = await client.createSession(
      databasePath,
      isDebugMode: kDebugMode,
    );
    final crdtSession = CrdtDatabaseSession.wraps(
      rawSession,
      syncTables: demoSyncTables,
      persistentUserId: persistentUserId,
    );
    await crdtSession.db.initialize();
    return OfflineReplica._(rawSession, crdtSession, persistentUserId);
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
    CrdtSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return client.crdt.syncOnce(session, onMergeSuccess: onMergeSuccess);
  }

  /// Streams changes through [client] until the returned session is cancelled
  /// (via [CrdtSyncSession.cancel]) or the remote stream closes.
  CrdtSyncSession syncContinuously(
    Client client, {
    CrdtSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return client.crdt.syncContinuously(
      session,
      onMergeSuccess: onMergeSuccess,
    );
  }

  /// Wipes this replica back to an empty device by deleting its local CRDT
  /// scope row. Every synced table cascades on `scopeId` -> `crdt_scopes`, so
  /// the domain rows and CRDT metadata go with it — no need to drop and recreate
  /// the database file. A fresh scope/node is established lazily on the next
  /// write.
  ///
  /// The delete runs with `defer_foreign_keys` on: the scopeId cascade fans out
  /// across the CRDT metadata diamond (`crdt_data_rows`/`crdt_data_fields`/
  /// `crdt_data_tombstone` reference `crdt_nodes` with NO ACTION while both
  /// sides cascade off `crdt_scopes`), and SQLite's cascade order can
  /// transiently violate those immediate checks. Deferring them to commit lets
  /// the whole cascade complete first.
  Future<void> reset() async {
    final scope = await CrdtScope.db.findFirstRow(
      session,
      where: (t) => t.uuidScopeId.equals(persistentUserId),
    );
    final scopeId = scope?.id;
    if (scopeId != null) {
      await session.db.transaction((transaction) async {
        await session.db.unsafeExecute(
          'PRAGMA defer_foreign_keys = ON',
          transaction: transaction,
        );
        await CrdtScope.db.deleteWhere(
          session,
          where: (t) => t.id.equals(scopeId),
          transaction: transaction,
        );
      });
    }
    await session.db.initialize();
  }

  /// Closes the underlying database connection.
  Future<void> close() => _rawSession.close();
}
