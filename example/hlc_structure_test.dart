import 'package:crdt/crdt.dart';

void main() {
  final hlc = Hlc.now('test-node-id');
  final hlcStr = hlc.toString();
  print('Full HLC: $hlcStr');
  
  // According to HLC format: timestamp-counter-nodeId
  // timestamp is in ISO 8601 format ending with Z
  // counter is 4-digit hex
  
  // Find the Z (end of timestamp)
  final timestampEnd = hlcStr.indexOf('Z-');
  if (timestampEnd == -1) {
    throw FormatException('Invalid HLC format');
  }
  
  final datetimeStr = hlcStr.substring(0, timestampEnd + 1);
  final remaining = hlcStr.substring(timestampEnd + 2);
  
  // Counter is next 4 characters
  final counterStr = remaining.substring(0, 4);
  final nodeIdStr = remaining.substring(5); // Skip hyphen after counter
  
  print('\nDatetime part: $datetimeStr');
  print('Counter part: $counterStr');
  print('Node ID part: $nodeIdStr');
  
  final dateTime = DateTime.parse(datetimeStr);
  print('\nDateTime: $dateTime');
  print('Unix microseconds: ${dateTime.microsecondsSinceEpoch}');
  print('Counter (hex): $counterStr => ${int.parse(counterStr, radix: 16)}');
  print('Counter property: ${hlc.counter}');
  print('Node ID property: ${hlc.nodeId}');
  
  // Verify we can reconstruct
  final reconstructed = Hlc.parse(hlcStr);
  print('\nReconstructed matches: ${reconstructed == hlc}');
  print('Reconstructed counter: ${reconstructed.counter}');
  print('Reconstructed nodeId: ${reconstructed.nodeId}');
}
