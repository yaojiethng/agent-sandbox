# Handover 20260917-05: fix -- session log in-place sed portability

## Status

Closed

## Type

Implementation

## Milestone

M2.6 (post-list close) -- operator-directed macOS robustness continuation

## Objective

Make the session activity-log upsert (`session_log_set`) independent of the sed flavor, so a Ctrl-C teardown on macOS never fails.

## Scope

The single GNU-only call site that runs in the teardown path: the `sed -i` upsert in `src/libs/session_inventory.sh`, its regression test, and the stale GNU-sed diagnostic in `scripts/install.sh`. The remaining GNU-only call sites stay out of scope; see What's Next.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | `session_log_set` works when sed has BSD semantics (macOS default) | No-in-place shim on PATH: set + upsert write the log | done |
| 2 | No `-i` form is used anywhere in the upsert | The shim fails any `-i` invocation; both shim tests pass | done |
| 3 | Existing upsert behavior unchanged: idempotent, single line, second key appends | `test_session_log_set_read` plus suite 797/0/0 | done |
| 4 | The stale diagnostic names only the remaining consumer | `install.sh` names only `scripts/onboard.sh` | done |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/session_inventory.sh`](../../src/libs/session_inventory.sh) | The bitten call site: GNU-only `sed -i SCRIPT FILE` misparses under BSD sed |
| [`tests/test_session_log.sh`](../../tests/test_session_log.sh) | Regression guard: no-in-place-sed shim plus shim self-check |
| [`scripts/install.sh`](../../scripts/install.sh) | GNU-sed diagnostic text, propagation of the fix |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Drop in-place sed entirely (sibling temp file + mv) instead of `-i ''` | GNU sed 4.9 rejects `-i '' SCRIPT FILE` (script promoted to file position); BSD requires the suffix argument; no single `-i` form is portable | `session_inventory.sh` comment |
| Guard with a no-in-place shim, not a BSD-mimicking one | The invariant is "no `-i` at all", which is stronger and simpler to shim | `tests/test_session_log.sh` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| GNU sed 4.9 does not accept `sed -i '' SCRIPT FILE` - the BSD-canonical empty-suffix form is not portable in reverse. This rules out any `-i` compromise. | contradiction | next iteration |
| `scripts/onboard.sh:188` (`sed -i`) and `ts_to_epoch` (`date -u -d`) remain GNU-only host-side call sites; onboard's `sed -i` fails identically at `onboard --refresh` when gnubin is not on PATH. | scope change | next iteration |

Findings routed to the standing portable-call-sites port offer (from `20260917-02` and `20260917-03`); see What's Next.

## Completed

| File | Change |
|---|---|
| `src/libs/session_inventory.sh` | `sed -i` upsert replaced by sibling-temp rewrite; comment explains the flavor divergence |
| `tests/test_session_log.sh` | No-in-place-sed PATH shim, upsert-under-shim test, shim self-check; 3 new tests |
| `scripts/install.sh` | Diagnostic names only `scripts/onboard.sh` as the `sed -i` consumer |

## Deferred items

None.

## What's Next

Take the portable-call-sites port (the offer from `20260917-02`/`20260917-03`) so the macOS host runs without gnubin on PATH: `scripts/onboard.sh:188` inherently, `ts_to_epoch` (`date -u -d`) in `src/libs/session_inventory.sh`, and the remaining GNU-only sites from the offer list. Watch-out: verify each site against BSD semantics with a PATH shim, as done here.

**Conclusions from this iteration:** the teardown failure came from a GNU-only sed invocation, not from the teardown logic itself. Portable in-place sed does not exist across GNU and BSD; a temp-file rewrite is the portable answer, and the no-in-place shim makes the invariant testable.
