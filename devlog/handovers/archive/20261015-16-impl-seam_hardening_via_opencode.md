---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The runner seam hardening, dispatched to OpenCode

## Objective

Prove that the free OpenCode tier can perform a sizeable implementation task, by handing one to `opencode-dispatch` rather than to pi, and verify the result against the tree.

## Scope

The worker's change set across the seam lib, the CLI and the seam test, and the allocator defect the worker found.

Out of scope: the launch-site sweep, which is M3.6.3.

## The dispatch

| Item | Value |
|---|---|
| Skill | `$AGENT_HOME/agent/skills/opencode-dispatch/dispatch.sh` |
| Model | `opencode/deepseek-v4.1-flash-free`, confirmed in the worker log header |
| Role | `_IMPLEMENTER` |
| Command built by | the runner seam, so the flag mapping had one home |
| Result | rc 0 in 111 seconds, three files changed, 149 insertions |
| Log | `$AGENT_HOME/run/opencode-dispatch.ut4PzO/worker.log` |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The worker produced a change set in scope | `git status --porcelain` names only the three files the brief allowed | Accepted |
| The worker's check passes | `bash tests/test_dispatch.sh`, 19 passed, up from 14 | Accepted |
| The tree is clean under the other gates | `bash scripts/check_shell.sh` clean; `bash scripts/lint.sh` clean across 8 gates | Accepted |
| The whole suite is green | `bash scripts/run_tests.sh`, 1130 passed across 81 files, 0 failed | Accepted |
| The new behaviour is real, not a subset | `dispatch_roles` prints the fixture table literally, `dispatch_check` passes and refuses on a real and a missing binary, the CLI lists roles and refuses an empty brief | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The proof task is the seam hardening | it is code, multi-file, verifiable, and within the milestone; a docs sweep would test judgement but not the write-run-test loop | this record |
| The worker runs in the working tree from a clean commit | the change set is then the worker's, and every line is attributable | this record; the skill |
| The allocator defect the worker found is fixed here | a defect in what this iteration produced is fixed, not filed | the test comment; this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The free OpenCode tier completed a real multi-file implementation with passing tests in under two minutes. It read the three files in scope, read the test helpers and the shellcheck script without being told, made the edits, and ran both checks. | measurement, the proof the operator asked for | this record; the skill's viability |
| The worker found a pre-existing defect the primary had introduced: `tests/test_dispatch.sh` called the fixture allocator at file scope, before `run_test` initialises it, leaking `test_common.sh:44: : No such file or directory`. It correctly reported the line as pre-existing and unrelated to its change. | defect, found by the worker | fixed in the same unit |
| `scripts/dispatch.sh --check` exits through `exit $?` in an `else`, which reads the condition's status. It is correct but reads poorly; a later pass can use `if ! dispatch_check "$ROLE"`. | style, not a defect | no action |

## Completed

| File | Change |
|---|---|
| [`src/libs/dispatch.sh`](../../../src/libs/dispatch.sh) | `dispatch_roles` and `dispatch_check` |
| [`scripts/dispatch.sh`](../../../scripts/dispatch.sh) | `--list-roles`, `--check`, and the brief preflight |
| [`tests/test_dispatch.sh`](../../../tests/test_dispatch.sh) | five cases, and the allocator fix |
| [`devlog/roadmap.md`](../../roadmap.md) | the proof row |
