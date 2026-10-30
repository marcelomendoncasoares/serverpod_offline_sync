# Plain Dart WebSocket compression memory control

Each case runs in a fresh AOT server process without Serverpod, PostgreSQL, TLS or Offline Sync. Every connection delivers an exact 128-byte echo, idles for five seconds and closes. The server verifies actual compression negotiation and zero remaining sockets.

| Connections | Compression | Baseline RSS MiB | Connected RSS MiB | Increase KiB/connection | RSS after close MiB |
|---:|---|---:|---:|---:|---:|
| 256 | On | 7.51 | 74.32 | 267.22 | 74.90 |
| 256 | Off | 7.59 | 15.71 | 32.50 | 17.98 |
| 2,048 | On | 7.46 | 504.34 | 248.44 | 506.91 |
| 2,048 | Off | 7.39 | 51.32 | 21.96 | 51.60 |

At 2,048 sockets, turning compression off reduced connected server RSS from 504.34 MiB to 51.32 MiB, about 90%. This reproduces a large per-socket memory cost below Serverpod. It does not establish a Cloud capacity limit or prove that all Cloud failures have the same cause.

RSS stayed high five seconds after close even though every socket closed and file descriptors returned to their baseline. Garbage collection and native allocator retention were not separated; no leak is claimed.

The pinned SDK creates and retains per-message deflate/inflate filters when compression is negotiated with context reuse. Disabling compression also increases bytes sent for compressible application data; this control does not measure that bandwidth/CPU tradeoff under active sync.

See [results.json](results.json) for raw counters, [manifest.json](manifest.json) for build identity, and [websocket_memory.dart](../../tool/websocket_memory.dart) for the replayable probe.
