# Offline Sync Demo

Desktop Flutter demo for `serverpod_offline_sync`. It runs two independent local
replicas of one user's data side by side, plus a view of the server's merged
truth, so you can drive `A → server` and `B → server` independently and watch
them converge.

## How the package is wired

If you are here to learn the package, read **`lib/src/offline_replica.dart`**
first — it is the entire integration in ~60 lines, deliberately free of demo and
UI code. Every replica follows the same four steps:

1. **Open a local database.** `client.createSession(path)` opens a Serverpod
   client database (a local SQLite file) and runs the client migrations.
2. **Wrap it for CRDT sync.** `CrdtDatabaseSession.wraps(raw, syncTables: …,
   persistentUserId: …)`, then `crdtSession.db.initialize()` to establish this
   device's CRDT node so it can take part in sync.
3. **Read and write generated models** against that session, e.g.
   `Person.db.insertRow(session, person)` or `session.db.find<Person>()`. (The
   demo also routes these through a generic `TableOps` registry so its
   metadata-driven UI can touch any table without a per-type switch — that part
   is demo-only; the `seed*` methods in `lib/src/demo_controller.dart` show the
   plain form.)
4. **Synchronize through a Serverpod client.**
   `client.crdt.syncOnce(session, onMergeSuccess: …)` for a one-shot push/pull,
   or `client.crdt.syncContinuously(session, …)` to stream until cancelled.

Connectivity is just *which client you sync through*: the demo swaps
`Client.httpClientOverride` between a real transport and a failing one to
simulate going offline — the local database is untouched either way.

The rest of `lib/src` layers a UI on top: `demo_controller.dart` (a
`ChangeNotifier` orchestrating users, replicas, and the server panel),
`snapshot.dart` / `relationships.dart` / `table_ops.dart` (the metadata-driven
view of the synced schema), `demo_view.dart` / `sheets.dart` (widgets), and
`scenarios.dart` (guided scripts).

## What the UI shows

Each demo user owns two replicas (`<user>-a.db`, `<user>-b.db`) shown side by
side. A replica is a local SQLite store with its own CRDT node id but the same
sync scope; replicas share nothing locally and only converge by syncing through
the server — like two phones on one account (see the "i" button in the toolbar).

The layout is a **scenario rail**, **Replica A**, **Replica B**, and a **Server**
panel, with a global toolbar on top and a status line at the bottom.

**Toolbar**

- **Connectivity** toggles every client between a real and a failing HTTP
  transport (the offline switch).
- **Show hidden rows** reveals locally hidden / soft-deleted (tombstoned) rows,
  shown struck-through and muted alongside the visible "user view".
- **Refresh** reloads all three panels; **Reset all** wipes both replicas and the
  server scope at once.
- The **i** button explains replica isolation.
- The app bar carries a light/dark toggle and an avatar menu for switching
  between or creating demo users.

**Per replica**

- **Sync** runs one push/pull; **Stream** keeps syncing continuously until
  toggled off — drive A and B independently and watch them (and the Server
  panel) converge.
- **Add data** creates a root row or attaches a child through a foreign key; the
  same menu also offers ready-made seeds (a city/person/address/town graph, a
  typed row, an FK chain). Each row carries inline **attach child** and
  **re-parent / detach** actions, and every edge shows its `onDelete` action
  (restrict / cascade / set null / …).
- **Reset** wipes just that replica's local database (a fresh device); syncing
  afterwards re-pulls whatever the server still holds.
- Click any row to open its full record, edit fields, or delete it.

**Server panel**

- Shows the server's merged truth for the current scope, fetched through the
  `demoDebug.fetchScopeSnapshot` endpoint (reads run in the caller's scope via
  `transactionForUser`). It refreshes after each sync and via its own refresh
  button.
- **Reset server scope** hard-clears every row and CRDT metadata record in the
  scope; the seed buttons write a graph straight into the scope via
  `demoDebug.seedScope`, so you can reset a replica and sync to exercise the
  fetch-from-scratch flow.

**Scenario rail**

- Guided scripts (restrict, set-null, cascade, unique-conflict, …) that run a
  sequence of these same actions step by step. Every step is also doable by hand.

## Running

Run the test server first, then start this app from the repository root:

```sh
cd test/serverpod_offline_sync_test_server
dart bin/main.dart
```

```sh
cd example/offline_sync_demo
flutter run -d linux
```

The app accepts `--dart-define=SERVERPOD_URL=http://host:port/` when the server
is not running on `http://localhost:8080/`.
