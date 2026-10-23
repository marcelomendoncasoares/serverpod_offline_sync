import 'package:serverpod_offline_sync_benchmark/scale/server_diagnostics.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given a generated read-only CTE with quoted keyword identifiers, '
    'when it is considered for plan collection, '
    'then its SELECT plan is eligible.',
    () {
      const query =
          'WITH "update" AS (SELECT "id" FROM "crdt_data_rows") '
          'SELECT * FROM "update" WHERE '
          "'DELETE' <> 'INSERT'";

      expect(isReadOnlyPlanCandidate(query), isTrue);
    },
  );

  test(
    'Given a data-modifying CTE with an outer SELECT, '
    'when it is considered for plan collection, '
    'then it is excluded from execution-plan replay.',
    () {
      const query =
          'WITH "written" AS (UPDATE "offline_sync_spaces" '
          'SET "revision" = 1 RETURNING "id") SELECT * FROM "written"';

      expect(isReadOnlyPlanCandidate(query), isFalse);
    },
  );
}
