/// Performance diagnostics for benchmarks and sync investigations.
///
/// This is not an analytics, audit or telemetry API. Event names, fields and
/// timing points follow the sync internals and change without notice. Events
/// carry user, space and node ids, but never row data or SQL.
library;

export 'src/sync/diagnostics.dart';
