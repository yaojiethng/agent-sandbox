# Test Suite Per-Assertion Sweep -- Review Brief (report-only)

## Purpose

A fresh-subagent review brief that sweeps a shell test suite's assertions against an authoring bar and reports findings without editing. This is the U7 brief from M3.1, preserved as input for the future workflow review of the thermonuclear review prompt (`workflow/coding-agent/prompts/review-pass-run.md`; roadmap row "Review-pass framing fixes"; AGENT_FEEDBACK entry `[A] 2026-09-22 -- A condition on an always-true helper is a vacuous assertion`).

## Run record for that review

- Model: `deepseek-v4-flash` at `xhigh` thinking (opencode-go provider).
- Invocation: `timeout 1800 pi --provider opencode-go --model deepseek-v4-flash --thinking xhigh -p "$(cat <this file>)" > /tmp/u7-review.log 2>&1`.
- The run read all 58 test files in full (16,859 lines). It produced: six vacuous assertions that could not fail, one provable silent-green site, five silent-green or masked-rc classes, and a real production defect the masked suites had hidden (`scripts/prune.sh` committed without its exec bit, so `stop --prune` returned 126).

## Why it worked -- what the future review should extract

- The brief is self-contained. The reviewer has a clean context, so the harness contract (subshell-per-test, fail-fast, unit accounting, the allocator, benign-rc masks, the order gate) is stated before the checklist.
- The checklist is bounded and violation-shaped. Each of the seven authoring-bar items is a findable class, and "zero violations is an acceptable answer" is explicit per item.
- The constraint is report-only. Findings carry file:line, the offending code, the item violated, why it is a problem, and a concrete proposed fix. The main agent triages and applies; the reviewer never edits.
- The verdict is a per-item count plus a final judgment (correctness risk vs stylistic). The main agent triaged by severity in minutes.
- Fresh eyes are the dividend. With no session history, the reviewer flagged masked-rc reliability holes the implementing agent had normalised past.

## The brief

# Task: final per-assertion authoring sweep (report only)

You are a fresh reviewer with a clean context. Work in `/home/agentuser/sandbox` (a bash/shell project). The M3.1 test-harness work has landed; your job is a final quality sweep of the test suite's assertions against the authoring bar below. **Do NOT modify any file.** Produce a categorized findings report.

## The harness contract (so you do not misread the code)

- `tests/libs/test_common.sh` defines the model. Each test runs in its own subshell; `fail()` exits the test subshell (fail-fast); accounting is one unit per test; `run_test NAME` emits the unit markers `PASS: NAME` and `FAIL: NAME` (both indented two spaces; the runner counts them). Assertion detail lines use `ok:` and `not ok:`.
- Fixtures: `test_setup` at file scope sets `TEST_DIR`, `REPO_ROOT`, and a file-scope `FIXTURE_ROOT`. Inside a test, `FIXTURE_DIR` is a fresh per-test root. `get_fixture_dir` (alias `get_test_dir`) allocates extra fresh dirs, all removed on the test's exit. Teardown is the allocator's; tests must not hand-roll `rm -rf "$FIXTURE_DIR"` traps or bare `mktemp -d`.
- `assert_run EXPECTED_RC CMD [LABEL]` runs CMD in a subshell and captures its combined output into `RUN_OUT` (never discarded), asserting rc.
- The per-test subshell runs `set +e`, so errexit aborts cannot happen; `|| true` masks are tolerated where the rc is a benign signal (`git diff` rc1 = differences found; `grep -c` rc1 = no matches; trailing cleanup commands under the strict rule that a non-zero test-subshell exit is a failure). A mask on a plain success-expected command is still a smell.
- Each test runs in its own subshell with a fresh `FIXTURE_DIR`, so the suite is order-independent by construction; no order gate is needed.

## The authoring bar -- every assertion in `tests/test_*.sh` (58 files) against these

1. **Capture-and-assert**: a test that runs a command should keep its rc AND its output and assert both. Flag rc-only assertions that discard meaningful output (a failure message that would be blind), and tests running a command with `>/dev/null 2>&1` where the output would diagnose the failure.
2. **Assert the meaning, not the string**: labels describe the behavior under test, not the matched text. Flag labels that merely restate the needle or the rc.
3. **Per-test fixture directories**: flag any test that still uses a bare `mktemp -d`, writes outside `$FIXTURE_DIR`/`$FIXTURE_ROOT`/`get_fixture_dir`, or hand-rolls its own temp-dir trap instead of the allocator.
4. **Unified explicit teardown**: flag tests that clean up manually (`rm -rf` of their own dirs) where the allocator should own it, or that leak dirs (create via other means).
5. **No reliance on benign non-zero intermediates**: flag `|| true` on a plain command whose rc 0 means success and where the failure would be silently hidden (not the documented git-diff/grep-c/trailing-normalization cases).
6. **Descriptive labels where they disambiguate**: flag assertions that share a default or near-duplicate label within one test function such that a failure would not say which assertion fired. (The suite is documented as zero bare 2-arg calls -- verify and flag any found.)
7. **Order independence**: nothing to fix here; each test runs in its own subshell with a fresh fixture, so the suite is order-independent by construction. Only flag a test that obviously depends on a sibling's written file.

## Output format

Report findings grouped by checklist item. For each finding: `file:line`, the offending code, which item it violates, why it is a problem, and a concrete proposed fix (suggested code). Then a short summary paragraph: how many findings per item, and your judgment on whether any finding is a genuine correctness risk vs stylistic. Be decisive -- if something is fine, do not pad the report. If after a thorough sweep an item has zero violations, say so explicitly per item.

Sweep all 58 files; do not rely on grep alone -- read representative bodies to judge labels and discard patterns.
