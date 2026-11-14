#!/usr/bin/env bash
# tests/test_commit_hook.sh
# The `commit-msg` hook in `.githooks/` runs the message check through a real
# `git commit`: a non-conforming message is refused, a conforming one lands, and
# without `core.hooksPath` the hook is inert -- the seeding gap, stated.
#
# Covers:
#   bad message    -- `impl:` is refused by the hook, naming the policy layer
#   good message   -- a conforming message commits
#   unregistered   -- with no core.hooksPath the same bad message commits

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

seed_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts" "$repo/.githooks" \
    "$repo/.agents/skills/git-discipline/references"
  cp "$REPO_ROOT/scripts/check_commit_message.sh" "$repo/scripts/"
  cp "$REPO_ROOT/.agents/skills/git-discipline/references/commit-types.md" \
    "$repo/.agents/skills/git-discipline/references/"
  cp "$REPO_ROOT/.githooks/commit-msg" "$repo/.githooks/"
  chmod +x "$repo/.githooks/commit-msg" "$repo/scripts/check_commit_message.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'x\n' > "$repo/file.txt"
  git -C "$repo" add -A
}

test_hook_refuses_a_bad_message() {
  local repo out rc=0
  repo="$FIXTURE_DIR/repo"
  seed_repo "$repo"
  git -C "$repo" config core.hooksPath .githooks
  printf 'impl: do the thing\n' > "$repo/msg.txt"
  out="$(cd "$repo" && git commit -F msg.txt 2>&1)" || rc=$?
  assert_rc 1 "$rc" "the hook refuses the commit" || return 1
  assert_contains "$out" "policy: the type 'impl' is not an active type" "the hook's refusal reaches the committer"
}

test_hook_passes_a_good_message() {
  local repo out rc=0
  repo="$FIXTURE_DIR/repo"
  seed_repo "$repo"
  git -C "$repo" config core.hooksPath .githooks
  printf 'feat: add the thing\n\nA reason under the body budget.\n' > "$repo/msg.txt"
  out="$(cd "$repo" && git commit -F msg.txt 2>&1)" || rc=$?
  assert_rc 0 "$rc" "the hook passes a conforming commit" || return 1
  assert_contains "$out" "feat: add the thing" "the commit is created"
}

test_hook_is_inert_without_the_path() {
  local repo out rc=0
  repo="$FIXTURE_DIR/repo"
  seed_repo "$repo"
  printf 'impl: do the thing\n' > "$repo/msg.txt"
  out="$(cd "$repo" && git commit -F msg.txt 2>&1)" || rc=$?
  assert_rc 0 "$rc" "without core.hooksPath the hook does not run" || return 1
  assert_contains "$out" "impl: do the thing" "the unseeded clone accepts the unchecked message"
}

run_test test_hook_refuses_a_bad_message
run_test test_hook_passes_a_good_message
run_test test_hook_is_inert_without_the_path

test_done
