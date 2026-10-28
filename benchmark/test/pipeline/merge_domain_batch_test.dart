import 'package:serverpod_database/serverpod_database.dart';

import '../../../test/serverpod_offline_sync_test_server/test/integration/server/merge_domain_batch_test.dart'
    as contract;

void main() {
  postgresPipelineDepth = 8;
  contract.main();
}
