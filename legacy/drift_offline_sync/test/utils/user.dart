import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

// NOTE: Generated once per test so that the tests are deterministic, but also
// isolated between each other.
String get testNodeId {
  _testNodeId ??= const Uuid().v7();
  addTearDown(() {
    _testNodeId = null;
  });
  return _testNodeId!;
}

String get testUserId {
  _testUserId ??= const Uuid().v7();
  addTearDown(() {
    _testUserId = null;
  });
  return _testUserId!;
}

String? _testNodeId;
String? _testUserId;
