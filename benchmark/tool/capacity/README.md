# Replayable capacity benchmarks

The runner measures continuous sync on one Serverpod Cloud instance using native
PostgreSQL TLS without pipelining. It preserves exact convergence, offered-rate
adherence, latency, and observation completeness as separate verdicts.

`discover` finds workload boundaries. `replay` runs every case from a frozen
matrix, including previously failing cases, without stopping at the old boundary.
Use replay to compare a performance fix fairly. Run discovery afterward to find
any new capacity beyond the old matrix.

## Prepare an experiment

1. Build and deploy the candidate benchmark server using the repository's
   `benchmark/tool/prepare_cloud.dart` workflow. Keep its prepared configuration
   and shared secret private. Build the rounds client with the same intended SDK:

   ```sh
   cd benchmark
   dart pub get
   dart build cli --target bin/rounds.dart --output /private/build
   ```

2. Provision two empty PostgreSQL databases on the same server as the baseline:
   `benchmark_capacity_full_<experiment>` and
   `benchmark_capacity_city_<experiment>`. The runner never creates, truncates,
   or deletes databases. Use fresh databases for a new experiment to avoid
   quietly comparing different accumulated table sizes. The report retains
   database bytes before and after each case.

3. Copy `config.example.json` outside the repository. Fill in the target, Cloud
   project, prepared directory, client/server SHA-256 values, source revisions,
   resolved dependency revisions, SDK, and database placement. `secretFile`
   contains only the shared benchmark secret; it is read at runtime and never
   placed in command arguments or the exported report. Cloud credentials come
   from the installed `scloud` CLI's local authentication file.

   The candidate must already be deployed. The runner verifies its executable
   before measurements and after each resize or schema change. The current
   experiment keeps pool size 100, merge concurrency 50, logging off, and commit
   hints off. Schema transitions redeploy the same executable.

4. Use Linux, Python 3, and `prlimit` for the load generator. No Python packages
   are required. The generator samples its owned process group and stops its
   client if the host has less than 4 GiB available memory. A generator limit
   does not establish a server limit. Record client CPU, memory, and event-loop
   lag before drawing capacity conclusions.

Keep the configuration and evidence directory private. The public report consists
only of selected measurements and metadata; review it before committing. Set
`commandEnvironment` in the private configuration if `scloud` needs a specific
SDK or `PUB_CACHE`. Values must be environment strings.

## Discover and freeze the table

From the repository root:

```sh
python3 benchmark/tool/capacity/run.py --config /private/capacity.json discover
```

The versioned [plan](plans/standard.json) covers Small, Medium, Large, XL, and XXL;
idle connections; active users; row volume; three schema profiles; and mixed
idle/active, fan-out, burst, update, and longer controls. Adaptive screens are
finite experiments. Use repeated longer runs near a proposed operating point
before recommending a production limit.

The report is regenerated at completion or interruption. It includes:

- `README.md`: minimum, median, mean, p95, maximum, samples, and verdicts.
- `SIZING.md`: observed CPU/memory budgets, active-device screens by schema and
  row count, idle connection trials, and mixed/sustained controls.
- `sizing.json`: the selected sizing trials and all contributing observations.
- `results.json`: throughput, overlap, resources, SQL counts, and failure phases.
- `rounds.jsonl`: individual round measurements, including incomplete-run data.
- `manifest.json`: build identities, dependency pins, and experiment settings.
- `replay.json`: the exact completed case list and its parameter fingerprints.

Raw receipts, server diagnostics, local SQLite replicas, and recovery records stay
in the private evidence directory. The diagnostics collector drains queued pages
before its next polling interval and records any gaps; missing observations are
never silently treated as a complete profile.

## Rerun after a performance change

Create a new private configuration with the new candidate hashes, fresh evidence
directory and databases, and otherwise matching settings. Then run:

```sh
python3 benchmark/tool/capacity/run.py --config /private/candidate.json replay \
  --matrix /private/baseline/report/replay.json \
  --baseline /private/baseline/report
```

This refreshes the table and writes `comparison/README.md` and
`comparison/comparison.json`. A percentage reduction is reported only when both
runs passed correctness, observations are complete, and workload, resource budget,
and relevant configuration match. A failed run becoming successful remains a
separate result. Keep repetitions; do not select only the fastest run.

The original campaign contained a benchmark-client clock correction. Preserve
client build identities when comparing those historical cases. New experiments
should use the corrected client consistently. Collector versions are also
recorded because diagnostic traffic can affect a resource-constrained server.

The sizing view separates keeping up from a subsecond p95 and uses the latest
recorded client for active screens. It does not select a passing repetition when
another matching trial failed or had incomplete observations. Idle setup failures
remain separate from established-stream measurements. Regenerate that view from
an existing exported report without contacting Cloud:

```sh
python3 benchmark/tool/capacity/guidance.py --report /private/baseline/report
```

The orchestration has 13 offline regression checks covering frozen failures,
parameter tampering, offline export, comparison eligibility, and conservative
sizing selections. A live Cloud
smoke case also completed with exact convergence, complete diagnostics, and
verified restoration. Repeating its command reused the receipt without issuing
another workload. These checks validate the runner, not a capacity limit.

## Resume, stop, and restore

Repeat the same command and configuration to resume after completed cases.
Completed receipts are reused only if their workload, client, server, and size
match. A partially written receipt is refused for manual inspection, preventing
an overlapping retry of a possibly live client. A different build or plan needs
a fresh evidence directory.

A project lock also prevents two runner configurations on the same generator
machine from benchmarking or resizing the same Cloud project concurrently.
Coordinate separately if running from multiple machines.

The runner snapshots the deployment's starting compute size, relevant environment
variables, executable, and protected file hashes. Normally it restores and
verifies those settings in `finally`, including after a failed case or interrupt.
For a deliberately staged campaign, `--leave-deployed` defers restoration until:

```sh
python3 benchmark/tool/capacity/run.py --config /private/capacity.json restore
```

Restoration returns to the candidate and settings present when the runner
started. If the surrounding experiment replaced an earlier deployment before
starting the runner, restore that earlier source separately. This distinction is
recorded rather than claiming restoration of an artifact the runner never saw.
Hard termination or a machine failure cannot execute `finally`; use the saved
snapshot and the explicit restore command. The runner refuses to overwrite an
unrelated deployment or changed protected configuration.

Offline operations do not contact Cloud:

```sh
python3 benchmark/tool/capacity/run.py --evidence /private/evidence freeze --matrix /private/replay.json
python3 benchmark/tool/capacity/run.py --config /private/capacity.json export
python3 benchmark/tool/capacity/run.py --evidence /private/evidence status
python3 -m unittest discover -s benchmark/tool/capacity -p 'test_*.py'
```
