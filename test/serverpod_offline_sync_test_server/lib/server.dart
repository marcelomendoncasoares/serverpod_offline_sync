import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    hide Endpoints, Protocol;

import 'src/demo_auth.dart';
import 'src/demo_sync_tables.dart';
import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';

/// The starting point of the Serverpod server.
Future<void> run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: demoAuthenticationHandler,
    // TODO: Remove the duplicate [syncTables] argument from here and the
    // [initializeCrdtSync] call below.
    databaseInterceptor: (_, inner) => CrdtDatabase(
      inner,
      syncTables: demoSyncTables,
      scopeMembershipValidator: (session, {required userId, required scopeId}) =>
          CrdtScopeMembership.isMember(
            session,
            userUuid: userId,
            scopeUuid: scopeId,
          ),
      scopeMembershipResolver: CrdtScopeMembership.memberScopes,
    ),
  )..initializeCrdtSync(syncTables: demoSyncTables);

  // Start the server.
  await pod.start();
}
