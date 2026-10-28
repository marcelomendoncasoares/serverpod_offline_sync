import '../test/native_tls/pool_hook_test.dart' as hook;
import '../test/native_tls/socket_test.dart' as socket;
import '../test/native_tls/transactions_test.dart' as transactions;

void main() {
  socket.main();
  hook.main();
  transactions.main();
}
