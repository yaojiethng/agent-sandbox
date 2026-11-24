#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_session_evidence.sh
# Behavioural tests for the recovery skill's session_evidence command.
#
# Covers:
#   a named session id          -- the header, the touched files, the
#                                  write-shaped bash command and the last text
#   a transcript path           -- resolves the same file
#   --cwd PATH --latest         -- picks the newest session that ran in the tree,
#                                  not the newest in the store
#   a missing store             -- rc 1, the store named
#   an id that matches nothing  -- rc 1, the id named
#
# The fixtures sit under a per-test fixture store, outside the repo tree.
#
# Run:   bash tests/test_session_evidence.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

COMMAND="$REPO_ROOT/workflow/coding-agent/skills/recovery/scripts/pi/session_evidence.mjs"

# write_session PATH CWD ID START TEXT
write_session() {
  local path="$1" cwd="$2" id="$3" start="$4" text="$5"
  mkdir -p "$(dirname "$path")"
  {
    printf '{"type":"session","version":3,"id":"%s","timestamp":"%s","cwd":"%s"}\n' "$id" "$start" "$cwd"
    printf '{"type":"model_change","id":"m1","timestamp":"%s","provider":"test-provider","modelId":"test-model"}\n' "$start"
    printf '{"type":"message","id":"a1","timestamp":"%s","message":{"role":"assistant","content":[{"type":"toolCall","name":"write","arguments":{"path":"devlog/test.md"}},{"type":"toolCall","name":"edit","arguments":{"file_path":"devlog/test.md"}},{"type":"toolCall","name":"bash","arguments":{"command":"git commit -F msg.txt"}},{"type":"toolCall","name":"bash","arguments":{"command":"git status 2>/dev/null"}},{"type":"text","text":"%s"}]}}\n' "$start" "$text"
  } > "$path"
}

test_named_id_prints_the_evidence() {
  local store out rc=0
  store="$(get_test_dir)"
  write_session "$store/--tmp-project--/2026-11-01T00-00-00-000Z_id-one.jsonl" "/tmp/project" "id-one" "2026-11-01T00:00:00.000Z" "the work landed"
  out="$(node "$COMMAND" id-one --store "$store" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a named id resolves'
  assert_contains "$out" 'id-one' 'the header names the session'
  assert_contains "$out" '/tmp/project' 'the header names the tree'
  assert_contains "$out" 'devlog/test.md' 'the touched file is listed'
  assert_contains "$out" 'git commit' 'the write-shaped command is listed'
  assert_not_contains "$out" 'git status' 'a read-only command is not listed'
  assert_not_contains "$out" '2>/dev/null' 'a stderr redirect is not a write-shaped command'
  assert_contains "$out" 'the work landed' 'the last assistant text is printed'
}

test_path_resolves_the_same_file() {
  local store session out rc=0
  store="$(get_test_dir)"
  session="$store/--tmp-project--/2026-11-01T00-00-00-000Z_id-path.jsonl"
  write_session "$session" "/tmp/project" "id-path" "2026-11-01T00:00:00.000Z" "landed by path"
  out="$(node "$COMMAND" "$session" --store "$store" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a transcript path resolves'
  assert_contains "$out" 'id-path' 'the path resolves to its session'
  assert_contains "$out" 'landed by path' 'the path prints the last text'
}

test_cwd_latest_picks_the_newest_in_that_tree() {
  local store out rc=0
  store="$(get_test_dir)"
  write_session "$store/--tmp-one--/2026-11-01T00-00-00-000Z_id-old.jsonl" "/tmp/one" "id-old" "2026-11-01T00:00:00.000Z" "older"
  write_session "$store/--tmp-one--/2026-11-02T00-00-00-000Z_id-new.jsonl" "/tmp/one" "id-new" "2026-11-02T00:00:00.000Z" "newer"
  write_session "$store/--tmp-two--/2026-11-03T00-00-00-000Z_id-other.jsonl" "/tmp/two" "id-other" "2026-11-03T00:00:00.000Z" "other tree"
  out="$(node "$COMMAND" --cwd /tmp/one --latest --store "$store" 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'a cwd lookup resolves'
  assert_contains "$out" 'id-new' 'the newest session in that tree is chosen'
  assert_not_contains "$out" 'id-other' 'a newer session in another tree is not chosen'
}

test_missing_store_is_named() {
  local root out rc=0
  root="$(get_test_dir)"
  out="$(node "$COMMAND" id-one --store "$root/nope" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'a missing store exits 1'
  assert_contains "$out" 'session store not found' 'the failure names the store'
}

test_unknown_id_is_named() {
  local store out rc=0
  store="$(get_test_dir)"
  write_session "$store/--tmp-project--/2026-11-01T00-00-00-000Z_id-one.jsonl" "/tmp/project" "id-one" "2026-11-01T00:00:00.000Z" "the work landed"
  out="$(node "$COMMAND" id-absent --store "$store" 2>&1)" || rc=$?
  assert_rc 1 "$rc" 'an unknown id exits 1'
  assert_contains "$out" "no session matches id 'id-absent'" 'the failure names the id'
}

run_test test_named_id_prints_the_evidence
run_test test_path_resolves_the_same_file
run_test test_cwd_latest_picks_the_newest_in_that_tree
run_test test_missing_store_is_named
run_test test_unknown_id_is_named

test_done
