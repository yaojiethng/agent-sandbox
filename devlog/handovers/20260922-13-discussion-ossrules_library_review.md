# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3 -- T1 - Workflow + Policy Organization
**Type:** Discussion
**Status:** Closed

## Objective

Record the ossrules.md library exploration as a design-draft discussion document and schedule its review as a roadmap task under T1.

## Scope

The roadmap T1 task list gains one new entry: review the design-draft discussion document and decide which instruction patterns and skills to adopt. The exploration itself was already delivered in chat; the discussion document carries its findings.

## Carried forward

None.

## Acceptance criteria

- The discussion document exists at `devlog/discussions/20260922-design-draft-ossrules_instruction_patterns.md` with the design-doc section order (Context, Options Considered, Decision, Consequences) and pinned source links.
- The roadmap T1 list carries the new review task `Agent-instruction pattern review (ossrules.md library)`, linking the design draft.
- The staged Markdown gate reports zero findings on the three touched files.

Verified: all three criteria by `scripts/check_markdown.sh` (Clean, 0 findings) and file reads.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | gains the scheduled review task under T1 - Workflow + Policy Organization |
| [`devlog/discussions/20260922-design-draft-ossrules_instruction_patterns.md`](devlog/discussions/20260922-design-draft-ossrules_instruction_patterns.md) | the new design-draft discussion document |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Discussion-doc type `design`, status `draft` | the document records decision exploration pending review, per `discussion_policy.md` | the discussion document |
| Review scheduled as a T1 task, not performed this iteration | the operator asked to schedule the review; no instruction changes land until the review decides | roadmap T1 row |

## Findings

None.

## Completed

- [x] Created `devlog/discussions/20260922-design-draft-ossrules_instruction_patterns.md` - the exploration record with five patterns, four skills, pinned sources, and the adoption recommendation
- [x] Added the review task to roadmap T1 - Workflow + Policy Organization, linking the design draft
- [x] Markdown lint gate on the three touched files: Clean

## Deferred items

None.

## What's Next

T1 - Workflow + Policy Organization: the `Agent-instruction pattern review (ossrules.md library)` task. The review decides which patterns and skills move into `AGENTS.md` and the policy docs; the design draft is the input. File the skill adoption under M8 (Skills / Templates).
