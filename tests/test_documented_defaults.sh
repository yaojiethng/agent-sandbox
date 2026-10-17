#!/usr/bin/env bash
# tests/test_documented_defaults.sh
#
# The skill owns its filenames and a caller names one root. Both are asserted
# here as behaviour, because a claim in SKILL.md that the code does not hold is
# the defect this file exists to catch.
#
# Covers:
#   init      -- a fresh session opens the tracker without hand-seeding
#   template  -- the seeded tracker carries a head the renderer maintains
#   names     -- one root holds every file, and no path can address them apart
#   boundary  -- the facade defaults the root, and a library call names what it lacks

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AT="$REPO_ROOT_DIR/src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs"

test_fresh_session_opens_the_tracker() {
  local d out rc
  d="$(get_fixture_dir)"

  out="$(cd "$d" && node "$AT" init 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "a fresh session opens the tracker: $out"

  out="$(cd "$d" && node "$AT" push root - --label "the work" --note "a directive" 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "a push needs no root argument: $out"

  out="$(cd "$d" && node "$AT" view 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "a view needs no root argument: $out"
  assert_contains "$out" "root. the work" "the seeded tracker renders the node"

  out="$(cd "$d" && node "$AT" report 2>&1)"
  rc=$?
  assert_eq "$rc" "0" "a report needs no root argument: $out"
  assert_contains "$out" "## Session memory" "the report composes both halves"
}

test_seeded_template_carries_a_hex_head() {
  local d head
  d="$(get_fixture_dir)"
  (cd "$d" && node "$AT" init >/dev/null 2>&1)
  head="$(sed -n 's/^Workspace HEAD at last write: `\(.*\)`$/\1/p' "$d/.scratchpad/ACTIVE_TASK_TRACKER.md")"
  if [[ "$head" =~ ^[0-9a-f]+$ ]]; then
    pass "the head placeholder is hex, so the renderer maintains it"
  else
    fail "the head placeholder is '$head', which the renderer leaves alone"
  fi
}

test_one_root_holds_every_file() {
  local d out names
  d="$(get_fixture_dir)"
  out="$(node "$AT" init --root "$d" 2>&1)"
  assert_contains "$out" "ACTIVE_TASK_TRACKER.json" "init names the store it seeds"

  out="$(node "$AT" push root - --label "the work" --note "a directive" --root "$d" 2>&1)"
  assert_eq "$?" "0" "a push into a named root: $out"

  names="$(cd "$d" && ls | sort | tr '\n' ' ')"
  assert_contains "$names" "ACTIVE_TASK_TRACKER.json" "the store lands under the root"
  assert_contains "$names" "ACTIVE_TASK_TRACKER.md" "the tracker lands under the root"
  assert_contains "$names" "SESSION_MEMORY_LOG.jsonl" "the log lands under the root"

  out="$(node "$AT" view --store "$d/elsewhere.json" 2>&1)"
  assert_contains "$out" "--store is gone" "a retired path flag refuses rather than landing in the default root"
}

test_the_facade_refuses_and_the_library_names_the_path() {
  local d out
  d="$(get_fixture_dir)"
  cat > "$d/probe.mjs" <<PROBE
import * as facade from "$AT";
const r = {};
try { facade.view(); r.facade = "defaulted"; } catch { r.facade = "refused"; }
try { facade.memory.note({ text: "x" }); r.library = "defaulted"; } catch (e) { r.library = e.message; }
console.log(JSON.stringify(r));
PROBE
  out="$(cd "$d" && node probe.mjs 2>&1)"
  assert_contains "$out" "refused" "the facade refuses on an absent store rather than seeding one"
  assert_contains "$out" "no log path given" "a library call names the path it lacks"
}

run_test test_fresh_session_opens_the_tracker
run_test test_seeded_template_carries_a_hex_head
run_test test_one_root_holds_every_file
run_test test_the_facade_refuses_and_the_library_names_the_path

test_done
