# Offline Sync Demo

Desktop Flutter demo for exercising `serverpod_offline_sync` against the test
server models.

Each demo user owns two independent local replicas (`<user>-a.db`,
`<user>-b.db`) shown side by side. A replica is just a local SQLite store with
its own CRDT node id but the same sync scope; replicas share nothing locally and
only converge by syncing through the server — like two phones on one account
(see the "i" button in the toolbar).

Key controls:

- **Connectivity** toggles `Client.httpClientOverride` between a real and a
  failing HTTP client.
- **Per-replica sync**: each panel has its own one-shot **Sync** and **Stream**
  (continuous) controls, so you drive `A → server` and `B → server`
  independently and watch them converge.
- A third **Server** panel shows the server's merged truth for the current
  scope, fetched through the `demoDebug.fetchScopeSnapshot` endpoint (reads run
  in the caller's scope via `transactionForUser`). It refreshes after each sync
  and via its own refresh button, so you can watch `A | B | Server` converge.
- **Show hidden rows** reveals locally hidden/soft-deleted rows (read through the
  unwrapped session and shown struck-through and muted) alongside the visible
  "user view".
- **Seed target** picks which replica the preset/seed buttons write to. Presets
  only seed locally; running sync to produce conflicts is up to you.
- Click any row to open its full record, edit fields, or delete it.
- The top bar carries a light/dark toggle and an avatar menu for switching
  between or creating demo users.

The main view uses `shadcn_flutter` tabs and tree nodes to seed and inspect
CRUD, unique conflict, and foreign key scenarios.

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
