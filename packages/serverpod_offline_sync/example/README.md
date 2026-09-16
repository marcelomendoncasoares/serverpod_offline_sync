# Example

The [Offline Sync Demo](https://github.com/marcelomendoncasoares/serverpod_offline_sync/tree/main/example/offline_sync_demo)
is the shared example app for `serverpod_offline_sync`,
`serverpod_offline_sync_client`, and `serverpod_offline_sync_server`.

The desktop Flutter app shows two independent local replicas alongside the
server's merged data, so you can edit offline, sync each replica, and watch them
converge. See the demo's README for setup and running instructions.

For the core client integration, start with
[`offline_replica.dart`](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/main/example/offline_sync_demo/lib/src/offline_replica.dart).
