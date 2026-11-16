#!/usr/bin/env bash
# tests/test_commit_message_check.sh
# Cases for `scripts/check_commit_message.sh`: the Conventional Commits grammar
# and the project's policy, over the real type reference and a fixture one.
#
# Covers:
#   passing           -- a conforming message exits 0
#   unknown type      -- `impl:` is refused as policy
#   long subject      -- 73 characters is refused as policy
#   scope field       -- `feat(api):` is refused as policy
#   long body         -- 281 characters is refused as policy
#   no blank line     -- a body on line 2 is refused as grammar
#   no space          -- `feat:` without the space is refused as grammar
#   breaking marker   -- `feat!:` is accepted by the grammar
#   fixture types     -- a type added to the fixture reference is accepted there
#                        and refused against the real one

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$REPO_ROOT/scripts/check_commit_message.sh"

msg_file() {
  printf '%s' "$1" > "$FIXTURE_DIR/message.txt"
  printf '%s' "$FIXTURE_DIR/message.txt"
}

test_passing() {
  local f
  f="$(msg_file $'feat: add the commit message check\n\nA reason under the body budget.')"
  assert_run 0 "$CHECK '$f'" "a conforming message passes" || return 1
}

test_unknown_type() {
  local f
  f="$(msg_file 'impl: do the thing')"
  assert_run 1 "$CHECK '$f'" "an unknown type fails" || return 1
  assert_contains "$RUN_OUT" "policy: the type 'impl' is not an active type" "the layer and the type are named"
  assert_contains "$RUN_OUT" "(feat, fix" "the refusal names the active set, so a first attempt can recover"
}

test_long_subject() {
  local f long
  long="feat: $(printf 'a%.0s' {1..67})"
  f="$(msg_file "$long")"
  assert_run 1 "$CHECK '$f'" "a 73-character subject fails" || return 1
  assert_contains "$RUN_OUT" "policy: the subject is 73 characters; 72 at most" "the length and the budget are named"
}

test_scope_field() {
  local f
  f="$(msg_file 'feat(api): add the thing')"
  assert_run 1 "$CHECK '$f'" "a scope field fails" || return 1
  assert_contains "$RUN_OUT" "policy: the project does not use a scope field" "the policy layer is named"
}

test_long_body() {
  local f body
  body="$(printf 'b%.0s' {1..281})"
  f="$(msg_file "feat: add the thing"$'\n\n'"$body")"
  assert_run 1 "$CHECK '$f'" "a 281-character body fails" || return 1
  assert_contains "$RUN_OUT" "policy: the body is 281 characters; 280 at most" "the body length is named"
}

test_no_blank_line() {
  local f
  f="$(msg_file $'feat: add the thing\nbody right after the subject')"
  assert_run 1 "$CHECK '$f'" "a body without a blank line fails" || return 1
  assert_contains "$RUN_OUT" "grammar: a blank line must separate the subject and the body" "the grammar layer is named"
}

test_no_space_after_colon() {
  local f
  f="$(msg_file 'feat:add the thing')"
  assert_run 1 "$CHECK '$f'" "a missing space after the colon fails" || return 1
  assert_contains "$RUN_OUT" "grammar: the subject must read" "the grammar layer is named"
}

test_breaking_marker() {
  local f
  f="$(msg_file 'feat!: add the thing')"
  assert_run 0 "$CHECK '$f'" "a breaking marker is grammar, not a policy failure" || return 1
}

test_fixture_types() {
  local root f
  root="$FIXTURE_DIR/root"
  mkdir -p "$root/workflow/coding-agent/skills/git-discipline/references"
  cat > "$root/workflow/coding-agent/skills/git-discipline/references/commit-types.md" <<'EOF'
# Commit types

## The active types

| Type | When to use |
|---|---|
| `feat` | New capability |
| `perf` | Performance |

## Future types

| Type | When |
|---|---|
EOF
  f="$(msg_file 'perf: speed up the check')"
  assert_run 0 "$CHECK --root='$root' '$f'" "a type in the fixture set is accepted there" || return 1
  assert_run 1 "$CHECK '$f'" "the same type is refused against the real set" || return 1
  assert_contains "$RUN_OUT" "not an active type" "the real set is the one that refused it"
}

run_test test_passing
run_test test_unknown_type
run_test test_long_subject
run_test test_scope_field
run_test test_long_body
run_test test_no_blank_line
run_test test_no_space_after_colon
run_test test_breaking_marker
run_test test_fixture_types

test_done
