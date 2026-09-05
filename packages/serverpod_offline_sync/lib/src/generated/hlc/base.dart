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
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Base class for HLC timestamps.
///
/// This class is used to represent the base HLC timestamp, which will be
/// extended with the node ID (in its canonical or normalized form).
class BaseHlc implements _iss.SerializableModel, _iss.ProtocolSerialization {
  BaseHlc({
    required this.hlcDatetime,
    required this.hlcCounter,
  });

  factory BaseHlc.fromJson(Map<String, dynamic> jsonSerialization) {
    return BaseHlc(
      hlcDatetime: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
    );
  }

  /// The datetime component of the HLC timestamp.
  DateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  int hlcCounter;

  /// Returns a shallow copy of this [BaseHlc]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  BaseHlc copyWith({
    DateTime? hlcDatetime,
    int? hlcCounter,
  }) {
    return BaseHlc(
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.BaseHlc',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.BaseHlc',
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}
