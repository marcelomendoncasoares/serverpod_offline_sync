# Rebuildable FK and unique projection strategy

Status: **proposed durable design — not yet implemented.** The branch contains
interim guards and deterministic regression tests that this design replaces.

Given the same authored CRDT facts and synchronized schema, every replica must
rebuild the same domain rows and projection metadata, including hidden rows.
The result must not depend on arrival order, batching, local history, or
bootstrap from another replica.

Related documents:

- [Foreign-key projection invariants](foreign-key-invariants.md)
- [Unique-constraint invariants](unique-constraint-invariants.md)
- [Outbound collection consistency](outbound-collection-consistency.md)

## Decisions

- Domain columns are materialized projection whenever FK or unique processing
  changes an authored value. The authored value must remain available.
- `CrdtDataAttemptedValue` is the single, generic attempted-value authority for
  FK, unique, and fields governed by both. Projectors never keep independent
  attempted values.
- FK-safe candidates are ephemeral planner output; no separate
  `CrdtDataForeignKey` record is needed. `CrdtDataAttemptedValue` also carries
  a generic diagnostic `projectionReason`.
- Hidden rows participate in FK and release projection. They may regain an
  FK-safe candidate, but are always released before unique conflict grouping
  and never participate in winner selection.
- FK projection runs before unique projection. Unique projection consumes
  FK-safe candidates and effective visibility, and produces final domain values.
- Projection never emits an authored field update or advances its HLC.
- Physical FK and unique constraints remain correctness backstops.
- Outbound sync sends authored values, never projected or temporary values.
- Persisted schema types are validated eagerly at initialization. A migration
  hook may automate conversion later, but is not required for safety.

## Why the current model fails

The domain column currently doubles as authored and projected storage. Once a
projector rewrites it, the authored value is lost unless separately retained.
This creates history-dependent behavior:

- unique resolution considers visible rows while hidden physical rows still
  occupy unique indexes;
- `releaseOnDelete` covers only local deletes, not remote tombstones or
  cascade-hidden rows;
- a synthetic release recorded as an authored update can be outranked later;
- the interim FK guard preserves whichever hidden value a replica already has;
- immediate unique constraints can reject local writes before after-write
  projection runs; and
- export reads a projected domain value unless it can substitute the authored
  one.

The focused tests expose these cases through physical SQLite unique violations:
`sync_unique_cascade_hidden_claim_test`, `sync_foreign_key_unique_reclaim_test`,
and `sync_unique_release_overwrite_test`.

## Storage ownership

### Authored facts

`CrdtDataField` owns the field HLC. Its authored value is read as:

```text
attemptedValue(field) =
  CrdtDataAttemptedValue.value, if that row exists
  domainRow[field],             otherwise
```

`CrdtDataAttemptedValue` is a sparse one-to-one dependent of
`CrdtDataField`:

```yaml
# Backlink added to CrdtDataField:
attemptedValue: CrdtDataAttemptedValue?, relation(optional, name=field_attempted_value)

class: CrdtDataAttemptedValue
table: crdt_data_attempted_value
database: all
fields:
  fieldId: int, unique
  field: CrdtDataField?, relation(name=field_attempted_value, field=fieldId, onDelete=Cascade)
  value: dynamic, serializationDataType=jsonb
  projectionReason: CrdtProjectionReason
```

Use Serverpod's existing dynamic `{className, data}` representation, as it
preserves `String`, `UuidValue`, null, and other supported Serverpod values
independently of the database dialect.

Create or update the row whenever the final domain value differs from the
authored value. Remove it only when the domain value again equals the authored
value and no projector still needs an override. At that point the domain column
itself safely carries the authored value. No changes to the `CrdtDataField`
existence policy, which is whenever its HLC is newer than the row HLC.

### Diagnostic projection reason

`projectionReason` replaces the FK-specific override enum and can describe any
projector, for example:

```yaml
enum: CrdtProjectionReason
serialized: byIndex
values:
  - foreignKeySetNull
  - foreignKeySetDefault
  - foreignKeyMissingParent
  - uniqueConflict
  - hiddenUniqueRelease
```

It is diagnostic-only derived state. Projection decisions must never read it;
the planner recomputes from authored facts and schema, then rewrites the reason
with the final domain value. Because it is singular, it records the terminal
stage that selected that value. Earlier causes remain reconstructible rather
than becoming combinatorial enum variants.

The row therefore deliberately contains data with two lifetimes:

- `value` is a durable authored fact and must survive rebuilds; and
- `projectionReason` is disposable and may be recomputed in place.

Code that rebuilds diagnostics must update the reason without deleting the row.

Examples:

| State | Attempted row | Reason | Domain value |
| --- | --- | --- | --- |
| No projection | absent | absent | authored value |
| FK `SET NULL` repair | authored UUID | `foreignKeySetNull` | `null` |
| Unique loser | authored value | `uniqueConflict` | released value |
| Hidden unique row | authored value | `hiddenUniqueRelease` | released value |
| FK candidate then unique release | authored UUID | `uniqueConflict` | released value |

## Exact projection order

Local writes and inbound merges use one fact-plus-projection planner.

1. **Merge or author facts.** Resolve row, field, tombstone, and HLC facts.
   Capture every affected authored field value before changing its materialized
   domain value. Projection does not alter these facts.
2. **Compute visibility and FK candidates.** Starting from authored FK values,
   resolve cascade, restrict/no-action, set-null, and set-default to the FK
   fixed point over visible and hidden rows. Produce effective visibility and
   an FK-safe candidate for every FK field.
3. **Release hidden rows, then resolve visible claims.** First assign every
   hidden row a deterministic conflict-free value, even when it is the only row
   with that claim. Hidden rows do not join conflict groups or winner selection.
   Then build conflict groups from visible rows only. For an FK field, key the
   lookup by its FK-safe candidate; for other fields, key it by its authored
   value from `CrdtDataAttemptedValue` when present, otherwise the domain
   column. Never key it by a previously released materialized value. Claim
   ordering still uses canonical authored field HLCs. The deterministic visible
   winner materializes the canonical claim and every visible loser receives a
   deterministic conflict-free value.
4. **Build one final plan.** The plan contains final visibility, final domain
   values, and required `CrdtDataAttemptedValue` rows with diagnostic reasons.
   Unique output does not feed back into FK visibility: it changes
   materialization, not the authored FK or FK-safe candidate. A full
   recomputation is the oracle for any incremental affected-closure algorithm.
5. **Materialize atomically.** Park changing unique tuples at deterministic
   constraint-safe temporary values when immediate indexes require it, then
   write final domain values and metadata in the same transaction. Temporary
   values are never facts or outbound changes.

This order resolves a hidden unique FK without an FK-side exception. If its
parent becomes visible, the FK stage may restore the authored UUID as its
candidate; the unique stage then releases it because the child is hidden. When
the child is restored, it enters visible winner selection and either reclaims
the UUID or receives the supported loser value. For a unique FK, that release
must be FK-safe; under the current policy the FK is nullable and releases to
`null`.

Local insert, update, upsert, delete, and tombstone restoration need this plan
before the underlying write can violate an immediate unique constraint. A
full-row passthrough of an existing projected value remains non-authored;
explicit/narrowed field writes author a new attempted value and field HLC.

## Outbound and rebuild behavior

Outbound collection substitutes `CrdtDataAttemptedValue.value` whenever it
exists; otherwise it reads the domain value. It never exports an FK candidate,
unique loser value, or temporary parking value as an authored update.

An empty replica merging a complete scope export must reproduce normalized
domain rows, hidden state, authored values/HLCs, and derived projection. A
rebuild may rewrite `projectionReason`, but it must preserve
`CrdtDataAttemptedValue.value`: while the row exists, that is the only copy of
the authored fact.

## Type and migration safety

### Persisted type identity

Add at least these fields to `CrdtSchemaColumn`:

```yaml
columnType: ColumnType
dartType: String
```

Both are required. Serverpod's stable `ColumnType` enum may be persisted
directly and records database storage; `dartType` records dynamic value
semantics. For example, `bigint` may represent `int`, `Duration`, or a by-index
enum, while one Dart value can use different storage such as `json` or `jsonb`.
Relevant parameters, nullability, FK definitions, unique indexes, and release
policy also belong in the persisted schema identity and sync compatibility hash.

### Dynamic validation

For normal engine writes and inbound sync, let Serverpod deserialize
`CrdtDataAttemptedValue.value`, then compare its canonical serialized class name
with the class expected by `dartType`. Do not compare
`runtimeType.toString()` and do not manually query inside the JSON envelope.
Null is validated from the persisted schema because it has no concrete runtime
class.

Top-level `List` does not validate its element type. Any supported generic or
custom type therefore needs recursive validation plus deterministic,
cross-dialect unique equality. Initialization must reject a schema containing a
releasable type whose validation or release semantics the projector does not
support; this is a schema check and does not scan persisted attempted values.

For now, synchronized unique projection must reject any `ColumnType.json` or
`ColumnType.jsonb` domain column participating in a unique claim. Neither
nullable JSON as a releasable candidate nor non-nullable JSON as a fixed
component is supported: sync semantics do not yet define canonical,
cross-dialect JSON equality. This restriction applies to the domain column's
schema type, not to the JSONB envelope used by `CrdtDataAttemptedValue.value` to
store an otherwise supported dynamic value.

### Initialization algorithm

Call `await crdtDatabase.initialize()` after application migrations and before
serving requests or starting sync. Reconciliation must plan before mutating:

1. Load the persisted CRDT registry and target `TableDefinition`s.
2. Compare names, persisted type identity, indexes, and relations.
3. Classify additions, drops, possible renames, and type/policy changes.
4. If types match, trust validated engine writes and do not scan values.
5. For each changed type, perform only an existence check for attempted rows;
   never deserialize them during initialization.
6. If attempted rows exist, fail without changing registry or projection state.
   The initialization exception must identify the table, column, stored and
   target type identities, and instruct the developer to convert the domain and
   attempted values and then attest completion in `CrdtSchemaColumn`.
7. Also fail without mutation when a rename or drop/add is ambiguous.
8. Otherwise update the registry, clear obsolete derived caches, rebuild, and
   publish the in-memory schema.

Initialization is therefore bounded by schema metadata and existence queries;
it never adds a data-size-dependent attempted-value scan to application startup.

### Direct migrations without a hook

For a non-destructive type change with attempted rows, the initialization
exception instructs the application migration to perform these operations in
one transaction and in this order:

1. Convert the domain column without destroying authored meaning.
2. Convert every affected `crdt_data_attempted_value.value` envelope using
   Serverpod's serialization format.
3. As the final step, update the corresponding `CrdtSchemaColumn` type and
   policy identity to the target values reported by the exception.

The final registry update is the migration's explicit attestation that all
dependent data was converted. If conversion fails before that step, the old
identity remains and initialization fails again safely. If the developer
converts the data but omits the attestation, the same actionable exception is
raised on the next start. Once the stored identity matches, initialization
trusts the migration and does not rescan attempted values.

This is an intentional trust boundary. Updating `CrdtSchemaColumn` without
correctly converting the data can cause a later deserialization failure;
proving otherwise would require the costly startup scan this design rejects.
Manual migrations already carry equivalent responsibility for domain data and
constraints.

For a rename with field metadata, the migration updates the existing
`CrdtSchemaColumn.name` so its identity survives. For a real drop, it
explicitly removes the old schema column and cascading field metadata. An
ambiguous drop/add with metadata fails before reconciliation mutates anything.

The future migration hook tracked by
[issue #87](https://github.com/marcelomendoncasoares/serverpod_offline_sync/issues/87)
can abstract the conversion and final attestation from application developers,
but it follows the same protocol and does not make startup scan existing rows.
New invalid peer input, external SQL after initialization, a live schema change,
or a falsely attested manual migration can still fail at runtime as an atomic
integrity or deserialization error. Unattested migration changes fail at
initialization with direct repair instructions.

## Rejected alternatives

- **Ignoring hidden-row materialization:** hidden values remain observable,
  exported, and indexed, so freezing them makes projection history-dependent.
  Unique conflict grouping is nevertheless intentionally visible-only after
  hidden rows have been unconditionally released.
- **The interim unique-FK guard:** it preserves stale materialization and merely
  moves failure to a later claim or restoration.
- **Extending `releaseOnDelete`:** it misses remote/cascade hiding and later
  authored changes.
- **Partial indexes excluding hidden rows:** visibility is stored outside the
  domain table; denormalizing it creates another engine-owned source of truth.
- **Removing physical unique indexes:** this hides projection defects instead
  of preventing divergence.
- **Independent FK and unique attempted stores:** a field governed by both
  would have competing authored authorities.
- **A separate FK projection table:** its candidate is recomputable planner
  output and its only useful persisted field was a diagnostic reason. A generic
  reason on `CrdtDataAttemptedValue` avoids another relation and table.
- **Untagged JSON or a custom codec:** Serverpod dynamic already preserves the
  wire type through `className`.
- **One table per Dart type:** it multiplies schema and migration machinery for
  values always addressed by field identity.
- **Scanning attempted values after a type change:** it proves more about a
  manual migration, but makes application initialization proportional to real
  data volume. The migration's final registry update is the explicit attestation
  instead.

## Verification gates

Deterministic tests must cover:

- hidden plain and FK unique claims, including lone hidden claimants;
- later authored writes while hidden and deterministic restoration;
- a visible loser reclaiming its canonical attempted value after the previous
  winner becomes hidden, without treating hidden rows as conflict candidates;
- bootstrap/export convergence for visible and hidden rows;
- all local write paths before immediate constraint checks;
- swaps, composite indexes, overlapping indexes, and safe two-phase writes;
- incremental projection equivalence to full recomputation;
- batch partition and replay convergence, plus proof that unrelated non-FK
  updates do not run FK projection;
- matching schema startup without value scans;
- initialization rejection of nullable and non-nullable JSON-backed unique
  candidates;
- changed types with no attempted rows, and actionable failure without scanning
  or mutation when attempted rows exist;
- transactional conversion with `CrdtSchemaColumn` attested last, including
  repeated failure when the attestation is omitted;
- normal write and sync rejection of malformed or incorrectly typed dynamic
  values;
- rename and drop migrations;
- sync rejection for incompatible type or projection schemas; and
- rebuild and mutation validation proving canonical-claim substitution and
  unconditional hidden-row release are required.

Run the DST only after these deterministic gates pass.

## Implementation sequence

1. Align this document and the FK/unique invariants.
2. Persist schema type identity and include it in sync compatibility.
3. Make schema reconciliation plan-first with eager, actionable failures.
4. Add `CrdtDataAttemptedValue` with a generic diagnostic reason, retire
   `CrdtDataForeignKey`, and make outbound collection use the attempted value.
5. Implement the ordered FK-then-unique planner: compute FK candidates and
   hidden releases over all affected rows, then resolve conflicts among visible
   canonical claims only.
6. Add pre-write planning and safe two-phase materialization.
7. Remove `releaseOnDelete`, the hidden unique-FK guard, and stale projection
   paths.
8. Land deterministic convergence, migration, rebuild, and mutation tests.
9. Run the DST.

Remaining implementation choices are supported generic/custom releasable types,
the initialization exception API, and return value semantics when a local
authored value is immediately projected. None may weaken the rule that authored
values are durable facts and materialized values are fully rebuildable from
those facts plus schema.
