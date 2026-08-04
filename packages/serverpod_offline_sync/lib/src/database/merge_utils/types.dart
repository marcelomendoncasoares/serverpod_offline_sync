import 'package:meta/meta.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/sync.dart';
import '../../generated/protocol.dart';
import '../../hlc/hlc.dart';

/// Identifies a domain row during merges: `(tableName, rowId)`.
@internal
typedef MergeRowKey = (String, UuidValue);

/// Identifies a domain field during merges: `(tableName, rowId, columnName)`.
@internal
typedef MergeFieldKey = (String, UuidValue, String);

/// Preloaded CRDT metadata shared while applying a merge set.
@internal
typedef MergeContext = ({
  Map<MergeRowKey, CrdtDataRow> rows,
  Map<MergeFieldKey, CrdtDataField> fields,
  Map<MergeFieldKey, Hlc> incomingFieldHlcs,
  Map<MergeRowKey, CrdtDataDeleted> tombstones,
  Map<MergeRowKey, DomainRowOwner> domainOwners,
});

/// Remote nodes and scope-node rows loaded for a merge.
@internal
typedef MergeNodes = ({
  Map<UuidValue, CrdtNode> nodesByUuid,
  Map<UuidValue, CrdtScopeNode> scopeNodesByUuid,
});
