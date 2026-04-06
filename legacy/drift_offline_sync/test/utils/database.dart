import 'package:drift/drift.dart';
import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'executor.dart';
import 'tables.dart';
import 'user.dart';
import 'views.dart';

part 'database.g.dart';

/// The test database for the SQLite3 database.
///
/// This is a memory-based SQLite3 database that is used for testing. It follows
/// the same pattern as the `test_descriptor` package to ensure one database is
/// created for each test. The database is closed once test ends.
TodoDb get database {
  if (_database != null) return _database!;

  final database = TodoDb(testExecutor);
  _database = database;

  addTearDown(() async {
    final database = _database!;
    _database = null;
    await database.close();
  });

  return database;
}

TodoDb? _database;

@DriftDatabase(
  tables: [
    TodosTable,
    Categories,
    Users,
    SharedTodos,
    TableWithoutPK,
    PureDefaults,
    WithCustomType,
    TableWithEveryColumnType,
    Department,
    Product,
    Listing,
    Store,
  ],
  views: [
    CategoryTodoCountView,
    TodoWithCategoryView,
  ],
  daos: [SomeDao],
  queries: {
    'allTodosWithCategory':
        'SELECT t.*, c.id as catId, c."desc" as catDesc '
        'FROM todos t INNER JOIN categories c ON c.id = t.category',
    'deleteTodoById': 'DELETE FROM todos WHERE id = ?',
    'withIn': 'SELECT * FROM todos WHERE title = ?2 OR id IN ? OR title = ?1',
    'search': 'SELECT * FROM todos WHERE CASE WHEN -1 = :id THEN 1 ELSE id = :id END',
    'findCustom': 'SELECT custom FROM table_without_p_k WHERE some_float < 10',
  },
)
class TodoDb extends _$TodoDb {
  TodoDb(super.e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int schemaVersion = 1;

  // This is what needs to be added to the user database class to make it CRDT aware.
  @override
  OfflineSyncMigrator createMigrator() => OfflineSyncMigrator(
    this,
    userId: testUserId,
    nodeId: testNodeId,
    synchronizedTables: [
      todosTable,
      categories,
      users,
      sharedTodos,
      // tableWithoutPK,
      pureDefaults,
      // withCustomType,
      tableWithEveryColumnType,
      department,
      // product,
    ],
    excludeTables: [
      listing,
      product,
      store,
      tableWithoutPK,
      withCustomType,
    ],
  );
}

@DriftAccessor(
  tables: [Users, SharedTodos, TodosTable],
  views: [TodoWithCategoryView],
  queries: {
    'todosForUser':
        'SELECT t.* FROM todos t '
        'INNER JOIN shared_todos st ON st.todo = t.id '
        'INNER JOIN users u ON u.id = st.user '
        'WHERE u.id = :user',
  },
)
class SomeDao extends DatabaseAccessor<TodoDb> with _$SomeDaoMixin {
  SomeDao(super.attachedDatabase);
}
