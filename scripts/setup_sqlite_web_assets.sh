#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root after dart pub get. The browser test runner
# serves assets relative to the test file, matching sqlite_async's defaults.
test_directory=test/serverpod_offline_sync_test_server/test/browser

resolved_version() {
  awk -v dependency="  $1:" '
    $0 == dependency { found = 1 }
    found && /^    version:/ {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' pubspec.lock
}

sqlite_version="$(resolved_version sqlite3)"

if [[ -z "$sqlite_version" || ! -f .dart_tool/package_config.json ]]; then
  echo 'Run dart pub get before provisioning SQLite browser assets.' >&2
  exit 1
fi

curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqlite_version/sqlite3.wasm" \
  --output "$test_directory/sqlite3.wasm"

# A released worker embeds the sqlite3 bindings available when it was built.
# Compile against the same resolved packages as the browser test and WASM asset.
worker_directory="$(mktemp -d)"
trap 'rm -rf "$worker_directory"' EXIT

cat > "$worker_directory/worker.dart" <<'DART'
import 'package:sqlite3_web/sqlite3_web.dart';
import 'package:sqlite_async/sqlite3_web_worker.dart';

void main() {
  WebSqlite.workerEntrypoint(controller: AsyncSqliteController());
}
DART

dart compile js \
  --packages=.dart_tool/package_config.json \
  --no-source-maps \
  -O2 \
  "$worker_directory/worker.dart" \
  --output="$worker_directory/db_worker.js"

mv "$worker_directory/db_worker.js" "$test_directory/db_worker.js"
