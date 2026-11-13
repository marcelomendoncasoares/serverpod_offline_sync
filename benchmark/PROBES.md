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
| `tool/cross_process_rounds.py` | Verifies two distinct server processes and device placement before timing delivered versus deliberately dropped commit hints. Exact convergence, offered schedule and cleanup remain required. Both arms publish hints, so the comparison does not measure notification overhead against no transport. |

Build the cross-process client with the same native provenance wrapper:

```sh
dart run benchmark/tool/build_native.dart --target bin/cross_rounds.dart \
  --output .scale-benchmark/cross-client

python3 benchmark/tool/cross_process_rounds.py \
  --target https://PRIMARY-API/ --peer-target https://PEER-API/ \
  --client .scale-benchmark/cross-client/bundle/bin/cross_rounds \
  --output .scale-benchmark/cross-runs --label delivered-a \
  --deliver on --server-sha EXPECTED_EXECUTABLE_SHA256 --quota 2
```

The two targets may be distinct ports or one load-balancer address. Configure
the benchmark servers with `BENCHMARK_COMMIT_HINTS=on` and suitable PostgreSQL
listener connections; see [commit-hint setup](../docs/commit-hints.md). The
controller rejects placement before timed exercise if both devices land on the
same process (exit 2). Repeat with fresh labels in a balanced comparison order.
The default is one user, two devices, 20 rounds and a 1700 ms period.

The controller deliberately changes the benchmark servers' hint-delivery and
sampling controls. It leaves those settings selected for the next comparison
arm. Use dedicated benchmark servers and explicitly select the next arm before
starting it. Check both processes' executable identity, actual CPU quota, zero
open streams and zero idle transactions from the retained receipts.

Local addresses, VM-service tokens, source paths, deployment identities and
configuration can occur in raw diagnostic files. Remove them before publishing
an evidence set while preserving sample values and consistent instance aliases.
