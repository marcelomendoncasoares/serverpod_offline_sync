UPDATE crdt_metadata
SET `value` = d.`value`
FROM crdt_metadata AS s
JOIN (
  -- Set multiple fields of the entities that match the where clause
  SELECT '__is_deleted__' AS `column`, 'TRUE' AS `value`
  UNION ALL
  SELECT 'reference_id', NULL;
) AS d ON s.`column` = d.`column`
WHERE (
  `table` = 'category' AND
  `column` = 'parent_id' AND
  `value` = 'THIS_ENTITY_ROW_ID'
);


INSERT INTO crdt_metadata ("table", "column", "value")
SELECT
  'category'            AS "table",
  d."column"            AS "column",
  d."value"             AS "value"
FROM (
  SELECT '__is_deleted__' AS "column", 'TRUE' AS "value"
  UNION ALL
  SELECT 'reference_id', NULL
) AS d
ON CONFLICT("table", "column") DO UPDATE
SET "value" = EXCLUDED."value";

INSERT INTO crdt_metadata ("table", "column", "value")
VALUES
  ('category', '__is_deleted__', 'TRUE'),
  ('category', 'reference_id', NULL)
ON CONFLICT("table", "column") DO UPDATE
SET "value" = excluded."value";


INSERT INTO __crdt_data (
  'user_id',
  'table_name',
  'column_name',
  'row_id',
  'hlc_timestamp',
  'raw_value',
  'value_changed'
)
VALUES
  (?, 'category', '__is_deleted__', ?, ?, ?, 1),
  (?, 'category', 'reference_id', ?, ?, ?, 1)
ON CONFLICT ('user_id', 'table_name', 'column_name', 'row_id') DO UPDATE
SET
  'hlc_timestamp' = excluded.'hlc_timestamp',
  'raw_value'     = excluded.'raw_value',
  'value_changed' = excluded.'value_changed';



WITH hlc AS (SELECT $nextHlcFunction() AS ts)
INSERT INTO __crdt_data (
  'table_name', 'column_name', 'row_id', 'hlc_timestamp', 'raw_value', 'value_changed'
)
SELECT
  '$table_name', d.'column_name', OLD.'$id_field', hlc.ts, d.'raw_value', d.'value_changed'
FROM (
  SELECT
    '$column_name' AS 'column_name',
    '?1' AS 'row_id',
    '?2' AS 'raw_value',
    'TRUE' AS 'value_changed'
) as d, hlc
ON CONFLICT ('table_name', 'column_name', 'row_id') DO UPDATE
SET
  'hlc_timestamp' = excluded.'hlc_timestamp',
  'raw_value'     = excluded.'raw_value',
  'value_changed' = excluded.'value_changed';


CREATE TRIGGER my_trigger
AFTER INSERT ON '$table_name'
BEGIN
  INSERT INTO __crdt_data (
    'table_name', 'column_name', 'row_id', 'hlc_timestamp', 'raw_value', 'value_changed'
  )
  SELECT * FROM (
    WITH hlc AS (SELECT $nextHlcFunction() AS ts)
    SELECT
      '$table_name' AS 'table_name',
      '$column_name' AS 'column_name',
      OLD.'$id_field' AS 'row_id',
      hlc.ts AS 'hlc_timestamp',
      NEW.'$column_name' AS 'raw_value',
      NEW.'$column_name' IS NOT OLD.'$column_name' AS 'value_changed'
    FROM hlc
    UNION ALL
    [repeat for each column]
  )
  WHERE NEW.'$column_name' IS NOT OLD.'$column_name';
END;
