# PostgreSQL driver integration

The workspace pins the PostgreSQL driver to
`79560a928c6b9307e89fe52f368f68dfce01eb79` from
[`marcelomendoncasoares/postgresql-dart`](https://github.com/marcelomendoncasoares/postgresql-dart).
The benchmark export copies this immutable dependency override into its regular
manifest, so Cloud resolves the same source as local workspace validation.

The upstream implementation is [PostgreSQL driver PR #477](https://github.com/isoos/postgresql-dart/pull/477).

The driver enables `TCP_NODELAY` on TCP connections before the TLS upgrade and
closes an exhausted extended-query portal before the execution exchange's
`Sync`. It still waits for `ReadyForQuery` and cancellation-channel cleanup
before making the connection available to the next operation. Named prepared
statements retain their independent lifetime.

TLS, transaction boundaries, row-lock lifetime, same-space merge admission, and
the streaming sync protocol are unchanged. Unix sockets do not receive a TCP
option. Unsupported socket-option implementations retain their existing startup
behavior. Sending small writes sooner can increase packet overhead; batching
portal cleanup removes a separate query exchange.

This override applies to this development and benchmark workspace. Dependency
overrides are not inherited by applications consuming the published offline-sync
packages. The Serverpod adoption is [draft PR #5917](https://github.com/serverpod/serverpod/pull/5917),
tracked by [issue #5916](https://github.com/serverpod/serverpod/issues/5916).
It uses the same immutable driver source, pending an upstream hosted release. Replace these development pins with the actual released dependency
constraint when that release is available; no unpublished version is assumed.

The six existing Serverpod streaming SDK pins remain at
`4f2a75ab967dccd56e88261a39203fc5e59d8e80`. Keeping them fixed lets the Cloud
comparison attribute differences to the driver rather than an SDK upgrade.
