---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Bump the mattpocock skills source

## Objective

Move the `mattpocock/skills` source to `a496f55` and take in `grilling`, `handoff` and `retro`, reconciling them with the existing `grill-me` and `writing-for-agents` forks.

## Scope

The mattpocock source refresh under M3.3.3: the `grill-me` and `writing-for-agents` edges move to `a496f55`, and `grilling`, `handoff` and `retro` land as new forks.

The `grill-me` fork follows the upstream split. `grill-me` stays the user-invoked skill whose body carries this repository's three-part problem summary and then invokes `grilling`; `grilling` carries the interview method itself. `grill-me`, `handoff` and `retro` disable model invocation; `grilling` remains model-invocable.

Out of scope: the other three edges (`domain-model`, `improve-codebase-architecture`, `setup-pre-commit`), whose upstream also moved at `a496f55`. `domain-model`'s upstream path is gone, which is a rename decision of its own; `improve-codebase-architecture` and `setup-pre-commit` are not named in the operator's request.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `grill-me`, `handoff` and `retro` carry `disable-model-invocation: true`, and `grilling` does not | `rg -n 'disable-model-invocation'` over the four skills shows the first three only | Agent [x] |
| `grill-me` carries the three-part problem summary and invokes `grilling`; `grilling` carries the design-tree interview method and no problem summary | `rg` in both skills; the negative check on `grilling` returns nothing | Agent [x] |
| `handoff` saves under `.scratchpad/` and names skills to read, with no `Skill tool` phrasing | `rg` both classes; the `Skill tool` check returns nothing | Agent [x] |
| `retro` names this repository's records and no `CLAUDE.md` or `CODING_STANDARDS.md` | `rg` both classes; the removed references return nothing | Agent [x] |
| Each new skill carries a record naming `mattpocock-skills`, and the skill-source gate is clean across eleven records | `bash scripts/check_skill_sources.sh` | Agent [x] |
| The store moves the `grill-me` and `writing-for-agents` bases to `a496f55` and adds `grilling`, `handoff` and `retro` at that revision | `node scripts/source_bump.mjs check`; read the eight edges | Agent [x] |
| The live counts follow: `source_tracking.md` says eight edges, and the skill-source test expects eleven records | `rg -n 'eight edges' docs/development/source_tracking.md`; `bash tests/test_skill_sources.sh` | Agent [x] |
| The roadmap row is `[x]` with handover `20261031-03` | `rg -n 'mattpocock source' devlog/roadmap.md`; `git diff devlog/roadmap.md` | Agent [x] |
| Every decision recorded this iteration is realized in the files | read `## Decisions`; check each destination | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Follow the upstream split: `grill-me` is the user-invoked entry and `grilling` carries the interview, while this repository's problem-summary logic stays in `grill-me` | The operator asked for `grill-me` to invoke `grilling` the way upstream does, and for our specialized logic to sit in `grill-me`; the summary grounds the interview, and `grilling` owns the method | this handover |
| `grill-me`, `handoff` and `retro` carry `disable-model-invocation: true`; `grilling` stays model-invocable | Operator direction; upstream sets the flag on the first three, and `grilling` is the linked method | this handover |
| `handoff` saves to `.scratchpad/` | The upstream writes to the OS temp directory; this repository's session scratch is `.scratchpad/`, which a `/fork` or `/tree` carries and which never reaches the diff | this handover |
| `retro` reports to `devlog/AGENT_FEEDBACK.md` and the roadmap | This repository's feedback record and task list are the durable destinations; the upstream's `CODING_STANDARDS.md` and `CLAUDE.md` are not files this project holds | this handover |
| The other three edges stay pinned | The operator named five artifacts; the remaining three are separate decisions, and `domain-model`'s upstream path no longer exists | this handover |
| Take upstream `a496f5513d4a4cf889bc48e189e579f4b0bdf6aa` | It is the HEAD of `mattpocock/skills` read from the clone on 2026-10-31 | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator requires `grill-me`, `handoff` and `retro` to disable model invocation. | steering | fixes the invocation mode for the three and leaves `grilling` model-invocable | this handover, Decisions |
| Upstream `grill-me` at `a496f55` is a router: `Call the Skill tool with "grilling".` The interview moved to `skills/productivity/grilling`. | structural change | a mechanical bump would replace the local interview with a two-line router | this handover, Decisions |
| `skills/engineering/domain-model` is absent at `a496f55`; the nearest path is `skills/engineering/domain-modeling`. | rename | the `domain-model` edge cannot be bumped without a rename decision | `roadmap.md`, `Refresh the remaining mattpocock edges` |
| `improve-codebase-architecture` drops `DEEPENING.md`, `INTERFACE-DESIGN.md` and `LANGUAGE.md`, and adds `HTML-REPORT.md`. | upstream rework | the fork's provider-specific subagent calls and sibling links need a fresh review | `roadmap.md`, `Refresh the remaining mattpocock edges` |
| `writing-for-agents` is unchanged from its `5beb35b0` base to `a496f55`. | no-op bump | only the store's base moves; the artifact and its record stay as they are | this handover, Completed |
| `setup-pre-commit` changes two lines at `a496f55`. | upstream edit | its edge is a cheap bump once the edge set is decided | `roadmap.md`, `Refresh the remaining mattpocock edges` |

## Completed

| File | Change |
|---|---|
| `.agents/registry/sources/mattpocock-skills.json` | Moved the `grill-me` and `writing-for-agents` bases to `a496f55` and added the `grilling`, `handoff` and `retro` edges. |
| `src/reasoning/agent/skills/grill-me/SKILL.md` | Kept the user-invoked entry and problem summary and made it invoke `grilling`. |
| `src/reasoning/agent/skills/grill-me/MAINTENANCE.md` | Records the upstream split and the router adaptation. |
| `src/reasoning/agent/skills/grilling/SKILL.md` | The design-tree interview method, with the `dispatch` skill and ASCII rounds. |
| `src/reasoning/agent/skills/grilling/MAINTENANCE.md` | Records the adaptation. |
| `src/reasoning/agent/skills/handoff/SKILL.md` | The session handoff, saved under `.scratchpad/`. |
| `src/reasoning/agent/skills/handoff/MAINTENANCE.md` | Records the adaptation. |
| `src/reasoning/agent/skills/retro/SKILL.md` | The retrospective, reporting to `devlog/AGENT_FEEDBACK.md` and the roadmap. |
| `src/reasoning/agent/skills/retro/MAINTENANCE.md` | Records the adaptation. |
| `docs/development/source_tracking.md` | The live store now holds eight edges. |
| `tests/test_skill_sources.sh` | The live tree now holds eleven records. |
| `devlog/roadmap.md` | Marks the bump row `[x]` with the handover and raises the remaining-edges row. |
| `devlog/handovers/20261031-03-workflow-mattpocock_bump.md` | Closed this handover. |
