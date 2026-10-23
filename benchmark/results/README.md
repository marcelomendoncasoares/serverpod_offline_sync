# Historical sync performance evidence

The [ledger](2026-10-16-sync-optimization.json) preserves all 26 experiments,
including rejected implementations, failed and ineligible runs, raw latency
populations, source/executable hashes, diagnostic counters and cleanup outcomes.
The [executive summary](../../docs/sync-optimization-executive-summary-2026-10-19.md)
links the detailed reports.

These are measurements made through 19 October 2026. Review packaging did not
rerun tests, benchmarks or deployments. Test counts in the reports belong to the
historical sources and do not establish that the current review branches pass
CI. This independent evidence change does not add runtime code, SDK pins or the
harness. Those are reviewed separately:

| Companion review source | Setup and implementation |
| --- | --- |
| [Core integration](https://github.com/marcelomendoncasoares/serverpod_offline_sync/tree/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb) | Retained core units include [duplex rounds PR #187](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/187), [durable recovery PR #188](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/188) and [commit hints PR #193](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/193); see [streaming protocol](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/streaming-sync-protocol.md) and [commit-hint setup](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/7f6a6c517895dfe1f9ce7e6eecf8376e05bf8edb/docs/commit-hints.md). |
| [Scale and round harness PR #194](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/194) | [Workload/defaults and Cloud preparation](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/67a993179a21d69dc63e2a04799add78c756ebf8/benchmark/SCALE.md), with the six SDK Git pins in that branch's root manifest. |
| [Standalone probes PR #195](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/195) | [Transport, heap and cross-process tools](https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/ad5d40a5a918ca0be2afaade2975682fd6e1ef13/benchmark/PROBES.md). |

The [SDK coupling PR #183](https://github.com/marcelomendoncasoares/serverpod_offline_sync/pull/183)
pins six sibling SDK packages to
[`4f2a75ab`](https://github.com/marcelomendoncasoares/serverpod/tree/4f2a75ab967dccd56e88261a39203fc5e59d8e80).
The SDK implementation is reviewed in [Serverpod PR #5898](https://github.com/serverpod/serverpod/pull/5898)
and [Serverpod PR #5900](https://github.com/serverpod/serverpod/pull/5900).

The implementation/setup links identify frozen review sources, not the original measured binaries.
The ledger retains those historical source and executable identities.

Private filesystem paths, target URLs, hostnames and deployment identifiers are
replaced by consistent aliases. `evidence://` references identify artifacts from
the original experiments; they are not public download URLs or files included
here. Numeric samples, booleans, null observations, sample ordering and source
hashes are preserved. Deployment IDs use aliases while source and executable
hashes still distinguish measured builds. Original archives and prototypes are
not part of this review history.

The contribution summary for attempt 16 incorporates the later attempt-18
controls, which did not reproduce the initial insert penalty. The original
attempt-16 measurements and its contemporaneous judgment remain in the ledger.

Interpret the results within their measured scope:

- Medium's quarter-core 64-stream active workload missed its offered rate.
  Faster two-core runs are a different capacity and environment.
- Compact ACK vectors reduced held heap after transmission. They did not earn
  a latency saving or bound peak capture/inbound memory.
- The cross-pod hint comparison used one user and two devices with profiling in
  both arms. It measures prompt delivery versus dropped hints, not multi-pod
  capacity or notification cost against a transport-disabled control.
- Rejected HTTP sync, joined source lookup and outbound preparation changes
  contribute no retained savings. Historical patch descriptions identify past
  builds; the companion code review uses the SDK Git dependency mechanism.
- Percentages across different clients, clocks, workloads, tracing modes,
  placements or CPU quotas must not be added or compounded.
