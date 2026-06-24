import 'package:serverpod/serverpod.dart';

import 'generated/protocol.dart';

/// Tables exposed through the offline-sync demo server.
final demoSyncTables = <Table>[
  Address.t,
  City.t,
  Company.t,
  FkChainCascadeMiddle.t,
  FkChainMiddleCascadeChild.t,
  FkChainMiddleSetNullChild.t,
  FkChainRestrictBlocker.t,
  FkChainRoot.t,
  FkChainSetNullCascadeChild.t,
  FkChainSetNullMiddle.t,
  FkChainSetNullRestrictChild.t,
  FkChainSetNullSetNullChild.t,
  Organization.t,
  Person.t,
  RequiredSetNullChild.t,
  RestrictChild.t,
  Town.t,
  Types.t,
  Unique.t,
  UniqueComposite.t,
  UniqueSetNullChild.t,
  UniqueUuid.t,
];
