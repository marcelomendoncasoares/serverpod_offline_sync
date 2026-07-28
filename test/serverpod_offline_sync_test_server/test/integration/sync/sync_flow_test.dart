import 'dart:async';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';
import '../test_tools/stderr_capture.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  final clientSyncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];

  final serverSyncTables = [
    server.Address.t,
    server.Person.t,
    server.Types.t,
    server.Unique.t,
  ];

  late client.Client testClient;
  late CrdtDatabaseSession serverSession;
  late CrdtDatabaseSession clientSession;

  withServerpod(
    '[CRDT Sync]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group('Given no local or remote pending changes,', () {
        test(
          'when client syncOnce is called repeatedly on a reused client, '
          'then the rounds complete promptly instead of stalling on teardown.',
          () async {
            // The first round opens the shared websocket connection; later
            // rounds reuse it. If a finished round leaves its inbound transport
            // stream paused, closing that stream stalls for the transport close
            // timeout (~6s), and the stall lands on the next round's critical
            // path. Empty rounds should each take milliseconds, so several of
            // them together must stay well under a single close-timeout budget,
            // independent of how much data was synced.
            const rounds = 6;
            final stopwatch = Stopwatch()..start();
            for (var round = 0; round < rounds; round++) {
              await testClient.crdt.syncOnce(clientSession);
            }
            stopwatch.stop();

            expect(
              stopwatch.elapsed,
              lessThan(const Duration(seconds: 10)),
              reason:
                  '$rounds empty reused syncOnce rounds took '
                  '${stopwatch.elapsed}; a leaked paused inbound stream stalls '
                  'each reused round on the ~6s transport close timeout.',
            );
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );

        test(
          'when client syncContinuously is called, '
          'then neither side reports a successful merge.',
          () async {
            var mergeSuccessCount = 0;
            final syncSession = testClient.crdt.syncContinuously(
              clientSession,
              onMergeSuccess: (_, _) => mergeSuccessCount++,
            );
            addTearDown(syncSession.cancel);

            await Future<void>.delayed(const Duration(seconds: 2));

            expect(mergeSuccessCount, 0);
          },
        );

        test(
          'when client syncContinuously runs, '
          'then neither side keeps sending frames while idle.',
          () async {
            final clientToServer = StreamController<CrdtSyncStreamEvent>();
            final serverToClient = StreamController<CrdtSyncStreamEvent>();
            final clientOutboundEvents = <CrdtSyncStreamEvent>[];
            final serverOutboundEvents = <CrdtSyncStreamEvent>[];

            void addIfOpen(
              StreamController<CrdtSyncStreamEvent> controller,
              CrdtSyncStreamEvent event,
            ) {
              if (!controller.isClosed) {
                controller.add(event);
              }
            }

            final clientSync = CrdtSync(
              syncTables: clientSyncTables,
              serializationManager: clientSession.db.serializationManager,
            );

            final clientSubscription = clientSync
                .sync(
                  clientSession,
                  userId: testCrdtUserId,
                  inbound: serverToClient.stream,
                  once: false,
                  mode: CrdtSyncPeerMode.follower,
                )
                .listen((event) {
                  clientOutboundEvents.add(event);
                  addIfOpen(clientToServer, event);
                });

            final serverSubscription = rawServerSession.crdt
                .sync(
                  userId: testCrdtUserId,
                  inbound: clientToServer.stream,
                  once: false,
                  mode: CrdtSyncPeerMode.authoritative,
                )
                .listen((event) {
                  serverOutboundEvents.add(event);
                  addIfOpen(serverToClient, event);
                });

            addTearDown(() async {
              await clientToServer.close();
              await serverToClient.close();
              await clientSubscription.cancel();
              await serverSubscription.cancel();
            });

            // Let the session establish: connect, scope handshake, first batch.
            await Future<void>.delayed(const Duration(seconds: 1));
            clientOutboundEvents.clear();
            serverOutboundEvents.clear();

            // An idle multi-scope session must then stay silent instead of
            // re-announcing the scope set and an end-of-batch every cycle.
            await Future<void>.delayed(const Duration(seconds: 1));

            expect(clientOutboundEvents, isEmpty);
            expect(serverOutboundEvents, isEmpty);

            for (final events in [clientOutboundEvents, serverOutboundEvents]) {
              expect(events.whereType<CrdtSyncMergeChunk>(), isEmpty);
              expect(events.whereType<CrdtSyncEndOfBatch>(), isEmpty);
              expect(events.whereType<CrdtSyncClose>(), isEmpty);
              expect(events.whereType<CrdtSyncIdleTimeout>(), isEmpty);
            }
          },
        );

        test(
          'when a running syncContinuously session is cancelled, '
          'then method stream teardown does not close the shared websocket.',
          () async {
            final stderr = await captureStderr(() async {
              final syncSession = testClient.crdt.syncContinuously(clientSession);

              await Future<void>.delayed(const Duration(milliseconds: 300));
              await syncSession.cancel();
              await syncSession.done;
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });

            expect(stderr, isNot(contains('WebSocketConnectionClosed')));
            expect(
              stderr,
              isNot(contains('Message posted when web socket connection is closed')),
            );
          },
        );
      });

      group('Given a pending client person,', () {
        late UuidValue personId;

        setUp(() async {
          personId = const Uuid().v7obj();

          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: personId, name: 'client-person'),
          );
        });

        test(
          'when client syncOnce is called, '
          'then the server merges the client pending changes.',
          () async {
            await testClient.crdt.syncOnce(clientSession);

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.id, personId);
            expect(serverPerson.name, 'client-person');
          },
        );

        test(
          'when client syncContinuously is called, '
          'then the server merges the client pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final serverPerson = await server.Person.db.findById(
                serverSession,
                personId,
              );
              return serverPerson != null;
            });

            await syncSession.cancel();

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.id, personId);
            expect(serverPerson.name, 'client-person');
          },
        );

        test(
          'when a running syncContinuously session is cancelled, '
          'then method stream teardown does not close the shared websocket.',
          () async {
            final stderr = await captureStderr(() async {
              final syncSession = testClient.crdt.syncContinuously(clientSession);

              await syncSession.cancel();
              await syncSession.done;
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });

            expect(stderr, isNot(contains('WebSocketConnectionClosed')));
            expect(
              stderr,
              isNot(contains('Message posted when web socket connection is closed')),
            );
          },
        );
      });

      group('Given a pending server person,', () {
        late UuidValue personId;

        setUp(() async {
          personId = const Uuid().v7obj();

          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: personId, name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when client syncContinuously is called, '
          'then the client merges the server pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final clientPerson = await client.Person.db.findById(
                clientSession,
                personId,
              );
              return clientPerson != null;
            });

            await syncSession.cancel();

            final clientPerson = await client.Person.db.findById(
              clientSession,
              personId,
            );

            expect(clientPerson, isNotNull);
            expect(clientPerson!.id, personId);
            expect(clientPerson.name, 'server-person');
          },
        );
      });

      group('Given pending client and server persons,', () {
        late UuidValue clientPersonId;
        late UuidValue serverPersonId;

        setUp(() async {
          clientPersonId = const Uuid().v7obj();
          serverPersonId = const Uuid().v7obj();

          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: clientPersonId, name: 'client-person'),
          );

          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: serverPersonId, name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when client syncOnce is called, '
          'then both the client and server have the two persons.',
          () async {
            await testClient.crdt.syncOnce(clientSession);

            final clientPerson = await client.Person.db.find(clientSession);

            expect(clientPerson, hasLength(2));
            expect(clientPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(clientPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });

            final serverPerson = await server.Person.db.find(serverSession);

            expect(serverPerson, hasLength(2));
            expect(serverPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(serverPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });
          },
        );

        test(
          'when client syncContinuously is called, '
          'then the client merges the server pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final clientMergedPerson = await client.Person.db.findById(
                clientSession,
                serverPersonId,
              );
              final serverMergedPerson = await server.Person.db.findById(
                serverSession,
                clientPersonId,
              );
              return clientMergedPerson != null && serverMergedPerson != null;
            });
            await syncSession.cancel();

            final clientPerson = await client.Person.db.find(clientSession);

            expect(clientPerson, hasLength(2));
            expect(clientPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(clientPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });

            final serverPerson = await server.Person.db.find(serverSession);

            expect(serverPerson, hasLength(2));
            expect(serverPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(serverPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });
          },
        );
      });

      group('Given a person synchronized to the client and server,', () {
        late UuidValue personId;

        setUp(() async {
          personId = const Uuid().v7obj();

          await client.Person.db.insertRow(
            clientSession,
            client.Person(
              id: personId,
              name: 'synced-person',
              surname: 'original-surname',
            ),
          );

          await testClient.crdt.syncOnce(clientSession);
        });

        test(
          'when the server deletes the person and the client syncs, '
          'then the person is hidden on the client.',
          () async {
            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );
            await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.deleteRow(
                serverSession,
                serverPerson!,
                transaction: tx,
              ),
            );

            await testClient.crdt.syncOnce(clientSession);

            expect(
              await client.Person.db.findById(clientSession, personId),
              isNull,
            );

            final hiddenPerson = await client.Person.db.findFirstRow(
              clientSession,
              where: (t) => t.id.equals(personId) & t.includeHiddenRows,
            );
            expect(hiddenPerson, isNotNull);
          },
        );

        test(
          'when the client and server update different columns offline, '
          'then both edits converge on both sides after one sync.',
          () async {
            final clientPerson = await client.Person.db.findById(
              clientSession,
              personId,
            );
            await client.Person.db.updateRow(
              clientSession,
              clientPerson!.copyWith(name: 'client-edited-name'),
              columns: (t) => [t.name],
            );

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );
            await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.updateRow(
                serverSession,
                serverPerson!.copyWith(surname: 'server-edited-surname'),
                columns: (t) => [t.surname],
                transaction: tx,
              ),
            );

            await testClient.crdt.syncOnce(clientSession);

            final mergedClientPerson = await client.Person.db.findById(
              clientSession,
              personId,
            );
            expect(mergedClientPerson, isNotNull);
            expect(mergedClientPerson!.name, 'client-edited-name');
            expect(mergedClientPerson.surname, 'server-edited-surname');

            final mergedServerPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );
            expect(mergedServerPerson, isNotNull);
            expect(mergedServerPerson!.name, 'client-edited-name');
            expect(mergedServerPerson.surname, 'server-edited-surname');
          },
        );

        test(
          'when the client deletes and reinserts the person offline, '
          'then the reinserted row is visible on the server after sync.',
          () async {
            final clientPerson = await client.Person.db.findById(
              clientSession,
              personId,
            );
            await client.Person.db.deleteRow(clientSession, clientPerson!);
            await client.Person.db.insertRow(
              clientSession,
              clientPerson.copyWith(name: 'reinserted-name'),
            );

            await testClient.crdt.syncOnce(clientSession);

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );
            expect(serverPerson, isNotNull);
            expect(serverPerson!.name, 'reinserted-name');
          },
        );
      });

      group('Given a pending client Types row with every field set,', () {
        late client.Types clientTypes;

        setUp(() async {
          clientTypes = await client.Types.db.insertRow(
            clientSession,
            client.Types(
              id: const Uuid().v7obj(),
              aBool: true,
              aDateTime: DateTime.utc(2026, 5, 8, 12, 34, 56),
              aText: 'wire text',
              anInt: 42,
              anInt64: BigInt.parse('9007199254740993'),
              aReal: 3.14,
              aBlob: ByteData.sublistView(
                Uint8List.fromList([1, 2, 3, 4]),
              ),
              anEnum: client.TypesEnum.gamma,
              optionalText: 'optional',
              optionalUuid: const Uuid().v7obj(),
            ),
          );
        });

        test(
          'when client syncOnce is called, '
          'then every field value survives the wire roundtrip to the server.',
          () async {
            await testClient.crdt.syncOnce(clientSession);

            final serverTypes = await server.Types.db.findById(
              serverSession,
              clientTypes.id!,
            );

            expect(serverTypes, isNotNull);
            expect(serverTypes!.aBool, clientTypes.aBool);
            expect(serverTypes.aDateTime, clientTypes.aDateTime);
            expect(serverTypes.aText, clientTypes.aText);
            expect(serverTypes.anInt, clientTypes.anInt);
            expect(serverTypes.anInt64, clientTypes.anInt64);
            expect(serverTypes.aReal, clientTypes.aReal);
            expect(
              serverTypes.aBlob.buffer.asUint8List(),
              clientTypes.aBlob.buffer.asUint8List(),
            );
            expect(serverTypes.anEnum, server.TypesEnum.gamma);
            expect(serverTypes.optionalText, clientTypes.optionalText);
            expect(serverTypes.optionalUuid, clientTypes.optionalUuid);
          },
        );

        group('with the row synchronized to the server,', () {
          setUp(() async {
            await testClient.crdt.syncOnce(clientSession);
          });

          test(
            'when the server updates typed columns and the client syncs again, '
            'then the client receives the typed values.',
            () async {
              final serverTypes = await server.Types.db.findById(
                serverSession,
                clientTypes.id!,
              );
              final updatedDateTime = DateTime.utc(2027, 1, 2, 3, 4, 5);
              final updatedInt64 = BigInt.parse('12345678901234567890');
              await serverSession.db.transactionForUser(
                testCrdtUserId,
                (tx) => server.Types.db.updateRow(
                  serverSession,
                  serverTypes!.copyWith(
                    aDateTime: updatedDateTime,
                    anInt64: updatedInt64,
                    anEnum: server.TypesEnum.beta,
                  ),
                  columns: (t) => [t.aDateTime, t.anInt64, t.anEnum],
                  transaction: tx,
                ),
              );

              await testClient.crdt.syncOnce(clientSession);

              final mergedTypes = await client.Types.db.findById(
                clientSession,
                clientTypes.id!,
              );
              expect(mergedTypes, isNotNull);
              expect(mergedTypes!.aDateTime, updatedDateTime);
              expect(mergedTypes.anInt64, updatedInt64);
              expect(mergedTypes.anEnum, client.TypesEnum.beta);
            },
          );
        });
      });

      group('Given a running client syncContinuously session,', () {
        late CrdtSyncSession syncSession;

        setUp(() async {
          syncSession = testClient.crdt.syncContinuously(clientSession);
        });

        tearDown(() async {
          await syncSession.cancel();
        });

        test(
          'when the session is cancelled, '
          'then done completes without hanging.',
          () async {
            await syncSession.cancel();
            await expectLater(syncSession.done, completes);
          },
        );

        test(
          'when the session remains idle before cancellation, '
          'then the idle session can still be cancelled cleanly.',
          () async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await syncSession.cancel();
            await expectLater(syncSession.done, completes);
          },
        );

        test(
          'when a new person is inserted into the client, '
          'then the server merges the client pending changes.',
          () async {
            final clientPerson = await client.Person.db.insertRow(
              clientSession,
              client.Person(name: 'client-person'),
            );

            await expectLater(
              _waitUntil(() async {
                final serverPerson = await server.Person.db.findById(
                  serverSession,
                  clientPerson.id!,
                );
                return serverPerson != null && serverPerson.name == 'client-person';
              }),
              completes,
            );
          },
        );

        test(
          'when a new person is inserted into the server for the same user, '
          'then the client merges the server pending changes.',
          () async {
            final serverPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) async => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'server-person'),
                transaction: tx,
              ),
            );

            await expectLater(
              _waitUntil(() async {
                final clientPerson = await client.Person.db.findById(
                  clientSession,
                  serverPerson.id!,
                );
                return clientPerson != null && clientPerson.name == 'server-person';
              }),
              completes,
            );
          },
        );

        test(
          'when a new person is inserted into the server for a different user, '
          'then the client does not merge the server pending changes.',
          () async {
            final serverPerson = await serverSession.db.transactionForUser(
              const Uuid().v7obj(),
              (tx) async => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'server-person'),
                transaction: tx,
              ),
            );

            await expectLater(
              _waitUntil(() async {
                final clientPerson = await client.Person.db.findById(
                  clientSession,
                  serverPerson.id!,
                );
                return clientPerson != null && clientPerson.name == 'server-person';
              }),
              throwsA(isA<TimeoutException>()),
            );
          },
        );
      });

      group(
        'Given a running client syncContinuously session with a merge success callback,',
        () {
          late CrdtSyncSession syncSession;
          late Completer<Hlc> mergeSuccessCompleter;

          setUp(() async {
            mergeSuccessCompleter = Completer<Hlc>();

            syncSession = testClient.crdt.syncContinuously(
              clientSession,
              onMergeSuccess: (_, hlc) => mergeSuccessCompleter.complete(hlc),
            );
          });

          tearDown(() async {
            await syncSession.cancel();
          });

          test(
            'when a new person is inserted into the client, '
            'then the merge success callback is called.',
            () async {
              await client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'client-person'),
              );

              await expectLater(mergeSuccessCompleter.future, completes);
            },
          );

          test(
            'when a new person is inserted into the server for the same user, '
            'then the merge success callback is called.',
            () async {
              await serverSession.db.transactionForUser(
                testCrdtUserId,
                (tx) async => server.Person.db.insertRow(
                  serverSession,
                  server.Person(name: 'server-person'),
                  transaction: tx,
                ),
              );

              await expectLater(mergeSuccessCompleter.future, completes);
            },
          );
        },
      );

      group('Given a user with readWrite membership in a shared scope,', () {
        late UuidValue sharedScopeId;

        setUp(() async {
          sharedScopeId = await rawServerSession.crdt.scopes.createFor(testCrdtUserId);
        });

        group('when client syncOnce is called,', () {
          setUp(() async {
            await testClient.crdt.syncOnce(clientSession);
          });

          test(
            'then the follower projects the shared membership with its role '
            'into the local cache.',
            () async {
              final granted = await CrdtScopeMembership.memberGrants(
                clientSession,
                testCrdtUserId,
              );
              final projected = granted
                  .where((g) => g.uuidScopeId == sharedScopeId)
                  .toList();

              expect(projected, hasLength(1));
              expect(projected.single.role, CrdtScopeRole.readWrite);
            },
          );
        });

        group('with personal and shared scope rows on the server,', () {
          late UuidValue personalPersonId;
          late UuidValue sharedPersonId;

          setUp(() async {
            final personalPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'personal-server-person'),
                transaction: tx,
              ),
            );
            personalPersonId = personalPerson.id!;

            final sharedPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'shared-server-person'),
                transaction: tx,
              ),
              scopeId: sharedScopeId,
            );
            sharedPersonId = sharedPerson.id!;
          });

          test(
            'when client syncOnce is called, '
            'then personal and shared scope rows converge in the same call.',
            () async {
              await testClient.crdt.syncOnce(clientSession);

              final personalClientPerson = await client.Person.db.findById(
                clientSession,
                personalPersonId,
              );
              final sharedClientPerson = await client.Person.db.findById(
                clientSession,
                sharedPersonId,
              );

              expect(personalClientPerson, isNotNull);
              expect(personalClientPerson!.name, 'personal-server-person');
              expect(sharedClientPerson, isNotNull);
              expect(sharedClientPerson!.name, 'shared-server-person');
            },
          );

          group('with those rows synchronized to the client,', () {
            setUp(() async {
              await testClient.crdt.syncOnce(clientSession);
            });

            test(
              'when finding people scoped to the shared scope uuid, '
              'then only the shared scope row is returned.',
              () async {
                final sharedOnly = await client.Person.db.find(
                  clientSession,
                  where: (t) => t.scopeEquals(sharedScopeId),
                );

                expect(sharedOnly, hasLength(1));
                expect(sharedOnly.single.id, sharedPersonId);
              },
            );

            test(
              'when finding people scoped to the personal scope uuid, '
              'then only the personal scope row is returned.',
              () async {
                final personalRows = await client.Person.db.find(
                  clientSession,
                  where: (t) => t.scopeEquals(testCrdtUserId),
                );

                expect(personalRows, hasLength(1));
                expect(personalRows.single.id, personalPersonId);
              },
            );
          });
        });

        group(
          'with a local person pending in the shared scope,',
          () {
            late UuidValue clientPersonId;

            setUp(() async {
              await testClient.crdt.syncOnce(clientSession);

              final clientPerson = await clientSession.db.transactionForUser(
                testCrdtUserId,
                (tx) => client.Person.db.insertRow(
                  clientSession,
                  client.Person(name: 'read-write-member-write'),
                  transaction: tx,
                ),
                scopeId: sharedScopeId,
              );
              clientPersonId = clientPerson.id!;
            });

            test(
              'when client syncOnce is called, '
              'then the server accepts the readWrite member write.',
              () async {
                await testClient.crdt.syncOnce(clientSession);

                final serverPerson = await server.Person.db.findById(
                  serverSession,
                  clientPersonId,
                );

                expect(serverPerson, isNotNull);
                expect(serverPerson!.name, 'read-write-member-write');
              },
            );
          },
        );

        test(
          'when client syncContinuously is already running and a shared scope is granted, '
          'then the client adopts and syncs the scope in the next cycle.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            final laterScopeId = await rawServerSession.crdt.scopes.createFor(
              testCrdtUserId,
            );

            final sharedPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'later-shared-person'),
                transaction: tx,
              ),
              scopeId: laterScopeId,
            );

            await _waitUntil(() async {
              final clientPerson = await client.Person.db.findById(
                clientSession,
                sharedPerson.id!,
              );
              return clientPerson?.name == 'later-shared-person';
            });
          },
        );

        group(
          'with an unsynced local person in the shared scope,',
          () {
            late UuidValue pendingPersonId;

            setUp(() async {
              await testClient.crdt.syncOnce(clientSession);

              final pendingPerson = await clientSession.db.transactionForUser(
                testCrdtUserId,
                (tx) => client.Person.db.insertRow(
                  clientSession,
                  client.Person(name: 'pending-before-demotion'),
                  transaction: tx,
                ),
                scopeId: sharedScopeId,
              );
              pendingPersonId = pendingPerson.id!;
            });

            group(
              'when the member is demoted to readOnly with a new server row and client syncOnce is called,',
              () {
                late UuidValue inboundPersonId;

                setUp(() async {
                  await rawServerSession.crdt.scopes.grant(
                    scope: sharedScopeId,
                    user: testCrdtUserId,
                    role: CrdtScopeRole.readOnly,
                  );
                  final inboundPerson = await serverSession.db.transactionForUser(
                    sharedScopeId,
                    (tx) => server.Person.db.insertRow(
                      serverSession,
                      server.Person(name: 'inbound-after-demotion'),
                      transaction: tx,
                    ),
                  );
                  inboundPersonId = inboundPerson.id!;

                  await testClient.crdt.syncOnce(clientSession);
                });

                test('then the projected role is updated to readOnly.', () async {
                  final grants = await CrdtScopeMembership.memberGrants(
                    clientSession,
                    testCrdtUserId,
                  );

                  expect(
                    grants.singleWhere((g) => g.uuidScopeId == sharedScopeId).role,
                    CrdtScopeRole.readOnly,
                  );
                });

                test('then the inbound server row is received.', () async {
                  final inboundPerson = await client.Person.db.findById(
                    clientSession,
                    inboundPersonId,
                  );

                  expect(inboundPerson, isNotNull);
                  expect(inboundPerson!.name, 'inbound-after-demotion');
                });

                test(
                  'then the pending local change is not streamed and no violation is recorded.',
                  () async {
                    expect(
                      await server.Person.db.findById(
                        serverSession,
                        pendingPersonId,
                      ),
                      isNull,
                    );
                    expect(
                      await CrdtSyncIntegrityViolation.db.find(
                        rawServerSession,
                        where: (t) =>
                            t.type.equals(CrdtSyncViolationType.unauthorizedWrite),
                      ),
                      isEmpty,
                    );
                  },
                );
              },
            );
          },
        );

        test(
          'when the membership is revoked during a running syncContinuously session, '
          'then the scope stops syncing without dropping the session.',
          () async {
            final sharedPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'shared-before-revoke'),
                transaction: tx,
              ),
              scopeId: sharedScopeId,
            );
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);
            await _waitUntil(() async {
              return await client.Person.db.findById(
                    clientSession,
                    sharedPerson.id!,
                  ) !=
                  null;
            });

            await rawServerSession.crdt.scopes.revoke(
              scope: sharedScopeId,
              user: testCrdtUserId,
            );

            // The revoked scope's rows disappear from membership-wide reads…
            await _waitUntil(() async {
              return await client.Person.db.findById(
                    clientSession,
                    sharedPerson.id!,
                  ) ==
                  null;
            });

            // …while the same session keeps syncing the personal scope.
            final personalPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'personal-after-revoke'),
                transaction: tx,
              ),
            );
            await _waitUntil(() async {
              return await client.Person.db.findById(
                    clientSession,
                    personalPerson.id!,
                  ) !=
                  null;
            });
          },
        );

        group(
          'with a server person already synchronized to the client,',
          () {
            late UuidValue revokedPersonId;

            setUp(() async {
              final revokedPerson = await serverSession.db.transactionForUser(
                testCrdtUserId,
                (tx) => server.Person.db.insertRow(
                  serverSession,
                  server.Person(name: 'revoked-scope-person'),
                  transaction: tx,
                ),
                scopeId: sharedScopeId,
              );
              revokedPersonId = revokedPerson.id!;
              await testClient.crdt.syncOnce(clientSession);
            });

            group('with the revoked membership synchronized to the client,', () {
              setUp(() async {
                await rawServerSession.crdt.scopes.revoke(
                  scope: sharedScopeId,
                  user: testCrdtUserId,
                );
                await testClient.crdt.syncOnce(clientSession);
              });

              test(
                'when member grants are resolved, '
                'then the revoked membership is absent from the local cache.',
                () async {
                  final grants = await CrdtScopeMembership.memberGrants(
                    clientSession,
                    testCrdtUserId,
                  );

                  expect(
                    grants.where((g) => g.uuidScopeId == sharedScopeId),
                    isEmpty,
                  );
                },
              );

              test(
                'when finding the person by id, '
                'then it is no longer returned by membership-wide reads.',
                () async {
                  final revokedPerson = await client.Person.db.findById(
                    clientSession,
                    revokedPersonId,
                  );

                  expect(revokedPerson, isNull);
                },
              );

              test(
                'when writing a person locally in the revoked scope, '
                'then the write is rejected before mutation.',
                () async {
                  await expectLater(
                    clientSession.db.transactionForUser(
                      testCrdtUserId,
                      (tx) => client.Person.db.insertRow(
                        clientSession,
                        client.Person(name: 'blocked-after-revoke'),
                        transaction: tx,
                      ),
                      scopeId: sharedScopeId,
                    ),
                    throwsA(isA<CrdtScopeMembershipException>()),
                  );

                  final blockedRows = await client.Person.db.find(
                    clientSession,
                    where: (t) => t.name.equals('blocked-after-revoke'),
                  );
                  expect(blockedRows, isEmpty);
                },
              );
            });
          },
        );
      });

      group(
        'Given a user with readOnly membership in a shared scope containing a server row,',
        () {
          late UuidValue readOnlyScopeId;
          late UuidValue serverPersonId;

          setUp(() async {
            readOnlyScopeId = await rawServerSession.crdt.scopes.create(
              grants: {testCrdtUserId: CrdtScopeRole.readOnly},
            );
            final serverPerson = await serverSession.db.transactionForUser(
              readOnlyScopeId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'read-only-server-person'),
                transaction: tx,
              ),
            );
            serverPersonId = serverPerson.id!;
          });

          test(
            'when client syncOnce is called, '
            'then the readOnly scope row is readable on the client.',
            () async {
              await testClient.crdt.syncOnce(clientSession);

              final clientPerson = await client.Person.db.findById(
                clientSession,
                serverPersonId,
              );

              expect(clientPerson, isNotNull);
              expect(clientPerson!.name, 'read-only-server-person');
            },
          );

          test(
            'when client syncOnce is called, '
            'then syncOnce closes without unexpected server protocol errors.',
            () async {
              final stderr = await captureStderr(
                () => testClient.crdt.syncOnce(clientSession),
              );

              expect(stderr, isNot(contains('CrdtSyncUnexpectedEventException')));
            },
          );

          group('with the membership synchronized to the client,', () {
            setUp(() async {
              await testClient.crdt.syncOnce(clientSession);
            });

            test(
              'when writing a person locally in the readOnly scope, '
              'then the write is rejected before mutation.',
              () async {
                await expectLater(
                  clientSession.db.transactionForUser(
                    testCrdtUserId,
                    (tx) => client.Person.db.insertRow(
                      clientSession,
                      client.Person(name: 'blocked-read-only-write'),
                      transaction: tx,
                    ),
                    scopeId: readOnlyScopeId,
                  ),
                  throwsA(isA<CrdtScopeRoleException>()),
                );

                final blockedRows = await client.Person.db.find(
                  clientSession,
                  where: (t) => t.name.equals('blocked-read-only-write'),
                );
                expect(blockedRows, isEmpty);
              },
            );
          });
        },
      );

      group(
        'Given a user without membership in a shared scope,',
        () {
          late UuidValue ungrantedScopeId;

          setUp(() async {
            ungrantedScopeId = await rawServerSession.crdt.scopes.create();
          });

          test(
            'when a transaction is started for that scope, '
            'then it is rejected before writing.',
            () async {
              await expectLater(
                serverSession.db.transactionForUser(
                  testCrdtUserId,
                  (tx) => server.Person.db.insertRow(
                    serverSession,
                    server.Person(name: 'ungranted-server-person'),
                    transaction: tx,
                  ),
                  scopeId: ungrantedScopeId,
                ),
                throwsA(isA<CrdtScopeMembershipException>()),
              );
            },
          );
        },
      );

      group(
        'Given a client with personal and local ungranted scope changes,',
        () {
          late UuidValue ungrantedScopeId;
          late UuidValue personalPersonId;
          late UuidValue ungrantedPersonId;

          setUp(() async {
            ungrantedScopeId = const Uuid().v7obj();
            final personalPerson = await client.Person.db.insertRow(
              clientSession,
              client.Person(name: 'personal-client-person'),
            );
            final ungrantedPerson = await clientSession.db.transactionForUser(
              ungrantedScopeId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'ungranted-client-person'),
                transaction: tx,
              ),
            );
            personalPersonId = personalPerson.id!;
            ungrantedPersonId = ungrantedPerson.id!;
          });

          test(
            'when client syncOnce is called, '
            'then the ungranted scope is not streamed to the server.',
            () async {
              await testClient.crdt.syncOnce(clientSession);

              final serverPersonalPerson = await server.Person.db.findById(
                serverSession,
                personalPersonId,
              );
              final serverUngrantedPerson = await server.Person.db.findById(
                serverSession,
                ungrantedPersonId,
              );

              expect(serverPersonalPerson, isNotNull);
              expect(serverPersonalPerson!.name, 'personal-client-person');
              expect(serverUngrantedPerson, isNull);
            },
          );
        },
      );

      test(
        'Given an unauthenticated client and an initialized client CRDT session, '
        'when the client calls syncOnce, '
        'then the unauthorized error is surfaced without waiting for stream teardown.',
        () async {
          final unauthenticatedClient = client.Client(
            'http://localhost:${rawServerSession.server.port}',
          );

          await expectLater(
            unauthenticatedClient.crdt
                .syncOnce(clientSession)
                .timeout(const Duration(seconds: 3)),
            throwsA(
              predicate<Object>(
                (error) =>
                    error.toString() ==
                    'ServerpodClientException: Unauthorized, statusCode = 401',
              ),
            ),
          );
        },
      );
    },
  );

  withServerpod(
    'Given initialized client and server CRDT sessions with a continuous sync interval,',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      const syncInterval = Duration(milliseconds: 400);

      rawServerSession.serverpod
        ..initializeCrdtSync(
          syncTables: serverSyncTables,
          continuousSyncInterval: syncInterval,
        )
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
          continuousSyncInterval: syncInterval,
        );
        await clientSession.db.initialize();
      });

      test(
        'when a client change is inserted after a sync round, '
        'then the next merge chunk waits for the configured interval.',
        () async {
          var mergeSuccessCount = 0;
          final firstMergeCompleter = Completer<void>();
          final secondMergeCompleter = Completer<void>();

          final syncSession = testClient.crdt.syncContinuously(
            clientSession,
            onMergeSuccess: (_, _) {
              switch (++mergeSuccessCount) {
                case 1:
                  firstMergeCompleter.complete();
                case 2:
                  secondMergeCompleter.complete();
                default:
                  throw Exception('Unexpected merge success count: $mergeSuccessCount');
              }
            },
          );

          addTearDown(syncSession.cancel);

          await client.Person.db.insertRow(
            clientSession,
            client.Person(
              id: const Uuid().v7obj(),
              name: 'first-person',
            ),
          );

          await expectLater(
            firstMergeCompleter.future.timeout(const Duration(seconds: 3)),
            completes,
          );

          final stopwatch = Stopwatch()..start();
          await client.Person.db.insertRow(
            clientSession,
            client.Person(
              id: const Uuid().v7obj(),
              name: 'second-person',
            ),
          );

          await Future<void>.delayed(syncInterval * 0.8);

          expect(secondMergeCompleter.isCompleted, isFalse);

          await expectLater(
            secondMergeCompleter.future.timeout(const Duration(seconds: 3)),
            completes,
          );

          expect(stopwatch.elapsed, greaterThanOrEqualTo(syncInterval));
        },
      );
    },
  );

  withServerpod(
    'Given two client CRDT sessions for the same user,',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      late CrdtDatabaseSession secondClientSession;

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await secondClientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      test(
        'when the first node uploads an offline deletion after the second node synchronized a newer change, '
        'then the second node receives the deletion on its next sync.',
        () async {
          final rowToDelete = await client.Unique.db.insertRow(
            clientSession,
            client.Unique(name: 'deleted-by-first-node'),
          );
          await testClient.crdt.syncOnce(clientSession);
          await testClient.crdt.syncOnce(secondClientSession);

          // After both nodes have synchronized, the first node deletes the row.
          await client.Unique.db.deleteRow(clientSession, rowToDelete);

          // The second node inserts a new row and synchronizes it.
          await client.Unique.db.insertRow(
            secondClientSession,
            client.Unique(name: 'inserted-by-second-node'),
          );
          await testClient.crdt.syncOnce(secondClientSession);

          // The first node synchronizes the deletion with the server.
          await testClient.crdt.syncOnce(clientSession);

          // This last sync from the second node will only receive the deletion
          // from the first node if checkpoints are tracked per known node.
          await testClient.crdt.syncOnce(secondClientSession);
          final deletedRow = await client.Unique.db.findById(
            secondClientSession,
            rowToDelete.id!,
          );
          expect(deletedRow, isNull);
        },
      );
    },
  );

  withServerpod(
    'Given two client CRDT sessions for different users sharing one readWrite scope,',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      final secondUserId = const Uuid().v7obj();
      late client.Client firstClient;
      late client.Client secondClient;
      late CrdtDatabaseSession firstClientSession;
      late CrdtDatabaseSession secondClientSession;
      late UuidValue sharedScopeId;

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          token.split(' ').last,
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        final serverUrl = 'http://localhost:${rawServerSession.server.port}';
        firstClient = client.Client(serverUrl)
          ..authKeyProvider = TestClientAuthKeyProvider(testCrdtUserId.toString());
        secondClient = client.Client(serverUrl)
          ..authKeyProvider = TestClientAuthKeyProvider(secondUserId.toString());

        firstClientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await firstClientSession.db.initialize();

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: secondUserId,
        );
        await secondClientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();

        sharedScopeId = await rawServerSession.crdt.scopes.create(
          grants: {
            testCrdtUserId: CrdtScopeRole.readWrite,
            secondUserId: CrdtScopeRole.readWrite,
          },
        );

        await firstClient.crdt.syncOnce(firstClientSession);
        await secondClient.crdt.syncOnce(secondClientSession);
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group(
        'when the first user writes shared and personal persons and both clients synchronize,',
        () {
          late UuidValue sharedPersonId;
          late UuidValue personalPersonId;

          setUp(() async {
            final sharedPerson = await firstClientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                firstClientSession,
                client.Person(name: 'first-user-shared-person'),
                transaction: tx,
              ),
              scopeId: sharedScopeId,
            );
            sharedPersonId = sharedPerson.id!;
            final personalPerson = await client.Person.db.insertRow(
              firstClientSession,
              client.Person(name: 'first-user-personal-person'),
            );
            personalPersonId = personalPerson.id!;

            await firstClient.crdt.syncOnce(firstClientSession);
            await secondClient.crdt.syncOnce(secondClientSession);
          });

          test('then the second user receives the shared scope person.', () async {
            final sharedPerson = await client.Person.db.findById(
              secondClientSession,
              sharedPersonId,
            );

            expect(sharedPerson, isNotNull);
            expect(sharedPerson!.name, 'first-user-shared-person');
          });

          test(
            "then the second user does not receive the first user's personal person.",
            () async {
              expect(
                await client.Person.db.findById(
                  secondClientSession,
                  personalPersonId,
                ),
                isNull,
              );
            },
          );
        },
      );

      group(
        'when the second user writes a shared person and both clients synchronize,',
        () {
          late UuidValue replyPersonId;

          setUp(() async {
            final replyPerson = await secondClientSession.db.transactionForUser(
              secondUserId,
              (tx) => client.Person.db.insertRow(
                secondClientSession,
                client.Person(name: 'second-user-shared-person'),
                transaction: tx,
              ),
              scopeId: sharedScopeId,
            );
            replyPersonId = replyPerson.id!;

            await secondClient.crdt.syncOnce(secondClientSession);
            await firstClient.crdt.syncOnce(firstClientSession);
          });

          test(
            "then the first user receives the second user's shared person.",
            () async {
              final replyPerson = await client.Person.db.findById(
                firstClientSession,
                replyPersonId,
              );

              expect(replyPerson, isNotNull);
              expect(replyPerson!.name, 'second-user-shared-person');
            },
          );
        },
      );
    },
  );
}

Future<void> _waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Condition was not met within $timeout.');
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  TestClientAuthKeyProvider([this.userKey = 'token']);

  final String userKey;

  @override
  Future<String?> get authHeaderValue async => 'Bearer $userKey';
}
