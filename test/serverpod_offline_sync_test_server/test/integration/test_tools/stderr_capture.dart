import 'dart:async';
import 'dart:io';

import 'package:serverpod_test/src/io_overrides.dart';

/// Runs [action] while suppressing stdout and capturing stderr.
Future<String> captureStderr(Future<void> Function() action) async {
  final stderr = _CapturingStdout();

  Stdout capturedStderr() => stderr;

  try {
    await IOOverrides.runZoned(
      () async {
        await action();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      stdout: NullStdOut.new,
      stderr: capturedStderr,
    );
    return stderr.output;
  } finally {
    await stderr.close();
  }
}

class _CapturingStdout extends NullStdOut {
  final _buffer = StringBuffer();

  String get output => _buffer.toString();

  @override
  void add(List<int> data) {
    _buffer.write(encoding.decode(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _buffer.write(error);
    if (stackTrace != null) _buffer.write(stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.forEach(add);
  }

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  void writeAll(Iterable objects, [String sep = '']) {
    _buffer.writeAll(objects, sep);
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _buffer
      ..write(object)
      ..write(lineTerminator);
  }
}
