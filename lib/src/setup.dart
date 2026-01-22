import 'package:drift/native.dart';

import '/src/hlc/stateful.dart';
import '/src/triggers.dart';
import 'tables/data.dart';

/// The database setup function to register the HLC function.
///
/// Will register the `next_hlc_timestamp` function in the SQLite3 database for usage
/// in the triggers that keep track of changes in the database.
///
/// If using Dart only, must be passed to the [NativeDatabase] constructor as `setup`
/// parameter. If using Flutter, this function must be passed to the `driftDatabase`
/// function as `setup` parameter.
DatabaseSetup get registerHlcFunction {
  return (database) {
    database.createFunction(
      functionName: nextHlcFunction,
      function: (args) {
        if (args.isEmpty) throw _MissingArgumentsError();
        if (args.length == 1) throw _MissingNodeIdError();
        if (args.length > 2) throw _TooManyArgumentsError();

        final userId = args[0] as String?;
        if (userId == null) throw _MissingUserIdError();

        final nodeId = args[1] as String?;
        if (nodeId == null) throw _MissingNodeIdError();

        return StatefulHlc.cached(userId, nodeId).increment().toString();
      },
      // argumentCount: const AllowedArgumentCount(2),
      deterministic: false,
      directOnly: false,
    );

    // Load the last HLC for the user from the control table.
    try {
      database.select(CrdtDataTable.getLastHlcTimestampQuery()).forEach((row) {
        final userId = row.values.first! as String;
        final lastHlcTimestamp = hlcConverter.fromSql(row.values.last! as String);
        StatefulHlc.initialize(userId, lastHlcTimestamp);
      });
    } on Exception catch (_) {
      // Ignore errors, as the HLC will be initialized to zero.
      // This is expected to happen on a new database.
    }
  };
}

class _MissingArgumentsError extends ArgumentError {}

class _MissingUserIdError extends _MissingArgumentsError {}

class _MissingNodeIdError extends _MissingArgumentsError {}

class _TooManyArgumentsError extends ArgumentError {}
