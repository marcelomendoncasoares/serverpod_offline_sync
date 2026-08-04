# Deterministic simulation tests

These suites drive several replicas through randomized operations and
adversarial delivery, then check properties the engine must hold. A run is
fully described by its seed, so a failure replays exactly.

They complement the `integration/` suites rather than replacing them.
Integration tests pin specific scenarios and assert exact outcomes; these
generate scenarios nobody wrote down and assert invariants.

## Running

```sh
dart test test/dst                                  # default smoke sweep
DST_SEEDS=200 DST_ROUNDS=40 dart test test/dst      # soak
DST_SEED_BASE=1781161784 DST_SEEDS=1 dart test/dst  # replay one seed
```

| Variable | Default | Meaning |
| --- | --- | --- |
| `DST_SEEDS` | 8 | How many seeds the sweep runs |
| `DST_ROUNDS` | 12 | Operation rounds per simulation |
| `DST_SEED_BASE` | `0x5EED` | First seed; successive seeds increment |
| `DST_DEBUG_TABLE` | unset | Print every merge touching this table, in delivery order |

A divergence is usually explained by which facts a replica had merged when it
derived its state, and in what order — which the end-of-run snapshot cannot
show. `DST_DEBUG_TABLE=unique` prints that delivery order.

The default base is fixed so an ordinary `dart test` run is reproducible. A
soak should set `DST_SEED_BASE` to explore fresh schedules.

## The properties

| Property | When it is checked |
| --- | --- |
| **Observer independence** - a scope looks identical to every replica holding it, whatever *other* scopes that replica holds | At quiescence |
| **No cross-scope link** - no visible foreign key resolves to a row owned by another scope | After every merge |
| **Foreign-key closure** - every visible foreign key resolves to a visible parent in the same scope | After every merge |
| **Unique closure** - no visible unique index is violated | After every merge |
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
| `framework/dst_world.dart` | Replicas, the simulated table graph, operation generation |
| `framework/dst_adversary.dart` | Delivery scheduling and quiescence |
| `framework/dst_snapshot.dart` | Canonical snapshots and the property oracle |
| `framework/dst_runner.dart` | One seeded run, and failure reporting |

The simulated world is five tables chosen to cover every foreign-key action and
both unique-index shapes in one small graph: `town.cityId` is cascade,
`town.mayorId` is set-null, `address.inhabitantId` is restrict and carries the
foreign-key-only global unique index, and `unique.name` is unique per scope.
