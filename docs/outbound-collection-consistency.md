# Outbound collection consistency (follow-up)

## Summary

Outbound change collection reads CRDT metadata and the domain data it describes
in **separate, non-atomic queries**. Under concurrent domain writes — real on
the server, where co-members of a shared scope write while a sync runs — this
race can make an otherwise-healthy stream sync **fail and record a durable
integrity violation** for a condition that the very next round would resolve on
its own. Failing the session for a transient, self-correcting race is the design
weakness to fix; no data is ever applied incorrectly, so this is a
robustness/liveness problem, not a corruption one.

This is **not yet implemented** — it is tracked design debt. The single-pass
multi-scope collection (`collectPendingChanges`) did not introduce the race
but widened its window, which is what surfaced it.

## The mechanism

Collection is *snapshot-then-fetch*, and lock-free by design (the per-scope
`transactionForUser` lock guards the inbound merge, not outbound collection):

1. `_streamInserts` / `_streamUpdates` / `_streamDeletes` read the CRDT metadata
   (`CrdtDataRow` / `CrdtDataField` / tombstones) as a query result — a snapshot
   at some point `t0`.
2. The domain row/column values are then read in **later, separate** queries
   (`_fetchDomainRow`, `_fetchOwnedColumnValue`, `_readDomainRowOwner`).

Between (1) and (2), and across the three independently-snapshotted queries, the
domain can change underneath the collection.

## Failure modes

1. **Concurrent delete → false-positive `missingDomainRow`.** A row whose CRDT
   insert metadata was snapshotted, but whose domain row is deleted before the
   domain read, makes `_fetchDomainRow` miss. Today that records a durable
   `missingDomainRow` violation and **fails the session** — even though the next
   round would simply collect the tombstone and converge.

2. **FK target inserted after the insert snapshot → dangling reference.** The
   insert snapshot is taken at `t0`, but FK *column values* are read at fetch
   time (later). If a referencing row's FK points to row `B` that was inserted
   **after** `t0`, then `B` is not in the collected insert batch, yet the
   reference to it is shipped. The same applies to an FK **update** collected in
   the updates pass whose target was inserted after the inserts pass: the edge is
   sent without the node. The peer then either churns through FK projection
   (`SET NULL` / `SET DEFAULT` / `RESTRICT` with the durable `attemptedValue`)
   until a later round delivers `B`, or trips an integrity violation and fails.
   Either way, a benign ordering skew degrades the stream.

3. **Value ahead of its HLC (self-correcting, listed for completeness).** If a
   column is bumped from HLC `h` to `h2` between the metadata read and the domain
   read, the batch ships `(value@h2, HLC=h)`. This converges: our own
   `CrdtDataField` is now at `h2`, our send checkpoint only advanced to `h`, so
   the next round re-ships `(value@h2, HLC=h2)` and every replica ratifies it.
   No permanent divergence — but it shares the same root cause as (1) and (2).

## Why "fail the session" is the wrong response

All three are **transient and self-correcting**: the next collection round picks
up the tombstone, the late insert, or the higher HLC, and replicas converge.
Tearing down the stream — and persisting an integrity-violation record that reads
like corruption — for a race that resolves itself next round converts an
ordering skew into an outage plus a misleading audit trail. A durable
`crdt_sync_integrity_violations` entry should mean a *genuine* invariant breach
(an ownership collision, real corruption), not "two reads happened to straddle a
concurrent commit."

## Directions

- **Read a consistent snapshot (primary).** Run the whole collection — the three
  metadata queries *and* the domain reads — inside one read-only,
  snapshot-consistent transaction (repeatable-read). On Postgres this is MVCC:
  **a read snapshot, not a write lock**, so it adds no cross-scope write
  contention (and is therefore the right answer to "do we have to lock all
  scopes?" — no, we take a snapshot, not a lock). A single snapshot closes the
  race outright:
  - The delete in (1) is invisible if it commits after the snapshot, and fully
    visible (metadata + domain) if before — never half-seen.
  - It makes each batch **referentially closed by construction**: the domain's
    own FK constraint guarantees that wherever `A.fk = B` is visible in the
    snapshot, `B` is too, so `B` is collected alongside `A`. (2) cannot happen.

- **Tolerate, don't fail (fallback / defense in depth).** Where a consistent
  snapshot is impractical, distinguish a *transient* missing row / missing
  referent (present in CRDT metadata, not yet consistently readable, or arriving
  next round) from a *true* violation, and **defer the racy change to the next
  round** instead of failing the session and recording a durable violation. The
  peer's FK projection already tolerates a transiently-missing referent — the
  collector should match that posture rather than failing on it.

- **Shrink the window.** Independent of the above, replace row-by-row domain
  reads with set-based queries (`WHERE id IN (…)`) per table, narrowing the gap
  between the metadata snapshot and the domain reads. Cheap, and reduces exposure
  even before a full snapshot lands.

## Priority

Correctness is preserved today (convergence + fail-safe: no wrong data is ever
applied), so this does not block current use. But because it can fail a healthy
long-lived continuous sync under concurrent shared-scope writes — the exact
workload shared scopes enable — it should be addressed before such deployments
are relied upon. The consistent-snapshot approach is the smallest change that
removes all three failure modes at once.
