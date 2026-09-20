#!/usr/bin/env bash
# tests/test_lint_umbrella.sh
# Behavioural tests for scripts/lint.sh -- the umbrella static-check gate.
#
# Covers:
#   both gates pass       --  rc 0
#   shell gate fails      --  rc 1
#   markdown gate fails   --  rc 1
#   both gates fail       --  rc 1
#   both gates run        --  a shell failure does not skip the Markdown gate
#   the shellcheck tool absent  --  rc 1 (fails closed, never reports "clean")
#   the tool exits 2      --  rc 1 (tool could not run)
#   markdownlint absent   --  rc 1 (fails closed, never reports "clean")
#
# The exit code carries the verdict only; the finding count is printed by the
# leaf gate and never encoded (docs/development/bash-coding-conventions.md 3.2).
#
# The real scripts/lint.sh, check_shell.sh and check_markdown.sh run; only the
# external tools (shellcheck, markdownlint-cli2) are stubbed on PATH.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

LINT="$REPO_ROOT/scripts/lint.sh"

LINT_RC=0

# make_shellcheck_stub COUNT [RC]  --  prints COUNT warning markers, exits RC
# (default 0). RC 2 models a tool that could not run.
make_shellcheck_stub() {
  local dir="$1" count="$2" rc="${3:-0}"
  mkdir -p "$dir"
  cat > "$dir/shellcheck" <<EOF
#!/usr/bin/env bash
for _ in \$(seq 1 $count); do echo "  ^-- SC0000"; done
exit $rc
EOF
  chmod +x "$dir/shellcheck"
}

# make_mdl_stub RC  --  records its run, prints the tool's summary lines and,
# when RC is nonzero, an error line; exits RC. The Linting line is what the
# gate's zero-file guard reads.
make_mdl_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir"
  cat > "$dir/markdownlint-cli2" <<EOF
#!/usr/bin/env bash
echo ran >> "$dir/mdl.log"
echo "Linting: 2 files"
echo "Summary: 0 issues in 0 files"
if (( $rc != 0 )); then echo "fake.md:1 error MD000/test"; fi
exit $rc
EOF
  chmod +x "$dir/markdownlint-cli2"
}

# run_lint SHELL_WARNINGS MDL_RC  --  stubs both tools and runs the real
# umbrella gate. Sets LINT_RC.
run_lint() {
  local shell_warnings="$1" mdl_rc="$2"
  local bin="$FIXTURE_DIR/bin"
  make_shellcheck_stub "$bin" "$shell_warnings"
  make_mdl_stub "$bin" "$mdl_rc"
  rm -f "$bin/mdl.log"
  LINT_RC=0
  PATH="$bin:$PATH" bash "$LINT" >/dev/null 2>&1 || LINT_RC=$?
}

test_lint_passes_when_both_gates_pass() {
  run_lint 0 0
  assert_rc 0 "$LINT_RC" "both gates pass: lint exits 0"
}

test_lint_reports_shell_failure() {
  run_lint 2 0
  assert_rc 1 "$LINT_RC" "shell gate warns: lint exits 1 (verdict, not the count)"
}

test_lint_reports_markdown_failure() {
  run_lint 0 1
  assert_rc 1 "$LINT_RC" "markdown gate fails: lint exits 1"
}

test_lint_reports_both_gate_failures() {
  run_lint 3 1
  assert_rc 1 "$LINT_RC" "both gates fail: lint exits 1"
}

test_lint_runs_both_gates() {
  run_lint 1 1
  assert_file_exists "$FIXTURE_DIR/bin/mdl.log" "Markdown gate runs even after the shell gate fails"
}

test_missing_shellcheck_fails_closed() {
  # Build a PATH that has the gate's ordinary tools (find, sort, grep) but not
  # the shellcheck tool, so the gate must report it absent and refuse to
  # report clean. Symlinks keep the rest of the environment irrelevant.
  local bin="$FIXTURE_DIR/bin_noshell"
  mkdir -p "$bin"
  local tool
  for tool in find sort grep dirname basename; do
    ln -sf "$(command -v "$tool")" "$bin/$tool"
  done
  local rc=0 out
  out=$(PATH="$bin" "$BASH" "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "absent shellcheck: the gate fails closed"
  assert_contains "$out" "shellcheck is not installed" \
      "absent shellcheck: the gate names the cause"
}

test_shellcheck_tool_failure_fails_closed() {
  # The tool runs and exits 2 (unreadable input, internal error): the gate
  # must not report clean.
  local bin="$FIXTURE_DIR/bin_scfail"
  make_shellcheck_stub "$bin" 0 2
  local rc=0 out
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "shellcheck exits 2: the gate fails closed"
  assert_contains "$out" "cannot run the gate" "shellcheck exits 2: the gate names the cause"
}

test_markdown_tool_absent_fails_closed() {
  # Mirror of the shellcheck-absent case for the Markdown gate: no
  # markdownlint-cli2 on PATH and none in $HOME/.local/bin.
  local bin="$FIXTURE_DIR/bin_nomdl"
  mkdir -p "$bin"
  local tool
  for tool in find sort grep dirname basename; do
    ln -sf "$(command -v "$tool")" "$bin/$tool"
  done
  local rc=0 out
  out=$(HOME="$FIXTURE_DIR/nohome" PATH="$bin" "$BASH" "$REPO_ROOT/scripts/check_markdown.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "markdownlint absent: the gate fails closed"
  assert_contains "$out" "markdownlint-cli2 is not installed" \
      "markdownlint absent: the gate names the cause"
}



test_shellcheck_directive_trap_is_named() {
  # The tool's own wording distinguishes the directive trap from an ordinary
  # parse error. Only the directive case may receive the directive remedy.
  local bin="$FIXTURE_DIR/bin_scdir"
  mkdir -p "$bin"
  cat > "$bin/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "^-- SC1073 (error): Couldn't parse this shellcheck directive."
printf "%s\n" "^-- SC1072 (error): Expected '=' after directive key."
exit 1
EOF
  chmod +x "$bin/shellcheck"
  local rc=0 out
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "directive trap: the gate fails closed"
  assert_contains "$out" "parsed as a directive" "directive trap: the gate names the cause"
}

test_shellcheck_plain_parse_error_is_not_the_directive_trap() {
  # An ordinary syntax error also reports SC1072/SC1073. It must fall through to
  # the generic findings message, not receive a remedy that cannot work.
  local bin="$FIXTURE_DIR/bin_scparse"
  mkdir -p "$bin"
  cat > "$bin/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "^-- SC1073 (error): Couldn't parse this if expression."
printf "%s\n" "^-- SC1072 (error): Expected 'fi'."
exit 1
EOF
  chmod +x "$bin/shellcheck"
  local rc=0 out
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "plain parse error: the gate fails closed"
  if [[ "$out" == *"parsed as a directive"* ]]; then
    fail "plain parse error was misdiagnosed as the directive trap"
  else
    pass "plain parse error falls through to the generic message"
  fi
}





test_markdown_zero_lint_fails_closed() {
  # A config whose globs match nothing makes the tool lint zero files and exit
  # 0. The gate must not report Clean: the linted-file count, not the tracked
  # count, decides whether the gate ran.
  local bin="$FIXTURE_DIR/bin_mdzero"
  mkdir -p "$bin"
  cat > "$bin/markdownlint-cli2" <<'EOF'
#!/usr/bin/env bash
printf 'Linting: 0 files\nSummary: 0 issues in 0 files\n'
exit 0
EOF
  chmod +x "$bin/markdownlint-cli2"
  local rc=0 out
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_markdown.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "markdown gate: zero files linted fails closed"
  assert_contains "$out" "no Markdown files were linted" \
      "markdown gate: the zero-lint case names the cause"
}

test_markdown_counts_linted_files() {
  # A normal run lints >0 files and must still pass.
  local bin="$FIXTURE_DIR/bin_mdok"
  mkdir -p "$bin"
  cat > "$bin/markdownlint-cli2" <<'EOF'
#!/usr/bin/env bash
printf 'Linting: 3 files\nSummary: 0 issues in 0 files\n'
exit 0
EOF
  chmod +x "$bin/markdownlint-cli2"
  local rc=0
  PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_markdown.sh" >/dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" "markdown gate: a run that linted files passes"
}

test_markdown_singular_lint_count_passes() {
  # The tool pluralizes: exactly one file prints "Linting: 1 file". The gate
  # must read that as one linted file, not as none.
  local bin="$FIXTURE_DIR/bin_md1"
  mkdir -p "$bin"
  cat > "$bin/markdownlint-cli2" <<'EOF'
#!/usr/bin/env bash
printf 'Linting: 1 file\nSummary: 0 issues in 0 files\n'
exit 0
EOF
  chmod +x "$bin/markdownlint-cli2"
  local rc=0 out
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_markdown.sh" 2>&1) || rc=$?
  assert_rc 0 "$rc" "markdown gate: a single linted file passes (singular form)"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_lint_passes_when_both_gates_pass
run_test test_lint_reports_shell_failure
run_test test_lint_reports_markdown_failure
run_test test_lint_reports_both_gate_failures
run_test test_lint_runs_both_gates
test_shellcheck_missing_source_dir_fails_closed() {
  # A scanned directory that does not exist means the file set is unknown, not
  # empty: the gate must refuse to report clean.
  local fake="$FIXTURE_DIR/fakeroot_missing"
  mkdir -p "$fake/scripts" "$fake/tests"   # src/ deliberately absent
  local bin="$FIXTURE_DIR/bin_ok2"
  make_shellcheck_stub "$bin" 0
  local rc=0 out
  out=$(PATH="$bin:$PATH" SHELLCHECK_SCAN_ROOT="$fake" \
        bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a missing scanned directory fails closed"
  assert_contains "$out" "is missing; cannot determine the file set" \
      "a missing scanned directory names the cause"
}

test_shellcheck_empty_file_set_fails_closed() {
  # All three directories present but holding no shell files: the gate ran over
  # nothing and must not report clean.
  local fake="$FIXTURE_DIR/fakeroot_empty"
  mkdir -p "$fake/src" "$fake/scripts" "$fake/tests"
  local bin="$FIXTURE_DIR/bin_ok3"
  make_shellcheck_stub "$bin" 0
  local rc=0 out
  out=$(PATH="$bin:$PATH" SHELLCHECK_SCAN_ROOT="$fake" \
        bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "an empty file set fails closed"
  assert_contains "$out" "no shell files found" "an empty file set names the cause"
}

run_test test_shellcheck_missing_source_dir_fails_closed
run_test test_shellcheck_empty_file_set_fails_closed
run_test test_missing_shellcheck_fails_closed
run_test test_shellcheck_tool_failure_fails_closed
run_test test_shellcheck_directive_trap_is_named
run_test test_shellcheck_plain_parse_error_is_not_the_directive_trap
run_test test_markdown_tool_absent_fails_closed
run_test test_markdown_zero_lint_fails_closed
run_test test_markdown_counts_linted_files
run_test test_markdown_singular_lint_count_passes

test_done
