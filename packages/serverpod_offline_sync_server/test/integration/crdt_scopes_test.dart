import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('[CRDT scopes]', (sessionBuilder, _) {
    late Session session;

    setUp(() {
      session = sessionBuilder.build();
      session.serverpod.initializeCrdtSync(syncTables: []);
    });

    group('Given a database with no shared scopes,', () {
      test(
        'when createFor is called with only a user, '
        'then the user is granted readWrite access to the new scope.',
        () async {
          final user = const Uuid().v7obj();

          final scope = await session.crdt.scopes.createFor(user);

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            CrdtScopeRole.readWrite,
          );
          expect(
            await CrdtScopeMembership.memberScopes(session, user),
            contains(scope),
          );
        },
      );

      test(
        'when createFor is called with a user and a role, '
        'then the user is granted that role.',
        () async {
          final user = const Uuid().v7obj();

          final scope = await session.crdt.scopes.createFor(
            user,
            role: CrdtScopeRole.readOnly,
          );

          expect(
            await session.crdt.scopes.members(scope),
            {user: CrdtScopeRole.readOnly},
          );
        },
      );

      test(
        'when create is called without grants, '
        'then the new shared scope is dormant and has no explicit members.',
        () async {
          final user = const Uuid().v7obj();

          final scope = await session.crdt.scopes.create();

          expect(await session.crdt.scopes.members(scope), isEmpty);
          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            isNull,
          );
          expect(
            await CrdtScopeMembership.memberScopes(session, user),
            isNot(contains(scope)),
          );
        },
      );

      test(
        'when create is called with several grants, '
        'then every membership is stored with its role.',
        () async {
          final writer = const Uuid().v7obj();
          final reader = const Uuid().v7obj();

          final scope = await session.crdt.scopes.create(
            grants: {
              writer: CrdtScopeRole.readWrite,
              reader: CrdtScopeRole.readOnly,
            },
          );

          expect(await session.crdt.scopes.members(scope), {
            writer: CrdtScopeRole.readWrite,
            reader: CrdtScopeRole.readOnly,
          });
        },
      );

      test(
        'when roleOf is called for a personal scope with no row, '
        'then readWrite is returned.',
        () async {
          final user = const Uuid().v7obj();

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: user),
            CrdtScopeRole.readWrite,
          );
          expect(await session.crdt.scopes.members(user), isEmpty);
        },
      );

      test(
        'when createFor is called inside a transaction that rolls back, '
        'then no scope or membership rows leak.',
        () async {
          final user = const Uuid().v7obj();
          final countsBefore = await _membershipRowCounts(session);

          await expectLater(
            session.db.transaction((tx) async {
              await session.crdt.scopes.createFor(user, transaction: tx);
              throw StateError('rollback');
            }),
            throwsStateError,
          );

          expect(await _membershipRowCounts(session), countsBefore);
        },
      );

      test(
        'when grant is called for an unknown shared scope, '
        'then CrdtScopeNotFoundException is thrown.',
        () async {
          final missingScope = const Uuid().v7obj();

          await expectLater(
            session.crdt.scopes.grant(
              scope: missingScope,
              user: const Uuid().v7obj(),
              role: CrdtScopeRole.readWrite,
            ),
            throwsA(
              isA<CrdtScopeNotFoundException>().having(
                (error) => error.scope,
                'scope',
                missingScope,
              ),
            ),
          );
        },
      );
    });

    group('Given a database with a dormant shared scope,', () {
      late UuidValue scope;

      setUp(() async {
        scope = await session.crdt.scopes.create();
      });

      test(
        'when grant is called, '
        'then the membership is inserted.',
        () async {
          final user = const Uuid().v7obj();

          await session.crdt.scopes.grant(
            scope: scope,
            user: user,
            role: CrdtScopeRole.readOnly,
          );

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            CrdtScopeRole.readOnly,
          );
          expect(
            await session.crdt.scopes.members(scope),
            {user: CrdtScopeRole.readOnly},
          );
        },
      );

      test(
        'when grantAll is called with several users, '
        'then all memberships are applied.',
        () async {
          final readOnlyUser = const Uuid().v7obj();
          final readWriteUser = const Uuid().v7obj();

          await session.crdt.scopes.grantAll(scope, {
            readOnlyUser: CrdtScopeRole.readOnly,
            readWriteUser: CrdtScopeRole.readWrite,
          });

          expect(await session.crdt.scopes.members(scope), {
            readOnlyUser: CrdtScopeRole.readOnly,
            readWriteUser: CrdtScopeRole.readWrite,
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
              await session.crdt.scopes.grant(
                scope: scope,
                user: user,
                role: CrdtScopeRole.readWrite,
                transaction: tx,
              );
              throw StateError('rollback');
            }),
            throwsStateError,
          );

          expect(await _membershipRowCounts(session), countsBefore);
          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            isNull,
          );
        },
      );
    });

    group('Given a database with a readOnly member on a shared scope,', () {
      late UuidValue user;
      late UuidValue scope;

      setUp(() async {
        user = const Uuid().v7obj();
        scope = await session.crdt.scopes.create(
          grants: {user: CrdtScopeRole.readOnly},
        );
      });

      test(
        'when grant is called again for the same member with readWrite, '
        'then the existing membership is updated.',
        () async {
          await session.crdt.scopes.grant(
            scope: scope,
            user: user,
            role: CrdtScopeRole.readWrite,
          );

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            CrdtScopeRole.readWrite,
          );
          expect(
            await session.crdt.scopes.members(scope),
            {user: CrdtScopeRole.readWrite},
          );
        },
      );
    });

    group('Given a database with a shared scope that has one readWrite member,', () {
      late UuidValue member;
      late UuidValue nonMember;
      late UuidValue scope;

      setUp(() async {
        member = const Uuid().v7obj();
        nonMember = const Uuid().v7obj();
        scope = await session.crdt.scopes.createFor(member);
      });

      test(
        'when revoke is called for the member, '
        'then the membership is removed.',
        () async {
          await session.crdt.scopes.revoke(scope: scope, user: member);

          expect(
            await session.crdt.scopes.roleOf(user: member, scope: scope),
            isNull,
          );
          expect(await session.crdt.scopes.members(scope), isEmpty);
        },
      );

      test(
        'when revoke is called for a non-member, '
        'then it completes without changing the scope members.',
        () async {
          await expectLater(
            session.crdt.scopes.revoke(scope: scope, user: nonMember),
            completes,
          );

          expect(
            await session.crdt.scopes.members(scope),
            {member: CrdtScopeRole.readWrite},
          );
        },
      );

      test(
        'when roleOf is called for stored and missing memberships, '
        'then it returns the stored role or null.',
        () async {
          expect(
            await session.crdt.scopes.roleOf(user: member, scope: scope),
            CrdtScopeRole.readWrite,
          );
          expect(
            await session.crdt.scopes.roleOf(user: nonMember, scope: scope),
            isNull,
          );
        },
      );
    });

    group('Given a database with populated and dormant shared scopes,', () {
      late UuidValue readOnlyUser;
      late UuidValue readWriteUser;
      late UuidValue populatedScope;
      late UuidValue dormantScope;

      setUp(() async {
        readOnlyUser = const Uuid().v7obj();
        readWriteUser = const Uuid().v7obj();
        populatedScope = await session.crdt.scopes.create(
          grants: {
            readOnlyUser: CrdtScopeRole.readOnly,
            readWriteUser: CrdtScopeRole.readWrite,
          },
        );
        dormantScope = await session.crdt.scopes.create();
      });

      test(
        'when members is called, '
        'then explicit membership maps are returned.',
        () async {
          expect(await session.crdt.scopes.members(populatedScope), {
            readOnlyUser: CrdtScopeRole.readOnly,
            readWriteUser: CrdtScopeRole.readWrite,
          });
          expect(await session.crdt.scopes.members(dormantScope), isEmpty);
        },
      );
    });
  });
}

Future<Map<String, int>> _membershipRowCounts(Session session) async {
  return {
    CrdtScope.t.tableName: await CrdtScope.db.count(session),
    CrdtScopeMember.t.tableName: await CrdtScopeMember.db.count(session),
  };
}
