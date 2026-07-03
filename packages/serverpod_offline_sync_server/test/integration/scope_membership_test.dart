import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart' as server;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given a user with personal scope access and membership in one shared CRDT scope, '
    'and another user with membership in another scope,',
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

        await server.CrdtScopeMember.db.insertRow(
          session,
          server.CrdtScopeMember(
            scopeId: sharedScope.id!,
            userUuid: userUuid,
            role: server.CrdtScopeRole.readWrite,
          ),
        );
        await server.CrdtScopeMember.db.insertRow(
          session,
          server.CrdtScopeMember(
            scopeId: otherScope.id!,
            userUuid: otherUserUuid,
            role: server.CrdtScopeRole.readOnly,
          ),
        );
      });

      test(
        'when member scopes are resolved, '
        'then only the personal scope and the granted shared scope are included.',
        () async {
          final session = sessionBuilder.build();
          final scopes = await CrdtScopeMembership.memberScopes(session, userUuid);
          final expectedScopes = [userUuid, sharedScopeUuid]
            ..sort((a, b) => a.uuid.compareTo(b.uuid));

          expect(scopes, expectedScopes);
        },
      );

      test(
        'when membership is checked for the personal scope, '
        'then the user is a member.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: userUuid,
            ),
            isTrue,
          );
        },
      );

      test(
        'when membership is checked for the granted shared scope, '
        'then the user is a member.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: sharedScopeUuid,
            ),
            isTrue,
          );
        },
      );

      test(
        'when the role is resolved for the granted shared scope, '
        'then the stored membership role is returned.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: userUuid,
              scopeUuid: sharedScopeUuid,
            ),
            CrdtScopeRole.readWrite,
          );
        },
      );

      test(
        'when the role is resolved for the personal scope, '
        'then the readWrite role is returned.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: userUuid,
              scopeUuid: userUuid,
            ),
            CrdtScopeRole.readWrite,
          );
        },
      );

      test(
        'when membership is checked for a scope the user does not belong to, '
        'then the user is not a member.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: otherScopeUuid,
            ),
            isFalse,
          );
        },
      );

      test(
        "when the role is resolved for the other user's scope, "
        'then the correct role is returned.',
        () async {
          final session = sessionBuilder.build();

          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: otherUserUuid,
              scopeUuid: otherScopeUuid,
            ),
            CrdtScopeRole.readOnly,
          );
        },
      );
    },
  );
}
