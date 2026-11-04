import 'package:serverpod_database/serverpod_database.dart';

import '../crdt/extensions.dart';
import '../generated/protocol.dart';

/// SQLite's update hook only reports table names. Keep a transactional revision
/// per tracked table so shared metadata writes can report their actual owners.
/// Revisions also discard notifications left over from rolled back savepoints.
/// This SQLite-local table is initialized alongside the CRDT registry, is never
/// synced, and holds one counter per table rather than a growing change log.
const visibleChangesTable = '_offline_sync_visible_changes';

/// Installs the SQLite-local change journal as part of schema initialization.
/// SQL triggers keep revisions in the writer's transaction, including caller-
/// owned transactions for which Serverpod exposes no post-commit callback.
Future<void> installVisibleChanges(Database db, Iterable<Table> tables) async {
  if (db.dialect != DatabaseDialect.sqlite) return;

  await db.transaction((tx) async {
    await db.unsafeExecute('''
CREATE TABLE IF NOT EXISTS "$visibleChangesTable" (
  "tableName" TEXT PRIMARY KEY NOT NULL,
  "revision" INTEGER NOT NULL DEFAULT 0
)
''', transaction: tx);

    for (final table in tables) {
      final name = table.tableName;
      final literal = _literal(name);
      await db.unsafeExecute(
        'INSERT OR IGNORE INTO "$visibleChangesTable" ("tableName") VALUES ($literal)',
        transaction: tx,
      );

      // These triggers cover recorder writes and materialized merge projections,
      // including writes made through another wrapper on the same database.
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        // A migration may have added columns since the last initialization.
        // Refresh the UPDATE comparison from the current generated schema.
        if (operation == 'UPDATE') {
          await db.unsafeExecute(
            'DROP TRIGGER IF EXISTS ${_identifier('${visibleChangesTable}_${name}_$operation')}',
            transaction: tx,
          );
        }
        final changed = operation == 'UPDATE'
            ? 'WHEN ${table.columns.map((c) => 'OLD.${_identifier(c.columnName)} IS NOT NEW.${_identifier(c.columnName)}').join(' OR ')}'
            : '';
        await db.unsafeExecute('''
CREATE TRIGGER IF NOT EXISTS ${_identifier('${visibleChangesTable}_${name}_$operation')}
AFTER $operation ON ${_identifier(name)} $changed
BEGIN
  UPDATE "$visibleChangesTable" SET "revision" = "revision" + 1
  WHERE "tableName" = $literal;
END
''', transaction: tx);
      }
    }

    final rows = _identifier(CrdtDataRow.t.tableName);
    final schema = _identifier(CrdtSchemaTable.t.tableName);
    final members = _identifier(OfflineSyncSpaceMember.t.tableName);
    final spaces = _identifier(OfflineSyncSpace.t.tableName);
    final hidden = crdtRowLastVisibleVisibilityIndex;

    // Clock updates do not change visibility. Deletes and FK cascade/restrict
    // projections do, even when the domain row is never physically written.
    for (final (operation, condition, references) in [
      ('INSERT', 'NEW."visibility" > $hidden', ['NEW']),
      ('DELETE', 'OLD."visibility" > $hidden', ['OLD']),
      (
        'UPDATE',
        '(OLD."visibility" > $hidden) IS NOT (NEW."visibility" > $hidden) '
            'OR OLD."tblId" IS NOT NEW."tblId" '
            'OR OLD."spaceId" IS NOT NEW."spaceId" '
            'OR OLD."uuidRowId" IS NOT NEW."uuidRowId"',
        ['OLD', 'NEW'],
      ),
    ]) {
      await db.unsafeExecute('''
CREATE TRIGGER IF NOT EXISTS "${visibleChangesTable}_visibility_$operation"
AFTER $operation ON $rows WHEN $condition
BEGIN
  UPDATE "$visibleChangesTable" SET "revision" = "revision" + 1
  WHERE "tableName" IN (
    SELECT "name" FROM $schema
    WHERE "id" IN (${references.map((r) => '$r."tblId"').join(', ')})
  );
END
''', transaction: tx);
    }

    // Repeated announcements and role-only changes leave readable rows alone.
    // Restrict grants/revocations to tables present in the affected space.
    for (final (operation, condition, references) in [
      ('INSERT', '', ['NEW']),
      ('DELETE', '', ['OLD']),
      (
        'UPDATE',
        'WHEN OLD."spaceId" IS NOT NEW."spaceId" '
            'OR OLD."userUuid" IS NOT NEW."userUuid"',
        ['OLD', 'NEW'],
      ),
    ]) {
      final affected = references
          .map(
            (r) =>
                '''
SELECT s."name" FROM $schema s
JOIN $rows r ON r."tblId" = s."id"
JOIN $spaces p ON p."id" = r."spaceId"
WHERE r."spaceId" = $r."spaceId" AND p."uuidSpaceId" IS NOT $r."userUuid"
''',
          )
          .join(' UNION ');
      await db.unsafeExecute('''
CREATE TRIGGER IF NOT EXISTS "${visibleChangesTable}_membership_$operation"
AFTER $operation ON $members $condition
BEGIN
  UPDATE "$visibleChangesTable" SET "revision" = "revision" + 1
  WHERE "tableName" IN ($affected);
END
''', transaction: tx);
    }
  });
}

String _identifier(String value) => '"${value.replaceAll('"', '""')}"';

String _literal(String value) => "'${value.replaceAll("'", "''")}'";

/// A small snapshot, independent of the number of domain or CRDT rows.
Stream<Map<String, int>> visibleTableRevisions(
  Database db,
  Iterable<String> tables, {
  Duration? throttle,
}) => db
    .unsafeWatch(
      'SELECT "tableName", "revision" FROM "$visibleChangesTable" '
      'WHERE "tableName" IN (${tables.map(_literal).join(', ')})',
      triggerOnTables: [visibleChangesTable],
      throttle: throttle,
    )
    .map((rows) => {for (final row in rows) row[0] as String: row[1] as int})
    .distinct(
      (a, b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value),
    );
