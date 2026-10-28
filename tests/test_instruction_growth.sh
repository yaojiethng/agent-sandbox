#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_instruction_growth.sh
# Behavioural tests for scripts/report_instruction_growth.sh, the report that
# counts how much of an instruction artifact's growth was appending.
#
# The script is a report and not a gate, so the assertions are about what it
# counts and what it prints, never about a refused exit.
#
# Covers:
#   a file grown by appends only      --  commits, grew and append all counted
#   a file that shrank once           --  the shrinking commit is reported as
#                                         the newest one, not the oldest
#   a deletion in a later commit      --  append stops counting for that commit
#   --detail                          --  one line per pure-append commit
#   a path that is not there          --  named as absent, rc 1, other rows still
#                                         printed
#   a file with no history            --  reported as such, no crash
#   a directory that is not a repo    --  rc 2, refused before any work
#   the default target set            --  runs in this repository and finds the
#                                         two `AGENTS.md` layers
#
# Every fixture is a throwaway git repository under $FIXTURE_DIR, so the
# repository's own history is never the subject.
#
# Run:   bash tests/test_instruction_growth.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

SCRIPT="$REPO_ROOT/scripts/report_instruction_growth.sh"

# new_repo  --  a git repository with an identity, so commits are possible.
new_repo() {
  local dir
  dir="$(get_fixture_dir)"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  printf '%s\n' "$dir"
}

# commit_file REPO MESSAGE CONTENT  --  write CONTENT to note.md and commit it.
commit_file() {
  local repo="$1" message="$2" content="$3"
  printf '%s\n' "$content" >"$repo/note.md"
  git -C "$repo" add note.md
  git -C "$repo" commit -q -m "$message"
}

# field TABLE COLUMN  --  the value in one column of the data row, by header name.
# The header is line 4 of the report and the first data row is line 5.
field() {
  local out="$1" name="$2"
  printf '%s\n' "$out" | awk -v want="$name" '
    NR == 4 { for (i = 1; i <= NF; i++) if ($i == want) col = i; next }
    NR == 5 && col { print $col }
  '
}

test_pure_appends_are_counted() {
  local repo out
  repo="$(new_repo)"
  commit_file "$repo" first "a"
  commit_file "$repo" second "$(printf 'a\nb')"
  commit_file "$repo" third "$(printf 'a\nb\nc')"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" note.md 2>&1)"
  assert_contains "$out" "note.md" "the file is reported"
  assert_eq "$(field "$out" commits)" "3" "three commits touch the file"
  assert_eq "$(field "$out" grew)" "3" "creating a file is growth too"
  assert_eq "$(field "$out" append)" "3" "no commit deleted anything"
  assert_eq "$(field "$out" last-shrank)" "-" "nothing ever made it smaller"
}

test_the_newest_shrinking_commit_is_reported() {
  local repo out old new
  repo="$(new_repo)"
  commit_file "$repo" grow "$(printf 'a\nb\nc')"
  old="$(git -C "$repo" rev-parse --short HEAD)"
  commit_file "$repo" shrink "a"
  new="$(git -C "$repo" rev-parse --short HEAD)"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" note.md 2>&1)"
  assert_eq "$(field "$out" last-shrank)" "$new" "the later commit wins"
  assert_ne "$(field "$out" last-shrank)" "$old" "not the earlier one"
}

test_a_deleting_commit_is_not_an_append() {
  local repo out
  repo="$(new_repo)"
  commit_file "$repo" grow "$(printf 'a\nb\nc')"
  commit_file "$repo" replace "$(printf 'a\nb\nc\nd')"
  commit_file "$repo" both "$(printf 'a\nb\nd')"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" note.md 2>&1)"
  assert_eq "$(field "$out" commits)" "3" "all three commits counted"
  assert_eq "$(field "$out" append)" "2" "the third deleted a line, so it is not one"
}

test_detail_lists_each_append() {
  local repo out
  repo="$(new_repo)"
  commit_file "$repo" first "a"
  commit_file "$repo" second "$(printf 'a\nb')"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" note.md --detail 2>&1)"
  assert_contains "$out" "append" "the detail line is printed"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^    append  [0-9a-f]')" "2" "one line per append"
}

test_an_absent_path_is_named_and_others_still_print() {
  local repo out rc
  repo="$(new_repo)"
  commit_file "$repo" first "a"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" gone.md note.md 2>&1)"
  rc=$?
  assert_contains "$out" "gone.md" "the absent path is named"
  assert_contains "$out" "absent" "and marked absent"
  assert_contains "$out" "note.md" "the real path is still reported"
  assert_rc 1 "$rc" "an absent path sets a non-zero exit, and only that"
}

test_a_file_with_no_history_is_reported_not_crashed() {
  local repo out
  repo="$(new_repo)"
  commit_file "$repo" first "a"
  printf 'untracked\n' >"$repo/fresh.md"

  out="$(INSTRUCTION_GROWTH_ROOT="$repo" bash "$SCRIPT" fresh.md 2>&1)"
  assert_contains "$out" "no history" "a file git has never seen is reported as such"
}

test_a_non_repository_is_refused() {
  local dir out rc
  dir="$(get_fixture_dir)"
  out="$(INSTRUCTION_GROWTH_ROOT="$dir" bash "$SCRIPT" note.md 2>&1)"
  rc=$?
  assert_rc 2 "$rc" "a non-repository is a usage error"
  assert_contains "$out" "not a git repository" "the reason is named"
}

test_the_default_set_finds_both_layers() {
  local out
  out="$(bash "$SCRIPT" 2>&1)"
  if printf '%s\n' "$out" | grep -q '^AGENTS\.md '; then
    pass "the project layer is in the default set"
  else
    fail "the project layer is in the default set"
  fi
  assert_contains "$out" "src/reasoning/providers/pi/config/agent/AGENTS.md" "and the provider layer"
  assert_contains "$out" "report only" "the run states that nothing is refused"
}

run_test test_pure_appends_are_counted
run_test test_the_newest_shrinking_commit_is_reported
run_test test_a_deleting_commit_is_not_an_append
run_test test_detail_lists_each_append
run_test test_an_absent_path_is_named_and_others_still_print
run_test test_a_file_with_no_history_is_reported_not_crashed
run_test test_a_non_repository_is_refused
run_test test_the_default_set_finds_both_layers

test_done
