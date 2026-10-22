#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_replay_criteria.sh
# Behavioural tests for scripts/replay_criteria.sh -- the lever that runs the
# Verification cell of every acceptance-criteria row and compares the result
# with the row's own mark.
#
# Covers:
#   a command that succeeds on a marked row     --  the row is `holds`
#   a command that fails on a marked row        --  the row is `FAILS-MARK`,
#                                                   named with file, line,
#                                                   criterion and command
#   a command on the deny list                  --  the row is `refused` and
#                                                   the command never ran
#   a prose verification cell                   --  the row is `unverified`
#   an open row whose command succeeds          --  the row is `would-pass`
#   --fail-on-failures                          --  rc 1 on a fixture holding
#                                                   a contradiction, rc 0 on a
#                                                   fixture holding none
#   --report                                    --  leaves the scanned tree
#                                                   unchanged
#
# Each test builds its own git repository under $FIXTURE_DIR, because the
# replay cuts a worktree from the root it is given. The handovers, the files a
# command checks and the deny-list marker are committed there, so the worktree
# holds them and the fixture root is the only subject.
#
# Run:   bash tests/test_replay_criteria.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

REPLAY="$REPO_ROOT/scripts/replay_criteria.sh"

# write_handover PATH STATUS ROW...  --  a conforming handover whose criteria
# table carries one row per argument, each spelled `criterion|verification|mark`.
write_handover() {
  local path="$1" status="$2"
  shift 2
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'date: 2026-10-04\n'
    printf 'milestone: T1 - Test\n'
    printf 'type: Workflow\n'
    printf 'status: %s\n' "$status"
    printf -- '---\n\n'
    printf '# Handover - Test\n\n'
    printf '## Objective\n\nTest.\n\n'
    printf '## Scope\n\nTest.\n\n'
    printf '## Acceptance criteria\n\n'
    printf '| Criterion | Verification | Result |\n'
    printf '|---|---|---|\n'
    local row
    for row in "$@"; do
      printf '| %s |\n' "${row//|/ | }"
    done
    printf '\n## Decisions\n\nNone.\n\n'
    printf '## Decisions pending\n\nNone.\n\n'
    printf '## Findings\n\nNone.\n\n'
    printf '## Completed\n\nNo file changes this iteration.\n'
  } > "$path"
}

# new_repo DIR  --  the tracked files a fixture command checks.
new_repo() {
  local dir="$1"
  mkdir -p "$dir/devlog/handovers"
  printf 'root\n' > "$dir/AGENTS.md"
  printf 'keep\n' > "$dir/keep.txt"
}

# seal_repo DIR  --  commit the fixture, so the replay can cut a worktree.
seal_repo() {
  local dir="$1"
  git -c init.defaultBranch=main init -q "$dir"
  git -C "$dir" add -A
  git -C "$dir" -c user.email=test@example.invalid -c user.name=Test \
    -c commit.gpgsign=false commit -qm fixture
}

# contradiction_repo DIR  --  one repository with three handovers: a hold and
# an open row that pass, a failing marked row, a prose row, and a denied row.
contradiction_repo() {
  local dir="$1"
  new_repo "$dir"
  write_handover "$dir/devlog/handovers/20261004-01-workflow-a.md" Active \
    'The repository root is present|`test -f AGENTS.md`|Agent [x]' \
    'The repository root is present again|`test -f AGENTS.md`|Agent [ ]'
  write_handover "$dir/devlog/handovers/20261004-02-workflow-b.md" Closed \
    'The lock file is absent|`test -f missing.md`|Agent [x]' \
    'The output reads clean|read the output line|Agent [x]'
  write_handover "$dir/devlog/handovers/20261004-03-workflow-c.md" Closed \
    "The keep file is removed|\`grep -c root AGENTS.md > $dir/marker.txt\`|Agent [x]"
  seal_repo "$dir"
}

test_command_success_holds() {
  local root="$FIXTURE_DIR/fx" out rc=0
  contradiction_repo "$root"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --report 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'the report mode exits 0 when it ran'
  assert_contains "$out" \
    'devlog/handovers/20261004-01-workflow-a.md: 2 row(s), holds=1, fails-mark=0, would-pass=1, unverified=0, refused=0, timeout=0' \
    'a successful marked command is a hold, and its open twin would pass'
}

test_command_failure_contradicts_mark() {
  local root="$FIXTURE_DIR/fx" out rc=0 line
  contradiction_repo "$root"
  line="$(grep -n 'The lock file is absent' "$root/devlog/handovers/20261004-02-workflow-b.md" | cut -d: -f1)"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --report 2>&1)" || rc=$?
  assert_contains "$out" \
    "FAILS-MARK devlog/handovers/20261004-02-workflow-b.md:$line The lock file is absent :: test -f missing.md" \
    'a failing marked command is named with its file, line, criterion and command'
}

test_denied_command_is_refused() {
  local root="$FIXTURE_DIR/fx" out rc=0
  contradiction_repo "$root"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --report 2>&1)" || rc=$?
  assert_contains "$out" \
    'devlog/handovers/20261004-03-workflow-c.md: 1 row(s), holds=0, fails-mark=0, would-pass=0, unverified=0, refused=1, timeout=0' \
    'a denied command is reported as refused'
  if [[ -e "$root/marker.txt" ]]; then
    fail 'the denied command never ran (it wrote its redirect target)'
  else
    pass 'the denied command never ran (its redirect target is absent)'
  fi
}

test_prose_row_is_unverified() {
  local root="$FIXTURE_DIR/fx" out rc=0
  contradiction_repo "$root"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --report 2>&1)" || rc=$?
  assert_contains "$out" \
    'devlog/handovers/20261004-02-workflow-b.md: 2 row(s), holds=0, fails-mark=1, would-pass=0, unverified=1, refused=0, timeout=0' \
    'a prose verification cell is unverified, beside the failing command'
}

test_fail_on_failures_exits_one() {
  local root="$FIXTURE_DIR/fx" rc=0
  contradiction_repo "$root"
  bash "$REPLAY" --root "$root" --timeout 10 --fail-on-failures > /dev/null 2>&1 || rc=$?
  assert_rc 1 "$rc" 'a contradiction fails under --fail-on-failures'
}

test_fail_on_failures_clean_fixture_exits_zero() {
  local root="$FIXTURE_DIR/fx" out rc=0
  new_repo "$root"
  write_handover "$root/devlog/handovers/20261004-04-workflow-d.md" Active \
    'The repository root is present|`test -f AGENTS.md`|Agent [x]' \
    'The repository root is present again|`test -f AGENTS.md`|Agent [ ]'
  seal_repo "$root"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --fail-on-failures 2>&1)" || rc=$?
  assert_rc 0 "$rc" 'no contradicting row passes under --fail-on-failures'
  assert_contains "$out" 'replay-criteria: 2 row(s), 1 holds, 0 fails-mark, 0 unverified, 0 refused' \
    'the summary counts the corpus'
}

test_report_leaves_the_tree_clean() {
  local root="$FIXTURE_DIR/fx" out rc=0 dirty
  contradiction_repo "$root"
  out="$(bash "$REPLAY" --root "$root" --timeout 10 --report 2>&1)" || rc=$?
  dirty="$(git -C "$root" status --short)"
  assert_rc 0 "$rc" 'the report mode exits 0'
  assert_empty "$dirty" 'the report leaves the scanned tree unchanged'
}

run_test test_command_success_holds
run_test test_command_failure_contradicts_mark
run_test test_denied_command_is_refused
run_test test_prose_row_is_unverified
run_test test_fail_on_failures_exits_one
run_test test_fail_on_failures_clean_fixture_exits_zero
run_test test_report_leaves_the_tree_clean

test_done
