import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart' as server;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('[CRDT Scope Membership]', (sessionBuilder, _) {
    late Session session;

    setUp(() {
      session = sessionBuilder.build();
    });

    group(
      'Given a user with personal scope access and readWrite membership in one shared CRDT scope,',
      () {
        late UuidValue userUuid;
        late UuidValue sharedScopeUuid;

        setUp(() async {
          userUuid = const Uuid().v7obj();
          sharedScopeUuid = const Uuid().v7obj();

          final sharedScope = await server.CrdtScope.db.insertRow(
            session,
            server.CrdtScope(uuidScopeId: sharedScopeUuid),
          );
          await server.CrdtScopeMember.db.insertRow(
            session,
            server.CrdtScopeMember(
              scopeId: sharedScope.id!,
              userUuid: userUuid,
              role: server.CrdtScopeRole.readWrite,
            ),
          );
        });

        test(
          'when member scopes are resolved, '
          'then only the personal scope and the granted shared scope are included.',
          () async {
            final scopes = await CrdtScopeMembership.memberScopes(session, userUuid);
            final expectedScopes = [userUuid, sharedScopeUuid]
              ..sort((a, b) => a.uuid.compareTo(b.uuid));

            expect(scopes, expectedScopes);
          },
        );

        test(
          'when member grants are resolved, '
          'then the personal and granted shared scopes are returned with their roles.',
          () async {
            final grants = await CrdtScopeMembership.memberGrants(session, userUuid);

            expect(
              {for (final grant in grants) grant.uuidScopeId: grant.role},
              {
                userUuid: CrdtScopeRole.readWrite,
                sharedScopeUuid: CrdtScopeRole.readWrite,
              },
            );
          },
        );

        test(
          'when a stray membership row grants readOnly access to the personal scope, '
          'then the personal grant remains readWrite.',
          () async {
            final personalScope = await server.CrdtScope.db.insertRow(
              session,
              server.CrdtScope(uuidScopeId: userUuid),
            );
            await server.CrdtScopeMember.db.insertRow(
              session,
              server.CrdtScopeMember(
                scopeId: personalScope.id!,
                userUuid: userUuid,
                role: server.CrdtScopeRole.readOnly,
              ),
            );

            final grants = await CrdtScopeMembership.memberGrants(session, userUuid);

            expect(
              grants.singleWhere((grant) => grant.uuidScopeId == userUuid).role,
              CrdtScopeRole.readWrite,
            );
          },
        );

        test(
          'when membership is checked for the personal scope, '
          'then the user is a member.',
          () async {
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
          'when the role is resolved for a scope without a CRDT scope row, '
          'then no role is returned.',
          () async {
            final missingScopeUuid = const Uuid().v7obj();

            expect(
              await CrdtScopeMembership.roleOf(
                session,
                userUuid: userUuid,
                scopeUuid: missingScopeUuid,
              ),
              isNull,
            );
          },
        );

        test(
          'when a stored membership row has no role, '
          'then resolving grants fails instead of treating it as a grant.',
          () async {
            final scope = await server.CrdtScope.db.insertRow(
              session,
              server.CrdtScope(uuidScopeId: const Uuid().v7obj()),
            );
            final encodedScopeId = ValueEncoder.instance.convert(scope.id);
            final encodedUserUuid = ValueEncoder.instance.convert(userUuid);

            await session.db.unsafeExecute(
              'ALTER TABLE "crdt_scope_members" ALTER COLUMN "role" DROP NOT NULL',
            );
            await session.db.unsafeExecute(
              'INSERT INTO "crdt_scope_members" ("scopeId", "userUuid", "role") '
              'VALUES ($encodedScopeId, $encodedUserUuid, NULL)',
            );

            await expectLater(
              CrdtScopeMembership.memberGrants(session, userUuid),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  'crdt_scope_members.role must not be null.',
                ),
              ),
            );
          },
        );
      },
    );

    group('Given a shared CRDT scope without membership for a user,', () {
      late UuidValue userUuid;
      late UuidValue sharedScopeUuid;

      setUp(() async {
        userUuid = const Uuid().v7obj();
        sharedScopeUuid = const Uuid().v7obj();
        await server.CrdtScope.db.insertRow(
          session,
          server.CrdtScope(uuidScopeId: sharedScopeUuid),
        );
      });

      test(
        'when membership is checked for that scope, '
        'then the user is not a member.',
        () async {
          expect(
            await CrdtScopeMembership.isMember(
              session,
              userUuid: userUuid,
              scopeUuid: sharedScopeUuid,
            ),
            isFalse,
          );
        },
      );
    });

    group('Given a user with readOnly membership in a shared CRDT scope,', () {
      late UuidValue userUuid;
      late UuidValue sharedScopeUuid;

      setUp(() async {
        userUuid = const Uuid().v7obj();
        sharedScopeUuid = const Uuid().v7obj();
        final sharedScope = await server.CrdtScope.db.insertRow(
          session,
          server.CrdtScope(uuidScopeId: sharedScopeUuid),
        );
        await server.CrdtScopeMember.db.insertRow(
          session,
          server.CrdtScopeMember(
            scopeId: sharedScope.id!,
            userUuid: userUuid,
            role: server.CrdtScopeRole.readOnly,
          ),
        );
      });

      test(
        'when the role is resolved for that scope, '
        'then the readOnly role is returned.',
        () async {
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: userUuid,
              scopeUuid: sharedScopeUuid,
            ),
            CrdtScopeRole.readOnly,
          );
        },
      );
    });
  });
}
