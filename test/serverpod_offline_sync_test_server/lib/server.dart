import 'src/demo_auth.dart';
import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
Future<void> run(List<String> args) async {
  final pod = Serverpod(
    args,
    authenticationHandler: demoAuthenticationHandler,
  );

  await pod.start();
}
