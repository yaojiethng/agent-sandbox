# Agent Handover

**Session date:** 2026-04-22
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Audit the minor loop workflow for discipline failures and produce prompt templates and policy additions to enforce propagation coverage and gate adherence.

## Scope

Workflow audit session. No implementation tasks. Produced policy additions to `handover_policy.md` and `AGENTS.md` (Pi), and four prompt templates for the Pi prompt system: `/session`, `/wrapup`, `/defer`, `/propagation-check`.

## Carried forward

None.

## Acceptance criteria

Not yet defined. Workflow session — no operator-runnable acceptance criteria apply.

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `docs/operations/handover_policy.md` | Added pre-close propagation replay gate (Step 7b subsection) | ✓ Complete |
| `AGENTS.md` (Pi) | Added Propagation Discipline section | ✓ Complete |
| `.pi/prompts/session.md` | New prompt template — `/session` | ✓ Complete |
| `.pi/prompts/wrapup.md` | New prompt template — `/wrapup` | ✓ Complete |
| `.pi/prompts/defer.md` | New prompt template — `/defer` | ✓ Complete |
| `.pi/prompts/propagation-check.md` | New prompt template — `/propagation-check` | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Propagation checklist added to AGENTS.md (Pi) | Smaller models skip files silently on multi-file rule changes; externalising state into a chat checklist makes coverage verifiable | `AGENTS.md` — Propagation Discipline |
| Pre-close propagation replay gate added to handover_policy.md | Checklist during implementation + replay at close gives two checkpoints; catches gaps the live checklist missed | `handover_policy.md` — At pre-close verification (Step 7b) |
| AC definition rolled into `/session` (Step 6 gate) | Step 1b already gates on scope; AC must be agreed before implementation begins — same confirmation moment | `/session` template |
| `/spec` template deferred | Step 1b scope gate covers the failure mode; not needed now | None — deferred |
| Step numbers removed from prompt templates | Numbers add maintenance surface; policy link is more durable and correct | All four templates |
| `/defer` template added | Scope creep absorbed silently is a common failure; low-ceremony parking mechanism needed | `/defer` template |

## Completed this session

| File | Change summary |
|---|---|
| `docs/operations/handover_policy.md` | Added "At pre-close verification (Step 7b)" subsection — propagation replay table, trigger conditions, operator release gate |
| `AGENTS.md` (Pi) | Added "Propagation Discipline" section — pre-task checklist requirement, trigger language, rationale |
| `.pi/prompts/session.md` | New — Steps 1, 1b, 6 of minor loop; scope + AC confirmation gate |
| `.pi/prompts/wrapup.md` | New — Steps 7b, 8, 9 of minor loop; AC verification, propagation replay, scope reconciliation, roadmap mark, Trigger B, handover close, next session seed |
| `.pi/prompts/defer.md` | New — mid-session scope parking; records to Deferred items, prohibits partial fix |
| `.pi/prompts/propagation-check.md` | New — grep-first file discovery, propagation table, gap reporting, fix-or-defer |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation.
**Trigger B:** Not pending — mid-milestone, implementation not yet begun.

First task is Unit A (`INIT_SHA` at container init). Read the roadmap M2.3 pending section for the full A–G unit list and dependency order. Implement Unit A only.

**Watch-outs:**
- Grep `libs/` and `scripts/` for `BASELINE_SHA` callers before removing any write logic.
- `INIT_SHA` is written once at container init and never updated.
- Upload `scripts/apply_workspace.sh`, `scripts/checkpoint.sh`, `libs/diff.sh`, `libs/snapshot.sh`, `scripts/start_agent.sh`, `.skills/package-diff.md` at session open.

Context handover: [`20260422-01-design-change6_baseline_advancement_redesign.md`](handovers/20260422-01-design-change6_baseline_advancement_redesign.md)
