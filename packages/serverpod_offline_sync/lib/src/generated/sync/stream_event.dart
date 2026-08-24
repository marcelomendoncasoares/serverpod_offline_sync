/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
part 'close.dart';
part 'connect.dart';
part 'end_of_batch.dart';
part 'merge_chunk.dart';
part 'scope_set.dart';
part 'since_hlc.dart';
part 'timeout.dart';

/// A CRDT sync event sent over a bidirectional stream.
///
/// This is the base class of the CRDT sync protocol.
sealed class CrdtSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtSyncStreamEvent();

  /// Returns a shallow copy of this [CrdtSyncStreamEvent]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtSyncStreamEvent copyWith();
}
