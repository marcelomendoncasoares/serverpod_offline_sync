// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'migration.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<RowId, int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  ).withConverter<RowId>($CategoriesTable.$converterid);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'desc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryPriority, int> priority =
      GeneratedColumn<int>(
        'priority',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<CategoryPriority>($CategoriesTable.$converterpriority);
  static const VerificationMeta _descriptionInUpperCaseMeta = const VerificationMeta(
    'descriptionInUpperCase',
  );
  @override
  late final GeneratedColumn<String> descriptionInUpperCase = GeneratedColumn<String>(
    'description_in_upper_case',
    aliasedName,
    false,
    generatedAs: GeneratedAs(
      StringExpressionOperators(description).upper(),
      false,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    description,
    priority,
    descriptionInUpperCase,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('desc')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['desc']!, _descriptionMeta),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('description_in_upper_case')) {
      context.handle(
        _descriptionInUpperCaseMeta,
        descriptionInUpperCase.isAcceptableOrUnknown(
          data['description_in_upper_case']!,
          _descriptionInUpperCaseMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: $CategoriesTable.$converterid.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}id'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}desc'],
      )!,
      priority: $CategoriesTable.$converterpriority.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}priority'],
        )!,
      ),
      descriptionInUpperCase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description_in_upper_case'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RowId, int, int> $converterid =
      TypeConverter.extensionType<RowId, int>();
  static JsonTypeConverter2<CategoryPriority, int, int> $converterpriority =
      const EnumIndexConverter<CategoryPriority>(CategoryPriority.values);
}

class Category extends DataClass implements Insertable<Category> {
  final RowId id;
  final String description;
  final CategoryPriority priority;
  final String descriptionInUpperCase;
  const Category({
    required this.id,
    required this.description,
    required this.priority,
    required this.descriptionInUpperCase,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['id'] = Variable<int>($CategoriesTable.$converterid.toSql(id));
    }
    map['desc'] = Variable<String>(description);
    {
      map['priority'] = Variable<int>(
        $CategoriesTable.$converterpriority.toSql(priority),
      );
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      description: Value(description),
      priority: Value(priority),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: $CategoriesTable.$converterid.fromJson(
        serializer.fromJson<int>(json['id']),
      ),
      description: serializer.fromJson<String>(json['desc']),
      priority: $CategoriesTable.$converterpriority.fromJson(
        serializer.fromJson<int>(json['priority']),
      ),
      descriptionInUpperCase: serializer.fromJson<String>(
        json['description_in_upper_case'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>($CategoriesTable.$converterid.toJson(id)),
      'desc': serializer.toJson<String>(description),
      'priority': serializer.toJson<int>(
        $CategoriesTable.$converterpriority.toJson(priority),
      ),
      'description_in_upper_case': serializer.toJson<String>(
        descriptionInUpperCase,
      ),
    };
  }

  Category copyWith({
    RowId? id,
    String? description,
    CategoryPriority? priority,
    String? descriptionInUpperCase,
  }) => Category(
    id: id ?? this.id,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    descriptionInUpperCase: descriptionInUpperCase ?? this.descriptionInUpperCase,
  );
  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('descriptionInUpperCase: $descriptionInUpperCase')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, description, priority, descriptionInUpperCase);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.descriptionInUpperCase == this.descriptionInUpperCase);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<RowId> id;
  final Value<String> description;
  final Value<CategoryPriority> priority;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String description,
    this.priority = const Value.absent(),
  }) : description = Value(description);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? description,
    Expression<int>? priority,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (description != null) 'desc': description,
      if (priority != null) 'priority': priority,
    });
  }

  CategoriesCompanion copyWith({
    Value<RowId>? id,
    Value<String>? description,
    Value<CategoryPriority>? priority,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      description: description ?? this.description,
      priority: priority ?? this.priority,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>($CategoriesTable.$converterid.toSql(id.value));
    }
    if (description.present) {
      map['desc'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(
        $CategoriesTable.$converterpriority.toSql(priority.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('description: $description, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }
}

class $TodosTableTable extends TodosTable with TableInfo<$TodosTableTable, TodoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTableTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<RowId, int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  ).withConverter<RowId>($TodosTableTable.$converterid);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 4,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RowId?, int> category =
      GeneratedColumn<int>(
        'category',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES categories (id) DEFERRABLE INITIALLY DEFERRED',
        ),
      ).withConverter<RowId?>($TodosTableTable.$convertercategoryn);
  @override
  late final GeneratedColumnWithTypeConverter<TodoStatus?, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TodoStatus?>($TodosTableTable.$converterstatusn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    targetDate,
    category,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {title, category},
    {title, targetDate},
  ];
  @override
  TodoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoEntry(
      id: $TodosTableTable.$converterid.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}id'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      category: $TodosTableTable.$convertercategoryn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}category'],
        ),
      ),
      status: $TodosTableTable.$converterstatusn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        ),
      ),
    );
  }

  @override
  $TodosTableTable createAlias(String alias) {
    return $TodosTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RowId, int, int> $converterid =
      TypeConverter.extensionType<RowId, int>();
  static JsonTypeConverter2<RowId, int, int> $convertercategory =
      TypeConverter.extensionType<RowId, int>();
  static JsonTypeConverter2<RowId?, int?, int?> $convertercategoryn =
      JsonTypeConverter2.asNullable($convertercategory);
  static JsonTypeConverter2<TodoStatus, String, String> $converterstatus =
      const EnumNameConverter<TodoStatus>(TodoStatus.values);
  static JsonTypeConverter2<TodoStatus?, String?, String?> $converterstatusn =
      JsonTypeConverter2.asNullable($converterstatus);
}

class TodoEntry extends DataClass implements Insertable<TodoEntry> {
  final RowId id;
  final String? title;
  final String content;
  final DateTime? targetDate;
  final RowId? category;
  final TodoStatus? status;
  const TodoEntry({
    required this.id,
    this.title,
    required this.content,
    this.targetDate,
    this.category,
    this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['id'] = Variable<int>($TodosTableTable.$converterid.toSql(id));
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<int>(
        $TodosTableTable.$convertercategoryn.toSql(category),
      );
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(
        $TodosTableTable.$converterstatusn.toSql(status),
      );
    }
    return map;
  }

  TodosTableCompanion toCompanion(bool nullToAbsent) {
    return TodosTableCompanion(
      id: Value(id),
      title: title == null && nullToAbsent ? const Value.absent() : Value(title),
      content: Value(content),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      status: status == null && nullToAbsent ? const Value.absent() : Value(status),
    );
  }

  factory TodoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoEntry(
      id: $TodosTableTable.$converterid.fromJson(
        serializer.fromJson<int>(json['id']),
      ),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      targetDate: serializer.fromJson<DateTime?>(json['target_date']),
      category: $TodosTableTable.$convertercategoryn.fromJson(
        serializer.fromJson<int?>(json['category']),
      ),
      status: $TodosTableTable.$converterstatusn.fromJson(
        serializer.fromJson<String?>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>($TodosTableTable.$converterid.toJson(id)),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String>(content),
      'target_date': serializer.toJson<DateTime?>(targetDate),
      'category': serializer.toJson<int?>(
        $TodosTableTable.$convertercategoryn.toJson(category),
      ),
      'status': serializer.toJson<String?>(
        $TodosTableTable.$converterstatusn.toJson(status),
      ),
    };
  }

  TodoEntry copyWith({
    RowId? id,
    Value<String?> title = const Value.absent(),
    String? content,
    Value<DateTime?> targetDate = const Value.absent(),
    Value<RowId?> category = const Value.absent(),
    Value<TodoStatus?> status = const Value.absent(),
  }) => TodoEntry(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    content: content ?? this.content,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    category: category.present ? category.value : this.category,
    status: status.present ? status.value : this.status,
  );
  TodoEntry copyWithCompanion(TodosTableCompanion data) {
    return TodoEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      targetDate: data.targetDate.present ? data.targetDate.value : this.targetDate,
      category: data.category.present ? data.category.value : this.category,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('targetDate: $targetDate, ')
          ..write('category: $category, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, content, targetDate, category, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.targetDate == this.targetDate &&
          other.category == this.category &&
          other.status == this.status);
}

class TodosTableCompanion extends UpdateCompanion<TodoEntry> {
  final Value<RowId> id;
  final Value<String?> title;
  final Value<String> content;
  final Value<DateTime?> targetDate;
  final Value<RowId?> category;
  final Value<TodoStatus?> status;
  const TodosTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.category = const Value.absent(),
    this.status = const Value.absent(),
  });
  TodosTableCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    required String content,
    this.targetDate = const Value.absent(),
    this.category = const Value.absent(),
    this.status = const Value.absent(),
  }) : content = Value(content);
  static Insertable<TodoEntry> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<DateTime>? targetDate,
    Expression<int>? category,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (targetDate != null) 'target_date': targetDate,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
    });
  }

  TodosTableCompanion copyWith({
    Value<RowId>? id,
    Value<String?>? title,
    Value<String>? content,
    Value<DateTime?>? targetDate,
    Value<RowId?>? category,
    Value<TodoStatus?>? status,
  }) {
    return TodosTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>($TodosTableTable.$converterid.toSql(id.value));
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(
        $TodosTableTable.$convertercategoryn.toSql(category.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TodosTableTable.$converterstatusn.toSql(status.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('targetDate: $targetDate, ')
          ..write('category: $category, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

abstract class _$FirstDb extends GeneratedDatabase {
  _$FirstDb(QueryExecutor e) : super(e);
  $FirstDbManager get managers => $FirstDbManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TodosTableTable todosTable = $TodosTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [categories, todosTable];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<RowId> id,
      required String description,
      Value<CategoryPriority> priority,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<RowId> id,
      Value<String> description,
      Value<CategoryPriority> priority,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$FirstDb, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodosTableTable, List<TodoEntry>> _todosTable(
    _$FirstDb db,
  ) => MultiTypedResultKey.fromTable(
    db.todosTable,
    aliasName: $_aliasNameGenerator(db.categories.id, db.todosTable.category),
  );

  $$TodosTableTableProcessedTableManager get todos {
    final manager = $$TodosTableTableTableManager(
      $_db,
      $_db.todosTable,
    ).filter((f) => f.category.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_todosTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer extends Composer<_$FirstDb, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<RowId, RowId, int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryPriority, CategoryPriority, int>
  get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get descriptionInUpperCase => $composableBuilder(
    column: $table.descriptionInUpperCase,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todos(
    Expression<bool> Function($$TodosTableTableFilterComposer f) f,
  ) {
    final $$TodosTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todosTable,
      getReferencedColumn: (t) => t.category,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableTableFilterComposer(
            $db: $db,
            $table: $db.todosTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer extends Composer<_$FirstDb, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionInUpperCase => $composableBuilder(
    column: $table.descriptionInUpperCase,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$FirstDb, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<RowId, int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CategoryPriority, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get descriptionInUpperCase => $composableBuilder(
    column: $table.descriptionInUpperCase,
    builder: (column) => column,
  );

  Expression<T> todos<T extends Object>(
    Expression<T> Function($$TodosTableTableAnnotationComposer a) f,
  ) {
    final $$TodosTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todosTable,
      getReferencedColumn: (t) => t.category,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableTableAnnotationComposer(
            $db: $db,
            $table: $db.todosTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$FirstDb,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool todos})
        > {
  $$CategoriesTableTableManager(_$FirstDb db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<CategoryPriority> priority = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                description: description,
                priority: priority,
              ),
          createCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                required String description,
                Value<CategoryPriority> priority = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                description: description,
                priority: priority,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todos = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todos) db.todosTable],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todos)
                    await $_getPrefetchedData<Category, $CategoriesTable, TodoEntry>(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences._todosTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).todos,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.category == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FirstDb,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool todos})
    >;
typedef $$TodosTableTableCreateCompanionBuilder =
    TodosTableCompanion Function({
      Value<RowId> id,
      Value<String?> title,
      required String content,
      Value<DateTime?> targetDate,
      Value<RowId?> category,
      Value<TodoStatus?> status,
    });
typedef $$TodosTableTableUpdateCompanionBuilder =
    TodosTableCompanion Function({
      Value<RowId> id,
      Value<String?> title,
      Value<String> content,
      Value<DateTime?> targetDate,
      Value<RowId?> category,
      Value<TodoStatus?> status,
    });

final class $$TodosTableTableReferences
    extends BaseReferences<_$FirstDb, $TodosTableTable, TodoEntry> {
  $$TodosTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryTable(_$FirstDb db) => db.categories.createAlias(
    $_aliasNameGenerator(db.todosTable.category, db.categories.id),
  );

  $$CategoriesTableProcessedTableManager? get category {
    final $_column = $_itemColumn<int>('category');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TodosTableTableFilterComposer extends Composer<_$FirstDb, $TodosTableTable> {
  $$TodosTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<RowId, RowId, int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TodoStatus?, TodoStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$CategoriesTableFilterComposer get category {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.category,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodosTableTableOrderingComposer extends Composer<_$FirstDb, $TodosTableTable> {
  $$TodosTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get category {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.category,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodosTableTableAnnotationComposer
    extends Composer<_$FirstDb, $TodosTableTable> {
  $$TodosTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<RowId, int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TodoStatus?, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get category {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.category,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodosTableTableTableManager
    extends
        RootTableManager<
          _$FirstDb,
          $TodosTableTable,
          TodoEntry,
          $$TodosTableTableFilterComposer,
          $$TodosTableTableOrderingComposer,
          $$TodosTableTableAnnotationComposer,
          $$TodosTableTableCreateCompanionBuilder,
          $$TodosTableTableUpdateCompanionBuilder,
          (TodoEntry, $$TodosTableTableReferences),
          TodoEntry,
          PrefetchHooks Function({bool category})
        > {
  $$TodosTableTableTableManager(_$FirstDb db, $TodosTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<RowId?> category = const Value.absent(),
                Value<TodoStatus?> status = const Value.absent(),
              }) => TodosTableCompanion(
                id: id,
                title: title,
                content: content,
                targetDate: targetDate,
                category: category,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String content,
                Value<DateTime?> targetDate = const Value.absent(),
                Value<RowId?> category = const Value.absent(),
                Value<TodoStatus?> status = const Value.absent(),
              }) => TodosTableCompanion.insert(
                id: id,
                title: title,
                content: content,
                targetDate: targetDate,
                category: category,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodosTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({category = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (category) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.category,
                                referencedTable: $$TodosTableTableReferences
                                    ._categoryTable(db),
                                referencedColumn: $$TodosTableTableReferences
                                    ._categoryTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TodosTableTableProcessedTableManager =
    ProcessedTableManager<
      _$FirstDb,
      $TodosTableTable,
      TodoEntry,
      $$TodosTableTableFilterComposer,
      $$TodosTableTableOrderingComposer,
      $$TodosTableTableAnnotationComposer,
      $$TodosTableTableCreateCompanionBuilder,
      $$TodosTableTableUpdateCompanionBuilder,
      (TodoEntry, $$TodosTableTableReferences),
      TodoEntry,
      PrefetchHooks Function({bool category})
    >;

class $FirstDbManager {
  final _$FirstDb _db;
  $FirstDbManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TodosTableTableTableManager get todosTable =>
      $$TodosTableTableTableManager(_db, _db.todosTable);
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<RowId, int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  ).withConverter<RowId>($UsersTable.$converterid);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 6,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isAwesomeMeta = const VerificationMeta(
    'isAwesome',
  );
  @override
  late final GeneratedColumn<bool> isAwesome = GeneratedColumn<bool>(
    'is_awesome',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("is_awesome" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _profilePictureMeta = const VerificationMeta(
    'profilePicture',
  );
  @override
  late final GeneratedColumn<Uint8List> profilePicture = GeneratedColumn<Uint8List>(
    'profile_picture',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creationTimeMeta = const VerificationMeta(
    'creationTime',
  );
  @override
  late final GeneratedColumn<DateTime> creationTime = GeneratedColumn<DateTime>(
    'creation_time',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(creationTime).isBiggerThan(Constant(DateTime.utc(1950))),
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isAwesome,
    profilePicture,
    creationTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_awesome')) {
      context.handle(
        _isAwesomeMeta,
        isAwesome.isAcceptableOrUnknown(data['is_awesome']!, _isAwesomeMeta),
      );
    }
    if (data.containsKey('profile_picture')) {
      context.handle(
        _profilePictureMeta,
        profilePicture.isAcceptableOrUnknown(
          data['profile_picture']!,
          _profilePictureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profilePictureMeta);
    }
    if (data.containsKey('creation_time')) {
      context.handle(
        _creationTimeMeta,
        creationTime.isAcceptableOrUnknown(
          data['creation_time']!,
          _creationTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: $UsersTable.$converterid.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}id'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isAwesome: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_awesome'],
      )!,
      profilePicture: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}profile_picture'],
      )!,
      creationTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creation_time'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RowId, int, int> $converterid =
      TypeConverter.extensionType<RowId, int>();
}

class User extends DataClass implements Insertable<User> {
  final RowId id;
  final String name;
  final bool isAwesome;
  final Uint8List profilePicture;
  final DateTime creationTime;
  const User({
    required this.id,
    required this.name,
    required this.isAwesome,
    required this.profilePicture,
    required this.creationTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['id'] = Variable<int>($UsersTable.$converterid.toSql(id));
    }
    map['name'] = Variable<String>(name);
    map['is_awesome'] = Variable<bool>(isAwesome);
    map['profile_picture'] = Variable<Uint8List>(profilePicture);
    map['creation_time'] = Variable<DateTime>(creationTime);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      isAwesome: Value(isAwesome),
      profilePicture: Value(profilePicture),
      creationTime: Value(creationTime),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: $UsersTable.$converterid.fromJson(
        serializer.fromJson<int>(json['id']),
      ),
      name: serializer.fromJson<String>(json['name']),
      isAwesome: serializer.fromJson<bool>(json['is_awesome']),
      profilePicture: serializer.fromJson<Uint8List>(json['profile_picture']),
      creationTime: serializer.fromJson<DateTime>(json['creation_time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>($UsersTable.$converterid.toJson(id)),
      'name': serializer.toJson<String>(name),
      'is_awesome': serializer.toJson<bool>(isAwesome),
      'profile_picture': serializer.toJson<Uint8List>(profilePicture),
      'creation_time': serializer.toJson<DateTime>(creationTime),
    };
  }

  User copyWith({
    RowId? id,
    String? name,
    bool? isAwesome,
    Uint8List? profilePicture,
    DateTime? creationTime,
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    isAwesome: isAwesome ?? this.isAwesome,
    profilePicture: profilePicture ?? this.profilePicture,
    creationTime: creationTime ?? this.creationTime,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isAwesome: data.isAwesome.present ? data.isAwesome.value : this.isAwesome,
      profilePicture: data.profilePicture.present
          ? data.profilePicture.value
          : this.profilePicture,
      creationTime: data.creationTime.present
          ? data.creationTime.value
          : this.creationTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isAwesome: $isAwesome, ')
          ..write('profilePicture: $profilePicture, ')
          ..write('creationTime: $creationTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isAwesome,
    $driftBlobEquality.hash(profilePicture),
    creationTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.isAwesome == this.isAwesome &&
          $driftBlobEquality.equals(
            other.profilePicture,
            this.profilePicture,
          ) &&
          other.creationTime == this.creationTime);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<RowId> id;
  final Value<String> name;
  final Value<bool> isAwesome;
  final Value<Uint8List> profilePicture;
  final Value<DateTime> creationTime;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isAwesome = const Value.absent(),
    this.profilePicture = const Value.absent(),
    this.creationTime = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isAwesome = const Value.absent(),
    required Uint8List profilePicture,
    this.creationTime = const Value.absent(),
  }) : name = Value(name),
       profilePicture = Value(profilePicture);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isAwesome,
    Expression<Uint8List>? profilePicture,
    Expression<DateTime>? creationTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isAwesome != null) 'is_awesome': isAwesome,
      if (profilePicture != null) 'profile_picture': profilePicture,
      if (creationTime != null) 'creation_time': creationTime,
    });
  }

  UsersCompanion copyWith({
    Value<RowId>? id,
    Value<String>? name,
    Value<bool>? isAwesome,
    Value<Uint8List>? profilePicture,
    Value<DateTime>? creationTime,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isAwesome: isAwesome ?? this.isAwesome,
      profilePicture: profilePicture ?? this.profilePicture,
      creationTime: creationTime ?? this.creationTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>($UsersTable.$converterid.toSql(id.value));
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isAwesome.present) {
      map['is_awesome'] = Variable<bool>(isAwesome.value);
    }
    if (profilePicture.present) {
      map['profile_picture'] = Variable<Uint8List>(profilePicture.value);
    }
    if (creationTime.present) {
      map['creation_time'] = Variable<DateTime>(creationTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isAwesome: $isAwesome, ')
          ..write('profilePicture: $profilePicture, ')
          ..write('creationTime: $creationTime')
          ..write(')'))
        .toString();
  }
}

abstract class _$SecondDb extends GeneratedDatabase {
  _$SecondDb(QueryExecutor e) : super(e);
  $SecondDbManager get managers => $SecondDbManager(this);
  late final $UsersTable users = $UsersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [users];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<RowId> id,
      required String name,
      Value<bool> isAwesome,
      required Uint8List profilePicture,
      Value<DateTime> creationTime,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<RowId> id,
      Value<String> name,
      Value<bool> isAwesome,
      Value<Uint8List> profilePicture,
      Value<DateTime> creationTime,
    });

class $$UsersTableFilterComposer extends Composer<_$SecondDb, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<RowId, RowId, int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAwesome => $composableBuilder(
    column: $table.isAwesome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creationTime => $composableBuilder(
    column: $table.creationTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer extends Composer<_$SecondDb, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAwesome => $composableBuilder(
    column: $table.isAwesome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creationTime => $composableBuilder(
    column: $table.creationTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer extends Composer<_$SecondDb, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<RowId, int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isAwesome =>
      $composableBuilder(column: $table.isAwesome, builder: (column) => column);

  GeneratedColumn<Uint8List> get profilePicture => $composableBuilder(
    column: $table.profilePicture,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creationTime => $composableBuilder(
    column: $table.creationTime,
    builder: (column) => column,
  );
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$SecondDb,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$SecondDb, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$SecondDb db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isAwesome = const Value.absent(),
                Value<Uint8List> profilePicture = const Value.absent(),
                Value<DateTime> creationTime = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                isAwesome: isAwesome,
                profilePicture: profilePicture,
                creationTime: creationTime,
              ),
          createCompanionCallback:
              ({
                Value<RowId> id = const Value.absent(),
                required String name,
                Value<bool> isAwesome = const Value.absent(),
                required Uint8List profilePicture,
                Value<DateTime> creationTime = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                isAwesome: isAwesome,
                profilePicture: profilePicture,
                creationTime: creationTime,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$SecondDb,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$SecondDb, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;

class $SecondDbManager {
  final _$SecondDb _db;
  $SecondDbManager(this._db);
  $$UsersTableTableManager get users => $$UsersTableTableManager(_db, _db.users);
}
