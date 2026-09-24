# Agent Handover

**Date:** 2026-09-23
**Milestone:** M3 -- T9 - Session and Harness Identity (identity row moved from T7; registry row new)
**Type:** Design
**Status:** Closed

## Objective

Record the session-identity complection review as a discussion design doc and file a roadmap task for the sandbox command registry design.

## Scope

- `devlog/discussions/20260923-design-active-session_identity_and_sandbox_command_ergonomics.md` -- the review report plus the operator direction (registry, SANDBOX_DIR, Makefile strip) as design exploration.
- `devlog/roadmap.md` -- new section `#### T9 - Session and Harness Identity` carrying the amended T7 identity row (record-pair versioning added) and the new registry-design row. Row text was confirmed in chat at scope confirmation.
- No code changes this iteration.

Blockers: none.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The discussion design doc exists at `devlog/discussions/20260923-design-active-session_identity_and_sandbox_command_ergonomics.md` | `ls` | accepted |
| 2 | The roadmap has a `#### T9 - Session and Harness Identity` section carrying the identity row (amended) and the registry row; no identity row remains under T7 | `grep -n "Separate harness identity" devlog/roadmap.md` | accepted |
| 3 | Markdown and shell gates pass with zero findings | `bash scripts/lint.sh` | accepted |
| 4 | The doc records the record-versioning question and at least two options per explored choice | operator review | accepted |

## Hot files

None.

## Decisions

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Operator steering: design the CLI seam -- a registry resolves the sandbox dir and defaults so commands call `agent-sandbox` directly; `onboard` registers; SANDBOX_DIR retention is in question | steering | this iteration |
| Operator steering: new roadmap track T9 - Session and Harness Identity; the identity row moves from T7 and the registry row lands beside it | steering | this iteration |
| Review question: the session-record schema (`.compose/<id>.yml` + `.git/SESSION_STATE`) is not versioned as a unit; only the container boundary is guarded by `interface_contract_version` | technical finding | next iteration |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/discussions/20260923-design-active-session_identity_and_sandbox_command_ergonomics.md` | created: the review report (complection map, record question, unknowns) plus the command-surface direction and options |
| `devlog/roadmap.md` | added `#### T9 - Session and Harness Identity`; moved the identity row from T7 with the record-pair versioning amendment; added the registry-design row |
| `devlog/handovers/20260923-01-design-session_identity_and_sandbox_command_ergonomics.md` | this handover: milestone/scope/findings updated; AC, Completed, What's Next populated |

## Deferred items

None.

## What's Next

T9 - Session and Harness Identity.

Roadmap maintenance: none pending; the T9 rows are open tasks.

Blocking design questions for the registry row: where the registry stores records; whether SANDBOX_DIR stays an explicit flag or becomes registry-only; which per-sandbox Makefile targets carry behaviour beyond argument convenience.

Watch-outs: verify the record-pair versioning claim end to end before redesign (`.compose/<id>.yml` writers and `resume_list.sh` readers); keep roadmap rows statement-plus-link per the T8 format-drift row.

Grep at next start: `grep -n "registry" devlog/roadmap.md`; `grep -rn "record\(_\|\.\)version" src/libs/*.sh`.

**Conclusions from this iteration:** the review verdict (more complicated locally, simpler overall) with the session-record cluster as the accidental braid; the record-pair schema is not versioned as a unit (only the container boundary is); the command seam exploration is registered under T9 next to the identity row.
