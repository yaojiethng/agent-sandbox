---
date: 2026-10-24
milestone: M3.6.5 - OpenCode as a first-class provider
type: Workflow
status: Closed
---

# Handover - The argument placeholder unifies on `$ARGUMENTS`

## Objective

Rewrite every prompt that passes the operator's argument through so it names `$ARGUMENTS`, the only all-arguments form both pi and OpenCode substitute.

## Scope

The five prompt roots: `workflow/coding-agent/prompts/`, `src/reasoning/agent/prompts/`, `src/reasoning/providers/pi/config/agent/prompts/`, `.agents/prompts/` and `.agents/drafts/`. Records are out of scope: a handover, changelog or discussion that quotes `$@` is stating history. `src/reasoning/agent/prompt-templates.md` is also out of scope, because the open row **The duplicated runtime documentation is deleted** owns its deletion, and its sentence stays true of pi until then.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No prompt file carries `$@` | `grep -rn '\$@' --include=*.md workflow/coding-agent/prompts src/reasoning/agent/prompts src/reasoning/providers/pi/config/agent/prompts .agents/prompts .agents/drafts` prints nothing | Agent [x] |
| Every opening-line template uses `$ARGUMENTS` | `grep -rl '^> \$ARGUMENTS' --include=*.md` over the five roots returns 31 files | Agent [x] |
| The five inline carriers use it too | `grep -n 'ARGUMENTS' src/reasoning/agent/prompts/{agent-sandbox,defer,advisor}.md src/reasoning/providers/pi/config/agent/prompts/pi-agent.md .agents/prompts/auto.md` | Agent [x] |
| The roadmap row closes with this record | `grep -n 'The argument placeholder unifies' devlog/roadmap.md` shows `- [x]` and the handover id | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The nine `.agents/drafts/` prompts are rewritten too | a draft that is promoted would carry `$@` into a live prompt, which is the defect this row exists to remove | this record |
| Records are left alone | a handover or discussion quoting `$@` is evidence of what was written then, not a template | this record |
| `prompt-templates.md` is left alone | its sentence describes pi's accepted forms and is true; its deletion is a separate open row | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row filed 23 prompt files; the measured count is 36 | record | the row understated the sweep by 13 files, nine of them drafts and four carrying the placeholder inline | this record, and the closing note states the measured count |
| `src/reasoning/agent/prompt-templates.md` still says "`$@` or `$ARGUMENTS` for all args joined" | record | true of pi, so it does not contradict the prompt files; it goes with its own row | the open row **The duplicated runtime documentation is deleted** |

## Completed

| File | Change |
|---|---|
| [`adversarial-review-run.md`](../../.agents/drafts/adversarial-review-run.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`close-the-model-bypass-run.md`](../../.agents/drafts/close-the-model-bypass-run.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`dispatch-mechanism-run.md`](../../.agents/drafts/dispatch-mechanism-run.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`maintenance.md`](../../.agents/drafts/maintenance.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`parallel-work.md`](../../.agents/drafts/parallel-work.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`review-loop-run.md`](../../.agents/drafts/review-loop-run.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`seat-contract-run.md`](../../.agents/drafts/seat-contract-run.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`sequential-work.md`](../../.agents/drafts/sequential-work.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`task-queue.md`](../../.agents/drafts/task-queue.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`auto.md`](../../.agents/prompts/auto.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`dont-know-dont-care.md`](../../.agents/prompts/dont-know-dont-care.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`resync.md`](../../.agents/prompts/resync.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`advisor.md`](../../src/reasoning/agent/prompts/advisor.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`agent-sandbox.md`](../../src/reasoning/agent/prompts/agent-sandbox.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`defer.md`](../../src/reasoning/agent/prompts/defer.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`package-branch.md`](../../src/reasoning/agent/prompts/package-branch.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`pi-agent.md`](../../src/reasoning/providers/pi/config/agent/prompts/pi-agent.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`commit.md`](../../workflow/coding-agent/prompts/commit.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`document.md`](../../workflow/coding-agent/prompts/document.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`gm.md`](../../workflow/coding-agent/prompts/gm.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`iter.md`](../../workflow/coding-agent/prompts/iter.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`merge.md`](../../workflow/coding-agent/prompts/merge.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`package-eval-snapshot.md`](../../workflow/coding-agent/prompts/package-eval-snapshot.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`plan.md`](../../workflow/coding-agent/prompts/plan.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`read-back.md`](../../workflow/coding-agent/prompts/read-back.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`rebase.md`](../../workflow/coding-agent/prompts/rebase.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`record-correction.md`](../../workflow/coding-agent/prompts/record-correction.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`scope.md`](../../workflow/coding-agent/prompts/scope.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`sidequest.md`](../../workflow/coding-agent/prompts/sidequest.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | the argument placeholder becomes `$ARGUMENTS` |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes with the measured count |
| [`devlog/handovers/20261024-11-workflow-argument_placeholder.md`](20261024-11-workflow-argument_placeholder.md) | this record |
