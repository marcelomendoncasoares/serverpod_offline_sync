# Durable checkpoint comparison

Thirteen measured cases converged with complete observations and clean teardown; six kept up with the offered rate and seven fell behind. Three heavier cases were skipped after a comparable workload fell behind. Each user has two established streams and at most one outstanding round, offered every two seconds. Times include the local write and application on every peer.

These are single short trials on the same Cloud project, native TLS, no pipelining, database pool 100, merge concurrency 50, commit hints disabled, and persistent and console session logging disabled. Source, dependency and executable identities are in the manifest and ARTIFACT_PROVENANCE.json. The locally smoke-tested AOT executable and the Cloud-built executable have different hashes; Cloud identity was verified separately.

## Latency observations

Before is the fresh cached-checkpoint control. After is the durable revision-checkpoint implementation. Percentage differences are descriptive observations, not repeated estimates of an isolated causal effect. Matching exact starting domain-table counts does not establish identical physical database state. Full min/median/mean/p95/max results are in README.md and results.json.

| Case | Median before / after (ms) | p95 before / after (ms) | Kept up after | Starting counts match |
|---|---:|---:|---|---|
| medium-full-person-r1-c8-a8-spread-t2 | 324.1 / 356.9 | 425.4 / 587.4 | True | True |
| medium-full-person-r1-c32-a32-spread-t2 | 817.4 / 680.5 | 1009.9 / 858.4 | True | True |
| medium-full-person-r1-c64-a64-spread-t2 | 3688.8 / 3020.4 | 4989.7 / 4197.4 | False | True |
| medium-full-person-r200-c2-a2-spread-t2 | 1188.2 / 1081.7 | 1278.0 / 1276.9 | True | True |
| medium-full-person-r1000-c2-a2-spread-t2 | 6240.4 / 3782.2 | 7131.0 / 4162.3 | False | True |
| medium-full-town-linked-r200-c2-a2-spread-t2 | 2789.6 / 1209.8 | 3871.2 / 1253.8 | True | True |
| medium-full-town-linked-r1000-c2-a2-spread-t2 | unmeasured / 5011.2 | unmeasured / 5526.4 | False | None |
| medium-city-city-r200-c2-a2-spread-t2 | 926.1 / 858.3 | 1283.9 / 891.4 | True | True |
| medium-city-city-r1000-c2-a2-spread-t2 | 4147.9 / 2536.7 | 5272.7 / 3187.3 | False | True |
| small-full-person-r1-c8-a8-spread-t2 | 807.4 / 691.8 | 1011.1 / 875.6 | True | False |
| small-full-person-r200-c2-a2-spread-t2 | 2617.9 / 2249.4 | 2845.1 / 2331.9 | False | False |
| small-full-town-linked-r200-c2-a2-spread-t2 | 7148.2 / 2970.5 | 9572.9 / 3100.9 | False | False |
| small-city-city-r200-c2-a2-spread-t2 | 2368.9 / 1943.8 | 2590.4 / 2386.3 | False | True |

Medium Person at eight devices was slower in this trial (median 324 to 357 ms, p95 425 to 587 ms). At 32 devices the median was 817 to 680 ms and p95 1010 to 858 ms. At 64 devices both versions fell behind: the lower candidate latency does not establish supported capacity.

## Redundant upload removal

Each 1000-row case authored eight rounds, or 8000 exercise rows. Received chunk round/writer markers were matched to completed merge traces by request ID and batch ID. Both streams for this one-user workload were sampled; warmup markers were excluded.

| Medium workload | Uploaded rows before / after | Merge transactions before / after | SQL statements per round before / after | Median reduction | p95 reduction |
|---|---:|---:|---:|---:|---:|
| person | 14264 / 8000 | 16 / 8 | 23 / 10 | 39.4% | 41.6% |
| city | 14216 / 8000 | 16 / 8 | 16 / 8 | 38.8% | 39.6% |

The control retransmitted 783 Person rows or 777 City rows from the receiving peer per round. The candidate received exactly the authored 8000 rows and one merge transaction per round, with no additional peer upload in these trials. Both 1000-row workloads still miss the two-second cadence. These observations establish the change for these insert trials, not every workload or failure path.

## Dataset and resource qualifications

The candidate passed Medium linked Town at 200 rows and therefore attempted 1000 rows, which the control correctly skipped. Those additional rows persisted in the full-schema database. The three later Small full-schema cases consequently have unequal starting domain-table counts; their timings remain visible, but the comparison suppresses speedup percentages. City uses a separate database and its starting domain-table counts match. Medium linked Town at 1000 rows has no measured baseline.

CPU figures retain the [resource-accounting caveat](../native-tls-capacity-baseline-progress-2026-10-29/RESOURCE_ACCOUNTING.md). Visible quota and sampled process CPU do not establish effective host capacity or a correction factor. SQL wall time includes driver, network, scheduling, and database time.

This comparison does not establish sustained sizing limits. The five-tier discovery and longer boundary checks are separate. The comparison runner restores its own starting candidate configuration; restoring the original executable and configuration on one Small remains a final campaign obligation.
