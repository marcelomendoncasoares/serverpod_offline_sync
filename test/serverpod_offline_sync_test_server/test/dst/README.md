# Deterministic simulation tests

These suites drive several replicas through randomized operations and
adversarial delivery, then check properties the engine must hold. A run is
described by its seed, rounds, workload profile, and graph width. Those inputs
replay exactly within the same source/SDK revision.

They complement the `integration/` suites rather than replacing them.
Integration tests pin specific scenarios and assert exact outcomes; these
generate scenarios nobody wrote down and assert invariants.

## Running

The randomized sweeps carry the `dst` tag and are skipped by an ordinary
`dart test`, because they are slow and because a randomly seeded search makes
a poor edit-loop signal — a run can fail for a defect unrelated to the change that
triggered it. The `dst` preset opts back in:

```sh
dart test -P dst                                     # the simulation suite
DST_SEEDS=200 DST_ROUNDS=40 dart test -P dst         # soak
DST_SEED_BASE=1781161784 DST_SEEDS=1 dart test -P dst  # replay one seed
```

The deterministic oracle, operation-generator, and runner regressions in this
directory are untagged and run with ordinary `dart test`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `DST_SEEDS` | 8 | How many seeds the sweep runs |
| `DST_ROUNDS` | 40 | Operation rounds per simulation |
| `DST_SEED_BASE` | unix seconds | First seed; successive seeds increment |
| `DST_PROFILE` | sparse | `sparse`, `populated`, or `mixed` (even seeds populated, odd sparse) |
| `DST_GRAPH_WIDTH` | 2 | Rows per table in each populated graph, minimum 2 |
| `DST_DEBUG_TABLE` | unset | Print every merge touching this table, in delivery order |

A divergence is usually explained by which facts a replica had merged when it
derived its state, and in what order — which the end-of-run snapshot cannot
show. `DST_DEBUG_TABLE=unique` prints that delivery order.

The base defaults to the current time, so every run searches schedules no
previous run tried. A fixed default would make this a smoke test rather than a
search — the same simulations forever, either always catching a defect or never
— and it degrades invisibly, since any change that shifts merge scheduling moves
which defects those fixed seeds reach.

Nothing is lost to reproducibility: a seed determines its simulation entirely
and a failure prints its replay command. Tests are named by position rather
than by seed, so the suite stays stable while the schedules underneath it vary.
Pin the seed, rounds, profile, and graph width to re-run an exact sweep.

The consequence to expect is that a run can fail for a defect unrelated to the
change that triggered it. That is the suite doing its job; take the seed from
the failure and replay it.

## The properties

| Property | When it is checked |
| --- | --- |
| **Observer independence** - a space looks identical to every replica holding it, whatever *other* spaces that replica holds | At quiescence |
| **No cross-space link** - no visible foreign key resolves to a row owned by another space | After every local commit and merge |
| **Foreign-key closure** - every visible foreign key resolves to a visible parent in the same space | After every local commit and merge |
| **Unique closure** - no visible unique index is violated | After every local commit and merge |
| **Projection purity** - FK fields and recorded overrides satisfy the oracle's repair rules, including permitted terminal unique releases | After every local commit and merge |
| **Ownership collision is terminal** - a merge claiming another space's row id fails, records a durable violation, and leaves the owner untouched | `dst_ownership_collision_test.dart` |

Observer independence is the keystone. A synced row may only reference synced
rows of its own space (`docs/row-ownership.md`), so a merged cross-space
reference must be repaired or the child hidden. If that repair depended on
which spaces the merging replica happens to hold, visibility would become a
function of the observer's subscription set and the merge would no longer be a
deterministic function of the facts. `DstTopology.overlappingSpaces` exists to
make that falsifiable: two replicas hold one space each, a third holds both.

## What is injected

Determinism requires every source of variation to come from the seed.

- **Time** - `Hlc` reads `clock.now()`, so simulations install a manually
  advanced `Clock`. Each replica gets a small offset to model skew. Advances
  stay well under `Hlc`'s one-minute drift limit, so a run exercises clock
  disagreement without tripping `ClockDriftException`.
- **Identifiers** - `DstIds` mints UUIDv7-shaped values from the seed.
- **Node identity** - pinned per replica. `OfflineSyncSpaceManager` otherwise mints
  `CrdtNode()` with a wall-clock UUID, and `Hlc.compareTo` breaks ties on the
  node UUID, so an unpinned node id makes concurrent merge winners
  nondeterministic.

Node identity is currently pinned by pre-creating the `CrdtNode` row and
attaching it to every space, which relies on how `OfflineSyncSpaceManager` resolves
the current node. `DstReplica._assertSeededNodeIdentity` fails loudly if that
stops working, because the alternative is a silent loss of replayability. An
injectable node id on the engine would remove the need for the trick.

## What the adversary does

Reorders, delays, redelivers already-merged batches, and isolates incoming
delivery to selected replicas for a few rounds. Sources can still send during
this receive isolation; this is not a bidirectional network partition.

Two moves are deliberately unavailable, both because the merge contract states
that input arrives as a causally complete snapshot of the sender
(`docs/foreign-key-invariants.md`):

- **It never drops permanently.** Dropping manufactures failures outside the
  contract instead of finding real ones.
- **It never splits a collected batch.** An earlier version of this harness
  split batches at a random pivot to vary framing. That delivers, for example, a
  delete without its insert; the engine ignores the orphaned change, the harness
  records it as delivered, and the fact is lost - surfacing as a bogus
  convergence failure. Chunking in the real protocol sits *below* the merge
  (`chunked()` emits frames that `collectNextBatch` reassembles until
  `OfflineSyncEndOfBatch`), so the whole cycle is the causal unit and splitting here
  models nothing real.

Delay, reorder, and redelivery are the honest moves - and redelivery is how
idempotence gets probed.

## Layout

| File | Role |
| --- | --- |
| `framework/dst_random.dart` | Seeded randomness, identifiers, clock, sweep config |
| `framework/dst_world.dart` | Replicas and operation generation |
| `framework/dst_schema.dart` | Generated model adapters and declared unique indexes |
| `framework/dst_adversary.dart` | Delivery scheduling and quiescence |
| `framework/dst_snapshot.dart` | Portable domain/authored/projection snapshots and structural oracle |
| `framework/dst_authored.dart` | Pre-write evidence, primary visibility intents, and accepted-fact retention |
| `framework/dst_rejection.dart` | Concrete refusal prediction and accepted-error matching |
| `framework/dst_workload.dart` | Populated per-space graphs and deterministic semantic transitions |
| `framework/dst_coverage.dart` | Deduplicated authored transitions and observed graph shapes |
| `framework/dst_runner.dart` | One seeded run, and failure reporting |

The simulated graph includes nullable and required cascade, no-action,
set-null, and set-default references, the mixed cascade/no-action chains, and
all outbound references of person and organization. Person, company, and town
can form a cycle. Foreign-key actions, nullability, and defaults are read from
the generated schema; every domain FK of a simulated model is included.

The operation generator selects columns from that same schema. Nullable FKs
can be detached explicitly even when a parent is available. New required FK
values are only generated when a visible parent exists. The well-known default
town is inserted in one space because row IDs are globally unique.

Projection purity checks every FK field, including fields without a sparse
attempted-value record. A hidden child can retain its authored reference to a
physically present parent in the same space when its action has no legal repair;
it does not block that parent's deletion. Hidden values are recomputed, so an
earlier projected fallback is not frozen in place. Visible non-null references
must still resolve to visible parents in the same space. FK repair reasons must
match the action and nullability; FK columns in unique indexes may instead carry
a terminal unique-conflict or hidden-row release reason.

These checks validate the resulting fields and reasons against the observed
visibility. They do not independently recompute deletion arbitration or unique
winners. Replica agreement, export round trips, and the integration suites'
exact expected outcomes provide additional checks; a finite seed sweep is not
a proof for every possible merged history.

The unique simulation authors and captures text, non-FK UUID, nullable integer,
composite, fixed-discriminator, overlapping, FK-only composite, and space-scoped mixed
FK/text claims. The unique oracle reads all declared tuple components and space.
A null component releases the tuple, as in SQL.

The operation generator can insert, update, delete, restore a retained identity,
upsert, pass a full model back through update, insert/update/delete a batch,
swap unique tuples atomically, and perform predicate updates/deletes. Scripted regressions
use `DstOperations.apply` to select the same paths directly. Reports retain
attempted and committed counts by table/action so a passing run does not hide
which paths it visited. Rejected local transactions remain separate from
committed operations.


## Workload strength and metrics

The populated profile creates every declared table and FK edge, closes the
person/company/town cycles, and drives unique conflicts, a real tuple exchange,
restore/redelete, FK retarget/detach, and a constrained refusal. These are actual
ORM transactions, each checked immediately for structure, authored preservation,
and causal monotonicity. Complete exports distribute the populated spaces before
random scheduling starts. The sparse profile retains empty-world exploration.

Every run emits one `DST_METRICS` JSON record, including failed runs. It separates
setup attempts from scheduled commits and records attempted, committed, rejected,
skipped, unexpected failures, and committed transactions whose oracle failed.
A run failing during setup reports zero scheduled activity. Paths retain table
and action; network observations include merge counts, duplicate batches, maximum
batch size, total delivered changes, and receive-isolation events.

Coverage counts distinct field/tombstone events rather than repeated snapshot
appearances. FK edges and cycles are **authored graph** observations. Unique
projection coverage reports columns, not a claim that every overlapping index
conflicted. A swap counts only a validated exchange of two different tuples.
The counters do not claim every FK transition or every unique shape was stressed.

Passing simulations require scheduled commits and merges. At 100+ rounds the
minimum is 30 scheduled commits; shorter runs are smoke checks. Populated runs
also require all declared authored FK edges and the mandatory semantic paths.
Setup commits alone cannot satisfy the scheduled-activity gate.

CI alternates sparse and populated profiles across four consecutive seeds at
200 rounds in both topologies: 4,800 scheduled operation attempts, versus the
previous 6,000 attempts spread across fifty shallow 20-round worlds. This keeps
comparable attempt volume while exploring ten times the history depth and
connected graphs. The simulation timeout is ten minutes per seed and the job
budget is sixty minutes to allow the additional real database observations.
Known engine failures remain failures; CI is intentionally not a PR merge gate.

```sh
DST_SEED_BASE=114 DST_SEEDS=1 DST_ROUNDS=200 DST_PROFILE=populated DST_GRAPH_WIDTH=2 dart test -P dst
DST_SEED_BASE=62 DST_SEEDS=1 DST_ROUNDS=200 DST_PROFILE=populated DST_GRAPH_WIDTH=3 dart test -P dst
```

The oracle remains bounded: it does not independently arbitrate all unique
winners or FK fixed points. Collector concurrency/checkpoint lifecycle, crash
recovery, space grant/revoke, and transport framing remain outside this schedule.
See `docs/testing/dst-harness-hardening.md` for exact validation and engine findings.
