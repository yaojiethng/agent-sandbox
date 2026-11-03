---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the handoff records the two fixed forms, not a summary of them

## Objective

Give `handoff` the cases where the operator already knows what the artifact is, so a workshopped prompt and an error report are preserved whole rather than summarised away at the end of a session.

## Scope

`src/reasoning/agent/skills/handoff/SKILL.md` and its edge in `.agents/registry/sources/mattpocock-skills.json`. The skill is vendored from `skills/productivity/handoff` at `a496f55`, so the edit is a local adaptation and the edge carries it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both forms land in `.agents/drafts/` and carry the marker the folder already uses | `sed -n '12,15p' src/reasoning/agent/skills/handoff/SKILL.md` | Agent [x] |
| An error report carries the four parts and no imposed headings; a skill is routed elsewhere | `sed -n '12,17p' src/reasoning/agent/skills/handoff/SKILL.md` | Agent [x] |
| The drafts folder carries the state, not the file | Sixteen files in `.agents/drafts/` carried three conventions for one fact: `**Status:** draft` on seven, `status: Active` on one, nothing on eight. `20261002-19` decision 1 already called the folder the durable gate, and the path is the fact; a marker beside it is a second owner, unchecked by any gate, that a promoted file would carry into a live root as a false statement. Instruction artifacts carry no status field at all: one of 184 carries one, and it is the handover template asset | `instruction-authoring` step 6, `/scope`, this skill |
| A release confirms the frontmatter parses | `grep -n 'confirms the frontmatter parses' .agents/skills/instruction-authoring/SKILL.md` | Agent [x] |
| The vendored adaptation is recorded | `bash scripts/check_skill_sources.sh` clean across 5 sources and 11 artifacts | Agent [x] |
| The shipped skill reaches nothing it cannot | `bash scripts/lint.sh` clean, 20 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Both fixed forms land in `.agents/drafts/`, not a discussion record | The folder already holds an example of the error report - a runnable brief with `argument-hint`, `> $ARGUMENTS` and per-defect `**Repro.**` blocks - and a `devlog/discussions/` story would have been a second shape for one artifact | the handoff body |
| The rule states the report's content and leaves its headings to the writer | An imposed section list is a format rule the reader cannot check and the writer must fight; the four parts are the requirement | the handoff body |
| The prompt is written verbatim, and releasing it follows the authoring convention | The workshopping is the value; a summary of a prompt is not the prompt, and the release rule already has one owner | the handoff body |
| A skill is not handed off: it is routed to `instruction-authoring` | A skill is created deliberately, with a root and a type decision, which is not what a session-end compaction is for; the handoff names the owner instead | the handoff body |
| The release confirms the frontmatter parses | A draft folder is never scanned, so an unparseable block is invisible there; the check belongs at the moment the file enters a live root | `SKILL.md` step 6 |
| `handoff` parks, and does not release | Release is the operator's word, and a session-end compaction that promotes its own text is the `maintenance` incident with another door. So it is a second route *into* drafts, not a second promoter, and `runbook/promotion.md` still has one caller | this record |
| The paragraph sits before the "do not duplicate" line | That line is what breaks this case: the prompt is captured nowhere, so there is no artifact to reference instead | the handoff body |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `.agents/drafts/` holds four kinds - prompt drafts, run briefs, handoff briefs and one handover-shaped file - and states its marker inconsistently: `**Status:** draft` on most, `status: Active` on one, none on `dispatch-harness-defects-handoff.md` | defect | a reader cannot tell the folder's rule from its practice | not fixed; named here |
| The first draft of this unit sent the error report to a `devlog/discussions/` story record | defect, corrected before landing | would have created a second home for a shape the folder already holds | the operator's correction, applied |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/handoff/SKILL.md` | the fixed-form paragraph and its two bullets |
| `.agents/registry/sources/mattpocock-skills.json` | the `handoff` edge's `record.added` names the adaptation |
