---
date: 2026-11-14
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Workflow
status: Closed
---

# Handover - The interview advances on a question the user asked back

## Objective

Stop the `grill-me` interview from closing a branch on its own recommendation when the user asks a question back, and make it re-derive the frontier after the user's thread ends.

## Scope

The interview section of `src/reasoning/agent/skills/grill-me/SKILL.md`: the resolution sentence, the parked-side-question sentence, the probe paragraph, and the session-close sentence. Plus the T7 row that carries the behaviour family, amended to record what landed.

Out of scope: the harness navigation half of that row (the multi-question-turn stack and its break points), which stays open; and an eval case for the behaviour, because none exists and the operator ruled that evals are not run for this work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A question the user asks back takes precedence, and the pending question is held on the open list rather than answered for them. | `grill-me/SKILL.md`, the paragraph opening "A question the user asks back". | Agent [x] |
| The frontier is re-derived when the thread ends, and a branch whose premise the thread removed is re-opened. | `grill-me/SKILL.md`, the paragraph opening "When the thread ends". | Agent [x] |
| No branch is resolved by the recommendation, and the session does not close on a branch the user has not decided. | `grill-me/SKILL.md`, the last interview paragraph and the session-close sentence. | Agent [x] |
| The T7 row records the rule that landed and keeps the navigation half open. | `rg -n "Landed 2026-11-14" devlog/roadmap.md`. | Agent [x] |
| The suite and the lint gate are green. | `bash scripts/run_tests.sh` (1601 of 1601 passed); `bash scripts/lint.sh` (27 gates clean); `make` is absent from this container. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The user's question takes precedence and the pending question is held, rather than answered then re-asked. | The user may need it settled before they can answer, so it is a thread they own; treating it as an obstruction is what let the interview run ahead. | `grill-me/SKILL.md` |
| The frontier is re-derived at the thread's end instead of the pending question being resumed. | The thread can settle the pending question, move the frontier past it, or break an assumption a resolved branch rests on, so the question to put is the one the frontier now holds. | `grill-me/SKILL.md` |
| No eval case for the behaviour. | None exists, one would have to be constructed, and the operator ruled that evals are not run for this work. The risk is stated in the handover rather than papered over. | This handover |
| The removed duplicate sentence carried a correction rule in its second half, which moves into the re-derivation paragraph. | Instruction growth is paid for by removing a duplicate, not by dropping the rule that shared its sentence; an answer the thread overturns still has to be corrected. | `grill-me/SKILL.md` |
| No `[O]` entry in `devlog/AGENT_FEEDBACK.md`. | The defect was in the instruction, and the diff removes the permission that produced it; an entry would describe a mistake the corpus no longer permits. Operator ruling at the pre-close gate. | This handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The prior text covered a probe and left "resolved" without an owner, so the recommendation had a path to being read as the user's choice. | record | The run-ahead was permitted by the text rather than by a lapse in reading it. | `src/reasoning/agent/skills/grill-me/SKILL.md` |
| The family was already on record in the T7 row, and the row proposes harness instrumentation rather than the rule. | record | The behavioural half needed no new design; the navigation half remains open and unlanded. | `devlog/roadmap.md` |
| The behaviour has no automated check. | record | Nothing catches a regression in the interview's ordering; the next real interview does, and the T7 instrumentation half is where a check would come from. | `devlog/roadmap.md` |

## Completed

| File | One-line change |
|---|---|
| `src/reasoning/agent/skills/grill-me/SKILL.md` | The user's question takes precedence, the frontier is re-derived at the thread's end, and a branch is resolved only by the user's act. |
| `devlog/roadmap.md` | The T7 row records the landed rule and keeps the navigation half open. |
