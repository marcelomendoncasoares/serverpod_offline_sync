#!/usr/bin/env bash
#
# Continuous deterministic-simulation hunt.
#
# The simulation suite seeds from the clock by default, so a failure is only
# replayable if the seed it used survives. This script chooses every seed base
# itself, writes it down before the run starts, and keeps the whole unfiltered
# output of any run that fails. A failure found overnight is therefore always
# replayable, even if the process is killed before it can summarize anything.
#
# Usage:
#   scripts/dst_soak.sh                      # hunt until 09:00 tomorrow
#   DST_SOAK_UNTIL=$(date -d '+2 hours' +%s) scripts/dst_soak.sh
#   DST_SOAK_OUT=/other/place scripts/dst_soak.sh
#
# Results live in .dst-soak:
#   FAILURES.md          one section per failing run, with its replay command
#   RUNS.tsv             every run attempted, so coverage is auditable
#   runs/<id>.log        full output, kept for failures only
#   tree.txt, tree.diff  the exact code state being hunted

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGE="$REPO_ROOT/test/serverpod_offline_sync_test_server"
OUT="${DST_SOAK_OUT:-$REPO_ROOT/.dst-soak}"
UNTIL="${DST_SOAK_UNTIL:-$(date -d 'tomorrow 09:00' +%s)}"
# One run may not eat the whole night: a 200-round sweep takes minutes, so an
# hour means the run is stuck rather than slow.
RUN_TIMEOUT="${DST_SOAK_RUN_TIMEOUT:-3600}"

# A broken environment fails every run in milliseconds, which would otherwise
# spin the loop all night and bury a real finding under thousands of entries.
# Check the two things that make a run possible before starting.
[ -d "$PACKAGE" ] || { echo "no test package at $PACKAGE" >&2; exit 2; }
command -v dart > /dev/null || { echo "dart is not on PATH" >&2; exit 2; }

mkdir -p "$OUT/runs"

# The code under test, recorded once. A failure is worthless without knowing
# which tree produced it, and the tree can move while the hunt is running.
{
  echo "head: $(git -C "$REPO_ROOT" rev-parse HEAD)"
  echo "branch: $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
  echo "started: $(date -Is)"
  echo "until: $(date -d "@$UNTIL" -Is)"
  echo "dirty:"
  git -C "$REPO_ROOT" status --porcelain
} > "$OUT/tree.txt"
git -C "$REPO_ROOT" diff HEAD > "$OUT/tree.diff"

[ -f "$OUT/RUNS.tsv" ] ||
  printf 'started\tid\tprofile\tseed_base\tseeds\trounds\twidth\ttarget\tresult\tseconds\n' \
    > "$OUT/RUNS.tsv"
[ -f "$OUT/FAILURES.md" ] || {
  echo "# Deterministic simulation failures"
  echo
  echo "Every entry replays on its own. Investigate one by pasting its command."
  echo
} > "$OUT/FAILURES.md"

# Configurations rotate so the hunt keeps changing shape: the workload profile
# decides which transitions a run can reach at all, and the round count decides
# how deep a schedule gets before the run ends. A single fixed shape would keep
# re-searching the same corner of the space all night.
#
# profile:seeds:rounds:width:target
CONFIGS=(
  "sparse:8:40:2:"
  "mixed:6:120:2:"
  "mixed:4:200:2:test/dst/dst_cross_space_test.dart"
  "populated:3:200:3:"
  "sparse:12:40:3:test/dst/dst_convergence_test.dart"
  "mixed:8:80:2:"
)
# Space-separated entries in the same shape, to steer or test the hunt.
[ -z "${DST_SOAK_CONFIGS:-}" ] || read -r -a CONFIGS <<< "$DST_SOAK_CONFIGS"
[ "${#CONFIGS[@]}" -gt 0 ] || { echo "no configurations to run" >&2; exit 2; }

# Seeds advance monotonically from the clock, so no two runs ever explore the
# same schedule and the space covered is one contiguous range per night.
cursor=$(date +%s)
index=0
# A simulation that fails takes minutes, like one that passes. Failing in
# seconds means the run never got as far as simulating anything, so the hunt
# stops rather than reporting the same broken environment a thousand times.
suspicious=0

while [ "$(date +%s)" -lt "$UNTIL" ]; do
  IFS=':' read -r profile seeds rounds width target <<< "${CONFIGS[index % ${#CONFIGS[@]}]}"
  index=$((index + 1))

  # The index keeps two runs that start in the same second from sharing a log.
  id="$(date +%Y%m%d-%H%M%S)-$index-$profile-$rounds"
  log="$OUT/runs/$id.log"
  seed_base=$cursor
  cursor=$((cursor + seeds))

  replay="DST_SEED_BASE=$seed_base DST_SEEDS=$seeds DST_ROUNDS=$rounds"
  replay="$replay DST_PROFILE=$profile DST_GRAPH_WIDTH=$width"
  replay="$replay dart test -P dst --concurrency=1 ${target:+$target}"

  # The command is written down before the run, so a kill -9 mid-run still
  # leaves the seed behind.
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -Is)" "$id" "$profile" "$seed_base" "$seeds" "$rounds" "$width" \
    "${target:-all}" "started" "" >> "$OUT/RUNS.tsv"

  started=$(date +%s)
  (
    cd "$PACKAGE" || exit 1
    DST_SEED_BASE=$seed_base \
    DST_SEEDS=$seeds \
    DST_ROUNDS=$rounds \
    DST_PROFILE=$profile \
    DST_GRAPH_WIDTH=$width \
      timeout "$RUN_TIMEOUT" dart test -P dst --concurrency=1 \
        --reporter=expanded ${target:+"$target"}
  ) > "$log" 2>&1
  status=$?
  elapsed=$(($(date +%s) - started))

  # Exit 79 is "no tests ran": the target holds no `dst`-tagged test, so the
  # run searched nothing. Silently, it would waste every turn this
  # configuration takes for the rest of the night.
  if [ $status -eq 79 ]; then
    echo "$(date -Is) $id matched no dst-tagged test: ${target:-the suite}" >&2
    exit 4
  fi

  if [ $status -eq 0 ]; then
    # A passing run proves the seeds were searched; its output proves nothing,
    # and a night of them fills the disk.
    rm -f "$log"
    result="passed"
    suspicious=0
  else
    result="FAILED($status)"
    if [ "$elapsed" -lt 30 ]; then
      suspicious=$((suspicious + 1))
    else
      suspicious=0
    fi
    {
      echo "## $id"
      echo
      echo "- tree: $(git -C "$REPO_ROOT" rev-parse --short HEAD) on $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
      echo "- exit: $status after ${elapsed}s"
      echo "- log: .dst-soak/runs/$id.log"
      echo
      echo '```'
      echo "cd test/serverpod_offline_sync_test_server"
      echo "$replay"
      echo '```'
      echo
      echo "Failing tests:"
      echo
      # The suite prints its own single-seed replay line for each failure. It is
      # narrower than the sweep command above, so it is kept when present.
      sed -n 's/.*\(Replay: DST_SEED_BASE=[^ ]* DST_SEEDS=[^ ]* DST_ROUNDS=[^ ]* DST_PROFILE=[^ ]* DST_GRAPH_WIDTH=[0-9]*\).*/- \1/p' \
        "$log" | sort -u
      sed -n 's/^\s*\(test\/dst\/[a-z_]*\.dart:.*\)$/- \1/p' "$log" | sort -u | head -20
      echo
    } >> "$OUT/FAILURES.md"
  fi

  # Rewrite the provisional row rather than leaving a dangling "started".
  tmp=$(mktemp)
  awk -F'\t' -v id="$id" -v r="$result" -v e="$elapsed" 'BEGIN { OFS = FS }
    $2 == id && $9 == "started" { $9 = r; $10 = e } { print }' \
    "$OUT/RUNS.tsv" > "$tmp" && mv "$tmp" "$OUT/RUNS.tsv"

  echo "$(date -Is) $id $result ${elapsed}s seeds=$seed_base..$((seed_base + seeds - 1))"

  if [ "$suspicious" -ge 3 ]; then
    echo "$(date -Is) three runs failed without simulating; see $OUT/runs" >&2
    exit 3
  fi
done

echo "$(date -Is) deadline reached; $(grep -c 'FAILED' "$OUT/RUNS.tsv") failing runs"
