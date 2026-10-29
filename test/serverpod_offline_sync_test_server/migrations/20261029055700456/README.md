# Replica revision schema upgrade

`migration.sql` is the SQLite upgrade used by this repository. It preserves
authored metadata IDs and dependent attempted values through a transactional
copy/swap, with foreign-key validation before commit. The embedded client
migration contains the same SQL.

`migration.postgres.sql` is the PostgreSQL upgrade. It adds field/tombstone
`spaceId` as nullable, derives ownership from the immutable row foreign key,
then sets `NOT NULL`. Populated tables are altered in place.

Both SQL variants seed existing facts and their spaces at revision 1 with
unknown immediate provenance, so a fresh receiver at revision 0 sees them.
New facts are assigned revisions by the production recorder.

`migration.json` describes the structural ALTER operations. Use the checked-in
SQL for upgrades: regenerating SQL from the structural plan alone omits the
ownership backfill and initial revision seeding. `definition.json` remains the
complete target schema for fresh databases and subsequent migrations.
