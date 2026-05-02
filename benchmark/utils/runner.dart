// Progress-style logging for the benchmark CLI.

Future<T> runWithProgress<T>(
  String message,
  Future<T> Function() runner, {
  bool Function(T result)? validator,
  bool skipProgress = false,
}) async {
  if (!skipProgress) {
    print('$message…');
  }
  final result = await runner();
  final ok = validator?.call(result) ?? true;
  if (!skipProgress) {
    print(
      ok ? '  done.' : '  failed validation (CRDT not slower than baseline).',
    );
  }
  return result;
}
