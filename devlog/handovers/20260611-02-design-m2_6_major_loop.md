# Agent Handover

**Date:** 2026-06-11
**Type:** Design — Major Loop Planning
**Status:** Closed

## Objective

Initiate the major loop for M2.6 (Session Resume Across Provider Implementations). Scope the sub-milestone, resolve open design questions, and produce a confirmed roadmap entry that meets the milestone policy scoping criteria, so that minor loop implementation sessions can begin.

## Context

M2.7 (Session Identity and Harness Versioning) is complete and closed in the changelog. M2.6 is the next unstarted sub-milestone under M2. It is already defined in `roadmap.md` under `## Upcoming Milestones` with an objective and scope paragraph, but has no story closure, no resolved design decisions, and no task list — meaning it does not yet meet the milestone policy's "ready to session" criteria.

## Scope

This session is a major loop planning session. Per `milestone_policy.md`, the output should be:

- A scoped and ready M2.6 with resolved design decisions, recorded rationale, and a task list specific enough that each item identifies a file and a nature of change
- Explicit records of what cannot yet be scoped and why
- A confirmed roadmap entry

## Open Questions (to be resolved this session)

1. **Investigation scope** — M2.6's objective says "Investigation-first. Characterise session file format, export mechanism, and resume invocation for pi, Hermes, and opencode." Should this be run as one investigation per provider, or a single comparative investigation?
2. **Autosave reliability** — A task was moved from M2.7: "Autosave subshell has no resilience; EXIT trap discards diff_export return value." Where does this fit in the M2.6 task list?
3. **Compose template hardcoded Pi path** — flagged in `story_agent_state_persistence.md`. Does this block non-Pi providers from working, and should it be resolved as part of M2.6?
4. **Story closure** — `story_agent_state_persistence.md` is the related story. Is it ready to graduate to a roadmap entry, or does it need further investigation?
5. **Provider order** — pi, Hermes, and opencode each have different known starting points for session resume. What order should they be tackled in?

## Inputs Read

- `docs/operations/milestone_policy.md` — major loop definition, scoping criteria, closure rules
- `docs/operations/roadmap_policy.md` — roadmap update rules, compaction, milestone promotion
- `docs/operations/story_policy.md` — story graduation and closure (referenced by milestone policy)
- `devlog/roadmap.md` — M2.6 section, related story reference, deferred items from M2.7
- `devlog/changelog.md` — M2.7 closure confirmed
- `devlog/discussions/story_agent_state_persistence.md` — related story with open questions

## Proposed Agenda

1. Confirm M2.7 closure is clean and M2.6 is the next sub-milestone
2. Review each open design question above and reach resolution
3. Decide investigation structure: per-provider or comparative
4. Scope the task list to "ready to session" granularity
5. Resolve or explicitly defer `story_agent_state_persistence.md`
6. Update `roadmap.md` with resolved decisions and task list
7. Confirm the entry meets milestone policy scoping criteria before closing

## Next Step

Wait for operator response to confirm the agenda, discuss open questions, and proceed with scoping.
