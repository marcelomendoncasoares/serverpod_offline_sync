import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('[CRDT spaces]', (sessionBuilder, _) {
    late Session session;

    setUp(() {
      session = sessionBuilder.build();
      session.serverpod.initializeOfflineSync(syncTables: []);
    });

    group('Given a database with no shared spaces,', () {
      test(
        'when createFor is called with only a user, '
        'then the user is granted readWrite access to the new space.',
        () async {
          final user = const Uuid().v7obj();

          final space = await session.offlineSync.spaces.createFor(user);

          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: space),
            OfflineSyncSpaceRole.readWrite,
          );
          expect(
            await OfflineSyncSpaceMembership.memberSpaces(session, user),
            contains(space),
          );
        },
      );

      test(
        'when createFor is called with a user and a role, '
        'then the user is granted that role.',
        () async {
          final user = const Uuid().v7obj();

          final space = await session.offlineSync.spaces.createFor(
            user,
            role: OfflineSyncSpaceRole.readOnly,
          );

          expect(
            await session.offlineSync.spaces.members(space),
            {user: OfflineSyncSpaceRole.readOnly},
          );
        },
      );

      test(
        'when create is called without grants, '
        'then the new shared space is dormant and has no explicit members.',
        () async {
          final user = const Uuid().v7obj();

          final space = await session.offlineSync.spaces.create();

          expect(await session.offlineSync.spaces.members(space), isEmpty);
          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: space),
            isNull,
          );
          expect(
            await OfflineSyncSpaceMembership.memberSpaces(session, user),
            isNot(contains(space)),
          );
        },
      );

      test(
        'when create is called with several grants, '
        'then every membership is stored with its role.',
        () async {
          final writer = const Uuid().v7obj();
          final reader = const Uuid().v7obj();

          final space = await session.offlineSync.spaces.create(
            grants: {
              writer: OfflineSyncSpaceRole.readWrite,
              reader: OfflineSyncSpaceRole.readOnly,
            },
          );

          expect(await session.offlineSync.spaces.members(space), {
            writer: OfflineSyncSpaceRole.readWrite,
            reader: OfflineSyncSpaceRole.readOnly,
          });
        },
      );

      test(
        'when roleOf is called for a personal space with no row, '
        'then readWrite is returned.',
        () async {
          final user = const Uuid().v7obj();

          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: user),
            OfflineSyncSpaceRole.readWrite,
          );
          expect(await session.offlineSync.spaces.members(user), isEmpty);
        },
      );

      test(
        'when createFor is called inside a transaction that rolls back, '
        'then no space or membership rows leak.',
        () async {
          final user = const Uuid().v7obj();
          final countsBefore = await _membershipRowCounts(session);

          await expectLater(
            session.db.transaction((tx) async {
              await session.offlineSync.spaces.createFor(user, transaction: tx);
              throw StateError('rollback');
            }),
            throwsStateError,
          );

          expect(await _membershipRowCounts(session), countsBefore);
        },
      );

      test(
        'when grant is called for an unknown shared space, '
        'then OfflineSyncSpaceNotFoundException is thrown.',
        () async {
          final missingSpace = const Uuid().v7obj();

          await expectLater(
            session.offlineSync.spaces.grant(
              space: missingSpace,
              user: const Uuid().v7obj(),
              role: OfflineSyncSpaceRole.readWrite,
            ),
            throwsA(
              isA<OfflineSyncSpaceNotFoundException>().having(
                (error) => error.space,
                'space',
                missingSpace,
              ),
            ),
          );
        },
      );
    });

    group('Given a database with a dormant shared space,', () {
      late UuidValue space;

      setUp(() async {
        space = await session.offlineSync.spaces.create();
      });

      test(
        'when grant is called, '
        'then the membership is inserted.',
        () async {
          final user = const Uuid().v7obj();

          await session.offlineSync.spaces.grant(
            space: space,
            user: user,
            role: OfflineSyncSpaceRole.readOnly,
          );

          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: space),
            OfflineSyncSpaceRole.readOnly,
          );
          expect(
            await session.offlineSync.spaces.members(space),
            {user: OfflineSyncSpaceRole.readOnly},
          );
        },
      );

      test(
        'when grantAll is called with several users, '
        'then all memberships are applied.',
        () async {
          final readOnlyUser = const Uuid().v7obj();
          final readWriteUser = const Uuid().v7obj();

          await session.offlineSync.spaces.grantAll(space, {
            readOnlyUser: OfflineSyncSpaceRole.readOnly,
            readWriteUser: OfflineSyncSpaceRole.readWrite,
          });

          expect(await session.offlineSync.spaces.members(space), {
            readOnlyUser: OfflineSyncSpaceRole.readOnly,
            readWriteUser: OfflineSyncSpaceRole.readWrite,
          });
        },
      );

      test(
        'when grant is called inside a transaction that rolls back, '
        'then no membership row leaks.',
        () async {
          final user = const Uuid().v7obj();
          final countsBefore = await _membershipRowCounts(session);

          await expectLater(
            session.db.transaction((tx) async {
              await session.offlineSync.spaces.grant(
                space: space,
                user: user,
                role: OfflineSyncSpaceRole.readWrite,
                transaction: tx,
              );
              throw StateError('rollback');
            }),
            throwsStateError,
          );

          expect(await _membershipRowCounts(session), countsBefore);
          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: space),
            isNull,
          );
        },
      );
    });

    group('Given a database with a readOnly member on a shared space,', () {
      late UuidValue user;
      late UuidValue space;

      setUp(() async {
        user = const Uuid().v7obj();
        space = await session.offlineSync.spaces.create(
          grants: {user: OfflineSyncSpaceRole.readOnly},
        );
      });

      test(
        'when grant is called again for the same member with readWrite, '
        'then the existing membership is updated.',
        () async {
          await session.offlineSync.spaces.grant(
            space: space,
            user: user,
            role: OfflineSyncSpaceRole.readWrite,
          );

          expect(
            await session.offlineSync.spaces.roleOf(user: user, space: space),
            OfflineSyncSpaceRole.readWrite,
          );
          expect(
            await session.offlineSync.spaces.members(space),
            {user: OfflineSyncSpaceRole.readWrite},
          );
        },
      );
    });

    group('Given a database with a shared space that has one readWrite member,', () {
      late UuidValue member;
      late UuidValue nonMember;
      late UuidValue space;

      setUp(() async {
        member = const Uuid().v7obj();
        nonMember = const Uuid().v7obj();
        space = await session.offlineSync.spaces.createFor(member);
      });

      test(
        'when revoke is called for the member, '
        'then the membership is removed.',
        () async {
          await session.offlineSync.spaces.revoke(space: space, user: member);

          expect(
            await session.offlineSync.spaces.roleOf(user: member, space: space),
            isNull,
          );
          expect(await session.offlineSync.spaces.members(space), isEmpty);
        },
      );

      test(
        'when revoke is called for a non-member, '
        'then it completes without changing the space members.',
        () async {
          await expectLater(
            session.offlineSync.spaces.revoke(space: space, user: nonMember),
            completes,
          );

          expect(
            await session.offlineSync.spaces.members(space),
            {member: OfflineSyncSpaceRole.readWrite},
          );
        },
      );

      test(
        'when roleOf is called for stored and missing memberships, '
        'then it returns the stored role or null.',
        () async {
          expect(
            await session.offlineSync.spaces.roleOf(user: member, space: space),
            OfflineSyncSpaceRole.readWrite,
          );
          expect(
            await session.offlineSync.spaces.roleOf(user: nonMember, space: space),
            isNull,
          );
        },
      );
    });

    group('Given a database with populated and dormant shared spaces,', () {
      late UuidValue readOnlyUser;
      late UuidValue readWriteUser;
      late UuidValue populatedSpace;
      late UuidValue dormantSpace;

      setUp(() async {
        readOnlyUser = const Uuid().v7obj();
        readWriteUser = const Uuid().v7obj();
        populatedSpace = await session.offlineSync.spaces.create(
          grants: {
            readOnlyUser: OfflineSyncSpaceRole.readOnly,
            readWriteUser: OfflineSyncSpaceRole.readWrite,
          },
        );
        dormantSpace = await session.offlineSync.spaces.create();
      });

      test(
        'when members is called, '
        'then explicit membership maps are returned.',
        () async {
          expect(await session.offlineSync.spaces.members(populatedSpace), {
            readOnlyUser: OfflineSyncSpaceRole.readOnly,
            readWriteUser: OfflineSyncSpaceRole.readWrite,
          });
          expect(await session.offlineSync.spaces.members(dormantSpace), isEmpty);
        },
      );
    });
  });
}

Future<Map<String, int>> _membershipRowCounts(Session session) async {
  return {
    OfflineSyncSpace.t.tableName: await OfflineSyncSpace.db.count(session),
    OfflineSyncSpaceMember.t.tableName: await OfflineSyncSpaceMember.db.count(session),
  };
}
