# Study: Lint and Tests Duration

**Status:** Lint recommendation adopted and landed (iteration `20260921-12`). This supplement (2026-09-21) records the test-suite-duration investigation: parallel execution measured about 5x, a per-test deadline is advised, no major busy-wait exists, and the bash-harness evaluation compares bats-core / shunit2 / shellspec per-option. The harness decision is settled: keep-current adopted, bats rejected - [`20260922-design-settled-m3_1_test_harness_decision.md`](20260922-design-settled-m3_1_test_harness_decision.md).

## Direction + Parent story

Roadmap task "Lint and tests take forever" under M3.1 - Backpressure. The recorded symptom: `scripts/lint.sh` costs about 30 seconds because it lints every tracked file (recorded in handover `20260921-01`). This study measures where the time goes, verifies the staged-file hook scope, and presents approaches. It does not implement a fix.

## Required reading

- [`docs/adr/git_hooks.md`](../../docs/adr/git_hooks.md) - the copy-delivery hook gates staged Markdown and shell files
- [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) section 3.2 - verdict-only exit codes
- `scripts/check_shell.sh` - the ShellCheck gate measured here
- `scripts/check_markdown.sh` - the Markdown gate measured here
- `scripts/check_lib_contract.sh` - the sourced-lib contract gate measured here
- `devlog/handovers/20260921-01-*.md` - the original 30-second record

## Summary

`scripts/lint.sh` runs three gates sequentially: the ShellCheck gate (`check_shell.sh`), the sourced-lib contract gate (`check_lib_contract.sh`), and the Markdown gate (`check_markdown.sh`). The ShellCheck gate dominates the lint total. The test suite is a separate ~40s run driven mostly by per-file process latency, not CPU; the same 58 files run in ~7.8s when parallel at depth 8. The staged-file pre-commit hook does not re-lint the repository; it lints only the staged file lists. **2026-09-21 supplement:** measures the suite (40s serial, 7.8s at depth 8), evaluates per-test timeouts and busy-waiting, and compares bash test frameworks.

## Findings

### Timing, measured 2026-09-21 on the 16-core host (two runs each)

| Gate | Wall time | Files checked | Notes |
|---|---|---|---|
| `check_shell.sh` | ~30s | 135 `.sh` | one `shellcheck -S warning` invocation over all files |
| `check_markdown.sh` | ~3s | 591 `.md` | `markdownlint-cli2` over the tree |
| `check_lib_contract.sh` | ~0.04s | 22 `.sh` | awk pass; negligible |
| `scripts/lint.sh` total | ~34s | | sequential sum of the three gates |
| `scripts/run_tests.sh` | ~37s | 57 files, 1030 tests | user 8s, sys 10s; the rest is wait time |

### The ShellCheck batch invocation is both slow and lenient

Re-checking the same 135 files one shell check per file changes both numbers:

| Mode | Wall time | Result |
|---|---|---|
| batch: `shellcheck -S warning f1 ... f135` (the gate today) | ~30s | 0 warnings; gates report Clean |
| serial per-file: 135 invocations | ~9s | 8 files fail at `-S warning` |
| parallel per-file: `xargs -P16` | ~1.1s | 8 files fail at `-S warning` |

`shellcheck` treats the first file in a multi-file invocation as the script and the remaining files as sourced libraries. Library-mode checks suppress script-context warnings, most visibly `SC2154` (variable referenced but not assigned). The batch result therefore depends on argument order: file one is strict, the other 134 are lenient. Per-file checking is strict for every file.

The 8 files that fail per-file checking (`scripts/start_agent.sh`, `scripts/workflows/reject.sh`, six tests) reference variables that the file itself does not assign; they pass today only because the batch treats them as libraries. Whether each reference is a real defect or a sourced-context false positive needs a per-file review before any strict mode is enabled.

### The staged-file hook does not re-lint the repository

The copy-delivery hook (`src/capability/git-hooks/pre-commit.sh`, ADR entry 2026-09-21) passes the explicit staged lists to the linters: `--no-globs` for Markdown, the staged file set for ShellCheck. Live evidence from this session's commits: the hook printed `Linting: 3 files` and `Linting: 2 files`, the staged Markdown sets, never the 591-file tree. Confirmed.

### The test suite cost is latency and child CPU, not busy-waiting

The early measurement (8s user, 10s sys over 37s wall, "wait-dominated") is stale. A fresh 2026-09-21 measurement records user ~32s and sys ~14s over ~40s wall serial, and a ~7.8s wall at `xargs -P8` with the CPU cost spread over cores. The suite spends time in per-file process latency (git fixtures, docker stub, node) and child CPU, not in idle waits. The test-family split (handover `20260920-03`) bounded the optics; the run stays serial today.

## Open Questions

1. May the ShellCheck gate switch from one batch invocation to per-file checking? Per-file is strict (8 files fail until reconciled) and faster (9s serial, ~1s parallel). The strictness is a semantics change, not a pure speed change.
   **Resolved:** yes - the operator chose parallel per-file. `check_shell.sh` now runs shellcheck once per file, concurrently (`20260921-12`), cutting the shell gate from ~30s to ~1.5s.
2. If strict per-file becomes the gate, are the 8 failing references fixed (real defects) or suppressed with rationale (sourced-context false positives)?
   **Resolved:** mixed - each was judged on its merit. One dead assignment removed (`make_real_session`'s unused `PROJECT_DIR`); five `AGENT_SANDBOX_REPO` presets exported (the documented preset-and-sourcing contract, matching two sibling tests); four flagged sites got a targeted rationale directive (`ENV_REL`, the interactive-test `PROJECT_DIR`, `COMPOSE_ARGS`, and `reject.sh`'s eval-emitted `source_branch`) where the value is genuinely consumed by code `source`/`eval` introduces that ShellCheck cannot trace.
3. If the batch stays, is the 30s cost acceptable at pre-close, given the commit hook already gives fast feedback on staged files?
   **Resolved:** moot - per-file parallel replaced the batch.
4. May the three gates run in parallel (background jobs) to cut the lint total, or must output stay serial per gate?
   **Resolved:** yes - the operator authorized background jobs. `lint.sh` runs the shell, lib-contract, and markdown gates concurrently and prints each gate's output on completion, so the report stays deterministic.

## Constraints

- Exit codes stay verdict-only: 0 = clean, 1 = findings or could-not-run. No count in the code (convention 3.2).
- All three gates always run; a failure in one never hides another.
- The pre-commit hook stays staged-scoped; it must not re-lint the repository.
- The Markdown and lib-contract gates are already cheap; only the ShellCheck gate and the test runner are in play.

## Test-suite duration findings (2026-09-21 supplement)

Measured on the 16-core host. Per-file wall times (each file run independently with `bash file < /dev/null`), sorted:

| Test file | ~Wall | Notable cost |
|---|---|---|
| `test_doc_wrap_rule.sh` | 4.7s | `test_real_tree_zero_findings` runs `markdownlint-cli2` over all 596 `.md` files (genuine guard, added iteration `20260921-11`) |
| `test_start_agent.sh` | 3.6s | multiple start/render fixtures: node substitution, compose render, git |
| `test_trace_start.sh` | 2.8s | docker stub + `compose_sandbox_wait` calls |
| `test_diff_export.sh` | 2.5s | `wait_git_lockfile_timeout` deliberately spends the 3s default |
| `test_lint_umbrella.sh` | 2.2s | runs `lint.sh`/gates several times (real shellcheck + node) |
| next 10 files | ~14s | routing, draft_workflow, dry_run_probe, interactive_select, trace_resume, resume, seed_volume, onboard, package_branch, diff_dispatch |
| remaining 43 files | ~11s | all under 1s; typical ~0.1-0.5s |
| **full suite (serial)** | **~40s** | user ~32s, sys ~14s |

Two facts make file-level parallelism safe: every test file allocates its own `FIXTURE_DIR` (`mktemp -d /tmp/XXXXXX`, `trap` cleanup), and no test file writes a repo-relative path or binds a fixed port. The docker stub derives project names from the per-file fixture, so two parallel files share no mutable path.

### Parallel test execution -- feasible, measured about 5x

Running the same 58 files concurrently with `xargs -P8` (one worker per file, output captured per worker) cuts the wall time from ~40s to ~7.8s. The CPU cost is unchanged but spread over cores; the suite is latency-bound, not CPU-bound. All 58 files pass under parallel execution (rc 0, same assertions as serial).

Runner change required, mirroring the `lint.sh` worker pattern: launch one `bash "$FILE"` per worker writing per-slot temp files, `wait` all, then print each file's report and aggregate in a deterministic order. The liveness gate (`check_test_liveness.sh`) is a read-only tree scan and stays serial before the parallel phase. The runner self-test (`test_runner_selftest.sh`) asserts the current serial ordering and counts and must move to the parallel contract.

Concurrency caution: no two files should run another lint pass against a shared mutable config; the only cross-file lint activity is `test_doc_wrap_rule.sh`'s read-only real-tree scan, which is safe.

### Individual timeout per test -- feasible and advisable

Today a hanging test file hangs `make test` and the `bash` tool without bound. Options:

- GNU `timeout 300 bash "$FILE"` -- not portable: macOS hosts lack `timeout` (only `gtimeout` from coreutils), and some `timeout` invocation forms wait the maximum instead of interrupting (the tool-run-budget feedback).
- Pure-bash deadline -- start `bash "$FILE" &`, poll a per-file budget (configurable `TEST_TIMEOUT`, default ~180s), `kill` on expiry and mark the file failed. Portable on bash 3.2, no external tool.

Recommend the pure-bash form. A killed file exits nonzero, and the runner already treats a nonzero rc as a suite failure, so the count and verdict logic is unchanged.

### Major unnecessary busy-waiting -- none to remove

The waits are deliberate, small, and mostly not the cost:

- `compose_sandbox_wait` polls with `sleep 1` up to a 120s default, but the docker stub reports healthy immediately and tests clamp the record wait (`DRY_RUN_RECORD_TIMEOUT`), so each call costs at most ~1s and usually 0.
- `wait_git_lockfile` polls at 200ms; one test intentionally spends the 3s default to assert the timeout path (the observed `test_diff_export.sh` cost). That is coverage, not waste.
- `test_routing.sh` polls `seq 1 50` with `sleep 0.05` (up to 2.5s worst case, a couple of polls in practice).

The suite cost is per-file process latency. Parallel execution recovers it.

## Bash unit-test framework evaluation (2026-09-21)

The question is not metric-for-metric feature parity. It is whether a battle-tested framework removes bug-prone, lightly-designed infrastructure so the project can focus on sandboxing a coding agent. Compared empirically on 2026-09-21 by cloning the projects: bats-core v1.14.0 (maintained, release 2026-07), shunit2 v2.1.8 (last release 2020-03), shellspec (master). None is installed in the image today.

### The harness-bug baseline a switch would leave behind

The bespoke harness is `tests/libs/test_common.sh` (261 lines), `scripts/run_tests.sh` (181), `scripts/check_test_liveness.sh` (91), and `tests/test_runner_selftest.sh` (223), plus 344 lines of test stubs. It has produced four testing-harness bugs:

| # | Bug | Consequence | Status |
|---|---|---|---|
| 1 | The runner's discovery shared one here-string FD; a test that read stdin advanced it and silently skipped trailing files | silent coverage loss reported green | worked around with `< /dev/null` |
| 2 | A `run_test` registered after `test_done` is dead code, so a test could silently never run | needed a bespoke 91-line liveness awk gate | gate built |
| 3 | Pass/fail counting greps `^  PASS:` from captured output | output-coupled; a pass is counted even when the file failed | live fragility |
| 4 | No per-test timeout; a hanging test hangs `make test` and the tool | the hang / tool-run-budget family (AGENT_FEEDBACK) | open |

### Per-option comparison along the axes that matter

| Axis | bats-core 1.14 | shunit2 2.1.8 | shellspec master |
|---|---|---|---|
| Parallel (duration) | `-j/--jobs`, but requires GNU parallel or rush (a new external dependency) | none - serial only, fails the duration need | `-j/--jobs` built-in |
| Per-test timeout | native - `BATS_TEST_TIMEOUT` env with a watchdog and a `# timeout after Ns` tap annotation | none | none - its internal `timeout()` is a retry helper, not a per-example limit |
| Isolated execution | each `@test` runs in its own subshell | same-process serial function calls | per-example isolation |
| Registration artifact (liveness) | static `@test` registration - the dead-registration class disappears | static `testFoo` registration - ditto | static `It` - ditto |
| Counting / accounting | own counters; pretty / tap / tap13 / junit / custom formatter | own counters; only `--lineno` flag, no tap or junit | own counters; formatter + output generators (junit etc) |
| bash portability | requires bash >= 3.2 (runs on macOS system bash) | plain sh; runs on 3.2 | heavier framework-directory install |
| Install / dependency cost | single script + lib; pin in image, Dockerfile, macOS bootstrap | single sh file | full framework directory + config |
| Maintenance status | actively maintained (release 2026-07) | last release 2020-03 | actively maintained |

### Bug-reduction verdict per class

Class 1 (FD discovery) is eliminated by all three - they isolate execution and discover tests without a shared read FD. Class 2 (dead registration) disappears under static registration, so the bespoke 91-line liveness gate becomes unnecessary. Class 3 (grep counting) is replaced by each framework's own battle-tested counters. Class 4 (per-test timeout) is solved **only by bats** natively; shellspec and shunit2 leave it to us to wrap. On bug reduction, bats wins outright.

### LOC and maintenance surface

Switching is not a lines reduction: the frameworks are larger than our harness (bats runtime ~4.7k lines, shellspec ~8.9k, shunit2 a 1.3k single file), but we install rather than author them, so our maintenance surface shrinks to a pinned version. The dominant LOC, the ~16.8k-line test tree, is not absorbed by any framework - a migration converts it without deleting it; and the docker-stub wiring and the zero-skip / verdict-exit contract must be re-established in framework terms either way. The leftover bespoke burden is a real but bounded ~1100 lines (harness + stubs) plus the runner self-test.

### Is outsourcing justified?

The focus argument holds: the harness is infrastructure patched piecemeal (an FD workaround, a liveness gate, a self-test) in a domain the project has not deeply designed, and a battle-tested framework with documented behavior becomes the substrate. The objection is that the harness is small against the test tree and currently returns green. The deciding axis is bug reduction: the harness has demonstrably produced silent-wrongness bugs (classes 1 and 2) that all three frameworks would have prevented, and bats additionally closes the timeout class. If the project values that guarantee, bats-core is the credible adoption; shellspec fails the timeout axis and installs heavier; shunit2 fails both the parallel and timeout axes and is six years stale.

## Open questions raised by this supplement

1. May `run_tests.sh` run the test files in parallel (one worker per file, buffered output, liveness gate first)? Measured about 5x.
2. May `run_tests.sh` add a per-test-file deadline (pure-bash, default `TEST_TIMEOUT`, kill-on-expiry treated as a suite failure)? The same need is met natively by bats (`BATS_TEST_TIMEOUT`) if the operator adopts bats instead.
3. What default deadline for items 1-2? The observed max is ~5s; a generous default (~180s) bounds a hang without risking a flaky kill.
4. On the framework item: adopt bats-core (accept the GNU-parallel dependency for `--jobs` and a one-time migration of the ~16.8k-line test tree), or keep the bespoke harness and close its gaps with the dependency-free `xargs -P8` parallel and a pure-bash deadline? If adopted, is the migration subsumed by M3.1 or kept as its own iteration?

## Comparison-methodology caveat (two-branch plan)

The framework decision is being run as two parallel branches: branch A (keep-current, parallel + deadline) and branch B (bats-core). The comparison evaluates branch B at its minimal migration -- bespoke bodies re-skinned as `@test` blocks with the `set +e; set +T` heads kept -- against branch A at the status-quo suite. The two suites are authored differently in kind, not just in harness: branch A runs tests in-process with a shared file-scoped `FIXTURE_DIR` and PASS-marker accounting; branch B runs each `@test` in an isolated subshell and counts test units. Judging the harnesses while the suites are authored differently confounds the harness choice with the authoring model. The authoring equalization is owned by the unified test-harness improvement task (roadmap row **Test-harness improvement**): apply the harness-independent checklist to both suites, re-measure both on equal footing, then compare. The harness-specific halves of that work live in the [branch A](20260921-design-active-m3_1_test_runner_merge_comparison_branch_a.md) and [branch B](20260921-study-settled-m3_1_bats_harness_merge_branch_b.md) off-branch records (harness improvements for branch A, bats-idiomatic rewrites for branch B). This caveat corrects the comparison framing, not the framework matrix above.

## Next Steps

1. Lint-side recommendation landed in iteration `20260921-12`: per-file parallel shellcheck + concurrent gates, with the 8 exposed sites patched. The lint roadmap row is closed.
2. The suite-duration task is a roadmap row. If keep-current: parallel + a pure-bash deadline land on `run_tests.sh` next. If adopt bats: a migration iteration converts the test tree, wires the docker stubs and the zero-skip / verdict-exit contract, and pins the dependency in the image, Dockerfile, and macOS bootstrap. Both paths await the operator's answers on items 1-4.
