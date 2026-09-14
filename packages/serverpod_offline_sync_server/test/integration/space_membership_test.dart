import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart' as server;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('[CRDT Space Membership]', (sessionBuilder, _) {
    late Session session;

    setUp(() {
      session = sessionBuilder.build();
    });

    group(
      'Given a user with personal space access and readWrite membership in one shared CRDT space,',
      () {
        late UuidValue userUuid;
        late UuidValue sharedSpaceUuid;

        setUp(() async {
          userUuid = const Uuid().v7obj();
          sharedSpaceUuid = const Uuid().v7obj();

          final sharedSpace = await server.OfflineSyncSpace.db.insertRow(
            session,
            server.OfflineSyncSpace(uuidSpaceId: sharedSpaceUuid),
          );
          await server.OfflineSyncSpaceMember.db.insertRow(
            session,
            server.OfflineSyncSpaceMember(
              spaceId: sharedSpace.id!,
              userUuid: userUuid,
              role: server.OfflineSyncSpaceRole.readWrite,
            ),
          );
        });

        test(
          'when member spaces are resolved, '
          'then only the personal space and the granted shared space are included.',
          () async {
            final spaces = await OfflineSyncSpaceMembership.memberSpaces(
              session,
              userUuid,
            );
            final expectedSpaces = [userUuid, sharedSpaceUuid]
              ..sort((a, b) => a.uuid.compareTo(b.uuid));

            expect(spaces, expectedSpaces);
          },
        );

        test(
          'when member grants are resolved, '
          'then the personal and granted shared spaces are returned with their roles.',
          () async {
            final grants = await OfflineSyncSpaceMembership.memberGrants(
              session,
              userUuid,
            );

            expect(
              {for (final grant in grants) grant.uuidSpaceId: grant.role},
              {
                userUuid: OfflineSyncSpaceRole.readWrite,
                sharedSpaceUuid: OfflineSyncSpaceRole.readWrite,
              },
            );
          },
        );

        test(
          'when membership is checked for the personal space, '
          'then the user is a member.',
          () async {
            expect(
              await OfflineSyncSpaceMembership.isMember(
                session,
                userUuid: userUuid,
                spaceUuid: userUuid,
              ),
              isTrue,
            );
          },
        );

        test(
          'when membership is checked for the granted shared space, '
          'then the user is a member.',
          () async {
            expect(
              await OfflineSyncSpaceMembership.isMember(
                session,
                userUuid: userUuid,
                spaceUuid: sharedSpaceUuid,
              ),
              isTrue,
            );
          },
        );

        test(
          'when the role is resolved for the granted shared space, '
          'then the stored membership role is returned.',
          () async {
            expect(
              await OfflineSyncSpaceMembership.roleOf(
                session,
                userUuid: userUuid,
                spaceUuid: sharedSpaceUuid,
              ),
              OfflineSyncSpaceRole.readWrite,
            );
          },
        );

        test(
          'when the role is resolved for the personal space, '
          'then the readWrite role is returned.',
          () async {
            expect(
              await OfflineSyncSpaceMembership.roleOf(
                session,
                userUuid: userUuid,
                spaceUuid: userUuid,
              ),
              OfflineSyncSpaceRole.readWrite,
            );
          },
        );

        test(
          'when the role is resolved for a space without a CRDT space row, '
          'then no role is returned.',
          () async {
            final missingSpaceUuid = const Uuid().v7obj();

            expect(
              await OfflineSyncSpaceMembership.roleOf(
                session,
                userUuid: userUuid,
                spaceUuid: missingSpaceUuid,
              ),
              isNull,
            );
          },
        );

        test(
          'when a stray membership row grants readOnly access to the personal space, '
          'then the personal grant remains readWrite.',
          () async {
            final personalSpace = await server.OfflineSyncSpace.db.insertRow(
              session,
              server.OfflineSyncSpace(uuidSpaceId: userUuid),
            );
            await server.OfflineSyncSpaceMember.db.insertRow(
              session,
              server.OfflineSyncSpaceMember(
                spaceId: personalSpace.id!,
                userUuid: userUuid,
                role: server.OfflineSyncSpaceRole.readOnly,
              ),
            );

            final grants = await OfflineSyncSpaceMembership.memberGrants(
              session,
              userUuid,
            );

            expect(
              grants.singleWhere((grant) => grant.uuidSpaceId == userUuid).role,
              OfflineSyncSpaceRole.readWrite,
            );
          },
        );

        test(
          'when a stored membership row has no role, '
          'then resolving grants fails instead of treating it as a grant.',
          () async {
            final space = await server.OfflineSyncSpace.db.insertRow(
              session,
              server.OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
            );
            final encodedSpaceId = ValueEncoder.instance.convert(space.id);
            final encodedUserUuid = ValueEncoder.instance.convert(userUuid);

            await session.db.unsafeExecute(
              'ALTER TABLE "offline_sync_space_members" ALTER COLUMN "role" DROP NOT NULL',
            );
            await session.db.unsafeExecute(
              'INSERT INTO "offline_sync_space_members" ("spaceId", "userUuid", "role") '
              'VALUES ($encodedSpaceId, $encodedUserUuid, NULL)',
            );

            await expectLater(
              OfflineSyncSpaceMembership.memberGrants(session, userUuid),
              throwsA(isA<Error>()),
            );
          },
        );
      },
    );

    group('Given a user with readOnly membership in a shared CRDT space,', () {
      late UuidValue userUuid;
      late UuidValue sharedSpaceUuid;

      setUp(() async {
        userUuid = const Uuid().v7obj();
        sharedSpaceUuid = const Uuid().v7obj();
        final sharedSpace = await server.OfflineSyncSpace.db.insertRow(
          session,
          server.OfflineSyncSpace(uuidSpaceId: sharedSpaceUuid),
        );
        await server.OfflineSyncSpaceMember.db.insertRow(
          session,
          server.OfflineSyncSpaceMember(
            spaceId: sharedSpace.id!,
            userUuid: userUuid,
            role: server.OfflineSyncSpaceRole.readOnly,
          ),
        );
      });

      test(
        'when the role is resolved for that space, '
        'then the readOnly role is returned.',
        () async {
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: userUuid,
              spaceUuid: sharedSpaceUuid,
            ),
            OfflineSyncSpaceRole.readOnly,
          );
        },
      );
    });

    group('Given a shared CRDT space without membership for a user,', () {
      late UuidValue userUuid;
      late UuidValue sharedSpaceUuid;

      setUp(() async {
        userUuid = const Uuid().v7obj();
        sharedSpaceUuid = const Uuid().v7obj();
        await server.OfflineSyncSpace.db.insertRow(
          session,
          server.OfflineSyncSpace(uuidSpaceId: sharedSpaceUuid),
        );
      });

      test(
        'when membership is checked for that space, '
        'then the user is not a member.',
        () async {
          expect(
            await OfflineSyncSpaceMembership.isMember(
              session,
              userUuid: userUuid,
              spaceUuid: sharedSpaceUuid,
            ),
            isFalse,
          );
        },
      );
    });
  });
}
