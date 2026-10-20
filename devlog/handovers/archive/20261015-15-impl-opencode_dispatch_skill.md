---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The general OpenCode dispatch skill

## Objective

Give the harness a general subagent over OpenCode on the free model, the read-write counterpart to the read-only reviewer dispatch, so the free tier is usable for real work and not only for review.

## Scope

The skill and its script, in the repository and installed into the agent home so it is usable now.

Out of scope: the proof dispatch, which is the next unit; the parallel fan-out, which is the `taskq_*` shape.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill exists with valid frontmatter | `SKILL.md` carries `name` and `description`; `bash scripts/lint.sh` frontmatter gate | Accepted |
| The script builds its command through the runner seam | `dispatch.sh` sources `<repo>/src/libs/dispatch.sh` and calls `dispatch_command`; the flag mapping has one home | Accepted |
| The script refuses the preconditions | brief missing or empty, scratch absent or unwritable, dirty tree | Accepted |
| The script is shellcheck clean | `shellcheck -S warning`, clean | Accepted |
| The skill is usable now | installed at `$AGENT_HOME/agent/skills/opencode-dispatch/` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Read-write, unlike the reviewer dispatch | the operator wants a general subagent, not a constrained reviewer | `SKILL.md` |
| The default model is `opencode/deepseek-v4.1-flash-free` | the free tier pi cannot reach, the model the operator names as general | `SKILL.md`; `dispatch.sh` |
| The worker runs in the working tree, one at a time, from a clean tree | the change set is then the worker's and the caller attributes it; a worktree per worker is the `taskq_*` shape | `SKILL.md` |
| The command is built through the seam, not restated | the flag mapping has one home | `dispatch.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The skill is a general worker, not a reviewer, so it needs isolation the reviewer does not. The first cut runs in the working tree with a clean-tree precondition and a single worker; parallel work is the `taskq_*` shape. | design boundary | `SKILL.md` non-goals |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md) | new: the worker contract, the form, the steps, the non-goals, the failure modes |
| [`dispatch.sh`](../../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh) | new: the dispatch wrapper over the runner seam |
| [`devlog/roadmap.md`](../../roadmap.md) | the dispatch-skill row |
