# Relation storage cost

## Result

Foreign-key projection metadata is now sparse. A synchronized relation uses:

- only its UUID in the domain row when it has not changed since insert;
- one `crdt_data_fields` row after an explicit field update; and
- one `crdt_data_foreign_key` row only while the visible value is repaired away
  from the attempted value.

The reduction removes the duplicated projection row from the ordinary updated
relation and removes all per-relation CRDT metadata from an ordinary insert.
At 10,000 rows, the compacted physical allocation was:

| Ordinary populated relation | PostgreSQL 16.13 | SQLite 3.45.1 |
| --- | ---: | ---: |
| Before: field + projection metadata | 236.75 B | 73.45 B |
| After an explicit update: field metadata | **131.07 B** | **33.59 B** |
| Saved after an explicit update | **105.67 B (45%)** | **39.87 B (54%)** |
| After insert, before any field update | **0 B** | **0 B** |

The domain UUID itself averages 16.38 bytes on PostgreSQL and 16.11 bytes on
SQLite in these fixtures. Therefore an explicitly updated ordinary relation now
uses 147.46 bytes on PostgreSQL or 49.70 bytes on SQLite including the domain
UUID. A relation that remains at its insert value pays only the domain cost.

An active repair still needs both metadata rows. That cost is temporary: when a
missing or hidden parent becomes usable again, or the user authors a new visible
value, the projection row is deleted. A lazily created field that still equals
the row clock is deleted with it; an independently updated field clock remains.
Initialization also removes resolved projection rows written by older package
versions, so upgraded databases realize the projection reduction without a
schema migration.

## Storage model

`crdt_data_rows` timestamps the inserted row. That row HLC already timestamps
every field which has not subsequently changed, so a valid insert does not need
one `crdt_data_fields` row per populated relation.

An explicit relation update creates a `crdt_data_fields` row containing its HLC,
row, column, and node IDs, plus the `(rowId, columnId)` unique-index entry. The
attempted value is read from the domain row in the normal state; it is not copied
into projection storage.

When foreign-key projection must materialize a different safe value, it creates
`crdt_data_foreign_key` with the attempted UUID, visible UUID, and override
reason. If the insert did not already have a field clock, projection creates one
lazily with the row HLC. This preserves the attempted value for convergence and
outbound sync without manufacturing a field update.

PostgreSQL has a separate primary-key B-tree for each metadata table. SQLite's
`INTEGER PRIMARY KEY` aliases the rowid and does not allocate equivalent
indexes. That explains most of the difference between engines.

## Measurement

### SQLite production path

[`benchmark/relation_storage.dart`](../benchmark/relation_storage.dart) inserts
`Person` rows with no foreign keys, adds three relations through the real
`CrdtDatabaseSession` update path, validates the sparse row counts, compacts the
database, and uses `dbstat` to attribute bytes to each table and index.

Run it with:

```sh
dart run benchmark/relation_storage.dart --rows=10000
```

The 10,000-row result with 4,096-byte pages was:

| Added relation | Domain | Field table + index | Projection table + index | CRDT metadata | Focused total |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 15.56 B | 33.59 B | 0.00 B | 33.59 B | 49.15 B |
| 2 | 15.97 B | 33.18 B | 0.00 B | 33.18 B | 49.15 B |
| 3 | 16.79 B | 34.00 B | 0.00 B | 34.00 B | 50.79 B |
| **Mean** | **16.11 B** | **33.59 B** | **0.00 B** | **33.59 B** | **49.70 B** |

The metadata's logical payload was 24.97 bytes per updated relation. The
difference between payload and allocated size is B-tree page structure and free
space.

The independently runnable DDL companion is
[`benchmark/relation_storage.sql`](../benchmark/relation_storage.sql). It uses
the generated SQLite column and index shapes and measured 33.04 bytes of CRDT
metadata and 49.15 bytes total per relation. Run it with:

```sh
sqlite3 :memory: < benchmark/relation_storage.sql
```

### PostgreSQL physical shape

[`benchmark/relation_storage_postgres.sql`](../benchmark/relation_storage_postgres.sql)
uses Serverpod's PostgreSQL types (`bigint`, `uuid`, and timestamp), includes
the generated primary-key and unique indexes, and runs `VACUUM FULL` before each
snapshot. It creates and removes an isolated `relation_storage_benchmark`
schema. Run it against a scratch database with:

```sh
psql --dbname=postgres --file=benchmark/relation_storage_postgres.sql
```

The 10,000-row result on embedded PostgreSQL 16.13 with 8,192-byte pages was:

| Added relation | Domain | Field table + indexes | Projection table + indexes | CRDT metadata | Focused total |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 16.38 B | 133.53 B | 0.00 B | 133.53 B | 149.91 B |
| 2 | 16.38 B | 129.43 B | 0.00 B | 129.43 B | 145.82 B |
| 3 | 16.38 B | 130.25 B | 0.00 B | 130.25 B | 146.64 B |
| **Mean** | **16.38 B** | **131.07 B** | **0.00 B** | **131.07 B** | **147.46 B** |

These are compacted table and index allocations excluding sequences, WAL, and
dead tuples. Production allocation varies with fill factor, update churn,
autovacuum, and index bloat. A synchronized row also has a separate baseline
cost for `crdt_data_rows`: 176.13 bytes on PostgreSQL and 62.67 bytes on SQLite
in these fixtures. It is paid once per row, not once per relation.

## Remaining opportunities

For active overrides, `fieldId` is already a unique 1:1 identity. Making it the
projection table's physical key could remove the separate generated `id` and a
redundant index. This is less urgent now that only exceptional rows pay the
projection cost.

The remaining `crdt_data_fields` table and indexes cost about 131 bytes per
actual field update on PostgreSQL and 34 bytes on SQLite. A composite physical
key such as `(rowId, columnId)` or denser HLC representation could reduce it,
but would affect every updated field and should be benchmarked independently.
Neither unique index should be dropped without preserving its cardinality
invariant and lookup path.
