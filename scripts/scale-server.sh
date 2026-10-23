#!/usr/bin/env bash
set -euo pipefail

# Stage only benchmark runtime files; existing test configs and DBs are untouched.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
server_dir="${BENCHMARK_SERVER_DIR:-$repo_root/.scale-benchmark/server}"
mkdir -p "$server_dir/config"
cp "$repo_root/benchmark/scale_server/config/"*.yaml "$server_dir/config/"
cp -R "$repo_root/test/serverpod_offline_sync_test_server/migrations" "$server_dir/"

# Non-secret provenance the server reports; this runs source from the checkout.
revision="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"
revision_json=null
dirty=null
if [[ -n "$revision" ]]; then
  revision_json="\"$revision\""
  if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then dirty=true; else dirty=false; fi
fi
printf '{"sourceRevision":%s,"sourceDirty":%s,"preparedAt":"%s","mode":"scale-server.sh"}\n' \
  "$revision_json" "$dirty" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$server_dir/config/benchmark_build.json"

cd "$server_dir"
exec "${DART:-dart}" run "$repo_root/benchmark/bin/scale_server.dart" --apply-migrations "$@"
