import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:drift_offline_first/src/triggers.dart';
import 'package:test/test.dart';

void main() {
  group('Given an executor with the HLC function registered', () {
    late NativeDatabase executor;

    setUp(() async {
      executor = NativeDatabase.memory(setup: registerHlcFunction);
      await executor.ensureOpen(_TestQueryExecutorUser());
    });

    tearDown(() async {
      await executor.close();
    });

    test(
        'when calling the HLC function with valid arguments '
        'then it returns a valid HLC timestamp.', () async {
      final result = await executor.runSelect(
        'SELECT $nextHlcFunction(?, ?) as hlc_timestamp;',
        ['user_id', 'node_id'],
      );

      final hlcTimestamp = result.first['hlc_timestamp'] as String?;
      expect(hlcTimestamp, isA<String>());
      expect(hlcConverter.fromSql(hlcTimestamp!), isA<Hlc>());
    });

    test(
        'when calling the HLC function with no arguments '
        'then it throws a SqliteException due to the MissingArgumentsError.', () async {
      expect(
        () => executor.runSelect(
          'SELECT $nextHlcFunction() as hlc_timestamp;',
          [],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('MissingArgumentsError'),
          ),
        ),
      );
    });

    test(
        'when calling the HLC function with only the first argument '
        'then it throws a SqliteException due to the MissingNodeIdError.', () async {
      expect(
        () => executor.runSelect(
          'SELECT $nextHlcFunction(?) as hlc_timestamp;',
          ['user_id'],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('MissingNodeIdError'),
          ),
        ),
      );
    });

    test(
        'when calling the HLC function with only the second argument '
        'then it throws a SqliteException due to the MissingUserIdError.', () async {
      expect(
        () => executor.runSelect(
          'SELECT $nextHlcFunction(?, ?) as hlc_timestamp;',
          [null, 'user_id'],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('MissingUserIdError'),
          ),
        ),
      );
    });

    test(
        'when calling the HLC function with more than two arguments '
        'then it throws a SqliteException due to the TooManyArgumentsError.', () async {
      expect(
        () => executor.runSelect(
          'SELECT $nextHlcFunction(?, ?, ?) as hlc_timestamp;',
          ['user_id', 'node_id', 'extra_argument'],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('TooManyArgumentsError'),
          ),
        ),
      );
    });
  });
}

class _TestQueryExecutorUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {
    return;
  }
}
