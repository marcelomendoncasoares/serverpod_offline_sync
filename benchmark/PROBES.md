# Diagnostic and mechanism probes

These tools complement the [scale and round harness](SCALE.md). Their results
answer narrower questions than a capacity run. Use the workspace's pinned SDK Git
dependencies for every build and retain source identities with each comparison.
Credentials come from `BENCHMARK_SECRET` and must stay out of shared artifacts.

| Tool | Measurement and limits |
| --- | --- |
| `tool/network_probe.dart API_URL OUTPUT_JSON` | Sixteen fresh HTTP control and WebSocket connections in alternating order. The HTTP request is a database-free benchmark control, not an HTTP sync protocol. Setup and ping observations are not `syncOnce` timings. Partial failures are retained. |
| `tool/transport_probe.dart API_URL OUTPUT_JSON` | Fresh WebSocket setup and four pings on each connection, with cleanup. DNS, TLS and runtime caches are not cleared. |
| `tool/profile_rounds.py EVIDENCE_DIRECTORY LABEL` | Joins sampled rounds to explicit authored row/writer, request and batch identities on one server clock. Requires complete collector sequences and rejects negative or inconsistent partitions without clamping. The receipt names the client and server event artifacts. |
| `tool/profile_retained_batch.py OUTPUT_DIRECTORY LABEL ROWS PAYLOAD_BYTES` | Starts the Dart retained-batch probe with a loopback VM service, collects post-GC live heap at seeded, held-ACK, acknowledged and closed barriers, then stops its owned process. Set `DART` to select the SDK executable. Held payload savings are separate from peak capture memory, RSS and capacity. |

Local addresses, VM-service tokens, source paths, deployment identities and
configuration can occur in raw diagnostic files. Remove them before publishing
an evidence set while preserving sample values and consistent instance aliases.
