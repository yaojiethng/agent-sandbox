# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation (workflow audit, not implementation)
**Session type:** Workflow

## Objective

Diagnose and fix the handover leanness problem: handovers are carrying completed acceptance criteria, changed files, and ticked task checklists from prior sessions, creating noise that obscures the current session's actual scope and in some cases violates policy.

## Scope

- Audit `handover_policy.md` and `iteration_policy.md` against the observed problem
- Identify which rules are missing, ambiguous, or not enforced
- Propose targeted amendments to policy documents

Not in scope: roadmap changes, implementation tasks, M2.2 provider integrations.

## Acceptance criteria

- [x] `handover_policy.md` amendments proposed and operator-confirmed: no checklist copying in Scope, Completed table resets at session open, accepted criteria do not carry forward

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Primary subject — population rules and format definition |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Accepted criteria do not carry forward to next handover; only pushed criteria transfer | Completed criteria are noise in the next session's context | `handover_policy.md` |
| Completed this session table resets to null marker at session open | Table is session-scoped; prior session's file changes are irrelevant to current session | `handover_policy.md` |
| Scope section must not copy task items or checkbox state from prior handover | Roadmap is the canonical task list; duplicating it in the handover creates drift | `handover_policy.md` |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/handover_policy.md` | Four targeted amendments: Scope no-copy rule, Completed table reset, accepted-vs-pushed criteria distinction at session open and in Rules section |

## Deferred items

None.

## Next session

Chore session — `docs/` folder restructure.

Proposed moves (operator-specified, to be scoped at session open):
- `docs/log/` → `docs/devlog/`
- `docs/development/discussions/` → `docs/devlog/discussions/`
- `docs/development/handovers/` → `docs/devlog/handovers/`
- `docs/development/changelog.md` → `docs/devlog/changelog.md`
- `docs/development/roadmap.md` → `docs/devlog/roadmap.md`
- `docs/development/roadmap_future.md` → `docs/devlog/roadmap_future.md`

Watch-out items:
1. Cross-references to all moved files are pervasive — `documentation_policy.md`, `iteration_policy.md`, `roadmap_policy.md`, `handover_policy.md`, `agent_context_brief.md`, `contributors.md`, `readme.md`, and any story/investigation documents will need link updates.
2. `documentation_policy.md` folder ownership table will need amending to reflect the new structure.
3. Scope the full affected file list before producing any moves — grep for each moved path is the right starting point.
