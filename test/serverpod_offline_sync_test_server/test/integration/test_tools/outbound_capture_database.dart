import 'package:serverpod_database/serverpod_database.dart' as database;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

/// Pauses real collection after a bounds or metadata query has completed.
/// No query results or transaction behavior are replaced.
class OutboundCaptureDatabase extends OfflineSyncDatabase {
  OutboundCaptureDatabase(super.delegate, {required super.syncTables});

  Future<void> Function()? afterInsertMetadata;
  Future<void> Function()? afterSpaceBounds;

  final predicates = <String, String>{};

  @override
  Future<List<T>> find<T extends database.TableRow>({
    database.Expression? where,
    int? limit,
    int? offset,
    database.Column? orderBy,
    List<database.Column>? orderByList,
    bool orderDescending = false,
    database.Transaction? transaction,
    database.Include? include,
    database.LockMode? lockMode,
    database.LockBehavior? lockBehavior,
  }) async {
    final rows = await super.find<T>(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );

    final tableName = switch (T) {
      const (CrdtDataRow) => 'crdt_data_rows',
      const (CrdtDataField) => 'crdt_data_fields',
      const (CrdtDataDeleted) => 'crdt_data_tombstone',
      _ => null,
    };
    if (tableName != null && where != null) predicates[tableName] = where.toString();

    if (T == OfflineSyncSpace) {
      final afterBounds = afterSpaceBounds;
      afterSpaceBounds = null;
      await afterBounds?.call();
    }

    if (T == CrdtDataRow) {
      final afterMetadata = afterInsertMetadata;
      afterInsertMetadata = null;
      await afterMetadata?.call();
    }

    return rows;
  }
}
