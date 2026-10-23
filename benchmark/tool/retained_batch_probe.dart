import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

Future<void> seed(
  OfflineSyncDatabaseSession session,
  UuidValue user,
  int count,
  int bytes,
) async {
  for (var start = 0; start < count; start += 50) {
    final rows = [
      for (var i = start; i < (start + 50).clamp(0, count); i++)
        Person(
          id: UuidValue.fromString(const Uuid().v5(Namespace.url.value, 'retained/$i')),
          name: '$i:'.padRight(bytes, String.fromCharCode(65 + i % 26)),
        ),
    ];
    await session.db.transactionForUser(
      user,
      (tx) => Person.db.insert(session, rows, transaction: tx),
    );
  }
}

Future<void> main(List<String> args) async {
  final count = int.parse(args[0]);
  final bytes = int.parse(args[1]);
  final directory = await Directory.systemTemp.createTemp('sync-retained-');
  final client = Client('http://localhost:8081/');
  final raw = await client.createSession(
    '${directory.path}/replica.db',
    isDebugMode: true,
  );
  final context = OfflineSyncDatabaseContext(
    syncTables: [Person.t],
    serializationManager: raw.db.serializationManager,
  );
  final session = OfflineSyncDatabaseSession(
    raw.db,
    syncTables: [Person.t],
    context: context,
  );
  final engine = OfflineSyncEngine(
    syncTables: [Person.t],
    serializationManager: raw.db.serializationManager,
    databaseContext: context,
  );
  final user = const Uuid().v7obj();
  final commands = StreamIterator(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );
  final input = StreamController<OfflineSyncStreamEvent>();
  final done = Completer<void>();
  final firstAck = Completer<void>();
  final secondAck = Completer<void>();
  final seen = <UuidValue>{};
  var firstBatch = 0;
  var secondBatch = 0;
  var frames = 0;
  var activeTransactions = 0;

  void emit(String stage) => stdout.writeln(
    jsonEncode({
      'stage': stage,
      'rows': seen.length,
      'frames': frames,
      'activeTransactions': activeTransactions,
      'firstBatch': firstBatch,
      'secondBatch': secondBatch,
    }),
  );

  Future<void> command(String expected) async {
    if (!await commands.moveNext() || commands.current != expected) {
      throw StateError('Expected command $expected');
    }
  }

  try {
    await session.db.initialize();
    await seed(session, user, count, bytes);
    emit('seeded');
    await command('open');
    OfflineSyncDiagnostics.run(
      (event) {
        if (event['name'] == 'transaction') {
          if (event['kind'] == 'start') activeTransactions++;
          if (event['kind'] == 'end') activeTransactions--;
        }
        if (event['name'] == 'sync.batchCommitted') {
          final id = (event['data']! as Map)['batchId'];
          if (id == firstBatch && !firstAck.isCompleted) firstAck.complete();
          if (id == secondBatch && !secondAck.isCompleted) secondAck.complete();
        }
      },
      () {
        engine
            .sync(
              session,
              userId: user,
              inbound: input.stream,
              mode: OfflineSyncPeerMode.authoritative,
            )
            .listen(
              (event) {
                if (event is OfflineSyncConnect) {
                  input.add(
                    OfflineSyncConnect(
                      localNodeId: const Uuid().v7obj(),
                      syncTablesHash: event.syncTablesHash,
                      spaces: [],
                    ),
                  );
                } else if (event is OfflineSyncSinceHlc) {
                  input.add(
                    OfflineSyncSinceHlc(
                      uuidSpaceId: event.uuidSpaceId,
                      nodeCheckpoints: [],
                    ),
                  );
                } else if (event is OfflineSyncReady) {
                  input.add(OfflineSyncReady());
                } else if (event is OfflineSyncMergeChunk) {
                  frames++;
                  for (final change in event.changes) {
                    if (!seen.add(change.uuidRowId)) {
                      throw StateError('A committed row was resent');
                    }
                    final row = (change as CrdtMergeInsert).data as Person;
                    if (seen.length <= count && row.name.length != bytes) {
                      throw StateError('Payload mismatch');
                    }
                  }
                } else if (event is OfflineSyncEndOfBatch) {
                  if (firstBatch == 0) {
                    if (seen.length != count) {
                      throw StateError('Incomplete initial snapshot');
                    }
                    firstBatch = event.batchId;
                    emit('held');
                  } else {
                    if (seen.length != count + 1) {
                      throw StateError('Missing next insertion');
                    }
                    secondBatch = event.batchId;
                    input.add(OfflineSyncCommitted(batchId: secondBatch));
                  }
                }
              },
              onDone: done.complete,
              onError: done.completeError,
            );
      },
    );
    await command('acknowledge');
    input.add(OfflineSyncCommitted(batchId: firstBatch));
    await firstAck.future.timeout(const Duration(seconds: 10));
    emit('acknowledged');
    await command('write');
    await session.db.transactionForUser(
      user,
      (tx) => Person.db.insertRow(
        session,
        Person(id: const Uuid().v7obj(), name: 'after acknowledgement'),
        transaction: tx,
      ),
    );
    await secondAck.future.timeout(const Duration(seconds: 10));
    input.add(OfflineSyncClose());
    await done.future.timeout(const Duration(seconds: 10));
    await input.close();
    await Future<void>.delayed(Duration.zero);
    emit('closed');
    await command('finish');
  } finally {
    await input.close();
    await commands.cancel();
    await raw.close();
    client.close();
    await directory.delete(recursive: true);
  }
}
