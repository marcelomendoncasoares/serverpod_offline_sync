import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a client CRDT session with materialized personal, shared, and stale spaces, '
    'when follower membership is projected from server grants,',
    () {
      late UuidValue sharedSpaceUuid;
      late UuidValue staleSpaceUuid;
      late UuidValue notMaterializedSpaceUuid;
      late OfflineSyncSpace sharedSpace;

      setUp(() async {
        sharedSpaceUuid = const Uuid().v7obj();
        staleSpaceUuid = const Uuid().v7obj();
        notMaterializedSpaceUuid = const Uuid().v7obj();

        final personalSpace = await OfflineSyncSpace.db.insertRow(
          session,
          OfflineSyncSpace(uuidSpaceId: testCrdtUserId),
        );
        sharedSpace = await OfflineSyncSpace.db.insertRow(
          session,
          OfflineSyncSpace(uuidSpaceId: sharedSpaceUuid),
        );
        final staleSpace = await OfflineSyncSpace.db.insertRow(
          session,
          OfflineSyncSpace(uuidSpaceId: staleSpaceUuid),
        );

        await OfflineSyncSpaceMember.db.insertRow(
          session,
          OfflineSyncSpaceMember(
            spaceId: personalSpace.id!,
            userUuid: testCrdtUserId,
            role: OfflineSyncSpaceRole.readOnly,
          ),
        );
        await OfflineSyncSpaceMember.db.insertRow(
          session,
          OfflineSyncSpaceMember(
            spaceId: staleSpace.id!,
            userUuid: testCrdtUserId,
            role: OfflineSyncSpaceRole.readWrite,
          ),
        );

        // This is a test, so we can ignore the internal member warning.
        // ignore: invalid_use_of_internal_member
        await OfflineSyncSpaceMembership.projectFollowerMembership(
          session,
          userUuid: testCrdtUserId,
          grants: [
            OfflineSyncSpaceGrant(
              uuidSpaceId: testCrdtUserId,
              role: OfflineSyncSpaceRole.readWrite,
            ),
            OfflineSyncSpaceGrant(
              uuidSpaceId: sharedSpaceUuid,
              role: OfflineSyncSpaceRole.readOnly,
            ),
            // Project a not-yet-materialized space to test that it is not
            // stored as a membership row.
            OfflineSyncSpaceGrant(
              uuidSpaceId: notMaterializedSpaceUuid,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          ],
        );
      });

      test(
        'then only the materialized shared grant is stored as an explicit membership row.',
        () async {
          final rows = await OfflineSyncSpaceMember.db.find(
            session,
            where: (t) => t.userUuid.equals(testCrdtUserId),
          );

          expect(rows, hasLength(1));
          expect(rows.single.spaceId, sharedSpace.id);
          expect(rows.single.role, OfflineSyncSpaceRole.readOnly);
        },
      );

      test(
        'then direct member space resolution includes the implicit personal space and projected shared space.',
        () async {
          final spaces = await OfflineSyncSpaceMembership.memberSpaces(
            session,
            testCrdtUserId,
          );
          final expectedSpaces = [testCrdtUserId, sharedSpaceUuid]
            ..sort((a, b) => a.uuid.compareTo(b.uuid));

          expect(spaces, expectedSpaces);
        },
      );

      test(
        'then direct member grant resolution includes the implicit personal role and projected shared role.',
        () async {
          final grants = await OfflineSyncSpaceMembership.memberGrants(
            session,
            testCrdtUserId,
          );

          expect(
            {for (final grant in grants) grant.uuidSpaceId: grant.role},
            {
              testCrdtUserId: OfflineSyncSpaceRole.readWrite,
              sharedSpaceUuid: OfflineSyncSpaceRole.readOnly,
            },
          );
        },
      );

      test(
        'then direct role resolution reflects projected membership and missing local spaces.',
        () async {
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: testCrdtUserId,
            ),
            OfflineSyncSpaceRole.readWrite,
          );
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: sharedSpaceUuid,
            ),
            OfflineSyncSpaceRole.readOnly,
          );
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: staleSpaceUuid,
            ),
            isNull,
          );
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: notMaterializedSpaceUuid,
            ),
            isNull,
          );
        },
      );

      test(
        'then direct membership checks reflect projected membership and missing local spaces.',
        () async {
          expect(
            await OfflineSyncSpaceMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: testCrdtUserId,
            ),
            isTrue,
          );
          expect(
            await OfflineSyncSpaceMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: sharedSpaceUuid,
            ),
            isTrue,
          );
          expect(
            await OfflineSyncSpaceMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: staleSpaceUuid,
            ),
            isFalse,
          );
          expect(
            await OfflineSyncSpaceMembership.isMember(
              session,
              userUuid: testCrdtUserId,
              spaceUuid: notMaterializedSpaceUuid,
            ),
            isFalse,
          );
        },
      );
    },
  );
}
