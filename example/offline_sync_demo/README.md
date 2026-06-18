# Offline Sync Demo

Desktop Flutter demo for exercising `serverpod_offline_sync` against the test
server models.

The app opens two local SQLite device sessions per demo user, lets connectivity
be toggled through `Client.httpClientOverride`, and exposes one-shot and
continuous sync controls. The main view uses `shadcn_flutter` tabs and tree
nodes to seed and inspect CRUD, unique conflict, and foreign key scenarios.

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
