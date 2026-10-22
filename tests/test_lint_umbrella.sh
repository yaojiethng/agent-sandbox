#!/usr/bin/env bash
# tests/test_lint_umbrella.sh
# TEST_DEADLINE: 20
#   This file runs the real umbrella gate many times over, so its honest
#   runtime is about 4s and the 5s default leaves no headroom under parallel
#   dispatch. The declaration is a budget, not a licence: the file must stay
#   near this cost.
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
#   a registered rule enabled nowhere  --  the config is incoherent, not clean
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

# make_frontmatter_fixture LINE...  -- builds a scan root holding a single
# prompt whose file content is exactly the given lines, and echoes the root
# path. The caller supplies the whole file, frontmatter fences included, so a
# fixture that is not a prompt is as easy to write as one that is.
make_frontmatter_fixture() {
  local root dir
  root="$FIXTURE_DIR/frontmatter_$$_$RANDOM"
  dir="$root/workflow/coding-agent/prompts"
  mkdir -p "$dir"
  printf '%s\n' "$@" > "$dir/broken.md"
  printf '%s\n' "$root"
}

LINT_RC=0
LINT_OUT=""

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
  LINT_OUT=$(PATH="$bin:$PATH" bash "$LINT" 2>&1) || LINT_RC=$?
}

# Given: both tool stubs are on PATH and report success
# When:  scripts/lint.sh runs with those stubs
# Then:  the umbrella exits 0
# Asserts: the clean verdict when every declared gate passes
test_lint_passes_when_both_gates_pass() {
  run_lint 0 0
  assert_rc 0 "$LINT_RC" "both gates pass: lint exits 0"
}

# Given: the shellcheck stub prints 2 warning markers and exits 0, and markdownlint exits 0
# When:  scripts/lint.sh runs with those stubs
# Then:  the umbrella exits 1
# Asserts: a failing gate maps to the failure verdict, not to the warning count
test_lint_reports_shell_failure() {
  run_lint 2 0
  assert_rc 1 "$LINT_RC" "shell gate warns: lint exits 1 (verdict, not the count)"
}

# Given: the shellcheck stub exits 0 and the markdownlint stub exits 1
# When:  scripts/lint.sh runs with those stubs
# Then:  the umbrella exits 1
# Asserts: the Markdown gate's non-zero exit reaches the umbrella verdict
test_lint_reports_markdown_failure() {
  run_lint 0 1
  assert_rc 1 "$LINT_RC" "markdown gate fails: lint exits 1"
}

# Given: the shellcheck stub prints 3 warnings and the markdownlint stub exits 1
# When:  scripts/lint.sh runs with those stubs
# Then:  the umbrella exits 1
# Asserts: the verdict stays boolean when every gate fails
test_lint_reports_both_gate_failures() {
  run_lint 3 1
  assert_rc 1 "$LINT_RC" "both gates fail: lint exits 1"
}

# Given: the shellcheck stub prints 1 warning and the markdownlint stub exits 1
# When:  scripts/lint.sh runs with those stubs
# Then:  the markdownlint stub's log file exists
# Asserts: the Markdown gate still runs after the shell gate fails
test_lint_runs_both_gates() {
  run_lint 1 1
  assert_file_exists "$FIXTURE_DIR/bin/mdl.log" "Markdown gate runs even after the shell gate fails"
}

# Given: PATH holds the gate's ordinary tools but no shellcheck
# When:  check_shell.sh runs
# Then:  rc is 1 and stderr names shellcheck as absent
# Asserts: a missing tool fails closed
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

# Given: the shellcheck stub exits 2 (the tool could not run)
# When:  check_shell.sh runs
# Then:  rc is 1 and stderr says the gate cannot run
# Asserts: a tool abort fails closed
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

# Given: no markdownlint-cli2 on PATH and none in the fixture HOME
# When:  check_markdown.sh runs
# Then:  rc is 1 and stderr names the tool as not installed
# Asserts: the Markdown gate fails closed on a missing tool
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



# Given: the shellcheck stub prints the SC1073/SC1072 directive wording and exits 1
# When:  check_shell.sh runs
# Then:  rc is 1 and stderr names the directive trap
# Asserts: a directive-parse error receives the directive remedy
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

# Given: a fixture comment starts with the tool name but is not a directive
# When:  check_shell.sh runs with the scan root at that fixture
# Then:  rc is 1 and stderr names a prose shellcheck comment
# Asserts: the prose-comment pass flags a non-directive use of the tool name
test_shellcheck_prose_comment_flagged() {
  # Independent of the tool's parse-error wording: a comment whose first token
  # after '#' is the tool name, but which is not a real directive, trips the
  # prose-comment pass. A passing shellcheck stub isolates the pass.
  local bin="$FIXTURE_DIR/bin_scprose"
  make_shellcheck_stub "$bin" 0
  local fake="$FIXTURE_DIR/fakeroot_prose"
  mkdir -p "$fake/src" "$fake/scripts" "$fake/tests"
  printf '#!/usr/bin/env bash\n# shellcheck absent -- rc 1\necho ok\n' \
    > "$fake/scripts/demo.sh"
  local rc=0 out
  out=$(PATH="$bin:$PATH" SHELLCHECK_SCAN_ROOT="$fake" \
        bash "$REPO_ROOT/scripts/check_shell.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "prose shellcheck comment: the gate fails"
  assert_contains "$out" "prose comment(s) whose first token" \
      "prose shellcheck comment: the gate names the cause"
}

# Given: a fixture holds a genuine shellcheck disable directive
# When:  check_shell.sh runs with the scan root at that fixture
# Then:  rc is 0
# Asserts: a real directive does not trip the prose-comment pass
test_shellcheck_real_directive_allowed() {
  # A genuine disable= directive must NOT trip the prose-comment pass.
  local bin="$FIXTURE_DIR/bin_scdir_ok"
  make_shellcheck_stub "$bin" 0
  local fake="$FIXTURE_DIR/fakeroot_dird"
  mkdir -p "$fake/src" "$fake/scripts" "$fake/tests"
  printf '#!/usr/bin/env bash\n# shellcheck disable=SC2034 reason\nlocal x\n' \
    > "$fake/scripts/demo.sh"
  local rc=0
  PATH="$bin:$PATH" SHELLCHECK_SCAN_ROOT="$fake" \
    bash "$REPO_ROOT/scripts/check_shell.sh" >/dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" "real disable directive: the prose comment pass allows it"
}


# Given: the shellcheck stub prints a plain if/fi parse error and exits 1
# When:  check_shell.sh runs
# Then:  rc is 1 and the output lacks the directive remedy
# Asserts: the directive remedy is not applied to an ordinary parse error
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





# Given: the markdownlint stub prints "Linting: 0 files" and exits 0
# When:  check_markdown.sh runs
# Then:  rc is 1 and stderr refuses to report Clean
# Asserts: a zero-file run fails closed
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

# Given: the markdownlint stub prints "Linting: 3 files" and exits 0
# When:  check_markdown.sh runs
# Then:  rc is 0
# Asserts: the plural linted-file count is read as a real run
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

# Given: the markdownlint stub prints "Linting: 1 file" and exits 0
# When:  check_markdown.sh runs
# Then:  rc is 0
# Asserts: the singular form is read as one linted file
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
# Given: the scan root's src/ directory is absent and the shellcheck stub passes
# When:  check_shell.sh runs
# Then:  rc is 1 and stderr names the missing directory
# Asserts: a missing scan root fails closed instead of reporting clean
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

# Given: all three scan roots exist but hold no shell files and the shellcheck stub passes
# When:  check_shell.sh runs
# Then:  rc is 1 and stderr says no shell files were found
# Asserts: an empty file set fails closed
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
run_test test_shellcheck_prose_comment_flagged
run_test test_shellcheck_real_directive_allowed
run_test test_markdown_tool_absent_fails_closed
run_test test_markdown_zero_lint_fails_closed
run_test test_markdown_counts_linted_files
run_test test_markdown_singular_lint_count_passes

# Given: the umbrella's GATES list
# When:  the declared gates and the scripts/check_*.sh set are compared
# Then:  every gating gate is listed, and every other check script is classified
# Asserts: a new check script cannot be silently absent from the umbrella.
test_lint_gate_set_is_complete() {
  local gates g base f
  gates=$(sed -n 's/^GATES=(\(.*\))$/\1/p' "$LINT")
  for g in check_shell.sh check_lib_contract.sh check_markdown.sh; do
    assert_contains "$gates" "$g" "GATES includes $g"
  done
  # check_*.sh invoked by other entry points (the repo Makefile), never by the
  # lint umbrella.
  local non_umbrella="check_lib_liveness.sh check_test_coverage.sh check_test_liveness.sh check_test_smoke.sh"
  for f in "$REPO_ROOT"/scripts/check_*.sh; do
    base=$(basename "$f")
    if [[ " $gates " == *" $base "* || " $non_umbrella " == *" $base "* ]]; then
      pass "check script classified: $base"
    else
      fail "$base is neither a GATES member nor classified as non-umbrella"
    fi
  done
}

# Given: a failing shell gate and a passing Markdown gate
# When:  the umbrella runs
# Then:  the failing gate's findings and the umbrella summary both reach output
# Asserts: the umbrella forwards each gate's report; it does not swallow it.
test_lint_forwards_gate_output() {
  run_lint 2 0
  assert_contains "$LINT_OUT" "SC0000" "umbrella forwards the failing gate's findings"
  assert_contains "$LINT_OUT" "Lint: one or more gates failed" "umbrella prints its failure summary"
  run_lint 0 0
  assert_contains "$LINT_OUT" "Lint: clean in" "umbrella prints its clean summary"
  # The count is read from the GATES array rather than hardcoded, so adding a
  # gate does not fail this test and tempt an author into deleting the check.
  local declared
  declared=$(sed -n 's/^GATES=(\(.*\))$/\1/p' "$LINT" | wc -w)
  assert_contains "$LINT_OUT" "across $declared gates" "clean summary names the gate count"
}

# Given: a markdownlint stub that prints a finding line and exits 0
# When:  check_markdown.sh runs
# Then:  rc is 1 and the finding count is printed
# Asserts: a finding reported with a zero tool status still fails the gate.
test_markdown_finding_with_zero_status_fails() {
  local bin="$FIXTURE_DIR/bin_mdfinding"
  mkdir -p "$bin"
  cat > "$bin/markdownlint-cli2" <<'EOF'
#!/usr/bin/env bash
printf 'Linting: 2 files\nSummary: 1 issue in 2 files\nfake.md:1 error MD000/test\n'
exit 0
EOF
  chmod +x "$bin/markdownlint-cli2"
  local out rc=0
  out=$(PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_markdown.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a finding with tool status 0 fails the gate"
  assert_contains "$out" "markdownlint: 1 finding(s)" "the printed finding count reaches the operator"
}

# Given: a recording markdownlint stub and a caller in a sibling directory
# When:  check_markdown.sh runs
# Then:  the stub is invoked with the repository root as its working directory
# Asserts: the **/*.md glob is evaluated at the repository root.
test_markdown_gate_runs_at_repo_root() {
  local bin="$FIXTURE_DIR/bin_mdcwd"
  mkdir -p "$bin"
  cat > "$bin/markdownlint-cli2" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$PWD" > "$bin/mdl.cwd"
printf 'Linting: 1 file\nSummary: 0 issues in 0 files\n'
exit 0
EOF
  chmod +x "$bin/markdownlint-cli2"
  ( cd "$FIXTURE_DIR" && PATH="$bin:$PATH" bash "$REPO_ROOT/scripts/check_markdown.sh" >/dev/null 2>&1 ) || true
  assert_eq "$(cat "$bin/mdl.cwd")" "$REPO_ROOT" "markdownlint runs from the repository root"
}

# Given: a fixture root whose only prompt has frontmatter that parses
# When:  check_document_shape.sh runs against that root
# Then:  rc is 0
# Asserts: the clean verdict, so a passing gate is not a gate that never fires.
test_frontmatter_gate_passes_on_a_parsing_block() {
  local root out rc=0
  root=$(make_frontmatter_fixture '---' 'description: "Draft: a quoted value"' '---' '' '# Sequential Work')
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 0 "$rc" "a parsing block passes the gate"
  assert_contains "$out" "Clean" "the clean verdict reaches the operator"
}

# Given: a fixture root holding a prompt whose unquoted description contains a
# colon followed by a space
# When:  check_document_shape.sh runs against that root
# Then:  rc is 1 and the finding names the file, the line, and the offending text
# Asserts: the silent drop is reported at the line an author has to edit. A gate
# that only printed a count would leave the author hunting for it.
test_frontmatter_gate_names_the_offending_line() {
  local root out rc=0
  root=$(make_frontmatter_fixture '---' 'description: Draft - the shape: run a plan' '---' '' '# Sequential Work')
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "an unquoted colon-space fails the gate"
  assert_contains "$out" "broken.md" "the finding names the file"
  assert_contains "$out" "offending line: description: Draft - the shape: run a plan" \
    "the finding quotes the offending line"
}

# Given: a fixture root holding a prompt that opens on its title, with no
# frontmatter block at all
# When:  check_document_shape.sh runs against that root
# Then:  rc is 0
# Asserts: the gate scopes itself to a block that fails to parse. A prompt draft
# with no block is a separate, tracked defect; failing every known open item
# would make this gate unreadable.
test_frontmatter_gate_skips_a_prompt_with_no_block() {
  local root out rc=0
  root=$(make_frontmatter_fixture '# Fan-Out Run' '' '## Purpose')
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 0 "$rc" "a prompt with no frontmatter block is skipped, not flagged"
  assert_contains "$out" "clean across 1 instruction file(s)" "the file is collected and its block skipped"
}

# Given: a PATH with no node on it
# When:  check_document_shape.sh runs
# Then:  rc is 1
# Asserts: the gate fails closed. A missing parser must never read as a pass.
test_frontmatter_gate_fails_closed_without_node() {
  local bin out rc=0
  bin="$FIXTURE_DIR/bin_nonode"
  mkdir -p "$bin"
  ln -sf "$(command -v dirname)" "$bin/dirname"
  ln -sf "$(command -v bash)" "$bin/bash"
  out=$(PATH="$bin" "$bin/bash" "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "no node on PATH fails the gate"
  assert_contains "$out" "node is not on PATH" "the missing dependency is named"
}

# Given: a manifest root with no container-interface.json
# When:  check_document_shape.sh runs
# Then:  rc is 1 and the missing declaration is named
# Asserts: the gate fails closed. The instruction roots are derived from the
# declaration, so an absent declaration means the root set is unknown; reading
# an empty set as clean is exactly the silent pass this branch prevents.
test_frontmatter_gate_fails_closed_without_manifest() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_nomanifest_$$_$RANDOM"
  mkdir -p "$root"
  out=$(DOCUMENT_SHAPE_MANIFEST_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a missing manifest fails the gate"
  assert_contains "$out" "cannot derive the instruction roots" "the missing declaration is named"
}

# Given: a fixture root holding a policy file whose frontmatter does not parse
# When:  check_document_shape.sh runs against that root
# Then:  rc is 1 and the finding names the policy file
# Asserts: the policy scan root is live. A policy block is never loaded at
# runtime, so a malformed one has no other symptom; the gate is the only check.
test_frontmatter_gate_scans_policy_files() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_policy_$$_$RANDOM"
  mkdir -p "$root/docs/policies"
  printf '%s\n' '---' 'description: Owns a rule: unquoted colon' '---' '' '# X Policy' \
    > "$root/docs/policies/x_policy.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a malformed policy block fails the gate"
  assert_contains "$out" "x_policy.md" "the finding names the policy file"
}

# Given: a fixture root holding a project convention-skill whose unquoted
# description contains a colon followed by a space
# When:  check_document_shape.sh runs against that root
# Then:  rc is 1 and the finding names the skill file
# Asserts: the project convention-skill tree is scanned. It sat outside the
# gate's root list, so a malformed description in `.agents/skills/` cost the
# skill silently while the gate still reported clean.
test_frontmatter_gate_scans_project_convention_skills() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_agents_$$_$RANDOM"
  mkdir -p "$root/.agents/skills/task-list"
  printf '%s\n' '---' 'name: task-list' 'description: the roadmap and the changelog: their shape' '---' '' '# task-list' \
    > "$root/.agents/skills/task-list/SKILL.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a malformed convention-skill block fails the gate"
  assert_contains "$out" ".agents/skills/task-list/SKILL.md" "the finding names the convention-skill"
}

# Given: a fixture root holding a malformed frontmatter block in every
#        instruction root the container interface declares, plus the two
#        project convention roots
# When:  check_document_shape.sh runs against that root
# Then:  rc is 1 and the finding count equals the number of planted files
# Asserts: the scan set is derived from the declaration, not hand-listed. The
# test reads the same declaration the gate does, so a cell source added to the
# manifest is scanned and asserted without editing the gate or this test.
test_frontmatter_gate_covers_every_declared_instruction_root() {
  local root out rc=0 rel count=0 rels
  rels=$( cd "$REPO_ROOT" && node --input-type=module -e '
    import { load_manifest, manifest_rows } from "./src/build/container-interface.mjs";
    const sources = manifest_rows(load_manifest(process.cwd()), "cells")
      .flatMap((cell) => cell.sources ?? []);
    const roots = [...sources, ".agents/skills", ".agents/prompts"].map((root) => root.replace(/\/+$/, ""));
    process.stdout.write([...new Set(roots)].join("\n"));
  ' ) || return 1
  root="$FIXTURE_DIR/frontmatter_roots_$$_$RANDOM"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    rel="${rel%/}/a.md"
    mkdir -p "$root/$(dirname "$rel")"
    printf '%s\n' '---' 'description: shape: unquoted colon' '---' '' '# a' > "$root/$rel"
    count=$((count + 1))
  done <<< "$rels"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a malformed block in every declared instruction root fails the gate"
  assert_contains "$out" "$count finding(s) across" "every declared instruction root is scanned"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    assert_contains "$out" "${rel%/}/a.md:" "the finding names ${rel%/}/a.md"
  done <<< "$rels"
}

# Given: the repository's own .markdownlint-cli2.mjs
# When:  the rules its customRules entries export are read against the names its
#        config block enables
# Then:  every exported rule is enabled
# Asserts: the config-coherence property. config.default is false, so a rule
# registered in customRules but named nowhere in the config never runs and
# reports nothing: the gate prints a clean verdict over an empty rule set.
# linking sat in that state, and the guard in check_markdown.sh checked
# only the opposite direction (enabled but unregistered), so it stayed silent.
test_every_registered_rule_is_enabled() {
  local out
  out=$( cd "$REPO_ROOT" && node --input-type=module -e '
    import settings from "./.markdownlint-cli2.mjs";
    import { pathToFileURL } from "node:url";
    import { resolve } from "node:path";
    const cfg = settings?.config ?? {};
    const enabled = Object.entries(cfg)
      .filter(([k, v]) => k !== "default" && v !== false)
      .map(([k]) => k);
    const registered = new Set();
    for (const ref of settings?.customRules ?? []) {
      try {
        const mod = await import(pathToFileURL(resolve(ref)).href);
        for (const rule of mod.default ?? []) {
          for (const n of rule?.names ?? []) registered.add(n);
        }
      } catch {
        process.stdout.write("unloadable:" + ref);
        process.exit(0);
      }
    }
    const silent = [...registered].filter((n) => !enabled.includes(n));
    process.stdout.write(silent.length === 0 ? "ok" : "not-enabled:" + silent.join(","));
  ' 2>&1);
  assert_eq "$out" "ok" "every rule registered in customRules is enabled in the config"
}

run_test test_every_registered_rule_is_enabled
run_test test_lint_gate_set_is_complete
run_test test_lint_forwards_gate_output
# Given: a fixture root holding a shipping document with no reader declared
# When:  check_document_shape.sh runs with that folder as a shipping root
# Then:  rc is 1 and the finding names the file
# Asserts: the reader field is required where it has teeth. The ship set is a
# decision, so a shipping document that declares no reader is the one state the
# gate must not pass over.
test_frontmatter_gate_requires_a_reader_on_a_shipping_document() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_reader_$$_$RANDOM"
  mkdir -p "$root/docs/reference"
  printf '%s\n' '# Undeclared' '' 'Prose.' > "$root/docs/reference/undeclared.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" DOCUMENT_SHAPE_SHIPPED_ROOTS="docs/reference" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a shipping document with no reader fails the gate"
  assert_contains "$out" "undeclared.md frontmatter: no frontmatter" "the finding names the file and the reason"
}

# Given: a fixture root holding a shipping document that declares the maintainer alone
# When:  check_document_shape.sh runs with that folder as a shipping root
# Then:  rc is 1 and the finding says the document does not ship
# Asserts: the declaration and the folder set cannot disagree. A maintainer-only
# document belongs outside a shipping folder, and the check states which side moves.
test_frontmatter_gate_rejects_a_maintainer_only_shipping_document() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_maintainer_$$_$RANDOM"
  mkdir -p "$root/docs/reference"
  printf '%s\n' '---' 'reader: [maintainer]' '---' '' '# Maintainer Only' > "$root/docs/reference/maintainer_only.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" DOCUMENT_SHAPE_SHIPPED_ROOTS="docs/reference" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a maintainer-only shipping document fails the gate"
  assert_contains "$out" "does not ship" "the finding states the consequence"
}

# Given: a fixture root holding a shipping document with a declared reader
# When:  check_document_shape.sh runs with that folder as a shipping root
# Then:  rc is 0
# Asserts: the positive case, so the two findings above are not a gate that fails
# on every tree.
test_frontmatter_gate_accepts_a_declared_reader() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_ok_$$_$RANDOM"
  mkdir -p "$root/docs/reference"
  printf '%s\n' '---' 'reader: [agent, operator]' '---' '' '# Declared' > "$root/docs/reference/declared.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" DOCUMENT_SHAPE_SHIPPED_ROOTS="docs/reference" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 0 "$rc" "a declared reader passes the gate"
  assert_contains "$out" "1 shipping document(s)" "the verdict counts the shipping documents"
}

# Given: a fixture root holding a skill whose disable-model-invocation value is a
#        string rather than a boolean
# When:  check_document_shape.sh runs against that root
# Then:  rc is 1 and the finding names the field and the value
# Asserts: the field's type. Pi's loader tests the value with `=== true`, so a
# string such as `yes` leaves the skill visible, the opposite of the author's
# intent, and no other check reads the field.
test_frontmatter_gate_rejects_a_non_boolean_disable_field() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_flag_$$_$RANDOM"
  mkdir -p "$root/.agents/skills/x"
  printf '%s\n' '---' 'name: x' 'description: a skill' 'disable-model-invocation: yes' '---' '' '# x' \
    > "$root/.agents/skills/x/SKILL.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 1 "$rc" "a non-boolean disable-model-invocation fails the gate"
  assert_contains "$out" "disable-model-invocation is" "the finding names the field"
}

# Given: the same fixture with a boolean value
# When:  check_document_shape.sh runs against that root
# Then:  rc is 0
# Asserts: the boolean value passes, so the check is not a blanket rejection.
test_frontmatter_gate_accepts_a_boolean_disable_field() {
  local root out rc=0
  root="$FIXTURE_DIR/frontmatter_flag_ok_$$_$RANDOM"
  mkdir -p "$root/.agents/skills/x"
  printf '%s\n' '---' 'name: x' 'description: a skill' 'disable-model-invocation: true' '---' '' '# x' \
    > "$root/.agents/skills/x/SKILL.md"
  out=$(DOCUMENT_SHAPE_SCAN_ROOT="$root" bash "$REPO_ROOT/scripts/check_document_shape.sh" 2>&1) || rc=$?
  assert_rc 0 "$rc" "a boolean disable-model-invocation passes the gate"
}

run_test test_markdown_finding_with_zero_status_fails
run_test test_markdown_gate_runs_at_repo_root
run_test test_frontmatter_gate_passes_on_a_parsing_block
run_test test_frontmatter_gate_names_the_offending_line
run_test test_frontmatter_gate_skips_a_prompt_with_no_block
run_test test_frontmatter_gate_fails_closed_without_node
run_test test_frontmatter_gate_fails_closed_without_manifest
run_test test_frontmatter_gate_scans_policy_files
run_test test_frontmatter_gate_scans_project_convention_skills
run_test test_frontmatter_gate_covers_every_declared_instruction_root
run_test test_frontmatter_gate_requires_a_reader_on_a_shipping_document
run_test test_frontmatter_gate_rejects_a_maintainer_only_shipping_document
run_test test_frontmatter_gate_accepts_a_declared_reader
run_test test_frontmatter_gate_rejects_a_non_boolean_disable_field
run_test test_frontmatter_gate_accepts_a_boolean_disable_field

test_done
