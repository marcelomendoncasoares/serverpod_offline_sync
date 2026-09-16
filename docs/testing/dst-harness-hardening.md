# DST harness hardening

The harness uses isolated SQLite replicas, the production ORM, collector and
merge boundary. Production packages are unchanged. Replay is exact within a
revision; correcting generator inputs can change schedules between revisions.

## Portable oracle and independent evidence

Snapshots compare all schema columns, including omitted nullable JSON values,
portable effective field HLCs, authored values, projection reasons,
and tombstone generation/HLC/reason. Absent field metadata inherits the insertion
clock; an explicit field at that same clock is equivalent. Replica-local integer
IDs and space/node checkpoints are not portable facts.

The generator retains submitted values before each ORM write and verifies them
after commit. Full-row projected passthrough preserves its attempted value/HLC.
The oracle admits only the local before/after clock delta after these checks;
an unrelated write cannot bless prior merged corruption. Controlled initial
fixtures may initialize it explicitly. At quiescence, accepted row identities/spaces, effective field facts
and real tombstones must survive LWW merging. Local FK side effects are retained
from the acknowledged delta; real DB scenarios cover their semantics rather
than duplicating a general FK/unique planner.

Raw SQLite ORM controls independently establish persisted insert defaults and
explicit narrowed null updates. Existing-row reinsertion uses update semantics,
while visible upsert applies insert defaults; separate controls cover each path.
A visibility rule rejects hiding a live row with no authored outbound references.
It does not arbitrate general FK fixed points or unique winners. Hidden
unrepairable SET DEFAULT references remain legal, and FK-before-unique rules are
preserved. Bootstrap compares export plus merge/projection against the source;
it is not independent proof against identical corruption on both sides.

## Incremental validation

Commands run from `test/serverpod_offline_sync_test_server` with
`/home/msoares/fvm/versions/3.35.3/bin/cache/dart-sdk/bin/dart` (Dart 3.12.2).
Implementation logs are in `/tmp/dst-fix-logs/`.

- Oracle increment: `dart test test/dst/dst_authored_oracle_test.dart
  test/dst/dst_operations_test.dart test/dst/dst_projection_oracle_test.dart
  --concurrency=1 --reporter expanded`: **29 passed**;
  `issue1-commit-controls.log`.
- Initial full untagged DST run: **47 passed, 1 failed, 3 tagged-suite skips**;
  `issue1-focused-v3.log`. The original 400-operation test reaches a projected
  `unique_set_default_child.updateWhere` whose explicit null is not retained.
  This remains a failure for investigation, not an expected refusal. Its timeout
  increased to 2 minutes because the pre/post database observations add work;
  assertions are unchanged.
- Seed 114 / 40 rounds / overlapping spaces exposes membership-wide generator
  reads selecting another space's row (`issue1-seed114-v3.log`). This is a harness
  selection defect; correcting it belongs to the rejection-handling increment.

The starting revision's seed 114 / 200-round engine failures remain deferred:
empty-replica bootstrap violates `unique.spaceId,name`, and overlapping spaces
rematerialize a mixed unique FK name differently. Collector interleaving bug #84
is outside this task. No engine failure is skipped or converted to success.

## Concrete operations and refusals

All generator reads, including parent selection, use the public `spaceEquals`
filter. Production space-scoped reads are membership-wide, so a transaction's acting
space alone does not constrain those reads. Admin snapshots remain unfiltered.
Refusal prediction follows the selected row IDs through the cascade closure;
no-action children, non-null SET NULL children, and unavailable defaults justify
only their exact exceptions. A default deleted in the same batch is unavailable.
Definite blockers also fail an unexpected successful return. Successful primary
delete/restore intents must advance the authored tombstone with the right parity.

Expected refusals compare the whole domain/authored/projection/tombstone state,
explicit field-clock representation, and persisted space-node progress before
and after the transaction. Arbitrary UNIQUE and FOREIGN KEY errors propagate.
Real SQLite trigger fault injection checks that path; ordinary competing unique
insert/batch/update regressions verify supported operations really commit.

- Rejection increment: `dart test test/dst/dst_rejection_test.dart
  test/dst/dst_operations_test.dart --concurrency=1 --reporter expanded`:
  **21 passed** (`issue2-focused.log`).
- `dart analyze test/dst`: **no issues** (`issue2-analyze.log`).

## Populated profiles and observable activity

`DST_PROFILE=sparse|populated|mixed` and `DST_GRAPH_WIDTH` accompany seed/rounds in
replay messages. Mixed alternates even populated and odd sparse seeds. Populated
worlds create all 32 tables and 28 authored FK edges, cycles, competing unique
writes, a verified tuple exchange, restore/redelete, retarget/detach and a blocked
delete before random scheduling. Every scripted commit runs the same structural,
causal, authoring and rollback observations as random operations. Complete
collector batches are delivered; known keys only decide whether to enqueue them.

`DST_METRICS` separates setup from scheduled activity, including on early failure.
Attempts reconcile with commits, refusals, skips and unexpected failures; an
oracle failure after a successful transaction remains a counted commit with a
validation-failure counter. Semantic observations deduplicate field/tombstone
HLC events. Authored edges/cycles are distinguished from visibility. Unique
projection coverage names columns rather than inferring which overlapping index
conflicted; a swap requires an actual different-tuple exchange.

Passing 100+ round runs require at least 30 scheduled commits and merges;
populated runs also require every declared authored FK edge and the deterministic
semantic transitions. CI now uses four mixed seeds at 200 rounds across both
topologies (4,800 scheduled attempts), replacing fifty shallow 20-round worlds
(6,000 attempts). Per-simulation and job budgets are 10 and 60 minutes. These are
configured allowances, not a measured full-depth runtime guarantee: genuine
engine failures abort the current populated/deep runs before their full budget
can be measured.

- Final workload/rejection/runner controls: `dart test
  test/dst/dst_workload_test.dart test/dst/dst_runner_test.dart
  test/dst/dst_rejection_test.dart --concurrency=1 --reporter expanded`:
  **16 passed, 1 engine failure** (`final-issue3-controls.log`). Width-two populated
  controls pass with and without the fixed default and replay exactly in isolated
  databases. Width-three seed 62 fails a supported swap after three competing
  unique claims with `unique.spaceId,name`; the failing test remains enabled.
- A 200-round width-three seed-62 replay fails during setup and correctly reports
  **35 attempts, 34 commits, 1 unexpected failure, 0 scheduled operations**
  (`issue3-width3-early-failure.log`). No stress coverage is credited to setup.
- Populated seed 114 / 40 rounds exposes `unique_set_default_child.parentId`
  UNIQUE failure on a predicate write (`issue3-populated40.log`).
- Two independent minimal real-DB diagnostic probes in
  `/tmp/dst-fix-probes/unique_authored_null_test.dart` both fail against unchanged
  production: explicitly detaching a projected unique-FK loser leaves its old
  authored reference; inserting two omitted nullable FK defaults violates the
  unique index even with the default town present (`engine-unique-probes.log`).
  These establish engine findings independently of the operation classifier.


## Reviewed normalization of equivalent insertion storage

Raw row HLC anchors are not canonical facts independently of field clocks.
`_applyMergeInsertForExistingRow` keeps an existing anchor and records newer field
HLCs, whereas local restoration touches the row anchor. A real source, existing
receiver and empty bootstrap can therefore have different raw anchors with
identical effective field values/HLCs and real restore tombstones. The added
control explicitly verifies that the raw anchors differ before asserting portable
equality. Raw anchors remain in rollback fingerprints and as the fallback for
fields without explicit clocks; changing an inherited clock remains detectable.

An independently upserted newer insertion can also be encoded as a generation-1
`userInsert` marker on an existing receiver, while the source has no tombstone.
A separate real source/receiver/bootstrap control establishes this representation
pair. Only that marker is normalized, and only when every effective field clock
already includes its HLC. Future unexplained insertion markers and every real
delete/restore tombstone remain strict. The oracle checks row identity/space and
both presence and absence of accepted visibility facts, so fabricated tombstones
cannot be treated as accepted deletes.

The raw-anchor-only failures of sparse seeds 117/118 at the prior increment were
oracle false positives, not engine defects. They are superseded by the final
normalized sweep below; no domain or effective field/tombstone discrepancy was
ignored to make that correction.

- Normalization controls: `dart test test/dst/dst_authored_oracle_test.dart
  test/dst/dst_runner_test.dart test/dst/dst_operations_test.dart
  test/dst/dst_rejection_test.dart --concurrency=1 --reporter expanded`:
  **40 passed** (`normalization-controls.log`), before the additional negative
  generation-one-marker control included in the complete final DST rerun.

Two further public-API controls cover full-row visible upserts of a projected
town, both with the equivalent generation-one marker and after a real restore.
Changing only its name preserves the attempted FK value and its HLC. Upsert does
not advance the raw row anchor; a restored row can legitimately retain an older
projected FK clock while its real generation-three tombstone remains strict.
Both controls pass (`projected-upsert-controls.log`) and are permanent in
`dst_insertion_representation_test.dart`, included in the final DST suite below.

## Final validation and remaining engine failures

Use the pinned Dart binary above for every `dart` command. Test-server commands
run from `test/serverpod_offline_sync_test_server`; the core suite runs from
`packages/serverpod_offline_sync`. These runs overlap and their totals must not
be added together.

| Check | Command | Result | Revision and log |
| --- | --- | --- | --- |
| Complete untagged DST | `dart test test/dst --concurrency=1 --reporter expanded` | 73 passed, 2 engine failures, 3 tagged-suite skips | Final normalized implementation plus the two permanent insertion controls; `final-dst-all.log` |
| Sparse baseline-size sweep | `DST_SEED_BASE=114 DST_SEEDS=8 DST_ROUNDS=40 DST_PROFILE=sparse DST_GRAPH_WIDTH=2 dart test -P dst test/dst --concurrency=1 --reporter expanded` | 14 passed, 5 engine failures | `0d9829a`; `final-normalized-sparse40.log` |
| Stronger CI configuration | `DST_SEED_BASE=114 DST_SEEDS=4 DST_ROUNDS=200 DST_PROFILE=mixed DST_GRAPH_WIDTH=2 dart test -P dst test/dst --concurrency=1 --reporter expanded` | 3 passed, 8 engine failures | Pre-normalization `93a45cb`; `final-ci-mixed200.log` |
| Complete ordinary test-server suite | `dart test --concurrency=1 --reporter expanded` | 816 passed, 2 engine failures, 3 tagged-suite skips | Pre-normalization `93a45cb`; `final-server-suite.log` |
| Core package suite | `dart test --concurrency=1 --reporter expanded` | 56 passed | Production unchanged; `final-core-suite.log` |
| DST analyzer | `dart analyze test/dst` | No issues | Final files; `final-focused-analyze.log` |
| Workspace analyzer | `dart analyze` from repository root | 1 existing deprecated-lint warning | `analysis_options.yaml:110`, also present at starting revision; `final-normalized-analyze.log` |
| Formatting | `dart format --output=none --set-exit-if-changed test/serverpod_offline_sync_test_server/test/dst` from root | 23 files, 0 changed | Final files |
| Whitespace | `git diff --check` | Passed | Final files |

The final untagged failures are the existing 400-operation test reaching a
supported `unique_uuid.insertBatch` rejected by SQLite, and the width-three
populated replay reaching the supported unique swap described above. The sparse
sweep has 11 passing simulations plus 3 ownership checks; its five failures are
physical UNIQUE refusals: overlapping seed 119 (`unique_uuid.insert`), and
single-space seeds 114 (`unique_uuid.insert`), 115 and 120
(`unique_uuid.insertBatch`), and 118 (`unique_set_default_child.insert`). The
previous raw-anchor false positives no longer occur.

The deeper mixed run fails before completing its requested schedules. Six
simulations expose physical UNIQUE refusals on supported insert/update/upsert
paths, one overlapping run accepts a `unique_nullable.upsert` value of 1 but
retains 0, and one single-space run advances a projected passthrough field HLC
during `unique_overlapping.fullRowUpdate`. These local-operation failures precede
portable normalization, so the normalization correction does not invalidate
their diagnostic evidence. The pre-normalization full server/CI runs are not
claims that those complete suites passed on the final revision.

The final sparse sweep reports **1,630 attempted, 721 committed, 2 expected
rejections, 902 skipped, 5 unexpected failures**, all scheduled operations. The
deeper mixed run reports **1,486 attempted, 1,026 committed, 30 expected
rejections, 424 skipped, 6 unexpected failures**, including 2 committed writes
with validation failures. Of those attempts, 246 were setup; the schedule reached
1,240 attempts and 786 commits. Metrics record actual activity rather than
crediting the configured 200 rounds when an engine failure stops execution.

Production packages, the deferred bootstrap/round-trip engine defects and
collector bug #84 remain unchanged. The harness deliberately retains failing
regressions and surfaces the newly observable engine findings. Independent
coordinator review completed with no remaining findings, including source,
formatting and Given/when/then descriptions; its focused runs passed 31 distinct
authored/rejection/runner and projected insertion controls.


## 2026-09-14 rebase validation

Rebased the five hardening commits onto `b89725f` with the OfflineSync/Space
vocabulary. Production packages and model/migration definitions match that base.
All 28 changed Dart declaration snapshots across the five commits match their
original code after terminology and formatting changes, including assertions,
timeouts, refusal classification and workload budgets. Each commit retains its
original file boundaries and author. Workspace analysis and changed-file
formatting pass with Dart 3.12.2 from Flutter 3.44.4.

The documented deep replay was rerun from the test server with
`DST_SEED_BASE=114 DST_SEEDS=4 DST_ROUNDS=200 DST_PROFILE=mixed
DST_GRAPH_WIDTH=2 dart test -P dst test/dst --concurrency=1 --reporter expanded`.
It again reports **3 passed and 8 retained engine failures**: six physical UNIQUE
refusals, the overlapping seed-115 `unique_nullable.upsert` accepted-value loss,
and the single-space seed-117 `unique_overlapping.fullRowUpdate` passthrough-clock
advance. The physical refusals are overlapping seeds 114
(`unique_set_null_child.updateWhere`), 116 (`unique_fk_pair.updateWhere`) and 117
(`unique_discriminator.upsert`), and single-space seeds 114
(`unique_set_default_child.updateWhere`), 115 (`unique_uuid.insertBatch`) and 116
(`unique_cascade_child.upsert`).

The metrics exactly reproduce the previously documented deep run: **1,486
attempted, 1,026 committed, 30 expected refusals, 424 skipped, 6 unexpected
failures and 2 committed validation failures**. Setup accounts for 246 attempts;
scheduled work reaches 1,240 attempts and 786 commits. The simulations still stop
on engine failures before completing their configured 200 rounds. No failing
regression was skipped or converted into an expected refusal during this rebase.

The complete ordinary test-server suite (`dart test test/ --concurrency=1`)
reports **842 passed, 2 retained engine failures and 3 tagged-suite skips**.
The failures remain the 400-operation `unique_uuid.insertBatch` control and the
width-three seed-62 populated `unique.swapUnique` control. The rebase logs are in
`/tmp/offline-sync-rebase/pr-123-test-app.log` and
`/tmp/offline-sync-rebase/pr-123-dst-mixed200.log` on the validation workstation.
