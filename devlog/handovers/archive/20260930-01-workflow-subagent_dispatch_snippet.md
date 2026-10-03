# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Harden the subagent-dispatch guidance the agent actually follows so a silent no-op dispatch (an empty brief producing rc=0 and no work) fails loudly before it runs. Deliver the change as a bash snippet in a code block, not a bundled script, so no new script file enters the tree. Record the separate task-queue documentation gap (task-queue invisible to the agent) in the roadmap under the existing task-queue improvement tasks; do not implement that fix this iteration.

## Scope

- Harden the `-p "$(cat brief)"` invocation snippet in the provider-layer `AGENTS.md` source (`src/reasoning/providers/pi/config/agent/AGENTS.md`, Running Review Subagents section) into a bash code block that pre-flights the brief and records rc and elapsed-seconds out of band.
- Harden the parallel-auto dispatch snippet (`workflow/coding-agent/prompts/parallel-auto.md`, Step 3) with the same pre-flight guard.
- Directives: record the taskq/task-queue documentation gap (the extension is not surfaced to the agent) in the roadmap under the existing task-queue improvement tasks; do not fix it this iteration.
- Scope-gate steering: update the repo-source AGENTS.md only; the installed copy `~/.pi/agent/AGENTS.md` is not updated this iteration.
- Scope-gate steering: write the magic-constant rule (a fixed timeout or other literal in a snippet disincentivizes the agent from setting its own number) into `docs/development/prompt-authoring-conventions.md`, per the finding.
- In scope (scope-gate steer): drop the magic `1800` timeout from the AGENTS.md snippet; the agent sets its own.
- In scope (scope-gate steer): the parallel-auto prose maps observed output to its meaning ("this is what you see" -> "this is what happened").

## Decisions

| Decision | Rationale | Where recorded |
|------------|--------------------|-----------------|
| Update the repo-source AGENTS.md only, not the installed copy | operator scope-gate steer, 2026-09-30 | this handover |
| Deliver the guard as a bash snippet in a code block, not a bundled script | no new script file; both surfacing points already inline bash | this handover + scope gate |
| Hardcode no magic constants in the snippet; the agent sets its own timeout | a fixed literal disincentivizes the agent from choosing its own number | this handover + `prompt-authoring-conventions.md` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The AGENTS.md subagent-dispatch section carries a fenced bash snippet with a `[ -s "$brief" ]` guard, an out-of-band rc/sec record, a non-hardcoded timeout, and no bare `-p "$(cat brief)"` | `grep -n` the repo source | Accepted at scope gate |
| 2 | The parallel-auto Step 3 snippet carries the same guard ahead of the `cd` line and a symptom-to-meaning mapping | `grep -n` on `workflow/coding-agent/prompts/parallel-auto.md` | Accepted at scope gate |
| 3 | No new script file under `scripts/` (snippets only) | `git status` after edits | Accepted at scope gate |
| 4 | The taskq/task-queue documentation gap is recorded in the roadmap under the existing task-queue improvement tasks | `grep -n` the roadmap row | Accepted at scope gate |
| 5 | The magic-constant rule lands in `docs/development/prompt-authoring-conventions.md` | `grep -n` the rule | Accepted at scope gate |

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Hardcoding a magic constant (e.g. `timeout 1800`) in a snippet disincentivizes the agent from setting its own number** (operator, 2026-09-30): a fixed timeout literal reads as the sanctioned value and the agent does not override it. Snippets should name an unbound variable or an explicit agent-chosen value, not a literal. | steering | `docs/development/prompt-authoring-conventions.md` -- resolved: write-back this iteration |

## Completed

| File | Change | Status |
|---|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | subagent-dispatch line replaced with fenced bash snippet: `[ -s "$brief" ]` guard, out-of-band rc/sec record, agent-set timeout (magic `1800` removed) | done |
| `workflow/coding-agent/prompts/parallel-auto.md` | Step 3 dispatch: `[ -s "$brief" ]` guard ahead of the `cd` line; explanatory paragraph replaced with symptom-to-meaning mapping | done |
| `devlog/roadmap.md` | task-queue documentation-gap row (invisible to the agent) recorded under the existing task-queue improvement tasks | done |
| `docs/development/prompt-authoring-conventions.md` | "No magic constants in a snippet" rule added after the Degrees of freedom guidance | done |
| `devlog/handovers/20260930-01...md` | handover: scope, decisions, AC, findings, completed | done |

## Deferred items

- Fixing the taskq/task-queue documentation gap itself (surface task-queue to the agent context) -- recorded in the roadmap under the task-queue improvement tasks; not implemented this iteration.

## What's Next

The taskq/task-queue documentation gap itself is the next iteration: surface task-queue to the agent so a parallel-dispatch agent reaches for the fork/join/merge primitive over the raw `git worktree add` + `pi -p` loop. The gap row is recorded in the roadmap under the existing task-queue improvement tasks. Deferred items take priority: fix-taskq-doc-gap is the named next scope.
