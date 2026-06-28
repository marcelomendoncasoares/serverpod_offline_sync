# Serverpod Offline Sync — Product One-Pager

*This is a one-pager that describes the product and its features, plus a roadmap for the license transference at the end.*

## Overview

**Serverpod Offline Sync** is a Dart plugin that turns an ordinary [Serverpod](https://serverpod.dev) backend into an offline-first, collaborative system, without changing how developers write their app. It is a delta-CRDT (Conflict-free Replicated Data Type) engine that runs **the same code on the client and server databases**, transparently and with minimal configuration.

It sits nearly alone in the space of offline-first solutions, because most other solutions either use a non-relational database, require a new data API, or don't preserve foreign-key/unique invariants while merging data. And no other solution requires as little configuration from the developer as this one.

The work on this package was inspired by the excellent work on [Synql](https://github.com/coast-team/synql) ([Ignat et al., DAIS 2024](https://inria.hal.science/hal-04969158v4/document)), which provided the foundation for the CRDT layer. It goes beyond `Synql` by adding full support for all foreign-key `onDelete` actions and unique constraints, with a production-ready implementation.

### The developer experience

The selling point is that there is almost nothing to learn. The app is built
as a normal offline Serverpod app — generated models, ordinary CRUD — and the
plugin handles replication automatically:

- **No new data API.** Same repository calls, against Serverpod's generated models (e.g. `Person.db.insertRow(session, person)`).
- **Wire it up once.** Wrap a session — `CrdtDatabaseSession.wraps(raw, syncTables: …)`, call `initialize()` — and that's the whole integration.
- **User isolation.** Every row has exactly one owning `scopeId`, so reads and writes are isolated to their scope. Scope access is enforced on the server, ensuring data is isolated between users.
- **One call syncs everything.** `client.crdt.syncOnce(session)` for a one-shot push/pull, or `client.crdt.syncContinuously(session)` to stream changes until cancelled. A single call syncs every scope the user can access.
- **Offline is just "which client you sync through".** The local database is always live; going offline only stops the sync transport, never the app.

It is a **black box that "just works"**: operations are tracked atomically with each operation and the developer never intervenes in conflict resolution. Conflicts that need a human decision **bubble up as visible state** for the end user of the app to act on (e.g. a delete reverted by a concurrent constraint reappears, so the user can simply delete it again). Migrations work normally, and also applies for deleted rows - which never leave their tables, but they are transparently hidden from the user.

Understanding the behavior is also straightforward: conflict resolution respects unique and relational constraints, mirroring what would be expected if the merged data existed in a single database at the time of each operation.

### The end-user experience

The bundled desktop demo shows the model directly: two independent replicas of one account side by side, plus the server's merged truth, so you can drive each replica's sync independently and watch them converge. It visualizes hidden / tombstoned rows, every foreign-key `onDelete` action, and guided scenarios for restrict / cascade / set-null / unique-conflict cases.

### Performance

Below is one of the last performance reports of the package, showing the impact of the CRDT layer on the performance of the database operations.

```
📊 SELECT performance impact:
  Time: 12.62 ms --> 12.67 ms (48.50 μs)
  CRDT overhead: 0.38% slower
```
```
📊 INSERT performance impact:
  Time: 251.01 ms --> 482.05 ms (231.04 ms)
  CRDT overhead: 92.04% slower
  Delay per insert: 231.04 μs
```
```
📊 UPDATE performance impact:
  Time: 249.57 ms --> 2.13 s (1.88 s)
  CRDT overhead: 753.54% slower
  Delay per update: 1.88 ms
```
```
📊 DELETE performance impact:
  Time: 11.53 ms --> 420.28 ms (408.75 ms)
  CRDT overhead: 3,546.27% slower
  Delay per delete: 408.75 μs
```
```
🔭 SELECT scope impact (100 extra users, 100,000 CRDT noise rows):
  find all (1,000 rows): 9.91 ms --> 10.91 ms scoped (+10.07%) / 11.19 ms unscoped (+12.96%)
  findById (per lookup): 295.04 μs --> 375.24 μs scoped (+27.19%) / 348.88 μs unscoped (+18.25%)
```
```
💽 Storage impact (base footprint removed):
  Base database size: 540.00 KB --> 540.00 KB
  INSERT only:
    Net storage: 116.00 KB --> 188.00 KB (+72.00 KB)
    CRDT overhead: 62.07% increase
    Extra storage per inserted row: +73.73 B
  INSERT + UPDATE:
    Net storage: 128.00 KB --> 472.00 KB (+344.00 KB)
    CRDT overhead: 268.75% increase
    Extra storage per updated column: +34.82 B
  INSERT + UPDATE + DELETE:
    Net storage: 128.00 KB --> 512.00 KB (+384.00 KB)
    CRDT overhead: 300.00% increase
    Extra storage per deleted row: +40.96 B
  Storage overhead range: 62.07% --> 300.00%
```

Despite the high percentage of slowdown in the insert/update/delete operations, the absolute impact is on the microseconds range, making it barely noticeable in most cases - and way below a network delay if those operations were performed through an online endpoint.

The storage impact is also minimal, reaching at most 3x the base storage size, which is perfectly acceptable for the benefits of offline-first availability.

## Feature list

### Core sync engine

- Delta-CRDT replication between SQLite (client) and Postgres (server), one shared code path on both ends.
- Non-invasive proxy: per-operation metadata (insert / update / delete) is recorded atomically inside the user's own transaction; **no row data is duplicated** into metadata tables.
- Field-level last-writer-wins for column values via Hybrid Logical Clocks (HLC); row-level existence via monotone causal-length tombstones.
- Automatic, transparent tombstone filtering on all reads.
- Soft deletes: deleted rows stay physically in their tables (migration-safe) and can be restored.
- Strong Eventual Consistency: visibility is a deterministic, idempotent / associative / commutative function of merged state.

### Constraint preservation under merge (coordination-free)

- **Unique constraints** — the `flag` policy: all rows stay visible, a deterministic winner (oldest HLC) keeps the value, losers receive a conflict-free materialized value (null, a `__conflict__<rowId>` suffix, or a synthetic UUID).
- **Foreign keys** — projection-based repair handled by the CRDT layer, not the database: `RESTRICT`, `NO ACTION`, `SET NULL`, `SET DEFAULT`, and `CASCADE` all converge correctly, including deeply nested and cyclic relations, via a fixed-point projection. Local `ON DELETE` actions become authored CRDT facts.
- Incremental recomputation over the affected closure is provably equivalent to a full recompute (oracle-tested).

### Row ownership & isolation

- Every synced table carries a reserved `scopeId` column; the sync layer owns it (stamp-if-null, assert-if-set), keeps it off the wire, and returns it null for scoped reads.
- Scoped reads are isolated to their scope; unscoped reads are admin views.
- Ownership collisions (the same `(table, rowId)` claimed by two scopes) fail the sync and are recorded in a durable `crdt_sync_integrity_violations` table.
- Multi-device per account: each device is a distinct node in the scope's HLC chain; checkpoints are kept per `(scope, node)`.

### Shared scopes — collaboration

- A user belongs to a personal scope plus any number of shared scopes; a single
`sync` call cycles through **all** accessible scopes sequentially, with
bounded memory (one scope's changes in flight at a time).
- Server is the authority on membership (`crdt_scope_members`); the client
follows. Membership is re-resolved every cycle, so **grants and revokes take
effect mid-session** — a newly shared scope syncs in the same cycle.
- Membership-wide reads (`scopeId IN (…)`), scope-pinned writes
(`transactionForUser(userId, fn, {scopeId})` with a membership assertion).
- Roles are projected to the client as read-only cache, *but not yet enforced*. This is a deferred follow-up.

### Schema safety & lifecycle

- `initialize()` validates the schema with paste-ready error messages: requires
`id: UuidValue` and `scopeId: int?`, requires composite unique indexes to
include `scopeId`, rejects unsafe global unique indexes and unsupported
foreign-key shapes / sync-boundary relations.
- Scope purge for GDPR / account erasure via a database-enforced cascade
(`scopeId → crdt_scopes`, `onDelete=Cascade`).

**Packaging**

- Three Dart packages — `_client`, `_server`, `_shared` — plus a worked desktop
example app. Comprehensive test suite (252/252 green, run serialized).

## Technical fundamentals

**Architecture.** The engine is a transparent layer between the application and
its database. Because the identical code runs on the client's SQLite and the
server's Postgres, there are no asymmetric merge results to reconcile — only the
CRDT triad (idempotent, associative, commutative) must hold.

**Metadata model.** Three metadata tables track change history without copying
row data: `crdt_data_rows` (insert: table, rowId, HLC), `crdt_data_fields`
(update: table, column, rowId, HLC), and `crdt_data_tombstone` (delete/restore).
HLCs order field-level values and break ties; a monotone causal-length tombstone
governs row existence, so add/delete/restore advance generations forward and can
never oscillate.

**Visibility as a pure function.** Replicas never coordinate. Each merge applies
remote facts monotonically, then derives the visible database — tombstone state,
unique-conflict winners, and foreign-key repair — as a deterministic projection
computed to a fixed point. This is the architecture proven by *Synql* (Ignat et
al., DAIS 2024), extended here to cover the full set of `ON DELETE` actions over
deeply relational schemas.

**Ownership & scopes.** A *scope* is the unit of replication and ownership; a
*user* is an authentication identity. Each row is globally identified by
`(table, rowId)` and owned by exactly one scope (`scopeId`), so merging is always
one chain per row. Sharing is a membership layer in front of scopes, not a change
to row ownership.

**Sync protocol.** A session handshakes once (validating a schema hash), then per
cycle exchanges the authoritative scope set and, per scope, a since-HLC
checkpoint followed by tagged merge chunks. Scopes sync one at a time; the wire
protocol is a near-verbatim repetition of the single-scope exchange wrapped in an
outer loop, keeping the protocol delta and memory footprint minimal.

## Roadmap

The package is in a production-ready state, but it must go through a review process before it can be merged into the monorepo. Since this process will be exhaustive, we must solve some minor technical debts before the review.

### Technical debts

Although the product is already in a production-ready state, there are still some technical debts that need to be addressed before the package gets reviewed:

- **Move the core of the package to a shared package instead of the client package**. Since the same code runs on the client and server and requires table models, the first implementation was done in the client package, meaning that users have to import it on their server - crossing an isolation that is not common on Serverpod projects. This change requires support for tables on shared models on Serverpod, mapped on issue #5400. Then we'll be able to move the core of the package to a shared package and remove all manually written SQL queries from the codebase.
- **Require that all foreign-key relations are declared deferrable**. Because the package does not store a copy of the data with the metadata, there are some scenarios in which the stored data might violate the causal order of the foreign-key constraints and a merge can fail irreversibly. To prevent this, all foreign-key constraints must be deferrable, which will be supported with issue #5338.
- **Rename the `scope` name for data isolation to `space`**. This is to avoid confusion with the `scope` keyword used in the Serverpod Auth modules. Using `space` is also clearer for usage on an application level.

### Post-integration UX improvements

The package already requires minimal configuration from the developer, but it can be made even less if we make the `serverpod_cli` aware of the offline sync capabilities.

- **Simplify the `Serverpod` initialization by generating the class**. This is mapped on issue #4544 and will allow us to inject the CRDT database interceptor on the `Serverpod` constructor without the user having to call it manually.
- **Add a fourth `sync` option for the `database` keyword**. Together with the previous point, a new `sync` option will automatically inject the `scopeId` relation on the domain models and add it to the list of tables to sync on the generated server and client.
- **Inject the `serverpod_offline_sync` packages on the `pubspec.yaml` file**. We currently do not add/remove dependencies while generating the project, which means that the user will have to manually add the dependencies to their `pubspec.yaml` file.

If we do these changes, all that the user will have to do is add the `sync` keyword to the `database` keyword on synced table models and the package will be completely wired up. Given that all these changes are on the `serverpod_cli`, it doesn't even require other internal packages to depend on the `serverpod_offline_sync` packages.

## Review strategy

Besides not being that big (~30k LOC for the packages, ~10k LOC for the tests), the codebase is dense on the logic. So the best way to review it is to read the performance reports first, then all tests, and finally the main files of the packages as needed.

## Transference process

The transference process will be done following the steps below:

1. A branch transferring the copyrights to the Serverpod organization will be merged into the main branch of the original repository.
2. The original repository with the updated license will be made public on GitHub by the author. This copy will be kept for historical purposes and as a portfolio of the author's work.
3. The package will be reviewed by the Serverpod team on the original repository to prepare the codebase for the transference. After all changes, the repository will be archived with a note about the transference.
4. A PR will be created to merge the packages on the Serverpod monorepo, preserving its commit history.
