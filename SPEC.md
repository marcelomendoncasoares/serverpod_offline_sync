# Specification for the implementation

## Starting the database

- After the `createAll()`, call a custom function to inspect the database and
  list:
  - Each table unique constraints
  - All foreign keys

Check
[this research](https://www.perplexity.ai/search/on-drift-for-flutter-after-all-aaj9LV1QTeSST3brpolEMA)
for reference.

## How to specify which constraint to apply to each case?

Unique can be handled as:

- on_conflict_merge (default)
- on_conflict_overwrite

Foreign keys can be handled as:

- on_fk_deleted_delete_this (default, if cascade delete)
- on_fk_deleted_set_null (default, if optional)
- on_fk_deleted_restore_related

## After merge on sync, a callback must be available to check custom rules

There must have an easy way to issue fixes and re-run the merge.

## Next:

- [ ] Design the registration of constraints in the database.
- [ ] Integrate the CRDT for retrieval of changes.
- [ ] Integrate the CRDT merge logic.
- [ ] Integrate the compensation logic with the merge logic.
- [ ] Implement a regenerate process to run after migrations.
- [ ] Add pending tests marked as TODO.
- [ ] Transform this repo in a monorepo with this package and a Flutter version
      that provides a custom `driftDatabase` function that already passes the
      closure to add the `next_hlc_timestamp` function to the database.
