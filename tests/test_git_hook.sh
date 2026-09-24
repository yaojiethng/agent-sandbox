#!/usr/bin/env bash
# tests/test_git_hook.sh
# Behavioural tests for the copy-delivery pre-commit Markdown hook.
#
# Covers:
#   hook blocks         --  a staged Markdown finding fails the commit, bypass named
#   hook passes         --  a clean staged Markdown file commits
#   hook scope          --  a non-Markdown commit never invokes the linter
#   entrypoint install  --  copy delivery installs an executable hook
#   entrypoint skip     --  mount delivery installs no hook
#
# The entrypoint tests run the real entrypoint with SANDBOX_LIB_DIR pointing at
# the stub lib dir (tests/stubs/libs), and GIT_HOOKS_DIR at the repo's hook
# source, so the install path is exercised without a built image.
#
# Run:   bash tests/test_git_hook.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

ENTRYPOINT="$REPO_ROOT/src/capability/entrypoint.sh"
HOOK_SRC="$REPO_ROOT/src/capability/git-hooks/pre-commit.sh"
STUB_LIB_DIR="$TEST_DIR/stubs/libs"

EP_RC=0
EP_OUT=""

# make_repo DIR  --  git repo with one commit on the default branch.
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@t"
  git -C "$dir" config user.name "t"
  echo baseline > "$dir/file.txt"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m baseline
}

# make_lint_stub DIR RC  --  a fake markdownlint-cli2 on PATH recording every
# call to DIR/mdl-calls and exiting RC.
make_lint_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/markdownlint-cli2" <<EOF
#!/usr/bin/env bash
echo called >> "$dir/mdl-calls"
exit $rc
EOF
  chmod +x "$dir/bin/markdownlint-cli2"
}

# make_sc_stub DIR RC  --  a fake shellcheck on PATH recording every call to
# DIR/sc-calls and exiting RC.
make_sc_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/shellcheck" <<EOF
#!/usr/bin/env bash
echo called >> "$dir/sc-calls"
exit $rc
EOF
  chmod +x "$dir/bin/shellcheck"
}

# invoke_entrypoint DIR TYPE SANDBOX_DIR_NAME
#   Runs the sed-patched entrypoint copy in the background, waits for the hook
#   install line or preflight completion, SIGTERMs it, and collects rc/output.
invoke_entrypoint() {
  local dir="$1" type="$2" sandbox_name="$3"
  ( cd "$dir" && SANDBOX_LIB_DIR="$STUB_LIB_DIR" \
    GIT_HOOKS_DIR="$REPO_ROOT/src/capability/git-hooks" \
    SANDBOX_TYPE="$type" \
    SANDBOX_DIR_NAME="$sandbox_name" \
    CHANGES_DIR="$dir/.workspace/session-diffs" \
    INPUT_DIR="$dir/.workspace/input" \
    OUTPUT_DIR="$dir/.workspace/output" \
    SESSION_TS="20260912-120000" SESSION_ID="cpt000" \
    HOST_HEAD_SHA="cafebabe" HOST_UID="$(id -u)" HOST_GID="$(id -g)" \
    RESET_VOLUME="false" \
    AUTOSAVE_INTERVAL=0 \
    bash "$dir/entrypoint.sh" ) >"$dir/log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 100); do
    grep -q "Git hook installed\|ALL CHECKS PASSED" "$dir/log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -TERM "$pid" 2>/dev/null
  wait "$pid"
  EP_RC=$?
  EP_OUT=$(cat "$dir/log")
}

# ---------------------------------------------------------------------------
# Hook behaviour
# ---------------------------------------------------------------------------

test_hook_blocks_staged_markdown_finding() {
  local dir="$FIXTURE_DIR/hook_block"
  make_repo "$dir/repo"
  make_lint_stub "$dir" 1
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo "# finding" > "$dir/repo/bad.md"
  git -C "$dir/repo" add bad.md

  local out rc=0
  out="$(cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -m "add bad" 2>&1)" || rc=$?
  assert_ne "$rc" "0" "hook blocks the commit on a staged Markdown finding"
  assert_contains "$out" "no-verify" "hook output names the --no-verify bypass"
}

test_hook_passes_clean_staged_markdown() {
  local dir="$FIXTURE_DIR/hook_pass"
  make_repo "$dir/repo"
  make_lint_stub "$dir" 0
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo "# clean" > "$dir/repo/good.md"
  git -C "$dir/repo" add good.md

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "add good") || rc=$?
  assert_rc 0 "$rc" "hook allows the commit when the linter passes"
}

test_hook_blocks_staged_shell_finding() {
  local dir="$FIXTURE_DIR/sc_block"
  make_repo "$dir/repo"
  make_sc_stub "$dir" 1
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo "echo broken" > "$dir/repo/bad.sh"
  git -C "$dir/repo" add bad.sh

  local out rc=0
  out="$(cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -m "add bad sh" 2>&1)" || rc=$?
  assert_ne "$rc" "0" "hook blocks the commit on a staged ShellCheck finding"
  assert_contains "$out" "ShellCheck findings" "hook names the ShellCheck gate in the failure"
  assert_contains "$out" "no-verify" "hook output names the --no-verify bypass"
}

test_hook_passes_clean_staged_shell() {
  local dir="$FIXTURE_DIR/sc_pass"
  make_repo "$dir/repo"
  make_lint_stub "$dir" 0
  make_sc_stub "$dir" 0
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo "echo clean" > "$dir/repo/clean.sh"
  git -C "$dir/repo" add clean.sh

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "add clean sh") || rc=$?
  assert_rc 0 "$rc" "hook allows the commit when ShellCheck passes"
  assert_run 1 "test -f '$dir/mdl-calls'" "a shell-only commit never invokes markdownlint"
}

test_hook_ignores_non_shell_commit() {
  local dir="$FIXTURE_DIR/sc_scope"
  make_repo "$dir/repo"
  make_sc_stub "$dir" 1
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo note > "$dir/repo/notes.txt"
  git -C "$dir/repo" add notes.txt

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "add notes") || rc=$?
  assert_rc 0 "$rc" "hook allows a commit with no staged shell"
  assert_run 1 "test -f '$dir/sc-calls'" "hook never invoked shellcheck for a non-shell commit"
}

test_hook_runs_both_gates_on_mixed_commit() {
  local dir="$FIXTURE_DIR/sc_mixed"
  make_repo "$dir/repo"
  make_lint_stub "$dir" 0
  make_sc_stub "$dir" 0
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo "# clean" > "$dir/repo/good.md"
  echo "echo clean" > "$dir/repo/clean.sh"
  git -C "$dir/repo" add good.md clean.sh

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "add both") || rc=$?
  assert_rc 0 "$rc" "hook allows a clean mixed Markdown + shell commit"
  assert_run 0 "test -f '$dir/mdl-calls'" "mixed commit invoked the Markdown gate"
  assert_run 0 "test -f '$dir/sc-calls'" "mixed commit invoked the ShellCheck gate"
}

test_hook_ignores_non_markdown_commit() {
  local dir="$FIXTURE_DIR/hook_scope"
  make_repo "$dir/repo"
  make_lint_stub "$dir" 1
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  echo change > "$dir/repo/notes.txt"
  git -C "$dir/repo" add notes.txt

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "add notes") || rc=$?
  assert_rc 0 "$rc" "hook allows a commit with no staged Markdown"
  assert_run 1 "test -f '$dir/mdl-calls'" "hook never invoked the linter for a non-Markdown commit"
}

# ---------------------------------------------------------------------------
# Entrypoint install / skip
# ---------------------------------------------------------------------------

test_entrypoint_installs_hook_for_copy() {
  local dir="$FIXTURE_DIR/copy_install"
  local repo="$dir/sandbox"
  mkdir -p "$repo" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  make_repo "$repo"
  printf 'init_sha=%s\nsession_ts=20260912-120000\n' \
    "$(git -C "$repo" rev-parse HEAD)" > "$repo/.git/SESSION_STATE"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"

  invoke_entrypoint "$dir" copy sandbox

  assert_rc 0 "$EP_RC" "copy entrypoint exits cleanly after the hook install"
  assert_contains "$EP_OUT" "Git hook installed" "copy entrypoint reports the hook install"
  assert_file_exists "$repo/.git/hooks/pre-commit" "copy delivery installs the pre-commit hook"
  assert_run 0 "test -x '$repo/.git/hooks/pre-commit'" "installed hook is executable"
}

test_entrypoint_skips_hook_for_mount() {
  local dir="$FIXTURE_DIR/mount_skip"
  local worktree="$dir/worktree"
  mkdir -p "$worktree" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  make_repo "$worktree"
  printf 'init_sha=%s\nsession_ts=20260912-120000\n' \
    "$(git -C "$worktree" rev-parse HEAD)" > "$worktree/.git/SESSION_STATE"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"

  invoke_entrypoint "$dir" mount worktree

  assert_run 1 "test -f '$worktree/.git/hooks/pre-commit'" \
    "mount delivery installs no hook (host-resident .git)"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_hook_blocks_staged_markdown_finding
run_test test_hook_passes_clean_staged_markdown
run_test test_hook_ignores_non_markdown_commit
run_test test_hook_blocks_staged_shell_finding
run_test test_hook_passes_clean_staged_shell
run_test test_hook_ignores_non_shell_commit
run_test test_hook_runs_both_gates_on_mixed_commit
run_test test_entrypoint_installs_hook_for_copy
run_test test_entrypoint_skips_hook_for_mount

test_done
