import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a client CRDT session with materialized personal, shared, and stale scopes, '
    'when follower membership is projected from server grants,',
    () {
      late UuidValue sharedScopeUuid;
      late UuidValue staleScopeUuid;
      late UuidValue notMaterializedScopeUuid;
      late CrdtScope sharedScope;

      setUp(() async {
        sharedScopeUuid = const Uuid().v7obj();
        staleScopeUuid = const Uuid().v7obj();
        notMaterializedScopeUuid = const Uuid().v7obj();

        final personalScope = await CrdtScope.db.insertRow(
          session,
          CrdtScope(uuidScopeId: testCrdtUserId),
        );
        sharedScope = await CrdtScope.db.insertRow(
          session,
          CrdtScope(uuidScopeId: sharedScopeUuid),
        );
        final staleScope = await CrdtScope.db.insertRow(
          session,
          CrdtScope(uuidScopeId: staleScopeUuid),
        );

        await CrdtScopeMember.db.insertRow(
          session,
          CrdtScopeMember(
            scopeId: personalScope.id!,
            userUuid: testCrdtUserId,
            role: CrdtScopeRole.readOnly,
          ),
        );
        await CrdtScopeMember.db.insertRow(
          session,
          CrdtScopeMember(
            scopeId: staleScope.id!,
            userUuid: testCrdtUserId,
            role: CrdtScopeRole.readWrite,
          ),
        );

        // This is a test, so we can ignore the internal member warning.
        // ignore: invalid_use_of_internal_member
        await CrdtScopeMembership.projectFollowerMembership(
          session,
          userUuid: testCrdtUserId,
          grants: [
            CrdtScopeGrant(
              uuidScopeId: testCrdtUserId,
              role: CrdtScopeRole.readWrite,
            ),
            CrdtScopeGrant(
              uuidScopeId: sharedScopeUuid,
              role: CrdtScopeRole.readOnly,
            ),
            // Project a not-yet-materialized scope to test that it is not
            // stored as a membership row.
            CrdtScopeGrant(
              uuidScopeId: notMaterializedScopeUuid,
              role: CrdtScopeRole.readWrite,
            ),
          ],
        );
      });

      test(
        'then only the materialized shared grant is stored as an explicit membership row.',
        () async {
          final rows = await CrdtScopeMember.db.find(
            session,
            where: (t) => t.userUuid.equals(testCrdtUserId),
          );

          expect(rows, hasLength(1));
          expect(rows.single.scopeId, sharedScope.id);
          expect(rows.single.role, CrdtScopeRole.readOnly);
        },
      );

      test(
        'then direct member scope resolution includes the implicit personal scope and projected shared scope.',
        () async {
          final scopes = await CrdtScopeMembership.memberScopes(
            session,
            testCrdtUserId,
          );
          final expectedScopes = [testCrdtUserId, sharedScopeUuid]
            ..sort((a, b) => a.uuid.compareTo(b.uuid));

          expect(scopes, expectedScopes);
        },
      );

      test(
        'then direct member grant resolution includes the implicit personal role and projected shared role.',
        () async {
          final grants = await CrdtScopeMembership.memberGrants(
            session,
            testCrdtUserId,
          );

          expect(
            {for (final grant in grants) grant.uuidScopeId: grant.role},
            {
              testCrdtUserId: CrdtScopeRole.readWrite,
              sharedScopeUuid: CrdtScopeRole.readOnly,
            },
          );
        },
      );

      test(
        'then direct role resolution reflects projected membership and missing local scopes.',
        () async {
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: testCrdtUserId,
            ),
            CrdtScopeRole.readWrite,
          );
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: sharedScopeUuid,
            ),
            CrdtScopeRole.readOnly,
          );
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: staleScopeUuid,
            ),
            isNull,
          );
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: notMaterializedScopeUuid,
            ),
            isNull,
          );
        },
      );

      test(
        'then direct membership checks reflect projected membership and missing local scopes.',
        () async {
          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: testCrdtUserId,
            ),
            isTrue,
          );
          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: sharedScopeUuid,
            ),
            isTrue,
          );
          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: staleScopeUuid,
            ),
            isFalse,
          );
          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              scopeUuid: notMaterializedScopeUuid,
            ),
            isFalse,
          );
        },
      );
    },
  );
}
