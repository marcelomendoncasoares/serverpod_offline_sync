# Revision checkpoint deployment smoke check

The prepared Cloud server and benchmark client passed a local deployment check on
2026-10-29. Both ran as their existing AOT executables, using native PostgreSQL TLS
without pipelining. Fresh local PostgreSQL databases received the exported
application migration `20261029055700456`.

| Registry / workload | Mode | Devices | Rows per round | Measured rounds | Exact convergence | Cleanup |
|---|---|---:|---:|---:|---|---|
| Full / Person | Continuous stream | 2 | 1,000 | 2 | Passed | Zero streams and idle transactions |
| Isolated City / City | Short-lived `syncOnce` stream | 2 | 10 | 2 | Passed | Zero streams and idle transactions |

The check covers the actual exported migration, native libraries, compiled
protocol, and client/server pairing. It is a deployment check, not a capacity
measurement or a Cloud performance comparison. It did not change the Cloud
deployment. Each server, client, TLS proxy, and PostgreSQL fixture exited cleanly.

The server was built from `be5a9076ef7d165dd728f0ff99bff0096293ec2a`; the client
was built from `87451ccf2733f8792d90988f8e23aebfbe1bcb17`. The subsequent fixture and
documentation changes do not change the runtime artifacts. Executable hashes,
outcomes, and process exit codes are in [receipt.json](receipt.json).

Startup logs show migration application and graceful shutdown for the
[full registry](server-full.log) and [City registry](server-city.log).
[tls-proxy.log](tls-proxy.log) records the local TLS fixture. The first local
fixture attempt used a secret shorter than the benchmark's minimum and was
rejected before server startup; correcting that fixture value required no
application changes.
