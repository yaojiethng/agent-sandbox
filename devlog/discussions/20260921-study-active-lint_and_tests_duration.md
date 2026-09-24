# Study: Lint and Tests Duration

**Status:** Lint recommendation adopted and landed (iteration `20260921-12`); the suite-duration approach remains open.

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

`scripts/lint.sh` runs three gates sequentially: the ShellCheck gate (`check_shell.sh`), the sourced-lib contract gate (`check_lib_contract.sh`), and the Markdown gate (`check_markdown.sh`). The ShellCheck gate dominates the lint total. The test suite is a separate 37-second run driven mostly by process and stub latency, not CPU. The staged-file pre-commit hook does not re-lint the repository; it lints only the staged file lists.

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

### The test suite cost is wait time, not CPU

`scripts/run_tests.sh` uses 8s of user time and 10s of sys time over 37s wall. The remainder is process spawning, stub docker latency, and deliberate sleeps. The test-family split (handover `20260920-03`) already bounded the optics; the run itself stays serial.

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

## Next Steps

1. Lint-side recommendation landed in iteration `20260921-12`: per-file parallel shellcheck + concurrent gates, with the 8 exposed sites patched. The lint roadmap row is closed.
2. The suite-duration task is now its own roadmap row; its approach selection (test-runner parallelism) is open and lands separately.
