# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Fix the `task-queue` prompt frontmatter that failed to parse, add the frontmatter-quoting rule to the prompt-authoring conventions, and reconcile the standalone `commit-discipline-checkpoint` runbook into a `/wrapup` stub in `workflow/coding-agent/prompts/`, recording the close steps' current owners and leaving only the shared-invocation items open.

## Scope

- `src/reasoning/agent/prompts/task-queue.md` -- quote the `description` value so the YAML frontmatter parses; text byte-for-byte unchanged.
- `docs/development/prompt-authoring-conventions.md` -- add the frontmatter-quoting rule to the `**Description.**` paragraph.
- Rename `workflow/coding-agent/commit-discipline-checkpoint.md` to `workflow/coding-agent/prompts/wrapup.md`; quote its frontmatter; retitle as `/wrapup`; add a reconciliation note against the recovered old `/wrapup` (commit `ddb30d1`).
- `devlog/AGENT_FEEDBACK.md` -- update the `commit-discipline-checkpoint` runbook reference to the new name and path.
- `devlog/roadmap.md` -- update row 84's landing note to record the reconciliation; row stays open.

Out of scope: the full shared `/wrapup` runbook (roadmap row 84's future end state), and the four other prompt/skill files that share the unquoted-description defect (`commit`-discipline is fixed; the three disposal-bound skill files and `commit-discipline` -- see Findings).

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Double-quote the description rather than single-quote | the value contains `operator's` apostrophes, which break a single-quoted YAML scalar | conventions doc |
| Do not restore the old `/wrapup` content verbatim | it would duplicate `/iter` Steps 7 and 8-9 and `/milestone-close`, the anti-goal of roadmap row 84's one-rule-one-owner | `wrapup.md` reconciliation note |
| Reconcile (Option 2) now; defer the shared-invocation dedup (Option 1) to roadmap row 84's iteration | the dedup is roadmap-84's actual deliverable; restoring now would preempt it | roadmap row 84 landing note |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `task-queue.md` frontmatter parses | `yaml.parse` on the frontmatter | Met |
| 2 | conventions doc carries the frontmatter-quoting rule and lints clean | `scripts/check_markdown.sh` | Met |
| 3 | runbook renamed to `prompts/wrapup.md`; old path removed | `git status`, `ls workflow/coding-agent/` | Met |
| 4 | `devlog/AGENT_FEEDBACK.md` and old-name references updated; no stale `commit-discipline-checkpoint` reference remains | `grep -rn "commit-discipline-checkpoint"` | Met |
| 5 | roadmap row 84 records the reconciliation; row stays open | roadmap row 84 | Met |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/task-queue.md` | description quoted; parses |
| `docs/development/prompt-authoring-conventions.md` | frontmatter-quoting rule added; lint clean |
| `workflow/coding-agent/{commit-discipline-checkpoint.md => prompts/wrapup.md}` | renamed, frontmatter quoted, retitled, reconciliation note added |
| `devlog/AGENT_FEEDBACK.md` | runbook reference updated |
| `devlog/roadmap.md` | row 84 landing note updated |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Four other files carry the same unquoted-description parse defect: `commit-discipline-checkpoint.md` was fixed by this iteration; `dhh-code-audit.skill.md`, `architecture-doc-reviewer.skill.md`, `kelsey-code-reviewer.skill.md` remain, and two of them are slated for removal and one for folding into `bash-audit` under M3.2.2 | surfacing | Deferred: leave the three disposal-bound skill files to their scheduled disposition |
| No prompt currently owns closing ADRs and discussion docs whose work landed | gap | Rides roadmap row 84's Option 1: the shared `/wrapup` must cover it |
| The recovered old `/wrapup` carried the full close sequence now split across `/iter` and `/milestone-close` | context | Recorded in `wrapup.md` reconciliation note |
| `/iter` is pedantic: it pauses for confirmation at nearly every step instead of only at the gates; the operator previously expected to respond only at Gate 1, 2, 3 | steering (operator, 2026-09-29) | Fold into roadmap row 83 (`/iter` gate collapse and per-prompt quality pass) |

## Deferred items

- The three skill files (`dhh-code-audit`, `architecture-doc-reviewer`, `kelsey-code-reviewer`) with the unresolved description-defect class -- wait on M3.2.2's disposal/folding, then fix or retire.
- The shared `/wrapup` dedup (roadmap row 84) -- the next iteration's scope.

## What's Next

Seed the next iteration: roadmap row 84, the shared `/wrapup` close runbook (Option 1). The `/wrapup` stub is the base; it grows into the full shared close and `/iter`, `/plan` and `/milestone-start` link to it.
