# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general-track; test-harness defect)
**Type:** Fix
**Status:** Closed

## Objective

Fix the `test_runner_selftest.sh` FATAL: every clean suite run since the liveness scan landed exited rc=1 despite a green report. The dedicated fix iteration, per operator instruction.

## Scope

- `scripts/run_tests.sh` -- contract-anchored dead-registration scan.
- `tests/test_runner_selftest.sh` -- Case 12 payload rewritten so the words stay off column 0.
- `docs/development/testing-conventions.md` -- the scan's contract anchor documented.
- `devlog/roadmap.md` -- the selftest-FATAL row closed.

## Carried forward

| Item | From handover |
|---|---|
| None. | |

## Acceptance criteria

1. `run_tests.sh` exits rc=0 on a clean tree.
2. A genuine dead registration (`run_test` naming a `test_` function after `test_done`) is still flagged.
3. The selftest's own body is scan-clean: registration-shaped words inside its quoted payload do not trip the scan.
4. The registration contract is the same shape across `check_liveness`, `check_test_liveness.sh`, and the conventions doc.
5. All tests pass.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh) | the liveness scan (the defect site) |
| [`tests/test_runner_selftest.sh`](../../tests/test_runner_selftest.sh) | the false-positive payload (Case 12) |
| [`docs/development/testing-conventions.md`](../../docs/development/testing-conventions.md) | the dead-registration rule, now anchored |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Anchor the scan to the registration contract (`run_test` naming a `test_` function) instead of adding a shell quote/heredoc tokenizer to the awk | the corpus's only non-`test_` targets are exactly payload content (`t_ok`, `t_dead`, `t_noop`); `check_test_liveness.sh` already greps this shape, so the two tools now speak one contract; a 40-line state machine for a heuristic guard has its own correctness risk and must be maintained forever | run_tests.sh, testing-conventions.md, this handover |
| Case 12's payload names real `test_` targets and is printed via `printf` so the registration words never sit at column 0 in the selftest body | the old `t_*` payload only worked against the naive scan; under the contract anchor it would no longer exercise a dead registration, and typing `run_test test_ok` at column 0 inside the selftest would false-positive its own body | test_runner_selftest.sh |
| The column-0 limit is a documented boundary, not a handled case | a payload embedding a verbatim `run_test test_x` at column 0 would still trip the scan -- same exposure `check_test_liveness.sh` already has; it fails loudly (a FATAL), and payload authors keep words off column 0 (the selftest itself is the template) | run_tests.sh comment, testing-conventions.md |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `check_liveness` scanned line-shape, not semantics: a `run_test` word inside a multi-line quoted payload at column 0 was read as code | bug (root cause) | suite rc=1 on every clean run since the scan landed (commit `6621052`); report line stayed green, so the breakage was silent until the exit code was checked |
| A 40-line quote/heredoc state machine in awk was proposed and rejected in design review | design (superseded) | the operator challenged it as over-engineered; the contract anchor is one regex change with the same protection for the real corpus |
| Case 12's `t_*` payload did not survive the contract anchor: a `t_ok`/`t_dead` registration is not a `test_`-named registration | bug (test premise) | payload rewritten to `test_*` names, printed not typed at column 0 |

## Review pass outcome

Not run -- recommended: a development-diff review by the operator before merge; the change is a one-regex fix plus a test-payload rewrite, and the design was already operator-challenged and re-released in chat.

## Completed

| File | Change |
|---|---|
| `scripts/run_tests.sh` | `check_liveness` scan anchored: `run_test[[:space:]]+test_[A-Za-z0-9_]+` (the registration contract, matching `check_test_liveness.sh`'s grep); comment states the anchor and the column-0 boundary |
| `tests/test_runner_selftest.sh` | Case 12 payload rewritten: `test_`-named targets printed via `printf` (single physical line construction), so the dead registration still exercises the scan while the selftest body stays scan-clean; comment documents why |
| `docs/development/testing-conventions.md` | Test Structure Template dead-registration paragraph: the scan fires only on `test_`-named registrations, not registration-shaped words in quoted payloads (unless at column 0) |
| `devlog/roadmap.md` | selftest-FATAL row closed with root cause, fix, and handover reference |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence (general-track).

Roadmap maintenance: the selftest-FATAL row closed this iteration; no submilestone compaction.

Blocking design questions the next agent must resolve before advancing:

- None.

**Conclusions from this iteration:** the runner's dead-registration scan read line shape, not semantics: it flagged any word `run_test` that textually followed `test_done`, so the selftest's own quoted payload content tripped it and every clean suite run exited rc=1 since the scan landed. The fix anchors the scan to the registration contract -- a registration names a `test_` function, the same shape `check_test_liveness.sh` already greps -- one regex change instead of a shell tokenizer. Case 12 was rewritten to use real `test_` names printed off column 0, so it still exercises dead-registration detection while the selftest body stays scan-clean. Suite: rc=0, 803 passed / 0 failed, 0 FATAL.
