# Native TLS capacity campaign

Status: the cached/HLC baseline completed 372 cases across all five Cloud sizes.
Sustained boundary follow-ups and the revision-checkpoint comparison are still
in progress. See the [measurement ledger](../benchmark/reports/native-tls-capacity-baseline-progress-2026-10-29/README.md)
and [sizing tables](../benchmark/reports/native-tls-capacity-baseline-progress-2026-10-29/SIZING.md).
The 51
focused checks include actual separate worker processes, idle-stream probes,
exact PostgreSQL/SQLite convergence, and cleanup. Static analysis is clean.

## Objective and fixed implementation

The versioned [capacity runner](../benchmark/tool/capacity/README.md) separates
adaptive discovery from frozen replay. Both stop heavier comparable loads after
an unsuccessful measurement. Replay retains the same case arguments and compares
matching observations after a performance change; skipped cases remain explicitly
unmeasured. Failures on an older build do not preempt measurements on a new build.
Private configuration and credentials remain outside the repository.

One `discover` command automatically traverses all five sizes and schema profiles,
then restores the starting deployment. The stopping rule resets across independent
tiers and workloads. It carries failures across increasing row and device counts
within a comparable workload and never automatically retries at a slower cadence.

Measure one Cloud instance at each size: Small, Medium, Large, XL, and XXL.
Use the native TLS integration from PR #202, retaining transaction serialization,
TCP_NODELAY, inline portal close, and cancellation drainage. Do not enable
pipelining or change the Offline Sync engine within a campaign. The durable
revision-checkpoint implementation is a separate candidate with fresh databases,
its matching client, and its own measurements.

The table must relate schema complexity, rows changed per round, total connected
devices, and actively syncing devices. A connected stream is not equivalent to
an in-flight sync round. Record configured participation and measured overlap
separately. Report the instance's observed CPU quota and memory, not only its
marketing size.

## Independent workload controls

- `users × devices` determines total connected streams.
- `active-users` determines which users write during exercise; zero is an idle
  connection hold. Other users retain their established streams.
- `schedule=spread` measures sustained traffic; `schedule=burst` releases active
  users against a shared clock origin. Each user has at most one outstanding
  round; delayed work retains its original schedule rather than hiding backlog.
- `warmup-workers` bounds stream-opening work independently of the exercise
  workers, so a reconnect burst does not masquerade as an idle-stream limit.
- `rows` varies changed domain rows per round. Retain actual encoded payload
  bytes, delivered rows, application SQL counts, and bytes/rows per second.
- Vary devices per user to measure fan-out separately from independent users.
- Record round start/end timestamps from one cross-process monotonic clock to
  derive actual overlapping rounds and participating devices.

Every device authors a warmup sentinel, outside exercise. Idle users receive a
fresh end-of-hold probe before final verification. Final verification compares
the complete write journal with the server and every replica, without repair
syncs. Stream errors, missing rounds, partial convergence, and unclean teardown
must fail correctness even if some latency measurements exist.

The load-generator machine has measurable drift between its disciplined timer
clock and `CLOCK_MONOTONIC_RAW`. Long Dart timer waits initially delayed scheduled
starts by about 100 ms, even though write-to-peer latency measurements used the
correct raw clock. The client now waits in short slices and rechecks the shared
clock. A regression test doubles timer durations: the previous implementation
missed a 250 ms target by more than 300 ms; the bounded-wait implementation stays
within the 100 ms test tolerance. Preserve earlier latency observations, but
identify the corrected client separately when judging offered-rate adherence and
aligned bursts. This is a measurement correction, not a sync-engine speedup.

## Schema profiles

1. **Flat:** City-only sync registry, one scalar domain field, no persisted
   foreign keys. Use a separate benchmark database.
2. **Nullable relations:** full generated registry, Person writes with nullable
   references unpopulated, preserving the prior reference workload.
3. **Populated relations:** full registry, Town rows referencing both City and
   Person, with Person also referencing City. Seed parents before exercise.

Record the exact registered tables, persisted fields, foreign keys, seeded
parents, write mode, and payload size. Distinguish registration complexity from
populated relationship work. Add a same-table nullable Town control where the
measured difference needs separating from row width or table identity.

Use isolated benchmark databases for schema selection; do not repurpose or
replace the original database. Keep database placement, pool limit, logging,
commit hints, SDK, dependency pins, and instrumentation fixed across size
comparisons. Inserts are the primary sweep; validate representative update
workloads before generalizing guidance to average changes.

## Adaptive measurement sequence

For every instance size:

1. Verify deployed executable, native TLS pins, quota, memory, schema, pool,
   logging, and a clean server. Run a small reference workload.
2. Increase idle connected streams geometrically, then narrow a failing bracket.
   Hold streams without writes and probe them afterward. Stop only at an
   observed boundary or a documented generator/platform limit.
3. Sweep active participation and rows per round for each schema profile.
   Initial row points are 1, 10, 50, 200, and 1000; expand or refine where needed.
   Increase active groups until correctness, complete observations, or offered-rate
   adherence fail. Track latency targets separately. Carry that failure forward
   to heavier comparable loads; if the minimum concurrency fails at 200 rows,
   skip 1,000 rows. Lower concurrency can still refine the passing boundary.
4. At fixed active participation, add idle connected devices to measure their
   incremental cost. Check several active fractions near useful operating points.
5. Run aligned bursts, fan-out controls, and representative updates. Validate
   useful passing boundaries and recommended operating points
   with longer runs. Do not infer an unmeasured cell solely from monotonicity.
6. Confirm cleanup before the next run. Retain timeout and failure evidence.
   Verify any recovery/redeployment before continuing.

Exploratory runs locate brackets; repeated and longer runs support the guidance.
The final table must label these evidence levels. A benchmark-client bottleneck
is a lower bound on server capacity, not a server failure. Monitor client CPU,
memory, loop lag, dispatch skew, and server process/connection diagnostics.

## Verdicts and deliverables

Keep separate verdicts for:

- exact convergence and clean stream/transaction drainage;
- ability to finish the offered schedule without accumulating delay;
- average below 1 s, p95 below 1 s, and p95 below 2 s;
- saturation, timeout, memory failure, restart, or generator limitations.

Publish minimum, median, mean, p95, maximum, samples, offered/achieved rounds and
rows per second, active/connected counts, actual overlap, payload bytes, and
resource observations. Do not discard the slower repetitions. Report measured
passing/failing brackets rather than an unsupported exact maximum.

The final report will include the full measurement table, per-size limits,
schema/volume comparisons, and example sizing recommendations for mostly idle
devices, steady collaborative traffic, bursty changes, and bulk catch-up. State
the database placement and test constraints that limit portability. Recommendations
must identify their supporting runs and distinguish measured headroom from any
chosen operational margin.

Retain a machine-readable manifest, raw per-round measurements, verdicts, and
reproduction commands. Commit sanitized evidence; keep credentials, deployment
archives, and private configuration out of Git. Restore the original executable,
configuration, and one Small instance when the campaign finishes or is stopped.
