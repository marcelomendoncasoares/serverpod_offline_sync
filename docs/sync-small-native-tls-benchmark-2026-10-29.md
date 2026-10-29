# Small instance with native PostgreSQL TLS

Measured on 2026-10-29 UTC, during the evening of 2026-10-28 in São Paulo.

## Result

**Small passed the tested continuous-sync workloads with native TLS and no
pipelining.** Four established streams averaged 671.9 ms, with 828.4 ms p95.
Eight established streams averaged 848.4–860.6 ms across three runs, with
1005.2–1061.5 ms p95. Every native run kept up with its offered rate.

All 240 native exercise rounds converged exactly, with zero retries, unexpected
stream closures, or idle-in-transaction sessions after cleanup. The eight-stream
longer run exercised 120 rounds over about one minute; this was not a soak test.

The fresh Dart TLS controls varied substantially: 1136.1 ms before deployment
and 2238.3/2206.4 ms after restoring the original executable. All controls
converged, but the two restored controls fell behind the offered rate. Retaining
both the faster control and the slower controls is essential to interpreting the
gain. The native result is repeatable within this campaign; the baseline does
not justify a single stable percentage improvement.

## All measured runs

All rows used one Small instance, with a visible CPU quota of 0.10 cores and
256 MiB configured memory. Each user had two devices. Four streams offered one
round/s total; eight streams offered two rounds/s total. Values are milliseconds,
measured from the local write through application on every peer.

| Build / run | Streams | Rounds | Min | Median | Mean | p95 | Max | Converged | Kept up |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Dart TLS, before | 8 | 40 | 799.5 | 1055.1 | 1136.1 | 1546.1 | 1579.8 | Yes | Yes |
| Native TLS, first | 8 | 40 | 610.5 | 841.1 | 848.4 | 1026.9 | 1152.5 | Yes | Yes |
| Native TLS, repeat | 8 | 40 | 700.3 | 869.8 | 860.6 | 1005.2 | 1051.6 | Yes | Yes |
| Native TLS | 4 | 40 | 469.0 | 665.4 | 671.9 | 828.4 | 841.5 | Yes | Yes |
| Native TLS, longer | 8 | 120 | 514.0 | 853.4 | 855.0 | 1061.5 | 1375.2 | Yes | Yes |
| Dart TLS, restored | 8 | 40 | 1296.6 | 2277.8 | 2238.3 | 2804.8 | 2970.7 | Yes | No |
| Dart TLS, restored repeat | 8 | 40 | 1006.9 | 2202.0 | 2206.4 | 2613.6 | 2696.5 | Yes | No |

Median uses the arithmetic middle for even populations; p95 uses nearest rank.
The native eight-stream population contains 200 rounds in total: mean 854.8 ms,
median 851.9 ms, p95 1051.6 ms, minimum 514.0 ms, maximum 1375.2 ms. This pooled
description includes the longer run with its larger weight; it is not a separate
trial or a confidence interval.

Relative to each fresh control's mean, the pooled native mean was 24.8–61.8%
lower, a reduction of 281–1383 ms. The baseline variability and deployment
differences below prevent attributing that entire range exclusively to TLS.
The older 2.2-second Small result is not used as the sole comparison.

## Workload and comparison

- Established continuous streams; full schema; one inserted Person row per round.
- Two devices per user; one round every 2000 ms per user; no pipelining or added
  concurrent database-query execution.
- Ten rounds per user for the short eight-stream runs, thirty for the longer run,
  and twenty for the four-stream run. Setup concurrency was one.
- Same database endpoint and schema, TLS required, pool limit 100. Commit hints,
  persistent session logging, and console session logging stayed disabled.
- One immutable benchmark client for every run; the same client was used in the
  earlier native TLS campaign. Startup, warmup, final verification, and teardown
  are outside the reported exercise latency.
- User 0 was sampled through the existing server diagnostics. Diagnostics were
  fetched every two seconds; the client sampled SQL metrics every thirty seconds.
  No native heartbeat, wire profiler, or detailed client profiler was enabled.
- Exact convergence, offered-rate completion, collector completeness, and
  stream/transaction cleanup were checked independently.

The native deployment used PR #202 at
`c6fe9d8d6990699a6c270c45cf38f27c390ef889`, including its committed Cloud export
support. Its PostgreSQL driver is `e1079785`, native TLS package is `22067026`,
and Serverpod database connector hook is `010d23c7`; full immutable refs are in
the manifest. The original control used the wire-optimized `79560a9` Dart TLS
driver. Both retained TCP_NODELAY, inline portal close, and cancellation drainage.
Cloud compiled both with Dart 3.13.7.

All 107 core, 12 client, and 11 server Offline Sync runtime files were
byte-identical between the original deployment and the native export. The
benchmark harnesses were not completely identical: the original has optional
isolated-schema/database probes and a memory-cgroup read in its process sampler;
the committed PR harness omits those experimental extensions. The optional
probes were not used. This is a deployment comparison, not the one-variable TLS
comparison recorded in the [earlier matched experiment](sync-native-tls-benchmark-2026-10-28.md).

The restored control's repeat remained slow after warmup. This campaign does not
establish why the original executable ran faster before the redeployment;
Cloud placement and scheduling remain uncontrolled variables. Do not extrapolate
the results to a stream capacity limit or thousands of simultaneously active users.

## Sampled time profile

The longer native eight-stream run correlated all thirty rounds for sampled
user 0. The table partitions that sampled population's mean, 861.2 ms, rather
than the 855.0 ms mean over all 120 exercise rounds.

| Component | Mean ms |
| --- | ---: |
| Merge queue | 0.1 |
| Connection acquisition + BEGIN, both transactions | 41.7 |
| Merge SQL, 10 calls | 238.6 |
| Capture SQL, 3 calls | 129.8 |
| Non-SQL transaction body | 61.4 |
| Commit + connection release, both transactions | 37.0 |
| Other server spans and gaps | 80.6 |
| Transport + client residual | 272.1 |
| **Sampled total** | **861.2** |

The sampled server path was 589.1 ms. Combined application SQL wall time was
368.4 ms, or 28.3 ms per call. These spans include transport and scheduling;
they are not PostgreSQL execution time or CPU time. BEGIN/COMMIT are outside the
13 application SQL calls. Transaction work and serialization were preserved.

Raw CPU/RSS estimates are retained in the results. Process-tick CPU estimates
can exceed the visible quota and are not reliable measurements of Cloud
throttling. This campaign makes no quantitative CPU-saving claim. These short
runs also do not establish long-run memory stability.

## Reproduction

Use the existing benchmark secret through `BENCHMARK_SECRET`, without placing it
in the command line. The eight-stream short trial used:

```sh
rounds --target https://serverpod-offline-sync-benchmark.api.serverpod.space/ \
  --run-id UNIQUE_RUN_ID --data-dir OUTPUT_DIRECTORY \
  --users 4 --devices 2 --workers 4 --rounds 10 --rows 1 --period-ms 2000 \
  --sample-seconds 30 --timeout-seconds 45 --startup-timeout-seconds 300 \
  --setup-concurrency 1 --schema full --workload person --write-mode insert \
  --mode continuous --no-sync-diagnostics
```

For the longer run, set `--rounds 30`. For four streams, set `--users 2`,
`--workers 2`, and `--rounds 20`. The collector enables server sampling only for
user 0, drains numbered diagnostic records, and disables sampling after cleanup.
The exact client executable SHA-256 is
`044b08b4bee651780909be4c44949c90a25a239f72c1548417289d7301e2667e`.

## Deployment identity and cleanup

The native executable SHA-256 was
`b1fb477576fe873a8e4847b6b1524abfad6e8d5a0499c08e6e2a5dedd8890362`.
Its Cloud deployment was `e365a3c3-5982-4930-b27c-2fd85b3c8767`.
The original executable was restored in deployment
`5ef3dd72-c088-4d7a-98fb-da5e0f32a118`, with its original SHA-256:
`e61d7523bf14fb3771ecaab9de26b98df2ad525b8bc7e9c2987cad615fae5ffc`.

The deployment stayed on one Small instance throughout. All eleven protected
configuration and secret files matched their pre-test hashes in both the
original tree and native export. Existing migration files were preserved.
Prepared metadata was deliberately retained with the original configuration;
it does not identify the new runtime source. Runtime provenance comes from the
resolved Git pins, archived upload, successful build, and executable hashes.

All seven runs, totaling 360 exercise rounds, converged with zero retries or
unexpected stream ends. Each ended with zero open streams and zero
idle-in-transaction sessions. The final restored deployment was clean, sampling
was disabled, and normal idle pool connections were allowed. Every collector
drained its final traces without gaps or errors. A local duplicate-output-label
guard rejected one control invocation before starting a client; it produced no
benchmark run, and its log is retained privately.

## Evidence

- [Run distributions, timing breakdowns, and cleanup verdicts](benchmark-evidence/small-native-tls-2026-10-29/results.json).
- [Individual exercise-round measurements](benchmark-evidence/small-native-tls-2026-10-29/measurements.json).
- [Source pins, executable identities, and restoration manifest](benchmark-evidence/small-native-tls-2026-10-29/manifest.json).

Private raw events, diagnostic traces, deployment logs, and source archives are
under `/tmp/sync-native-tls-small-20261028`. Deployment archives and configuration
files are excluded from committed evidence. This report adds measurements only;
it changes no runtime implementation and does not measure syncOnce startup.
