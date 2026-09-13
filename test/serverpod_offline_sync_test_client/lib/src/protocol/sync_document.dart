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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _imkb9kra;

abstract class SyncDocument
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SyncDocument._({
    required this.title,
    required this.enabled,
    required this.numbers,
  });

  factory SyncDocument({
    required String title,
    required bool enabled,
    required List<int> numbers,
  }) = _SyncDocumentImpl;

  factory SyncDocument.fromJson(Map<String, dynamic> jsonSerialization) {
    return SyncDocument(
      title: jsonSerialization['title'] as String,
      enabled: _isc.BoolJsonExtension.fromJson(jsonSerialization['enabled']),
      numbers: _imkb9kra.Protocol().deserialize<List<int>>(
        jsonSerialization['numbers'],
      ),
    );
  }

  String title;

  bool enabled;

  List<int> numbers;

  /// Returns a shallow copy of this [SyncDocument]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SyncDocument copyWith({
    String? title,
    bool? enabled,
    List<int>? numbers,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SyncDocument',
      'title': title,
      'enabled': enabled,
      'numbers': numbers.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SyncDocument',
      'title': title,
      'enabled': enabled,
      'numbers': numbers.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SyncDocumentImpl extends SyncDocument {
  _SyncDocumentImpl({
    required String title,
    required bool enabled,
    required List<int> numbers,
  }) : super._(
         title: title,
         enabled: enabled,
         numbers: numbers,
       );

  /// Returns a shallow copy of this [SyncDocument]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SyncDocument copyWith({
    String? title,
    bool? enabled,
    List<int>? numbers,
  }) {
    return SyncDocument(
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
      numbers: numbers ?? this.numbers.map((e0) => e0).toList(),
    );
  }
}
