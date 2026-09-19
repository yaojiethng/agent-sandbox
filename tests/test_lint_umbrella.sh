#!/usr/bin/env bash
# tests/test_lint_umbrella.sh
# Behavioural tests for scripts/lint.sh -- the umbrella static-check gate.
#
# Covers:
#   both gates pass     --  rc 0
#   shell gate fails    --  rc is the ShellCheck warning count
#   markdown gate fails --  rc is markdownlint's status
#   both gates fail     --  rc is the shell gate's code (first failure)
#   both gates run      --  a shell failure does not skip the Markdown gate
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

# make_shellcheck_stub COUNT  --  prints COUNT warning markers, exits 0.
# check_shell.sh counts the '^--' markers, so COUNT is the gate's exit code.
make_shellcheck_stub() {
  local dir="$1" count="$2"
  mkdir -p "$dir"
  cat > "$dir/shellcheck" <<EOF
#!/usr/bin/env bash
for _ in \$(seq 1 $count); do echo "  ^-- SC0000"; done
exit 0
EOF
  chmod +x "$dir/shellcheck"
}

# make_mdl_stub RC  --  records its run, prints an error line when RC is
# nonzero, exits RC.
make_mdl_stub() {
  local dir="$1" rc="$2"
  mkdir -p "$dir"
  cat > "$dir/markdownlint-cli2" <<EOF
#!/usr/bin/env bash
echo ran >> "$dir/mdl.log"
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
  assert_rc 2 "$LINT_RC" "shell gate warns: lint exits with the warning count"
}

test_lint_reports_markdown_failure() {
  run_lint 0 1
  assert_rc 1 "$LINT_RC" "markdown gate fails: lint exits with markdownlint's status"
}

test_lint_reports_first_failure() {
  run_lint 3 1
  assert_rc 3 "$LINT_RC" "both gates fail: lint exits with the ShellCheck code"
}

test_lint_runs_both_gates() {
  run_lint 1 1
  assert_file_exists "$FIXTURE_DIR/bin/mdl.log" "Markdown gate runs even after the shell gate fails"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_lint_passes_when_both_gates_pass
run_test test_lint_reports_shell_failure
run_test test_lint_reports_markdown_failure
run_test test_lint_reports_first_failure
run_test test_lint_runs_both_gates

test_done
