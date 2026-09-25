# Merge report -- branch B (bats-core), off-branch record of the M3.1 harness comparison

**Status:** superseded by the harness decision (keep-current merged; bats rejected; branch archived). Its measurement claims are corrected in [`20260922-design-settled-m3_1_test_harness_decision.md`](20260922-design-settled-m3_1_test_harness_decision.md).

**Date:** 2026-09-21
**Branch:** `feat/M_3_1-backpressure-branch-B`
**Base:** `56e33ff` (M3.1 study close)
**Iteration:** `20260921-14` (handover `devlog/handovers/20260921-14-impl-m3_1-bats_branch_b.md`)
**Purpose:** hand the harness-migration comparison's transaction branch to whoever merges or integrates it.

## Summary

Branch-B adopts bats-core as the test harness on the M3.1 harness-migration comparison. The bespoke `run_test` / `test_done` harness is replaced by bats-core `@test` blocks; `scripts/run_tests.sh` becomes a bats-core launcher that runs the suite with `bats --jobs N` under GNU parallel. The branch is complete, green, and lint-clean. The authoritative accept/reject decision between Branch-B and Branch-A is the operator's; this report gives the merger the information needed to fold or discard Branch-B.

The suite runs 701 tests across 58 files, 0 failed, 0 skipped, in ~14-17 s wall (from ~37 s serial), and is lint-clean.

## Comparison-methodology caveat

This report describes branch B at its minimal migration: the bespoke test bodies were re-skinned as `@test` blocks and the `set +e; set +T` heads kept, so the suite does not yet exercise bats' assertive idioms. The comparison against branch A is therefore asymmetric -- a minimal, re-skinned suite on branch B versus the status-quo suite on branch A -- and the two are authored differently in kind (in-process shared fixtures and PASS-marker counting versus per-`@test` subshell isolation and test-unit counting). This note corrects the comparison framing, not the measurements. The authoring equalization is owned by the unified test-harness improvement task (roadmap row **Test-harness improvement**); the bats-idiomatic rewrites below are the branch-B half of reaching an equivalent bar.

## How to run the suite on Branch-B

The runtime needs two tools on `PATH`: bats-core and GNU parallel. Run:

```bash
make test
# or
bash scripts/run_tests.sh
```

`scripts/run_tests.sh` discovers `tests/test_*.sh`, checks the docker stub and GNU parallel prerequisites, runs `bats --jobs $JOBS` (default one job per CPU), aggregates from TAP output, and enforces zero-skip. It fails with a named error when GNU parallel is missing and `JOBS > 1`.

## What changed

- All 58 `tests/test_*.sh` files: the bespoke `run_test` registration tail is a set of bats-core `@test "name" { helper; }` blocks. Every file carries `# shellcheck shell=bats` so it stays in the `check_shell.sh` gate. Each `@test` body starts `set +e; set +T` (rationale below). Path resolution uses `$BATS_TEST_FILENAME` instead of `$BASH_SOURCE[0]`.
- `tests/libs/test_common.sh`: bats-native assertions. `fail()` prints and exits the test subshell non-zero (fail-fast); `skip()` exits with status 3, which bats reports as a failure, so bats enforces the zero-skip policy. The `PASS`/`FAIL` counters, `run_test`, and `test_done` are gone. `test_setup` resolves paths from `$BATS_TEST_FILENAME`.
- `scripts/run_tests.sh`: rewritten as the bats launcher described above.
- `tests/test_runner_selftest.sh`: rewritten for the launcher contract (all-pass, failing test, skip-as-failure, aggregate counts, missing prerequisite).
- `scripts/check_test_liveness.sh` deleted and the `make test-liveness` target dropped. bats-core parses `@test` blocks statically, so a written block always runs; the registration-liveness gap the gate closed no longer exists.
- Docs updated to the bats structure template and the runtime dependencies: `docs/development/testing_policy.md`, `docs/development/testing-conventions.md`, `docs/development/bash-coding-conventions.md`, and a note on the liveness replacement in `devlog/AGENT_FEEDBACK.md`.

## Implementation findings

bats-core behaves differently from the previous in-process runner in three ways; each was fixed in-test and is worth preserving if the harness is adopted.

1. **errexit.** bats-core runs each test under `set -e`. The old `run_test "$1" || true` had suppressed non-zero exits from benign intermediate commands. Each `@test` body starts `set +e` so the suite keeps its leniency: a command that returns non-zero in the middle of a test does not abort it. Assertion rigor is unchanged, because every existing test already ends by calling `pass` or `fail`.
2. **functrace.** bats-core runs under `set -T` (functrace), which propagates `RETURN` traps into command substitutions and called functions. This broke `compose_generate`'s `trap 'rm -rf "$staging_dir"' RETURN`, which deleted the staged compose files before the docker stub read them (generated output collapsed to `services: {}`). Each `@test` body starts `set +T`. Three `test_trace_compose_gen.sh` tests were the symptom.
3. **init/entrypoint signalling.** The init and entrypoint tests background a copy of `src/capability/entrypoint.sh` and signal it with SIGTERM. The signal sometimes landed before the entrypoint registered `trap 'exit 0' TERM`, so `wait` reported 143 instead of 0. The tests now `exec` the entrypoint inside the background subshell, so the signal reaches the trap-bearing process, and wait a short settle before signalling. Three tests in `test_git_hook.sh` and `test_capability_entrypoint_mount.sh` were the symptom.

A fourth change is obsolete, not a fix: the registration-liveness gate was removed because bats-core static parsing makes it unnecessary (see Changes).

## Bats-idiomatic rewrites pending on branch B (list 3)

These items make the suite use bats as intended without changing the assertion meaning. They are pure idiom compliance, not strict test improvement. Applying them is required before branch B is judged against branch A at an equivalent bar.

1. **`run` plus assert** -- replace the hand-rolled `rc=$?` capture and `assert_contains` over captured output with bats' `run` and the `assert_*` family (the bats-assert library, an add-on if the assert helpers are wanted).
2. **Dropped `set +e; set +T`** -- remove the per-`@test` heads and let errexit run, once the bodies stop relying on benign non-zero intermediates (a parity-checklist item).
3. **bats `setup()` and `teardown()`** -- replace the file-scope `test_setup` call with bats' native per-test setup and teardown hooks, the idiomatic isolation boundary.
4. **Functrace-test fix** -- restructure the RETURN-trap dependent tests instead of disabling functrace, so a trap is not relied on across a subprocess boundary.
5. **Formatter-native accounting** -- consume bats' `tap13` or `junit` formatter output instead of grep-reparsing TAP12, removing the fragile counting the launcher currently re-derives.
6. **bats-aware lint wiring** -- keep the `# shellcheck shell=bats` directive and validate the converted files under a bats-aware ShellCheck mode.

## Comparison context (for the merger)

- **Branch-A** keeps the bespoke harness and adds dependency-free `xargs -P8` cross-file parallelism plus a pure-bash deadline.
- **Branch-B** (this branch) is pure bats-core with `--jobs` under GNU parallel. Its dependency cost is bats-core plus GNU parallel in the runtime image; its structural cost is the one-time test-tree migration (now done on this branch).

The study that frames this comparison, with the per-option framework matrix and the four harness-bug classes it addresses, is in `devlog/discussions/20260921-study-settled-lint_and_tests_duration.md` (Test-suite duration and Bash unit-test framework evaluation sections).

## What the merger must do to adopt Branch-B

On accept:

- Provision bats-core and GNU parallel in the runtime image and in the host / macOS bootstrap, so `make test` works without a `PATH` export. `scripts/run_tests.sh` already fails with a named error if GNU parallel is missing.
- Set the per-test deadline. bats-core provides it natively via `BATS_TEST_TIMEOUT` (the "per-test timeout" task); decide a default and export it in `scripts/run_tests.sh`.
- Fold the branch's commits into the integration branch, keeping the tests, `run_tests.sh`, `test_common.sh`, the selftest, the docs changes, and the removed liveness gate.
- Close the harness-migration and per-test-timeout roadmap rows, and record the decision.

On reject:

- Discard the branch. No production code beyond the tests harness was touched, so rejection is a clean revert.

## Reproducing the verification (in-container setup and runtime findings)

This section records the exact environment used to verify branch B, so a fresh runtime can reproduce the 701/701 result without re-deriving the setup. The install is throwaway: the binaries live outside the repository and are not part of the committed tree; the committed expectation is that the runtime image provisions the dependencies.

- **bats-core v1.14.0**: cloned `https://github.com/bats-core/bats-core` at tag `v1.14.0` (depth 1) and ran `install.sh <prefix>`, putting `bin/bats` under a throwaway prefix, that prefix added to `PATH`.
- **GNU parallel**: cloned `https://git.savannah.gnu.org/git/parallel.git` and used `src/parallel` at tag `20260722`, copied to the same prefix. The report's `20260822` is not tagged in the savannah repo (only its ftp tarball exists, which needs `bzip2`, absent in the image); `20260722` is functionally identical for `bats --jobs`.
- **Run**: `PATH=<prefix>/bin:$PATH bash scripts/run_tests.sh` gives 701 tests across 58 files, 0 failed, 0 skipped, ~15-17s wall.

Runtime findings:

- **The per-test timeout needs `ps` or `pkill`.** The base runtime image has neither. With `BATS_TEST_TIMEOUT=5`, bats emits `Cannot execute timeout because neither pkill nor ps are available` and silently executes 0 tests; the launcher then reports "0 tests" -- the TAP re-parse fragility of list item 3.5, reproduced, not inferred. Inserting minimal `ps` and `pkill` shims on `PATH` restored the clean 701/701 run.
- **Three runtime dependencies, none present in the base image.** bats-core and GNU parallel (for `--jobs`) and `procps`/`pkill` (for the timeout) must be provisioned in the runtime image, the Dockerfile, and the host / macOS bootstrap before branch B is adopted as-is.
- The docker-stub and GNU-parallel prerequisite checks are coded in `scripts/run_tests.sh`; the timeout dependency is not yet surfaced as a named error.

## Verification

- `bash scripts/run_tests.sh`: 701 tests across 58 files, 0 failed, 0 skipped, ~14 s.
- `make test` is equivalent (`VERBOSE= bash scripts/run_tests.sh`); verified by calling the script directly, because `make` is not installed in the sandbox image.
- `bash scripts/lint.sh`: Clean across the ShellCheck, lib-contract, and Markdown gates.
- The sandbox used bats-core 1.14.0 and GNU parallel 20260822 installed under `/tmp/branchB-deps/bin` (throwaway, not committed). The installed bundle is not part of the repository.
