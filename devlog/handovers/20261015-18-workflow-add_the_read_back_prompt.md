---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Workflow
status: Closed
---

# Handover - Add the read-back prompt

## Objective

Add one operator-directed prompt, `/read-back`, that asks the agent to restate the operator's goals and the problem in its own words.

## Scope

One new file, `workflow/coding-agent/prompts/read-back.md`. Nothing else changed.

The operator invoked `/sidequest`. No handover carried `status: Active`, so the sidequest's parent-link precondition failed and the runbook's own failure mode applied: the work ran as one small iteration with its own handover. The missing Active handover for the open M3.6.1 work is itself a record gap, and it is recorded below rather than fixed here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt file exists | `workflow/coding-agent/prompts/read-back.md` | Agent [x] |
| Its frontmatter parses | `bash scripts/check_frontmatter.sh` clean | Agent [x] |
| It is reachable as `/read-back` | the file sits in the module prompt root the image copies, `COPY workflow/coding-agent/prompts/`, and the frontmatter gate accepts it | Agent [x] |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The body takes the prompt shape, not the given skill shape | the given body carried skill frontmatter (`name`, `disable-model-invocation`); the project's prompt convention is `description` plus `argument-hint` and a `> $@` line, and a prompt is operator-invoked by construction so the skill field is inert | this record; the file |
| One term, `operator`, in both the description and the body | the project's vocabulary is `operator`, and one file carries one term; the given sentence said `user` | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| No handover carries `status: Active`, so the open M3.6.1 work has no interrupted handover for a sidequest to name. The sidequest runbook's failure mode routes the work to a normal iteration, which is what ran. | record gap | the open M3.6.1 work should carry one Active handover; not fixed here |
| The given body was skill-shaped, and the project's frontmatter gate parses either form, so only the authoring convention separates a skill-shaped file from a prompt root. | authoring, caught at the gate | the Option B decision above |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/read-back.md`](../../workflow/coding-agent/prompts/read-back.md) | new: the read-back prompt |

## Roadmap write-back

None. The change is operator-directed and self-contained, and it had no roadmap row; no row is created for a one-file prompt addition.
