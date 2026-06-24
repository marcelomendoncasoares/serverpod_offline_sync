import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart' as server;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given personal and shared CRDT scope memberships,',
    (sessionBuilder, _) {
      final userUuid = const Uuid().v7obj();
      final otherUserUuid = const Uuid().v7obj();
      late UuidValue sharedScopeUuid;
      late UuidValue otherScopeUuid;

      setUp(() async {
        final session = sessionBuilder.build();
        sharedScopeUuid = const Uuid().v7obj();
        otherScopeUuid = const Uuid().v7obj();

        final sharedScope = await server.CrdtScope.db.insertRow(
          session,
          server.CrdtScope(uuidScopeId: sharedScopeUuid),
        );
        final otherScope = await server.CrdtScope.db.insertRow(
          session,
          server.CrdtScope(uuidScopeId: otherScopeUuid),
        );

        await CrdtScopeMember.db.insertRow(
          session,
          CrdtScopeMember(
            scopeId: sharedScope.id!,
            userUuid: userUuid,
            role: 'editor',
          ),
        );
        await CrdtScopeMember.db.insertRow(
          session,
          CrdtScopeMember(
            scopeId: otherScope.id!,
            userUuid: otherUserUuid,
          ),
        );
      });

      test(
        'when member scopes are resolved, '
        'then personal and shared scopes are returned in deterministic order.',
        () async {
          final session = sessionBuilder.build();
          final scopes = await CrdtScopeMembership.memberScopes(session, userUuid);
          final expectedScopes = [userUuid, sharedScopeUuid]
            ..sort((a, b) => a.uuid.compareTo(b.uuid));

          expect(scopes, expectedScopes);
        },
      );

      test(
        'when membership is checked, '
        'then personal and shared scopes are accepted and non-member scopes are rejected.',
        () async {
          final session = sessionBuilder.build();

          await expectLater(
            CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: userUuid,
            ),
            completion(isTrue),
          );
          await expectLater(
            CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: sharedScopeUuid,
            ),
            completion(isTrue),
          );
          await expectLater(
            CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: otherScopeUuid,
            ),
            completion(isFalse),
          );
        },
      );
    },
  );
}
