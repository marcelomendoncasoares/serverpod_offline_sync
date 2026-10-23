# Commit hints between server processes

Continuous streams on the process that commits a write already wake immediately. A stream on another process discovers that write through durable recovery polling unless a commit-hint transport is configured. Hints remove that polling wait; they do not replace database serialization, membership checks, complete captures or committed acknowledgements.

## PostgreSQL setup

Configure the transport once when initializing the server, using its resolved database configuration:

```dart
final pod = Serverpod(
  args,
  Protocol(),
  Endpoints(),
  databaseInterceptor: offlineSyncDatabaseInterceptor,
);

pod.initializeOfflineSync(
  syncTables: syncTables,
  commitHints: PostgresSyncCommitHints.fromConfig(
    pod.config.database! as PostgresDatabaseConfig,
  ),
);

await pod.start();
```

The hint connection requires session state. Use a direct PostgreSQL endpoint or a session pool. If ordinary queries use a transaction pool, pass its corresponding direct endpoint through `host:` while preserving the other database settings. The library does not infer provider-specific hostnames. For embedded PostgreSQL, resolve/start the database before constructing the transport from its connectivity settings.

Each configured server owns one additional database connection outside its application pool. Publishing uses asynchronous `pg_notify` calls after the original transaction commits. Ordinary same-process notifications still run immediately. The transport carries only space and revision UUIDs, coalesces queued revisions by space, caps its pending map at 1024 spaces and sends at most 64 revisions per notification. It does not retain row payloads.

One transport belongs to one Serverpod instance. The instance cancels its subscription and closes the transport on shutdown or replacement. The adapter reconnects independently of request sessions, starting at 250 ms and backing off to 30 seconds. `isConnected`, `connectionChanges` and `droppedRevisions` expose connection and outgoing queue observations; they are not acknowledgements of remote delivery.

## Correctness and failure behavior

A notification is a hint to read current durable state. It cannot grant membership or advance a checkpoint. The normal sender rereads permissions and performs the same complete snapshot capture as before. Database transaction locks still serialize same-space work across processes.

Only the owned transaction wrapper publishes after successful commit. A rollback publishes nothing. Publication failure cannot change a successful database commit into a failed application operation. Caller-owned transactions and writes outside the wrapper remain discoverable through polling.

Notifications can be lost, duplicated or reordered. There is deliberately a gap between committing the write and publishing the hint; a process can die in that gap. Recovery polling remains enabled and compares durable revisions and membership, including after listener reconnection. There is no dependency on successful notification delivery for eventual convergence. Malformed notifications are ignored.

`OfflineSyncCommitHints` also allows an application-supplied transport. Its synchronous `publish` implementation must enqueue best-effort work without awaiting network delivery. Its `changes` stream supplies committed revision hints. It must release its resources when `close` is called.
