import 'package:drift/drift.dart';

/// CRDT Compensation rules.
///
/// This table stores the compensation rules for each table and column.
///
@DataClassName('CrdtCompensationEntry')
class CrdtCompensationTable extends Table {
  @override
  String get tableName => '__crdt_compensation';

  /// Name of the table that data belongs to.
  late final tblName = text().named('table_name')();

  /// Name of the column this data belongs to.
  late final columnName = text()();

  /// Type of constraint this compensation rule applies to.
  late final constraintType = textEnum<ConstraintType>()();

  /// Compensation rule to preserve invariants.
  late final compensationRule = textEnum<CompensationRule>()();

  @override
  Set<Column> get primaryKey => {tblName, columnName, constraintType};
}

/// Type of constraint this compensation rule applies to.
enum ConstraintType {
  /// Unique constraint.
  unique,

  /// Foreign key constraint.
  foreignKey,
}

/// Available compensation rules for CRDT operations.
enum CompensationRule {
  /// No compensation rule.
  none,

  /// Handle unique key conflicts by merging values.
  // ignore: constant_identifier_names
  on_unique_conflict_merge,

  /// Handle unique key conflicts by overwriting the existing value.
  // ignore: constant_identifier_names
  on_unique_conflict_overwrite,

  /// Handle foreign key deletion by deleting this related row.
  // ignore: constant_identifier_names
  on_fk_deleted_delete_this,

  /// Handle foreign key deletion by setting the relation on this row to null.
  // ignore: constant_identifier_names
  on_fk_deleted_set_null,

  /// Handle foreign key deletion by restoring the related row.
  // ignore: constant_identifier_names
  on_fk_deleted_restore_related,
}
