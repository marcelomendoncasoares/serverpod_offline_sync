import 'package:serverpod_database/serverpod_database.dart';

/// A builder for a SQL CASE expression.
///
/// Creates a searched CASE expression when [_column] is omitted and a
/// simple CASE expression when it is provided.
class Case {
  /// Creates a new [Case] expression builder.
  Case([this._column]);
  final Column? _column;
  final List<_WhenThen> _whenThenExpressions = [];

  /// Adds a WHEN and THEN expression.
  void when(Expression expression, {required Expression then}) {
    _whenThenExpressions.add(_WhenThen(expression, then));
  }

  /// Completes the CASE expression with an ELSE expression.
  Expression orElse(Expression expression) {
    return _CaseExpression(
      _column,
      List.unmodifiable(_whenThenExpressions),
      expression,
    );
  }
}

class _CaseExpression extends Expression<void> {
  _CaseExpression(
    this._column,
    this._whenThenExpressions,
    this._elseExpression,
  ) : super(null);
  final Column? _column;
  final List<_WhenThen> _whenThenExpressions;
  final Expression _elseExpression;

  @override
  List<Column> get columns => [
    if (_column != null) _column,
    ..._whenThenExpressions.expand(
      (expressions) => [
        ...expressions.when.columns,
        ...expressions.then.columns,
      ],
    ),
    ..._elseExpression.columns,
  ];

  @override
  Iterable<Expression> get depthFirst sync* {
    yield* super.depthFirst;
    for (final expressions in _whenThenExpressions) {
      yield* expressions.when.depthFirst;
      yield* expressions.then.depthFirst;
    }
    yield* _elseExpression.depthFirst;
  }

  @override
  String toString() {
    var expression = 'CASE';
    if (_column != null) {
      expression += ' $_column';
    }
    for (final expressions in _whenThenExpressions) {
      // No need to use a string buffer here as the expression is not complex.
      // ignore: use_string_buffers
      expression += ' WHEN ${expressions.when} THEN ${expressions.then}';
    }
    return '$expression ELSE $_elseExpression END';
  }
}

class _WhenThen {
  _WhenThen(this.when, this.then);
  final Expression when;
  final Expression then;
}
