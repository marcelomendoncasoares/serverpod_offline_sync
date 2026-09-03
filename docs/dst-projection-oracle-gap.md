# DST projection oracle lost its healthy-row coverage

Status: **known gap — not yet fixed.**

## What changed

`CrdtDataForeignKey` was dense: one row per FK field, present whether or not an
override was active (`recordInsertAttempts` materialized it on every insert).
`CrdtDataAttemptedValue` is sparse by design — "present only while the
materialized domain value differs from the authored value".

`DstSnapshot._captureProjections` builds the oracle's population from an
unfiltered read of that table. So it went from seeing **every FK field** to
seeing **only the currently overridden ones**.

## What is no longer checked

`DstOracle` dropped this invariant, because `reason == null` stopped being
representable and the rows it guarded stopped appearing in the snapshot:

> With no override the target must be available, or the edge must have repaired
> the row some other way. Set null / set default rewrite the column, so a dead
> target without an override means the repair never ran; cascade hides the child
> instead of touching the column, so the child must actually be hidden;
> restrict makes the parent delete lose, so the target should still be visible.

That check is what caught "the repair never ran": a visible row whose FK points
at a hidden or missing parent, with no projection recorded. Nothing replaces it,
on any replica.

Two smaller losses in the same edit:

- `DstProjection.visibleValue` is hardcoded to `null` in `_captureProjections`
  (there is no stored visible value any more — the domain column is it), so any
  assertion reading it is vacuous.
- The "one unreadable state" skip changed from `overrideReason == null && fk
  value == null` to `projectionReason == hiddenUniqueRelease && fk value ==
  null`, a different and narrower set.

## Why it matters

FK repair correctness is exactly what the DST is for. A replica that silently
fails to repair a dangling FK now converges "successfully" as far as the oracle
is concerned, because a row with no attempted value is invisible to it.

## Fix

Derive the FK-field population from the schema and the domain rows rather than
from the attempted-value table, then assert both halves:

- an attempted row exists: the domain value must differ from the authored one,
  and the reason must match the edge's action (already checked);
- no attempted row: the parent must be available, or on a cascade edge the child
  must itself be hidden.

This is a change to `test/dst/framework/dst_snapshot.dart` only. No engine
change is implied — though the check may well find one.

## Scope

Reintroducing it will likely fail on real defects rather than pass immediately,
which is the point, so it is worth landing separately from the projection
redesign rather than as a rider on it.
