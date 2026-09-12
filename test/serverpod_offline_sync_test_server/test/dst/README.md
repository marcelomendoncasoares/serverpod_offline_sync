# Deterministic simulation tests

These suites drive several replicas through randomized operations and
adversarial delivery, then check properties the engine must hold. A run is
fully described by its seed, so a failure replays exactly.

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
| `DST_ROUNDS` | 12 | Operation rounds per simulation |
| `DST_SEED_BASE` | unix seconds | First seed; successive seeds increment |
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
Pin `DST_SEED_BASE` to re-run an exact sweep.

The consequence to expect is that a run can fail for a defect unrelated to the
change that triggered it. That is the suite doing its job; take the seed from
the failure and replay it.

## The properties

| Property | When it is checked |
| --- | --- |
| **Observer independence** - a scope looks identical to every replica holding it, whatever *other* scopes that replica holds | At quiescence |
| **No cross-scope link** - no visible foreign key resolves to a row owned by another scope | After every local commit and merge |
| **Foreign-key closure** - every visible foreign key resolves to a visible parent in the same scope | After every local commit and merge |
| **Unique closure** - no visible unique index is violated | After every local commit and merge |
| **Projection purity** - FK fields and recorded overrides satisfy the oracle's repair rules, including permitted terminal unique releases | After every local commit and merge |
| **Ownership collision is terminal** - a merge claiming another scope's row id fails, records a durable violation, and leaves the owner untouched | `dst_ownership_collision_test.dart` |

Observer independence is the keystone. A synced row may only reference synced
rows of its own scope (`docs/row-ownership.md`), so a merged cross-scope
reference must be repaired or the child hidden. If that repair depended on
which scopes the merging replica happens to hold, visibility would become a
function of the observer's subscription set and the merge would no longer be a
deterministic function of the facts. `DstTopology.overlappingScopes` exists to
make that falsifiable: two replicas hold one scope each, a third holds both.

## What is injected

Determinism requires every source of variation to come from the seed.

- **Time** - `Hlc` reads `clock.now()`, so simulations install a manually
  advanced `Clock`. Each replica gets a small offset to model skew. Advances
  stay well under `Hlc`'s one-minute drift limit, so a run exercises clock
  disagreement without tripping `ClockDriftException`.
- **Identifiers** - `DstIds` mints UUIDv7-shaped values from the seed.
- **Node identity** - pinned per replica. `CrdtScopeManager` otherwise mints
  `CrdtNode()` with a wall-clock UUID, and `Hlc.compareTo` breaks ties on the
  node UUID, so an unpinned node id makes concurrent merge winners
  nondeterministic.

Node identity is currently pinned by pre-creating the `CrdtNode` row and
attaching it to every scope, which relies on how `CrdtScopeManager` resolves
the current node. `DstReplica._assertSeededNodeIdentity` fails loudly if that
stops working, because the alternative is a silent loss of replayability. An
injectable node id on the engine would remove the need for the trick.

## What the adversary does

Reorders, delays, redelivers already-merged batches, and partitions replicas for
a few rounds.

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
  `CrdtSyncEndOfBatch`), so the whole cycle is the causal unit and splitting here
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
| `framework/dst_snapshot.dart` | Canonical snapshots and the property oracle |
| `framework/dst_runner.dart` | One seeded run, and failure reporting |

The simulated graph includes nullable and required cascade, no-action,
set-null, and set-default references, the mixed cascade/no-action chains, and
all outbound references of person and organization. Person, company, and town
can form a cycle. Foreign-key actions, nullability, and defaults are read from
the generated schema; every domain FK of a simulated model is included.

The operation generator selects columns from that same schema. Nullable FKs
can be detached explicitly even when a parent is available. New required FK
values are only generated when a visible parent exists. The well-known default
town is inserted in one scope because row IDs are globally unique.

Projection purity checks every FK field, including fields without a sparse
attempted-value record. A hidden child can retain its authored reference to a
physically present parent in the same scope when its action has no legal repair;
it does not block that parent's deletion. Hidden values are recomputed, so an
earlier projected fallback is not frozen in place. Visible non-null references
must still resolve to visible parents in the same scope. FK repair reasons must
match the action and nullability; FK columns in unique indexes may instead carry
a terminal unique-conflict or hidden-row release reason.

These checks validate the resulting fields and reasons against the observed
visibility. They do not independently recompute deletion arbitration or unique
winners. Replica agreement, export round trips, and the integration suites'
exact expected outcomes provide additional checks; a finite seed sweep is not
a proof for every possible merged history.

The unique simulation authors and captures text, non-FK UUID, nullable integer,
composite, fixed-discriminator, overlapping, FK-only composite, and scoped mixed
FK/text claims. The unique oracle reads all declared tuple components and scope.
A null component releases the tuple, as in SQL.

The operation generator can insert, update, delete, restore a retained identity,
upsert, pass a full model back through update, insert/update/delete a batch,
swap unique tuples atomically, and perform predicate updates/deletes. Scripted regressions
use `DstOperations.apply` to select the same paths directly. Reports retain
attempted and committed counts by table/action so a passing run does not hide
which paths it visited. Rejected local transactions remain separate from
committed operations.
