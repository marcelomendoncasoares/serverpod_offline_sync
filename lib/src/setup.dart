import 'package:drift/native.dart';

import '/src/hlc/stateful.dart';
import '/src/triggers.dart';

/// The database setup function to register the HLC function.
///
/// Will register the `next_hlc_timestamp` function in the SQLite3 database for usage
/// in the triggers that keep track of changes in the database.
///
/// If using Dart only, must be passed to the [NativeDatabase] constructor as `setup`
/// parameter. If using Flutter, this function must be passed to the `driftDatabase`
/// function as `setup` parameter.
///
DatabaseSetup get registerHlcFunction {
  // if (_initialized) return (database) {};
  // _initialized = true;

  return (database) {
    database.createFunction(
      functionName: nextHlcFunction,
      function: (args) {
        final nodeId = args.firstOrNull as String?;
        if (nodeId == null) throw ArgumentError('nodeId is required');
        return StatefulHlc.cached(nodeId).nextHlc().toString();
      },
      // argumentCount: const AllowedArgumentCount(1),
      deterministic: false,
      directOnly: false,
    );
  };
}
