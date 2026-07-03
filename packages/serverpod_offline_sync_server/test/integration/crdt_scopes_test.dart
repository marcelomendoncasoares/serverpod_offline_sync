import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given initialized CRDT scope management,',
    (sessionBuilder, _) {
      final bootstrapSession = sessionBuilder.build();
      bootstrapSession.serverpod.initializeCrdtSync(syncTables: []);

      late Session session;

      setUp(() {
        session = sessionBuilder.build();
      });

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
        'when createFor is called with an explicit role, '
        'then the user is granted that role.',
        () async {
          final user = const Uuid().v7obj();

          final scope = await session.crdt.scopes.createFor(
            user,
            role: CrdtScopeRole.readOnly,
          );

          expect(await session.crdt.scopes.members(scope), {
            user: CrdtScopeRole.readOnly,
          });
        },
      );

      test(
        'when create is called without grants, '
        'then the scope is dormant and has no explicit members.',
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
        'when grant is called for a dormant scope, '
        'then the membership is inserted.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await session.crdt.scopes.create();

          await session.crdt.scopes.grant(
            scope: scope,
            user: user,
            role: CrdtScopeRole.readOnly,
          );

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            CrdtScopeRole.readOnly,
          );
          expect(await session.crdt.scopes.members(scope), {
            user: CrdtScopeRole.readOnly,
          });
        },
      );

      test(
        'when grant is called again for the same member with a different role, '
        'then the existing membership is updated.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await session.crdt.scopes.create();

          await session.crdt.scopes.grant(
            scope: scope,
            user: user,
            role: CrdtScopeRole.readOnly,
          );
          await session.crdt.scopes.grant(
            scope: scope,
            user: user,
            role: CrdtScopeRole.readWrite,
          );

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            CrdtScopeRole.readWrite,
          );
          expect(await session.crdt.scopes.members(scope), {
            user: CrdtScopeRole.readWrite,
          });
        },
      );

      test(
        'when grant is called for an unknown scope, '
        'then ArgumentError is thrown.',
        () async {
          await expectLater(
            session.crdt.scopes.grant(
              scope: const Uuid().v7obj(),
              user: const Uuid().v7obj(),
              role: CrdtScopeRole.readWrite,
            ),
            throwsArgumentError,
          );
        },
      );

      test(
        'when revoke is called for an existing membership, '
        'then the membership is removed.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await session.crdt.scopes.createFor(user);

          await session.crdt.scopes.revoke(scope: scope, user: user);

          expect(
            await session.crdt.scopes.roleOf(user: user, scope: scope),
            isNull,
          );
          expect(await session.crdt.scopes.members(scope), isEmpty);
        },
      );

      test(
        'when revoke is called for a non-member, '
        'then it completes without changing the scope members.',
        () async {
          final member = const Uuid().v7obj();
          final nonMember = const Uuid().v7obj();
          final scope = await session.crdt.scopes.createFor(member);

          await expectLater(
            session.crdt.scopes.revoke(scope: scope, user: nonMember),
            completes,
          );

          expect(await session.crdt.scopes.members(scope), {
            member: CrdtScopeRole.readWrite,
          });
        },
      );

      test(
        'when grantAll is called with several users, '
        'then all memberships are applied.',
        () async {
          final readOnlyUser = const Uuid().v7obj();
          final readWriteUser = const Uuid().v7obj();
          final scope = await session.crdt.scopes.create();

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
        'when roleOf is called for stored and missing memberships, '
        'then it returns the stored role or null.',
        () async {
          final member = const Uuid().v7obj();
          final missing = const Uuid().v7obj();
          final scope = await session.crdt.scopes.createFor(member);

          expect(
            await session.crdt.scopes.roleOf(user: member, scope: scope),
            CrdtScopeRole.readWrite,
          );
          expect(
            await session.crdt.scopes.roleOf(user: missing, scope: scope),
            isNull,
          );
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
        'when members is called for populated and dormant scopes, '
        'then explicit membership maps are returned.',
        () async {
          final readOnlyUser = const Uuid().v7obj();
          final readWriteUser = const Uuid().v7obj();
          final populatedScope = await session.crdt.scopes.create(
            grants: {
              readOnlyUser: CrdtScopeRole.readOnly,
              readWriteUser: CrdtScopeRole.readWrite,
            },
          );
          final dormantScope = await session.crdt.scopes.create();

          expect(await session.crdt.scopes.members(populatedScope), {
            readOnlyUser: CrdtScopeRole.readOnly,
            readWriteUser: CrdtScopeRole.readWrite,
          });
          expect(await session.crdt.scopes.members(dormantScope), isEmpty);
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
        'when grant is called inside a transaction that rolls back, '
        'then no membership row leaks.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await session.crdt.scopes.create();
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
    },
  );
}

Future<Map<String, int>> _membershipRowCounts(Session session) async {
  return {
    CrdtScope.t.tableName: await _countRows(session, CrdtScope.t.tableName),
    CrdtScopeMember.t.tableName: await _countRows(
      session,
      CrdtScopeMember.t.tableName,
    ),
  };
}

Future<int> _countRows(Session session, String tableName) async {
  final result = await session.db.unsafeQuery('SELECT COUNT(*) FROM "$tableName"');
  return (result.single[0] as num).toInt();
}
