import 'package:crdt/crdt.dart';

void main() {
  final hlc = Hlc.now('test-node-id-that-is-very-long');
  print('Hlc toString: ${hlc.toString()}');
  print('Hlc toJson: ${hlc.toJson()}');
  print('Hlc counter: ${hlc.counter}');
  print('Hlc nodeId: ${hlc.nodeId}');
  
  final parsed = Hlc.parse(hlc.toString());
  print('\nParsed Hlc counter: ${parsed.counter}');
  print('Parsed Hlc nodeId: ${parsed.nodeId}');
  
  print('\nString length: ${hlc.toString().length}');
  print('Example HLC: ${hlc.toString()}');
}
