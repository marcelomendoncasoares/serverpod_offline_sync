import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show CrdtDatabase;

import '../generated/protocol.dart';

/// Read-only inspection endpoint used by the offline-sync demo app to show the
/// server's merged truth for the authenticated user's scope.
class DemoDebugEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Returns every synced row visible to the caller's scope on the server.
  Future<DemoServerSnapshot> fetchScopeSnapshot(Session session) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    final db = session.db;
    if (db is CrdtDatabase) {
      // Run the reads in the caller's scope so the snapshot reflects what this
      // user sees, not an unscoped admin view across every scope.
      return db.transactionForUser(
        userId,
        (transaction) => _loadSnapshot(session, transaction),
      );
    }
    return _loadSnapshot(session, null);
  }

  Future<DemoServerSnapshot> _loadSnapshot(
    Session session,
    Transaction? transaction,
  ) async {
    return DemoServerSnapshot(
      people: await Person.db.find(session, transaction: transaction),
      addresses: await Address.db.find(session, transaction: transaction),
      cities: await City.db.find(session, transaction: transaction),
      towns: await Town.db.find(session, transaction: transaction),
      uniques: await Unique.db.find(session, transaction: transaction),
      uniqueUuids: await UniqueUuid.db.find(session, transaction: transaction),
      restrictChildren: await RestrictChild.db.find(
        session,
        transaction: transaction,
      ),
      types: await Types.db.find(session, transaction: transaction),
      fkChainRoots: await FkChainRoot.db.find(
        session,
        transaction: transaction,
      ),
      fkChainCascadeMiddles: await FkChainCascadeMiddle.db.find(
        session,
        transaction: transaction,
      ),
      fkChainRestrictBlockers: await FkChainRestrictBlocker.db.find(
        session,
        transaction: transaction,
      ),
      fkChainMiddleSetNullChildren: await FkChainMiddleSetNullChild.db.find(
        session,
        transaction: transaction,
      ),
      fkChainMiddleCascadeChildren: await FkChainMiddleCascadeChild.db.find(
        session,
        transaction: transaction,
      ),
    );
  }
}
