import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

@internal
class CrdtDatabaseSession implements DatabaseSession {
  CrdtDatabaseSession(this._db);

  final Database _db;

  @override
  Database get db => _db;

  @override
  LogQueryFunction? get logQuery => null;

  @override
  LogWarningFunction? get logWarning => null;

  @override
  Transaction? transaction;
}
