#!/usr/bin/env bash
# tests/test_git_hook.sh
# Behavioural tests for the copy-delivery pre-commit Markdown hook.
#
# Covers:
#   hook blocks         --  a staged Markdown finding fails the commit, bypass named
#   hook passes         --  a clean staged Markdown file commits
#   hook scope          --  a non-Markdown commit never invokes the linter
#   hook args           --  each linter receives its own staged files and flags
#   hook deletion       --  a staged Markdown deletion is not linted
#   hook missing tool   --  a missing linter prints a note and allows the commit
#   hook directive hint --  an unparseable shellcheck directive is explained
#   entrypoint install  --  copy delivery installs an executable hook
#   entrypoint skip     --  mount delivery installs no hook
#   entrypoint copy     --  copy delivery writes workspace paths and reconciles identity
#   entrypoint abort    --  copy delivery against an unseeded volume fails closed
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
# call's argument list to DIR/mdl-calls and exiting RC.
make_lint_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/markdownlint-cli2" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$dir/mdl-calls"
exit $rc
EOF
  chmod +x "$dir/bin/markdownlint-cli2"
}

# make_sc_stub DIR RC  --  a fake shellcheck on PATH recording every call's
# argument list to DIR/sc-calls and exiting RC.
make_sc_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/shellcheck" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$dir/sc-calls"
exit $rc
EOF
  chmod +x "$dir/bin/shellcheck"
}

# make_sc_directive_stub DIR  --  a fake shellcheck that reports an unparseable
# directive and exits 1, the shape the hook recognises and explains.
make_sc_directive_stub() {
  local dir="$1"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/shellcheck" <<EOF
#!/usr/bin/env bash
printf "%s\n" "Couldn't parse this shellcheck directive"
exit 1
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
    exec bash "$dir/entrypoint.sh" ) >"$dir/log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 100); do
    grep -q "Git hook installed\|ALL CHECKS PASSED" "$dir/log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  # Settle grace: the readiness marker prints before the TERM trap registers, so
  # give the exec'd process time to reach `trap ... TERM` before the SIGTERM; a
  # signal landing on the un-trapped script makes wait return 143.
  sleep 0.2
  kill -TERM "$pid" 2>/dev/null
  wait "$pid"
  EP_RC=$?
  EP_OUT=$(cat "$dir/log")
}

# ---------------------------------------------------------------------------
# Hook behaviour
# ---------------------------------------------------------------------------

# Given: a repo with the installed hook, a markdownlint stub exiting 1, and a staged bad.md
# When:  git commit runs
# Then:  the commit is refused and the output names the --no-verify bypass
# Asserts: a Markdown finding blocks the commit and the linter receives the staged file with its glob policy
# Note:  the stub records the argument list, so the staged file and --no-globs are asserted directly
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
  assert_contains "$(cat "$dir/mdl-calls")" "bad.md" "markdownlint received the staged Markdown file"
  assert_contains "$(cat "$dir/mdl-calls")" "--no-globs" "markdownlint ran with --no-globs"
}

# Given: a repo with the installed hook, a markdownlint stub exiting 0, and a staged good.md
# When:  git commit runs
# Then:  the commit succeeds
# Asserts: a clean Markdown file passes the gate
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

# Given: a repo with the installed hook, a shellcheck stub exiting 1, and a staged bad.sh
# When:  git commit runs
# Then:  the commit is refused and the output names the ShellCheck gate and the bypass
# Asserts: a ShellCheck finding blocks the commit and shellcheck receives the staged file at the warning severity
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
  assert_contains "$(cat "$dir/sc-calls")" "bad.sh" "shellcheck received the staged shell file"
  assert_contains "$(cat "$dir/sc-calls")" "-S warning" "shellcheck ran at the warning severity"
}

# Given: a repo with the installed hook, both stubs exiting 0, and a staged clean.sh
# When:  git commit runs
# Then:  the commit succeeds and markdownlint was never invoked
# Asserts: the shell gate passes and the Markdown gate stays out of a shell-only commit
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

# Given: a repo with the installed hook, a shellcheck stub exiting 1, and a staged notes.txt
# When:  git commit runs
# Then:  the commit succeeds and shellcheck was never invoked
# Asserts: the shell gate reads only staged shell files
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

# Given: a repo with the installed hook, both stubs exiting 0, and a staged good.md plus clean.sh
# When:  git commit runs
# Then:  the commit succeeds and both linters were invoked
# Asserts: a mixed commit runs both gates, each against its own staged file set
# Note:  the stubs record their argument lists, so file-list separation is asserted directly
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
  assert_contains "$(cat "$dir/mdl-calls")" "good.md" "Markdown gate received its own staged file"
  assert_not_contains "$(cat "$dir/mdl-calls")" "clean.sh" "Markdown gate did not receive the shell file"
  assert_contains "$(cat "$dir/sc-calls")" "clean.sh" "ShellCheck gate received its own staged file"
  assert_not_contains "$(cat "$dir/sc-calls")" "good.md" "ShellCheck gate did not receive the Markdown file"
}

# Given: a repo with the installed hook, a markdownlint stub exiting 1, and a staged notes.txt
# When:  git commit runs
# Then:  the commit succeeds and the linter was never invoked
# Asserts: the Markdown gate reads only staged Markdown files
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

# Given: a repo with the installed hook and a committed bad.md removed from the index
# When:  git commit runs with a markdownlint double that would fail
# Then:  the commit succeeds and markdownlint is never invoked
# Asserts: the --diff-filter=ACMR staged-deletion exclusion
test_hook_skips_staged_markdown_deletion() {
  local dir="$FIXTURE_DIR/hook_deletion"
  make_repo "$dir/repo"
  echo "# bad" > "$dir/repo/bad.md"
  git -C "$dir/repo" add bad.md
  git -C "$dir/repo" commit -q -m "add bad"
  make_lint_stub "$dir" 1
  install -m 0755 "$HOOK_SRC" "$dir/repo/.git/hooks/pre-commit"
  git -C "$dir/repo" rm -q bad.md

  local rc=0
  (cd "$dir/repo" && PATH="$dir/bin:$PATH" git commit -q -m "remove bad") || rc=$?
  assert_rc 0 "$rc" "hook allows a commit that only deletes a Markdown file"
  assert_run 1 "test -f '$dir/mdl-calls'" "markdownlint never ran on a staged deletion"
}

# Given: a staged Markdown file and a PATH with no markdownlint-cli2
# When:  the hook runs
# Then:  it prints the tool-missing note and allows the commit
# Asserts: the ADR's missing-tool behaviour for the Markdown gate
test_hook_allows_when_markdownlint_missing() {
  local dir="$FIXTURE_DIR/hook_nomdl"
  make_repo "$dir/repo"
  mkdir -p "$dir/bin"
  ln -s "$(command -v git)" "$dir/bin/git"
  echo "# bad" > "$dir/repo/bad.md"
  git -C "$dir/repo" add bad.md

  local out rc=0
  out="$(cd "$dir/repo" && PATH="$dir/bin" "$BASH" "$HOOK_SRC" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "hook allows the commit when markdownlint is missing"
  assert_contains "$out" "markdownlint-cli2 not found" "hook prints the missing-tool note"
}

# Given: a staged shell file and a PATH with no shellcheck
# When:  the hook runs
# Then:  it prints the tool-missing note and allows the commit
# Asserts: the ADR's missing-tool behaviour for the ShellCheck gate
test_hook_allows_when_shellcheck_missing() {
  local dir="$FIXTURE_DIR/hook_nosc"
  make_repo "$dir/repo"
  mkdir -p "$dir/bin"
  ln -s "$(command -v git)" "$dir/bin/git"
  echo "echo clean" > "$dir/repo/clean.sh"
  git -C "$dir/repo" add clean.sh

  local out rc=0
  out="$(cd "$dir/repo" && PATH="$dir/bin" "$BASH" "$HOOK_SRC" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "hook allows the commit when shellcheck is missing"
  assert_contains "$out" "shellcheck not found" "hook prints the missing-tool note"
}

# Given: a shellcheck double reporting an unparseable shellcheck directive
# When:  the hook runs on a staged shell file
# Then:  it fails and explains that a comment starting with 'shellcheck' is parsed as a directive
# Asserts: the directive-parse hint branch
test_hook_explains_shellcheck_directive_parse_error() {
  local dir="$FIXTURE_DIR/sc_directive"
  make_repo "$dir/repo"
  make_sc_directive_stub "$dir"
  echo "echo x" > "$dir/repo/bad.sh"
  git -C "$dir/repo" add bad.sh

  local out rc=0
  out="$(cd "$dir/repo" && PATH="$dir/bin:$PATH" "$BASH" "$HOOK_SRC" 2>&1)" || rc=$?
  assert_ne "$rc" "0" "hook fails on the unparseable directive"
  assert_contains "$out" "is parsed as a directive" "hook explains the directive-parse failure"
  assert_contains "$out" "Reword the line" "hook gives the reword hint"
}

# ---------------------------------------------------------------------------
# Entrypoint install / skip
# ---------------------------------------------------------------------------

# Given: a copy-delivery entrypoint copy and a repo carrying SESSION_STATE
# When:  the entrypoint runs
# Then:  it reports the hook install and leaves an executable .git/hooks/pre-commit
# Asserts: copy delivery installs the hook and writes the workspace path fields
# Note:  the tool-absent path is covered by the dedicated missing-tool units
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

  local state
  state="$(cat "$repo/.git/SESSION_STATE")"
  assert_contains "$state" "changes_dir=" "copy entrypoint writes changes_dir into SESSION_STATE"
  assert_contains "$state" "input_dir=" "copy entrypoint writes input_dir into SESSION_STATE"
  assert_contains "$state" "output_dir=" "copy entrypoint writes output_dir into SESSION_STATE"
}

# Given: a copy-delivery entrypoint copy and a sandbox directory with no .git
# When:  the entrypoint runs
# Then:  it exits non-zero and names the unseeded volume
# Asserts: the copy branch fails closed instead of starting against an empty volume
test_entrypoint_aborts_unseeded_copy_volume() {
  local dir="$FIXTURE_DIR/copy_unseeded"
  local repo="$dir/sandbox"
  mkdir -p "$repo" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"

  invoke_entrypoint "$dir" copy sandbox

  assert_ne "$EP_RC" "0" "copy entrypoint fails without git state"
  assert_contains "$EP_OUT" "has no git state" "copy entrypoint names the unseeded volume"
}

# Given: a seeded copy volume carrying an earlier session's identity
# When:  the copy entrypoint runs with new identity env
# Then:  SESSION_STATE is reconciled to the current session_id, session_ts, and host_head_sha
# Asserts: the copy-resume identity-upgrade block
test_entrypoint_copy_reconciles_stale_identity() {
  local dir="$FIXTURE_DIR/copy_upgrade"
  local repo="$dir/sandbox"
  mkdir -p "$repo" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  make_repo "$repo"
  printf 'init_sha=%s\nsession_ts=OLD\nsession_id=stale\nhost_head_sha=old\n' \
    "$(git -C "$repo" rev-parse HEAD)" > "$repo/.git/SESSION_STATE"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"

  invoke_entrypoint "$dir" copy sandbox

  if [[ "$EP_RC" -ne 0 ]]; then
    fail "copy upgrade: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  local state
  state="$(cat "$repo/.git/SESSION_STATE")"
  assert_contains "$state" "session_id=cpt000" "copy upgrade: session_id reconciled"
  assert_contains "$state" "session_ts=20260912-120000" "copy upgrade: session_ts reconciled"
  assert_contains "$state" "host_head_sha=cafebabe" "copy upgrade: host_head_sha reconciled"
}

# Given: a seeded copy volume whose SESSION_STATE already names the current session
# When:  the copy entrypoint runs
# Then:  the existing session_ts is not rewritten
# Asserts: the upgrade block fires only when the stored identity differs
test_entrypoint_copy_keeps_matching_identity() {
  local dir="$FIXTURE_DIR/copy_match"
  local repo="$dir/sandbox"
  mkdir -p "$repo" "$dir/.workspace/session-diffs" \
           "$dir/.workspace/input" "$dir/.workspace/output"
  make_repo "$repo"
  printf 'init_sha=%s\nsession_ts=KEEPME\nsession_id=cpt000\nhost_head_sha=old\n' \
    "$(git -C "$repo" rev-parse HEAD)" > "$repo/.git/SESSION_STATE"
  sed "s|^ROOT=.*$|ROOT=$dir|" "$ENTRYPOINT" > "$dir/entrypoint.sh"

  invoke_entrypoint "$dir" copy sandbox

  if [[ "$EP_RC" -ne 0 ]]; then
    fail "copy match: entrypoint rc=$EP_RC: $EP_OUT"; return
  fi
  local last_ts
  last_ts="$(grep '^session_ts=' "$repo/.git/SESSION_STATE" | tail -1)"
  assert_eq "$last_ts" "session_ts=KEEPME" \
    "copy resume: matching identity is not rewritten"
}

# Given: a mount-delivery worktree carrying SESSION_STATE
# When:  the entrypoint runs
# Then:  no hook file exists in the worktree's .git/hooks
# Asserts: mount delivery installs no hook, because the host owns that .git
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
run_test test_hook_skips_staged_markdown_deletion
run_test test_hook_allows_when_markdownlint_missing
run_test test_hook_allows_when_shellcheck_missing
run_test test_hook_explains_shellcheck_directive_parse_error
run_test test_entrypoint_installs_hook_for_copy
run_test test_entrypoint_aborts_unseeded_copy_volume
run_test test_entrypoint_copy_reconciles_stale_identity
run_test test_entrypoint_copy_keeps_matching_identity
run_test test_entrypoint_skips_hook_for_mount

test_done
