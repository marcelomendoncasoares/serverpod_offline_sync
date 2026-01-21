import 'package:drift/drift.dart';

import 'tables.dart';

abstract class CategoryTodoCountView extends View {
  TodosTable get todos;
  Categories get categories;

  Expression<int> get categoryId => categories.id;
  Expression<String> get description => categories.description + const Variable('!');
  Expression<int> get itemCount => todos.id.count();

  @override
  Query as() => select([categoryId, description, itemCount])
      .from(categories)
      .join([innerJoin(todos, todos.category.equalsExp(categories.id))])
    ..groupBy([categories.id]);
}

abstract class TodoWithCategoryView extends View {
  TodosTable get todos;
  Categories get categories;

  @override
  Query as() => select([todos.title, categories.description])
      .from(todos)
      .join([innerJoin(categories, categories.id.equalsExp(todos.category))]);
}
