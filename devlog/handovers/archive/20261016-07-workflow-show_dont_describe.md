---
date: 2026-10-16
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the show-dont-describe principle

## Objective

File the project's first communication principle as a skill, so a prose standard is a skill a writer reaches for rather than a document to search.

## Scope

The skill at `src/reasoning/providers/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md`, its installed copy, and the M3.3.4 row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states the rule | the pattern table replaces a description with the artifact, and the test asks whether the reader can copy | Accepted |
| Both faces of the rule are present | the artifact itself, and the output that proves a rule was followed | Accepted |
| The shape follows `principle-minimize-reader-load` | frontmatter, a definition line, the pattern, the why, the test | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prefix is `communication-principle` | it marks the project's set against the upstream `principle-*` set the pi provider ships | the skill's directory name |
| A principle is a convention, not a rule | it cannot be enforced, so it carries no gate and no authority claim | the M3.3.4 scope paragraph |
| The skill ships from the pi provider config | the repo's skill root installs to `$AGENT_HOME/agent/skills/`, so the principle travels with the image | the M3.3.4 row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The two added examples, the roadmap write-back and the commit message, are one rule in another tense: show the output rather than trust the reader. | design | they landed as rows of one table, not as a second principle |
| The render failure of the prior unit is the rule's worked case, because a flag table that states no order is a description where a literal invocation is an artifact. | evidence | not written into the skill, because a principle carries no case study |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md) | the new principle |
| [`devlog/roadmap.md`](../../roadmap.md) | the M3.3.4 first row marked `[x]` |
| `$AGENT_HOME/agent/skills/communication-principle-show-dont-describe/` | the installed copy, identical to the repository |
