import 'dart:io';

/// Creates disposable localhost certificates; no private keys live in Git.
Future<Directory> createCertificates() async {
  final directory = await Directory.systemTemp.createTemp('native-tls-certs-');

  Future<void> openssl(List<String> arguments) async {
    final result = await Process.run(
      'openssl',
      arguments,
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw StateError('Could not generate TLS test certificates: ${result.stderr}');
    }
  }

  try {
    await openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-keyout',
      'ca.key',
      '-out',
      'ca.pem',
      '-subj',
      '/CN=Benchmark test CA',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
    ]);
    await openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      'server.key',
      '-out',
      'server.csr',
      '-subj',
      '/CN=localhost',
    ]);
    await File('${directory.path}/extensions.cnf').writeAsString(
      'subjectAltName=DNS:localhost\n'
      'basicConstraints=critical,CA:FALSE\n'
      'extendedKeyUsage=serverAuth\n',
    );
    await openssl([
      'x509',
      '-req',
      '-in',
      'server.csr',
      '-CA',
      'ca.pem',
      '-CAkey',
      'ca.key',
      '-CAcreateserial',
      '-days',
      '1',
      '-out',
      'server.pem',
      '-extfile',
      'extensions.cnf',
    ]);
    return directory;
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}
