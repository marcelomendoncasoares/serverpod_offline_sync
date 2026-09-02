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

/// The merge context's field cache, with the node authoring the batch.
///
/// The two are one parameter because they are only meaningful together: a
/// cached field is read back through `CrdtDataField.hlc`, which resolves the
/// node's uuid and throws without it. Separate optional parameters would allow
/// a cache with no node, whose entries throw when read.
@internal
typedef MergeFieldCache = ({
  Map<MergeFieldKey, CrdtDataField> fields,
  CrdtNode node,
});

/// Remote nodes and scope-node rows loaded for a merge.
@internal
typedef MergeNodes = ({
  Map<UuidValue, CrdtNode> nodesByUuid,
  Map<UuidValue, CrdtScopeNode> scopeNodesByUuid,
});

/// A row that will be written after projection, included in unique/FK planning.
@internal
typedef PendingProjectionRow = ({
  String tableName,
  UuidValue rowId,
  Map<String, Object?> authoredValues,
  Hlc rowHlc,
  CrdtNode node,
  bool hidden,
});

/// Authored value retained while a projector materializes a different domain value.
@internal
typedef ProjectionAttempt = ({
  Object? value,
  CrdtProjectionReason reason,
});
