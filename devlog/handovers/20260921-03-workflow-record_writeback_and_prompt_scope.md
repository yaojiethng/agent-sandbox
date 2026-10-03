# Handover - Record Write-Back Gate and Prompt-Scope Discipline

**Type:** Workflow
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Date:** 2026-09-21
**Status:** Closed
**Iteration:** 20260921-03
**Branch:** feat/M_3-orchestration

## Problem statement

Two T1 roadmap rows carry live feedback families. Both are recording/verification disciplines, not code changes:

- **Record write-back gate** -- a workflow gate verifying that a claimed record actually landed (row-key / content grep in the same turn). Resolves the recording/findings discipline family: findings churn + under-recording, throwaway stray files in the repo tree, a feedback follow-up note that is not a task assignment, and assert-without-write slips. Consolidated entry `[A] 2026-09-21` in `AGENT_FEEDBACK.md`.
- **Prompt-scope discipline** -- a campaign or review prompt must not contradict its own success criteria. Resolves the campaign-prompt-scope family: the test-quality-campaign prompt's "tests only - never change production source" contradicted criterion #3, which required touching the runner. Consolidated entry `[A] 2026-09-02`.

## Existing coverage

- `iteration_policy.md` already has a **roadmap write-back** procedure (Step 7/8-9) and a **findings review/publish step** at iteration end. The new record write-back gate is *distinct*: it fires at the moment of writing (same-turn grep), not at pre-close.
- `handover_policy.md` documents the Findings recording surface but has no verify-it-landed rule.
- `iteration_policy.md` Step 7's Roadmap write-back section states the procedure; the prompt-scope rule has no home yet -- it belongs near the prompt/campaign/review instructions.

## Accepted design

The scope grew during the discussion as the operator re-oriented the two tasks:

- The record write-back gate is the roadmap write-back gate extended to the other three record surfaces: findings rows, `AGENT_FEEDBACK.md`, `GOTCHAS.md`. It fires at the moment of writing (same-turn grep), not at pre-close.
- The real problem behind "a note is an observation, not a task" is cataloguing: a recurrence must land on its existing entry (grep-first, re-open, extend), so an increasing recurrence counter surfaces a pattern the operator can scope a durable fix for. Root cause of the note-is-a-task confusion: the GOTCHAS standing directive told the agent to "read the open gotchas and avoid or re-check" -- prohibition-style phrasing a literal agent turns into a free-floating task.
- Agents take instructions literally; the writing rules encode this. Add the literal-reader test to the STE100 section of `documentation_policy.md`: encode rules as instructions, not prohibitions; ask whether a literal reader would turn the sentence into a task.
- The prompt-scope rule is stronger than a non-contradiction statement: on detecting a scope/criterion contradiction at runtime, stop and ask the operator, do not resolve silently.

The reader-model for the feedback/gotchas records is amended to a cataloguing/frequency model: the agent does not read the raw file as a behavior source; it records a tripped mistake as a Finding, a recurrence re-opens its entry, a durable fix routes to a roadmap row (`scoped:`).

## Where the rules landed

| Rule | Home |
|---|---|
| Literal-reader test | `documentation_policy.md` STE100 section |
| Standing directives (cataloguing/frequency model) | root `AGENTS.md` lines 98-99 |
| Cataloguing rule (grep-first, re-open existing entry) | `devlog/AGENT_FEEDBACK.md` header |
| Reader-model reword | `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md` + `devlog/GOTCHAS.md` header/open-gotchas |
| Record write-back gate | `docs/operations/iteration_policy.md` recording block |
| Prompt-scope discipline (stop-and-ask) | `docs/operations/iteration_policy.md` + `test-quality-campaign.md` + `review-pass-run.md` |
| Roadmap rows | `devlog/roadmap.md` (two T1 rows done) |

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | added literal-reader test to the STE100 section |
| `AGENTS.md` (root) | reworded the two standing directives to the cataloguing/frequency model |
| `devlog/AGENT_FEEDBACK.md` | added the cataloguing rule to the header |
| `devlog/GOTCHAS.md` | reworded header and open-gotchas section to the new reader model |
| `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md` | amended the reader-model and next-session-integration sections |
| `docs/operations/iteration_policy.md` | added the record write-back gate and the prompt-scope discipline rules |
| `workflow/coding-agent/audits/test-quality-campaign.md` | seeded the stop-and-ask clause into the scope block |
| `workflow/coding-agent/prompts/review-pass-run.md` | seeded the stop-and-ask clause into the Scope directive item |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | added the `/tmp` throwaway-verification rule and the edit-tool-over-sed rule to the write discipline |
| `devlog/roadmap.md` | marked two T1 rows done; added the unify-`AGENT_FEEDBACK`/`GOTCHAS`-into-one-record row |
| `docs/adr/harness_iterative_improvement_loop.md` | created -- records the improvement-loop principle, current cataloguing model (2026-09-21) against the prior session-open-primer model (2026-08-09) |
| `devlog/handovers/20260809-04` | added the `[CORRECTION -- 2026-09-21]` tag superseding decision row 22 (session-open primer) |
| `devlog/AGENT_FEEDBACK.md` | flipped resolved entries to `probation`: Record write-back gate (`[A] 2026-09-21`) and Campaign prompt scope (`[A] 2026-09-02`) -- durable fixes now live in policy; kept for monitoring |

## Acceptance criteria

- [x] Literal-reader test added to the STE100 writing rules
- [x] Standing directives in root `AGENTS.md` ground the cataloguing/frequency model and drop the session-open reader
- [x] Cataloguing rule (grep-first, re-open existing entry) added to `AGENT_FEEDBACK.md`
- [x] Reader-model reworded across the settled discussion doc and `GOTCHAS.md`
- [x] Record write-back gate added to `iteration_policy.md` (same-turn grep, distinct from the roadmap write-back gate)
- [x] Prompt-scope discipline (stop-and-ask) added to `iteration_policy.md` and seeded into both prompt templates
- [x] Two T1 roadmap rows marked done
- [x] Follow-on propagation swept (see Findings)
- [x] `/tmp` throwaway-verification rule and edit-tool-over-sed rule added to the provider-layer `AGENTS.md` write discipline
- [x] ADR `harness_iterative_improvement_loop` created, logging this session's procedure changes against the prior design
- [x] `[CORRECTION -- 2026-09-21]` tag applied to `20260809-04` decision row 22
- [x] Lint gate clean

## Findings

- **Follow-on propagation caught after the written scope closed.** The raw `devlog/GOTCHAS.md` (header reader line and the open-gotchas section) still encoded the old "session-open primer / reads at Step 1 / avoids or re-checks" model after the root `AGENTS.md` directives were reworded. Fixed in this iteration. This is the propagation pattern to watch when a reader-model changes: the raw record surfaces and the policy pointer both carry the model, and both must move together.
- **Closed-origin decision carried the old model.** `devlog/handovers/20260809-04` decision-table row 22 recorded the settled "GOTCHAS integration = session-open primer" decision. At operator direction, the `[CORRECTION -- 2026-09-21]` tag was applied, superseding row 22. The historical record is kept (closed records are not edited in place; the tag documents the supersession and routes authority to the discussion doc and `AGENTS.md`).
- **`documentation_policy.md` literal-reader text self-cites "avoid or re-check those patterns"** as the rejected counter-example. That is intentional (it names the bad form); it is a negative illustration, not an instruction.

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Unify `AGENT_FEEDBACK.md` and `GOTCHAS.md` into one record | operator: lands in the very next iteration; ADR gets rewritten with a log entry appended | `devlog/roadmap.md` T1 row |

## What's Next

Next iteration: the two-forms merge (unify `AGENT_FEEDBACK.md` and `GOTCHAS.md`), followed by the ADR log entry. This iteration's substantive work (record write-back gate, prompt-scope discipline, reader-model reword, ADR) is committed and awaiting operator review for close.
