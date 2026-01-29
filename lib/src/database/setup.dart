import 'package:drift/native.dart';

import '../hlc/normalized.dart';
import '/src/hlc/stateful.dart';
import 'tables/data.dart';
import 'triggers.dart';

/// The database setup function to register the HLC function.
///
/// Will register the `next_hlc_timestamp` function in the SQLite3 database for usage
/// in the triggers that keep track of changes in the database.
///
/// The function now returns a delimited string in the format "datetime|counter"
/// where datetime is the Unix timestamp in microseconds and counter is the HLC counter.
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
        if (args.length > 1) throw _TooManyArgumentsError();

        final userId = args[0] as String?;
        if (userId == null) throw _MissingUserIdError();

        // Node ID is implicit - always use the cached instance for the current node
        // The nodeId must have been registered during initialization
        final statefulHlc = StatefulHlc.getCachedInstance(userId);
        if (statefulHlc == null) {
          throw StateError(
            'StatefulHlc not initialized for user "$userId". '
            'Ensure the database setup has completed.',
          );
        }

        final (datetime, counter) = statefulHlc.incrementNormalized();
        return '$datetime|$counter';
      },
      deterministic: false,
      directOnly: false,
    );

    // Load the last HLC for each user from the database
    try {
      database.select(CrdtDataTable.getLastHlcTimestampQuery()).forEach((row) {
        final userId = row.values[0]! as String;
        final hlcDatetime = row.values[1]! as int;
        final hlcCounter = row.values[2]! as int;
        final nodeId = row.values[3]! as String;

        // Reconstruct HLC from components
        final hlc = NormalizedHlc.reconstruct(
          datetime: hlcDatetime,
          counter: hlcCounter,
          nodeId: nodeId,
        );
        StatefulHlc.initialize(userId, hlc);
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
