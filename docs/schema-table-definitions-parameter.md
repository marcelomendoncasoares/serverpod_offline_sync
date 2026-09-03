# `CrdtSchemaRegistry.tableDefinitions` should replace, not overlay

Status: **pending fix — the overlay is currently in place.**

## What changed

`CrdtSchemaRegistry` used to let the caller **replace** the ambient schema:

```dart
final tableDefinitionsByName = {
  for (final tableDefinition
      in tableDefinitions ??
          _session.db.serializationManager.getTargetTableDefinitions())
    tableDefinition.name: tableDefinition,
};
```

It now **overlays** the caller's definitions on top of the ambient ones, and
requires every synced table to resolve to one:

```dart
_tableDefinitionsByName = {
  for (final tableDefinition
      in _session.db.serializationManager.getTargetTableDefinitions())
    tableDefinition.name: tableDefinition,
  for (final tableDefinition in tableDefinitions ?? const <TableDefinition>[])
    tableDefinition.name: tableDefinition,
};
// ... throws StateError when a synced table has no definition
```

## Why it happened

The missing-definition check is correct and should stay: persisted type identity
needs a `ColumnDefinition` per column, and without one `CrdtSchemaColumn` would
be written with an empty `columnType` and `dartType`.

But four test call sites pass fewer definitions than synced tables and relied on
replace semantics to leave the rest unresolved. Under replace plus the new
check, they would throw. The overlay keeps them working.

So the overlay exists to accommodate partially specified test fixtures, not a
production requirement.

## Production cannot tell the difference

There is exactly one production construction, `CrdtDatabaseContext._loadSchema`:

```dart
CrdtDatabaseContext({..., required DatabaseSerializationManager serializationManager})
    : _tableDefinitions = serializationManager.getTargetTableDefinitions();
...
CrdtSchemaRegistry(session, syncTables: syncTables, tableDefinitions: _tableDefinitions)
```

That manager is `delegate.serializationManager`, and the old fallback was
`_session.db.serializationManager`, where `CrdtDatabase.serializationManager`
returns the delegate's. Both resolve to the same list, so production always
passed exactly what the fallback would have produced.

## What the overlay costs

Of 19 test constructions:

- 14 pass one table and one crafted definition for it. The crafted definition
  still wins under the overlay, so these are unaffected.
- 1 (`_uuidPkRegistry`) uses tables absent from the real schema, so the extra
  ambient definitions are never iterated.
- 4 pass fewer definitions than synced tables and lose their isolation:

  | Line | `syncTables` | `tableDefinitions` |
  | --- | --- | --- |
  | 169 | `Town.t, City.t, Person.t` | `fkOnlyDefinition` |
  | 291 | `Address.t, Person.t` | `requiredForeignKeyDefinition` |
  | 344 | `Town.t, City.t, Person.t` | `requiredForeignKeyDefinition` |
  | 389 | `Address.t, Person.t` | `mixedUniqueDefinition` |

  Line 344 asserts the error names exactly `"town.cityId"`. It used to be
  isolated by construction, because `City` and `Person` resolved to `null` and
  the validators skipped them. Now those tables contribute their real
  definitions, so the same validators walk their real foreign keys and unique
  indexes. The test still passes only because those tables happen to be clean.

The overlay also removes a capability: a caller can substitute a definition but
can no longer exclude one, so validating against a hypothetical schema — a
proposed migration, say — is no longer expressible.

## Fix

Restore replace semantics and keep the missing-definition check, then give the
four partial call sites the real definitions for the tables they do not craft.
Production is unaffected because it already passes the full list.

If the overlay is kept instead, rename the parameter to
`tableDefinitionOverrides` and document it, because nothing currently states
which of the two it means.
