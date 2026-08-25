.bail on
.parameter init
.parameter set @rows 10000

PRAGMA page_size = 4096;

-- The measured tables and indexes reproduce the generated SQLite shapes. The
-- unrelated foreign-key target tables are deliberately omitted: they do not
-- grow as relations are added to the measured rows.
CREATE TABLE person (
  id BLOB PRIMARY KEY,
  scopeId INTEGER,
  name TEXT NOT NULL,
  surname TEXT,
  organizationId BLOB,
  oldCompanyId BLOB,
  cityId BLOB
) STRICT;

CREATE TABLE crdt_data_rows (
  id INTEGER PRIMARY KEY,
  hlcDatetime INTEGER NOT NULL,
  hlcCounter INTEGER NOT NULL,
  scopeId INTEGER NOT NULL,
  tblId INTEGER NOT NULL,
  uuidRowId BLOB NOT NULL,
  nodeId INTEGER NOT NULL,
  visibility INTEGER NOT NULL DEFAULT (0)
) STRICT;

CREATE UNIQUE INDEX crdt_data_rows_scope_tbl_row_idx
ON crdt_data_rows (scopeId, tblId, uuidRowId);

CREATE TABLE crdt_data_fields (
  id INTEGER PRIMARY KEY,
  hlcDatetime INTEGER NOT NULL,
  hlcCounter INTEGER NOT NULL,
  rowId INTEGER NOT NULL,
  columnId INTEGER NOT NULL,
  nodeId INTEGER NOT NULL
) STRICT;

CREATE UNIQUE INDEX crdt_data_fields_row_column_idx
ON crdt_data_fields (rowId, columnId);

CREATE TABLE crdt_data_foreign_key (
  id INTEGER PRIMARY KEY,
  fieldId INTEGER NOT NULL,
  attemptedValue BLOB,
  visibleValue BLOB,
  overrideReason INTEGER
) STRICT;

CREATE UNIQUE INDEX crdt_data_foreign_key_field_idx
ON crdt_data_foreign_key (fieldId);

CREATE TEMP TABLE snapshots (
  stage INTEGER NOT NULL,
  objectName TEXT NOT NULL,
  allocatedBytes INTEGER NOT NULL,
  payloadBytes INTEGER NOT NULL,
  PRIMARY KEY (stage, objectName)
);

VACUUM;
INSERT INTO snapshots
SELECT -1, name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_rows',
  'crdt_data_rows_scope_tbl_row_idx',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx'
)
GROUP BY name;

WITH RECURSIVE sequence(i) AS (
  VALUES (1)
  UNION ALL
  SELECT i + 1 FROM sequence WHERE i < @rows
)
INSERT INTO person (id, name)
SELECT randomblob(16), 'person' FROM sequence;

WITH RECURSIVE sequence(i) AS (
  VALUES (1)
  UNION ALL
  SELECT i + 1 FROM sequence WHERE i < @rows
)
INSERT INTO crdt_data_rows (
  hlcDatetime,
  hlcCounter,
  scopeId,
  tblId,
  uuidRowId,
  nodeId
)
SELECT 1787533200000, 0, 1, 1, randomblob(16), 1 FROM sequence;

VACUUM;
INSERT INTO snapshots
SELECT 0, name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_rows',
  'crdt_data_rows_scope_tbl_row_idx',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx'
)
GROUP BY name;

UPDATE person SET organizationId = zeroblob(16);
INSERT INTO crdt_data_fields (
  hlcDatetime,
  hlcCounter,
  rowId,
  columnId,
  nodeId
)
SELECT 1787533200000, 0, id, 1, 1 FROM crdt_data_rows;

VACUUM;
INSERT INTO snapshots
SELECT 1, name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_rows',
  'crdt_data_rows_scope_tbl_row_idx',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx'
)
GROUP BY name;

UPDATE person SET oldCompanyId = zeroblob(16);
INSERT INTO crdt_data_fields (
  hlcDatetime,
  hlcCounter,
  rowId,
  columnId,
  nodeId
)
SELECT 1787533200000, 0, id, 2, 1 FROM crdt_data_rows;

VACUUM;
INSERT INTO snapshots
SELECT 2, name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_rows',
  'crdt_data_rows_scope_tbl_row_idx',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx'
)
GROUP BY name;

UPDATE person SET cityId = zeroblob(16);
INSERT INTO crdt_data_fields (
  hlcDatetime,
  hlcCounter,
  rowId,
  columnId,
  nodeId
)
SELECT 1787533200000, 0, id, 3, 1 FROM crdt_data_rows;

VACUUM;
INSERT INTO snapshots
SELECT 3, name, SUM(pgsize), SUM(payload)
FROM dbstat
WHERE name IN (
  'person',
  'sqlite_autoindex_person_1',
  'crdt_data_rows',
  'crdt_data_rows_scope_tbl_row_idx',
  'crdt_data_fields',
  'crdt_data_fields_row_column_idx',
  'crdt_data_foreign_key',
  'crdt_data_foreign_key_field_idx'
)
GROUP BY name;

.mode list
.headers off
SELECT '# Relation storage DDL microbenchmark';
SELECT '';
SELECT printf(
  'SQLite %s, %d-byte pages, %,d rows. Measurements follow `VACUUM`.',
  sqlite_version(),
  (SELECT page_size FROM pragma_page_size),
  @rows
);
SELECT '';
SELECT '| Baseline synchronized row | Domain row + PK | CRDT row + index | Total |';
SELECT '| --- | ---: | ---: | ---: |';
WITH baseline AS (
  SELECT
    SUM(CASE WHEN current.objectName IN (
      'person', 'sqlite_autoindex_person_1'
    ) THEN current.allocatedBytes - empty.allocatedBytes ELSE 0 END) domain,
    SUM(CASE WHEN current.objectName IN (
      'crdt_data_rows', 'crdt_data_rows_scope_tbl_row_idx'
    ) THEN current.allocatedBytes - empty.allocatedBytes ELSE 0 END) metadata
  FROM snapshots current
  JOIN snapshots empty ON empty.objectName = current.objectName
  WHERE current.stage = 0 AND empty.stage = -1
)
SELECT printf(
  '| Insert, no populated relations | %.2f B | %.2f B | %.2f B |',
  1.0 * domain / @rows,
  1.0 * metadata / @rows,
  1.0 * (domain + metadata) / @rows
)
FROM baseline;

SELECT '';
SELECT '| Added relation | Domain | Field table + index | FK table + index | CRDT metadata | Focused total |';
SELECT '| ---: | ---: | ---: | ---: | ---: | ---: |';

WITH stage_deltas AS (
  SELECT
    current.stage,
    SUM(CASE WHEN current.objectName IN (
      'person', 'sqlite_autoindex_person_1'
    ) THEN current.allocatedBytes - previous.allocatedBytes ELSE 0 END) domain,
    SUM(CASE WHEN current.objectName IN (
      'crdt_data_fields', 'crdt_data_fields_row_column_idx'
    ) THEN current.allocatedBytes - previous.allocatedBytes ELSE 0 END) field,
    SUM(CASE WHEN current.objectName IN (
      'crdt_data_foreign_key', 'crdt_data_foreign_key_field_idx'
    ) THEN current.allocatedBytes - previous.allocatedBytes ELSE 0 END) foreignKey
  FROM snapshots current
  JOIN snapshots previous
    ON previous.stage = current.stage - 1
   AND previous.objectName = current.objectName
  WHERE current.stage > 0
  GROUP BY current.stage
)
SELECT printf(
  '| %d | %.2f B | %.2f B | %.2f B | %.2f B | %.2f B |',
  stage,
  1.0 * domain / @rows,
  1.0 * field / @rows,
  1.0 * foreignKey / @rows,
  1.0 * (field + foreignKey) / @rows,
  1.0 * (domain + field + foreignKey) / @rows
)
FROM stage_deltas
ORDER BY stage;

SELECT '';
SELECT '| Object | Allocated / relation | Logical payload / relation |';
SELECT '| --- | ---: | ---: |';
WITH object_deltas AS (
  SELECT
    final.objectName,
    final.allocatedBytes - initial.allocatedBytes allocated,
    final.payloadBytes - initial.payloadBytes payload
  FROM snapshots final
  JOIN snapshots initial ON initial.objectName = final.objectName
  WHERE final.stage = 3 AND initial.stage = 0
)
SELECT printf(
  '| `%s` | %.2f B | %.2f B |',
  objectName,
  1.0 * allocated / (3 * @rows),
  1.0 * payload / (3 * @rows)
)
FROM object_deltas
ORDER BY CASE objectName
  WHEN 'person' THEN 1
  WHEN 'sqlite_autoindex_person_1' THEN 2
  WHEN 'crdt_data_rows' THEN 3
  WHEN 'crdt_data_rows_scope_tbl_row_idx' THEN 4
  WHEN 'crdt_data_fields' THEN 5
  WHEN 'crdt_data_fields_row_column_idx' THEN 6
  WHEN 'crdt_data_foreign_key' THEN 7
  WHEN 'crdt_data_foreign_key_field_idx' THEN 8
END;

SELECT '';
WITH totals AS (
  SELECT
    SUM(CASE WHEN final.objectName IN (
      'crdt_data_fields',
      'crdt_data_fields_row_column_idx',
      'crdt_data_foreign_key',
      'crdt_data_foreign_key_field_idx'
    ) THEN final.allocatedBytes - initial.allocatedBytes ELSE 0 END) metadata,
    SUM(CASE WHEN final.objectName IN (
      'crdt_data_fields',
      'crdt_data_fields_row_column_idx',
      'crdt_data_foreign_key',
      'crdt_data_foreign_key_field_idx'
    ) THEN final.payloadBytes - initial.payloadBytes ELSE 0 END) metadataPayload,
    SUM(final.allocatedBytes - initial.allocatedBytes) focused
  FROM snapshots final
  JOIN snapshots initial ON initial.objectName = final.objectName
  WHERE final.stage = 3 AND initial.stage = 0
)
SELECT printf(
  'Mean per populated relation: **%.2f B CRDT metadata**, %.2f B logical metadata payload, **%.2f B focused physical total**.',
  1.0 * metadata / (3 * @rows),
  1.0 * metadataPayload / (3 * @rows),
  1.0 * focused / (3 * @rows)
)
FROM totals;
