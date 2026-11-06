---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the classifier-model usage prompt

## Objective

One concise prompt that states how to invoke a classifier model and when not to, and carries an antipattern register whose first entry is this session's Jev misuse.

## Scope

Operator-directed work raised after iteration `20261019-11` closed. There is no open handover, so this is a normal iteration rather than a sidequest, and no roadmap row was required at open; the write-back raises one.

Out of scope: the census revert and the re-plan, which the operator deferred to the next instruction; and any classifier usage the prompt has no lesson for yet, because the register grows one incident at a time.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt links the pi classifier-models section and the Hugging Face walkthrough, both as `https` | `grep -c "https://"` prints 2, one per link | Agent [x] |
| The invocation section states the three facts an invocation needs: one `state`, typed questions, one call is one request | read the section | Operator [x] |
| The prompt carries a pre-call check whose questions a reader answers before the call, and each names the failure it prevents | read `## Before the call`; four numbered questions, one per failure | Operator [ ] |
| The antipattern register carries this census as its first entry, in the five-line form: ask, cost, returned, why it failed anyway, rule | `grep -n '^### 2026-10-19'` names it, and the five labelled bullets follow | Agent [x] |
| The register states the form a later entry takes | the closing line names the four lines and the dated heading | Operator [x] |
| The prompt is discoverable as a slash command | `head -4` shows `name` and `description`, and `jq .prompts` names the directory | Agent [x] |
| The prompt stays short enough to read in one screen | `wc -l` prints 32, under the 60 the criterion allows | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prompt lives at `.agents/prompts/classifier-models.md` | that directory is the session's prompt directory, so a file there is repo-owned, committed, and reachable as a slash command; the loop runbooks that ship stay under `workflow/coding-agent/prompts/` | the prompt file |
| The work raises a roadmap row under M3.3.3 and marks it `[x]` | the operator chose a row over a no-home write-back at the gate | `devlog/roadmap.md` |
| The register takes five lines, newest first | an incident has to be filed in a minute or it is not filed; five lines are the least that keeps the lesson usable, and the fourth carries the cause rather than the symptom | the prompt, `## Antipatterns` |
| The general lesson is a pre-call check, not probe hygiene | the call was correct in 2026-10-19 and returned nothing, so the rule belongs before the call, where the instrument is chosen | the prompt, `## Before the call` |
| The 2026-10-19 entry records why a correct call failed | the first version blamed invented probes, which misstates the record: the probes stated observable properties as the design required | the prompt, `### 2026-10-19` |
| The prompt is held to one screen | a register that grows past a screen stops being read mid-task, which is the only moment it is read | 32 lines |
| The census numbers in the first entry cite the report | the numbers are the report's to own; the entry needs the cost and the non-result, not the four arms | the entry's source line |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first entry first blamed probe hygiene | correction | the call was correct; an entry that blames the wrong cause teaches the wrong rule | the prompt file, rewritten in this iteration on operator direction |
| The census report is organised for a reader auditing the method, so the operator could not read it as a decision record | record defect | the next reader cannot use it either | the new re-plan row under M3.3.4 |
| The first full suite run failed `test_entrypoint_copy_keeps_matching_identity` and the re-run and the file in isolation both pass | flake | a flake reads as a regression at a gate | the existing `[A] 2026-10-14` entry in `devlog/AGENT_FEEDBACK.md`, as a recurrence |

## Completed

| File | Change |
|---|---|
| `.agents/prompts/classifier-models.md` | new prompt: the four pre-call checks, the two references, the three invocation facts, and the register with the 2026-10-19 entry |
| `devlog/roadmap.md` | new `[x]` row under M3.3.3 with its landing note; the M3.3.3 summary row promoted to `In progress`; a new open re-plan row under M3.3.4 |
| `devlog/AGENT_FEEDBACK.md` | a recurrence note on the `[A] 2026-10-14` suite-flake entry |
| `devlog/handovers/20261019-12-workflow-classifier_models_prompt.md` | this record |
