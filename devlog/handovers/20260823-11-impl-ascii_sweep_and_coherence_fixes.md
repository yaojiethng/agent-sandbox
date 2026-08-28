# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Two works subsumed into one iteration after operator-directed renumbering (originally separate iterations `-11` and `-12`; see Findings):

1. Enforce the existing Character set rule (ASCII punctuation) across the repository.
2. Make error messages agree with control flow in the export and apply paths, and name the copyable idiom for the `grep -c` pitfall.

## Part 1: ASCII-punctuation sweep

The Character set rule (`documentation_policy.md` -- "Do not use non-ASCII punctuation (for example the section sign)") was live but unenforced; ~200 section signs across 66 files predated enforcement. Operator directive: acceptable in chat, never in the repo.

- Rule references (`§4.1` style) became `rule 4.1`; heading decorations stripped; em/en-dashes, ellipsis, curly quotes, `x`/`->`/`>=`/`!=`/`~` substitutions applied in live documents and session-authored files.
- Kept: the two backtick mentions in `documentation_policy.md` that name the banned symbol.
- **Deferred (operator: leave as-is):** corpus-wide conformance of historical records (every old handover carries an em-dash preamble).

## Part 2: error-message vs control-flow coherence

| File | Change |
|---|---|
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | `_session_export`: absorb `wait_git_lockfile`'s return -- "proceeding anyway" then return 1 killed the export under `set -e` at exactly the promised proceed point |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | `apply_run` + `apply_preview`: `\|\| echo 0` -> `\|\| true` capture with `${VAR:-0}` (grep -c self-reports zero; echo doubled it into `0\n0`) |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | Rule 4.3 names the copyable idiom and the `\|\| echo 0` double-emission hazard |
| [`tests/test_apply_count.sh`](../../tests/test_apply_count.sh) | New: pins single-line count reporting through `apply_run` (1-file and 2-file diffs) |

Plus the sweep's mechanical edits across tests/scripts comments.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Zero section signs outside policy-definition mentions; session/live docs fully ASCII | grep -P non-ASCII = 0 lines in that set | accepted |
| AC2 | Mechanical replacement only in the sweep; no semantic edits | spot-checks | accepted |
| AC3 | Lock persistence no longer aborts session-export; message and behavior agree | inspection; underlying contract unit-tested in test_diff_export | accepted |
| AC4 | Count reported exactly once, never doubled | test_apply_count green | accepted |
| AC5 | Rule 4.3 documents idiom + hazard | doc review | accepted |
| AC6 | Suite green and deterministic x2 | 631 tests / 39 files / 0 failed x2 | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Close-out propagation greps must sweep the full tests tree, not a file subset (stale "memoized" comments survived initially) | process gap | GOTCHAS entry recorded (handover `-09` review) |
| Empty diffs hard-fail inside `git apply` itself ("No valid patches in input") -- the zero-count branch was unreachable; fixes were hygiene, not behavior change. git's diagnostic names `--allow-empty`, which informed the empty-diff decision | scoping discovery | Roadmap bullet updated |
| This git build rejects `/dev/null`-source hunks lacking index metadata | test constraint | Documented in test_apply_count.sh |
| **Operator gotcha recorded:** flaky/hollow iterations whose content should have been amendments to an open handover (see GOTCHAS entry) | process | New GOTCHAS entry this iteration |

## Completed

| File | Change |
|---|---|
| 66 files swept for ASCII punctuation (mechanical) | Part 1 |
| [`devlog/GOTCHAS.md`](../../devlog/GOTCHAS.md) | Propagation-sweep entry; operator unit-of-work entry (this iteration) |
| Production + test changes per tables above | Part 2 |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Coherence bullet closed; naming one-liners bullet gained the apply.sh header-vs-guard contradiction |

## Decisions

| Decision | Rationale |
|---|---|
| Pinned-digest-style pinned-count assertions over stub tricks | A PATH-stubbed binary shadows all pipeline stages including legitimate uses |
| Operator renumbering: former `-12` subsumed here; next iteration takes number `12` | Hollow-iteration prevention (see Findings) |

## Deferred items

- Historical-corpus non-ASCII normalization: operator ruled to leave historical decisions/records as-is.
