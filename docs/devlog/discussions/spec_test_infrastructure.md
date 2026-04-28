# Spec: Test Infrastructure Improvements

**Type:** Implementation spec — ready for execution after apply_workspace refactor  
**Status:** Approved for implementation  
**Depends on:** apply_workspace refactor (spec: `spec_apply_workspace_refactor.md`) — specifically Changes 1–4, which establish `tests/lib/`, `test_draft_workflow.sh`, and `test_diff_workflow.sh`

---

## Problem

The test suite has four structural gaps that the apply_workspace refactor exposes but does not resolve:

1. **No unified runner.** Test files are run individually. Cross-file regressions are only caught if the operator remembers to run every file. The backpressure loop (run suite → fix failures → repeat) has no natural entry point.

2. **No staleness enforcement.** When a lib or script changes behaviour, there is no mechanism prompting the author to check which test files reference it. Test drift is silent.

3. **No self-containment rule.** The policy does not prohibit sourcing other test files or require that shared helpers live only in `tests/lib/`. The fixture consolidation in the refactor establishes this pattern but it is not yet policy-backed.

4. **Policy not enforced at the boundary.** The checklist in `testing_policy.md` does not include the runner or staleness checks, so the policy does not close on itself.

Items 3 and 4 are addressed in the `testing_policy.md` update produced alongside this spec. This spec covers items 1 and 2 — the runnable artefacts.

---

## Decisions

### 1. Unified runner: `scripts/run_tests.sh`

A single script that discovers and runs all test files under `tests/`, collects per-file pass/fail, and prints a consolidated summary. Registered as `make test`.

Auto-discovery over a hardcoded list: the runner finds test files by globbing `tests/test_*.sh`. This means new test files are picked up without editing the runner. The glob must exclude `tests/lib/` — lib files are not runnable test files.

Each test file runs in a subshell to prevent state leakage between files. The runner collects exit codes; a non-zero exit from any file is a suite failure.

Output format: one line per file (`PASS tests/test_package_branch.sh` / `FAIL tests/test_draft_workflow.sh`), then a summary line (`N passed, M failed`). Exit 0 if all pass, exit 1 if any fail.

### 2. Grep-based coverage check: `scripts/check_test_coverage.sh`

A script that, given one or more changed file paths as arguments, greps `tests/` for references to those files and prints which test files reference each. Output is informational — it does not block anything. It is a prompt, not a gate.

```bash
bash scripts/check_test_coverage.sh libs/session.sh libs/draft_workflow.sh
# → tests/test_session.sh references libs/session.sh
# → tests/test_draft_workflow.sh references libs/draft_workflow.sh
# → tests/test_diff_workflow.sh references libs/session.sh
```

If no test files reference a changed file, the script says so explicitly — a changed file with no test coverage is a signal worth surfacing, not suppressing.

The script does not determine whether the tests are adequate — that requires human judgement. It produces the list; the author reviews it.

### 3. No pre-commit lint script (descoped)

A lint script checking for missing `mktemp`/`trap` in test files was considered and descoped. The `testing_policy.md` checklist and the unified runner together provide sufficient enforcement at low cost. A lint script adds a dependency management surface (where does it run, who maintains it) that is not justified at current test suite scale. Revisit if the suite grows substantially or if fixture pollution regressions recur.

---

## File Specifications

### `scripts/run_tests.sh`

```
Usage: bash scripts/run_tests.sh
       make test
```

**Behaviour:**

1. Discover all files matching `tests/test_*.sh` — sorted, reproducible order.
2. For each file: run in a subshell (`bash "$FILE"`), capture exit code, print `PASS <file>` or `FAIL <file>`.
3. After all files: print `Results: N passed, M failed`.
4. Exit 0 if all passed, exit 1 if any failed.

**Constraints:**
- Must not source test files — runs each as a subprocess so fixture teardown (`trap ... EXIT`) fires correctly per file.
- Must not assume a working directory — use `SCRIPT_DIR` to locate `tests/`.
- Output from individual test files (the per-test `PASS:`/`FAIL:` lines) is printed as it runs, not buffered. The per-file summary line appears after the file completes.
- If no test files are found, print a warning and exit 1 — a runner that silently passes with no tests is a trap.

**`Makefile` addition:**
```makefile
test:
    bash scripts/run_tests.sh
```

Verify that `make test` does not conflict with any existing Makefile target before adding. If a `test` target already exists, read it before replacing.

### `scripts/check_test_coverage.sh`

```
Usage: bash scripts/check_test_coverage.sh <file> [<file> ...]
```

**Behaviour:**

1. For each argument: run `grep -rl "$(basename "$FILE")" tests/` (basename only — test files reference by name, not full path).
2. Print results grouped by input file:
   ```
   libs/session.sh:
     tests/test_session.sh
     tests/test_draft_workflow.sh
   libs/draft_workflow.sh:
     tests/test_draft_workflow.sh
   ```
3. If no test files reference an argument, print:
   ```
   libs/new_lib.sh:
     (no test files found — review whether coverage is needed)
   ```
4. Exit 0 always — this is informational output, not a gate.

**Constraints:**
- Exclude `tests/lib/` from the grep — lib files are helpers, not test files. A match in `tests/lib/git_fixtures.sh` is not meaningful coverage.
- Accept both full paths and basenames as arguments — strip to basename before grepping.
- If called with no arguments, print usage and exit 1.

---

## Implementation Order

These are independent of each other and can be done in either order. Both are independent of the apply_workspace refactor changes — they can be done before, during, or after the refactor, as long as the test files they will discover exist.

**Recommended:** implement the runner (`run_tests.sh`) first — it immediately improves the development loop and provides a concrete target for the staleness check to reference.

---

## Acceptance Criteria

- `make test` runs all `tests/test_*.sh` files and exits 0 when all pass, 1 when any fail
- `make test` output names each file with its pass/fail status; the final line gives totals
- `bash scripts/check_test_coverage.sh libs/session.sh` prints the test files that reference `session.sh`, or explicitly states none were found
- `bash scripts/check_test_coverage.sh` with no arguments prints usage and exits 1
- Neither script requires modification when a new `tests/test_*.sh` file is added
- `tests/lib/` files are not executed by `make test` and do not appear in coverage check results
