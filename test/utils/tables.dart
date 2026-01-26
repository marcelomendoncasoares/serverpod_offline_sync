// TODO: Add a note with Drift LICENSE in this file, since it is mostly a copy
// of the Drift example tables.
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'types.dart';

export 'types.dart';

extension type RowId._(int id) {
  const RowId(this.id);
}

mixin AutoIncrement on Table {
  late final id = integer().autoIncrement().map(
    TypeConverter.extensionType<RowId, int>(),
  )();
}

@DataClassName('TodoEntry')
class TodosTable extends Table with AutoIncrement {
  @override
  String get tableName => 'todos';

  late final title = text().withLength(min: 4, max: 16).nullable()();
  late final content = text()();
  @JsonKey('target_date')
  late final targetDate = dateTime().nullable().unique()();
  @ReferenceName('todos')
  late final category = integer()
      .references(Categories, #id, initiallyDeferred: true)
      .map(TypeConverter.extensionType<RowId, int>())
      .nullable()();

  late final status = textEnum<TodoStatus>().nullable()();

  @override
  List<Set<Column>>? get uniqueKeys => [
    {title, category},
    {title, targetDate},
  ];
}

enum TodoStatus { open, workInProgress, done }

class Users extends Table with AutoIncrement {
  late final name = text().withLength(min: 6, max: 32).unique()();
  late final isAwesome = boolean().withDefault(const Constant(true))();

  late final profilePicture = blob()();
  late final DateTimeColumn creationTime = dateTime()
      .check(creationTime.isBiggerThan(Constant(DateTime.utc(1950))))
      .withDefault(currentDateAndTime)();
}

@DataClassName('Category')
class Categories extends Table with AutoIncrement {
  late final description = text().named('desc').customConstraint('NOT NULL UNIQUE')();
  late final priority = intEnum<CategoryPriority>().withDefault(const Constant(0))();

  late final descriptionInUpperCase = text().generatedAs(description.upper())();
}

enum CategoryPriority { low, medium, high }

class SharedTodos extends Table {
  late final todo = integer()();
  late final user = integer()();

  @override
  Set<Column> get primaryKey => {todo, user};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (todo) REFERENCES todos(id)',
    'FOREIGN KEY (user) REFERENCES users(id)',
  ];
}

@UseRowClass(CustomRowClass, constructor: 'map', generateInsertable: true)
class TableWithoutPK extends Table {
  IntColumn get notReallyAnId => integer()();
  RealColumn get someFloat => real()();
  Int64Column get webSafeInt => int64().nullable()();

  TextColumn get custom =>
      text().map(const CustomConverter()).clientDefault(const Uuid().v4)();
}

class TableWithEveryColumnType extends Table with AutoIncrement {
  BoolColumn get aBool => boolean().nullable()();
  DateTimeColumn get aDateTime => dateTime().nullable()();
  TextColumn get aText => text().nullable()();
  IntColumn get anInt => integer().nullable()();
  Int64Column get anInt64 => int64().nullable()();
  RealColumn get aReal => real().nullable()();
  BlobColumn get aBlob => blob().nullable()();
  IntColumn get anIntEnum => intEnum<TodoStatus>().nullable()();
  TextColumn get aTextWithConverter =>
      text().named('insert').map(const CustomJsonConverter()).nullable()();
  Column<UuidValue> get aUuid => customType(uuidType).nullable()();
}

class Department extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
}

class Product extends Table {
  TextColumn get sku => text()();
  TextColumn get name => text().nullable()();
  IntColumn get department => integer().references(Department, #id).nullable()();
}

class Listing extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('listings')
  TextColumn get product => text().references(Product, #sku)();
  @ReferenceName('listings')
  IntColumn get store => integer().references(Store, #id).nullable()();
  RealColumn get price => real().nullable()();
}

class Store extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
}

class PureDefaults extends Table {
  // name after keyword to ensure it's escaped properly
  TextColumn get txt =>
      text().named('insert').map(const CustomJsonConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {txt};
}

class WithCustomType extends Table {
  Column<UuidValue> get id => customType(uuidType)();
}
