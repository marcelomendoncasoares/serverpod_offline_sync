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
worker_version="$(resolved_version sqlite_async)"

if [[ -z "$sqlite_version" || -z "$worker_version" ]]; then
  echo 'Run dart pub get before provisioning SQLite browser assets.' >&2
  exit 1
fi

curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqlite_version/sqlite3.wasm" \
  --output "$test_directory/sqlite3.wasm"

# Compile against the resolved dependencies so the worker's SQLite bindings
# match the downloaded WASM. Precompiled workers can embed older bindings.
# Rebuild on every setup to account for dependency and Dart SDK changes.
echo "Compiling sqlite_async ($worker_version) web worker with sqlite3 ($sqlite_version)"
dart compile js --packages=.dart_tool/package_config.json \
  -O4 -Dsqlite3.dartbigints=false --no-source-maps \
  -o "$test_directory/db_worker.js" \
  package:sqlite_async/src/web/worker/worker.dart
