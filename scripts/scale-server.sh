#!/usr/bin/env bash
set -euo pipefail

# Stage only benchmark runtime files; existing test configs and DBs are untouched.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
server_dir="${BENCHMARK_SERVER_DIR:-$repo_root/.scale-benchmark/server}"
mkdir -p "$server_dir/config"
cp "$repo_root/benchmark/scale_server/config/"*.yaml "$server_dir/config/"
cp "$repo_root/test/serverpod_offline_sync_test_server/pubspec.yaml" "$server_dir/pubspec.yaml"
cp -R "$repo_root/test/serverpod_offline_sync_test_server/migrations" "$server_dir/"
cd "$server_dir"
exec "${DART:-dart}" run "$repo_root/benchmark/bin/scale_server.dart" --apply-migrations "$@"
