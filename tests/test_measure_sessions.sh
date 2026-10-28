#!/usr/bin/env bash
# tests/test_measure_sessions.sh
# Behavioural test for scripts/measure_sessions.mjs against a fixture store.
#
# The fixture is four sessions written by hand, so every expected count is
# stated in the test rather than measured from the real store:
#   s1  a pass, names a convention skill, two operator turns, one a correction
#   s2  a pass with no convention read
#   s3  a session that commits and writes no handover
#   s4  a pass that names a convention skill
#
# The script is read-only over the store; the test also asserts that.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

SCRIPT="$REPO_ROOT/scripts/measure_sessions.mjs"
STORE="$FIXTURE_DIR/store/session-a"

# session_line ROLE JSON_CONTENT -- one JSONL line carrying a message.
session_line() {
  printf '{"message":{"role":"%s","content":%s}}\n' "$1" "$2"
}

write_fixtures() {
  mkdir -p "$STORE"

  { # s1: a pass, a convention read, a correction turn
    session_line user '"first brief for pass one"'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"read","arguments":{"path":".agents/skills/task-list/SKILL.md"}}]}}\n'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"write","arguments":{"path":"devlog/handovers/20260101-01-x.md"}}]}}\n'
    session_line user '"no, that is wrong, redo it"'
    session_line user '"ok"'
  } > "$STORE/s1.jsonl"

  { # s2: a pass with no convention read and no correction
    session_line user '"second brief"'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"write","arguments":{"path":"devlog/handovers/20260101-02-y.md"}}]}}\n'
    session_line user '"carry on"'
  } > "$STORE/s2.jsonl"

  { # s3: commits, writes no handover, so it is not a pass
    session_line user '"third brief"'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"bash","arguments":{"command":"git commit -m wip"}}]}}\n'
  } > "$STORE/s3.jsonl"

  { # s4: a pass that names a convention skill through bash
    session_line user '"fourth brief"'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"bash","arguments":{"command":"grep -n x .agents/skills/work-log/SKILL.md"}}]}}\n'
    printf '{"message":{"role":"assistant","content":[{"type":"toolCall","name":"write","arguments":{"path":"devlog/handovers/20260101-03-z.md"}}]}}\n'
  } > "$STORE/s4.jsonl"
}

test_delivery_counts() {
  local out; out="$(node "$SCRIPT" delivery "$STORE")"
  assert_contains "$out" '"sessions":4' "four sessions read"
  assert_contains "$out" '"passes":3' "three passes: one session writes no handover"
  assert_contains "$out" '"commits":1' "one session commits"
  assert_contains "$out" '"slashOpeners":0' "no session opens with a slash command"
  assert_contains "$out" ".agents/skills/task-list/SKILL.md	1" "the task-list read is counted once"
  assert_contains "$out" ".agents/skills/work-log/SKILL.md	1" "the bash hit on work-log is counted"
  assert_contains "$out" ".agents/skills/project-documentation/SKILL.md	0" "an unread convention reports zero"
}

test_join_counts() {
  local out; out="$(node "$SCRIPT" join "$STORE")"
  assert_contains "$out" '"passes":3' "the join uses passes only"
  assert_contains "$out" '"exposed":2' "two passes name a convention"
  assert_contains "$out" '"unexposed":1' "one pass names none"
  assert_contains "$out" '"rateExposed":250' "the exposed arm reports its correction rate"
}

test_missing_store_fails_loudly() {
  local out rc
  out="$(node "$SCRIPT" delivery "$FIXTURE_DIR/absent" 2>&1)"; rc=$?
  assert_eq "$rc" "2" "a missing store exits 2"
  assert_contains "$out" "no session store at" "the failure names the path it tried"
}

test_store_is_not_modified() {
  local before after
  before="$(cd "$STORE" && cat s1.jsonl s2.jsonl s3.jsonl s4.jsonl | cksum)"
  node "$SCRIPT" delivery "$STORE" >/dev/null
  after="$(cd "$STORE" && cat s1.jsonl s2.jsonl s3.jsonl s4.jsonl | cksum)"
  assert_eq "$after" "$before" "the store is read-only"
}

write_fixtures
run_test test_delivery_counts
run_test test_join_counts
run_test test_missing_store_fails_loudly
run_test test_store_is_not_modified

test_done measure_sessions
