---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the write-for-the-reader principle

## Objective

File the context-isolation judgement as one principle, absorb the retired `Records state, not session history` rule into it, and prove the principle separates a polluted artifact from a remediated one.

## Scope

Continues the M3.3.4 row **Settle the split criterion and prove the template**, and files one of the two or three principles that row asks for. It absorbs the judgement that `documentation_policy.md` stated under `### Records state, not session history`. The fold-back procedure for closed design questions stays in policy, because it is process and not the judgement. Instances in commit bodies and one archived ADR are recorded as evidence and not rewritten: history is immutable and an archived record is closed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One principle states the judgement and absorbs the records-state rule | `SKILL.md` states it; policy `### Subject, not the session` names the skill as the judgement's only home | Accepted |
| The policy states no duplicate judgement, and the fold-back procedure keeps a home and an observer | census rows read `model` for the pointer and `rule-reviewed` with `prompt:document` for the procedure; `document.md` Step 6 carries the check | Accepted |
| Every live carrier points at the skill | `documentation_taxonomy.md`, both `AGENTS.md` layers, the three `-run` drafts and the STE sweep row in `roadmap.md` name it | Accepted |
| Live instances are remediated | three handover rows and three code comments rewritten | Accepted |
| A blind reader separates a polluted artifact from a remediated one | `probe-comment-control.log` lists `option c` among the terms it cannot resolve; `probe-comment-treatment.log` does not | Accepted, with a reliability finding |
| A fresh agent finds the principle from its description | `probe-discovery3.log` names the skill and quotes the delivered description | Accepted |
| The gates are clean | `bash scripts/lint.sh` (9 gates), `test_dry_run_record.sh` 10/10, `test_trace_build.sh` 20/20 | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The principle absorbs the whole judgement, not only the dependency clauses | The shared judgement is that the artifact answers to its subject and its reader. A chat label, a session id and a change-of-mind narration are three ways the session displaces that answer. | the skill; this record |
| The fold-back of a closed design question stays in policy | It is a procedure with a trigger, not a judgement, and an open question is legitimate while it stays open. The operator's point that the residue comes from skipped fold-back, not from sanitization, decides this. | `documentation_policy.md` `### Subject, not the session` |
| Give the fold-back procedure an observer in the `document` prompt | The direction had no check, which is why it was skipped. A procedure with no observer is a judgement in a policy file, which the authority doctrine forbids. | `workflow/coding-agent/prompts/document.md` Step 6 |
| Name it `communication-principle-write-for-the-reader` | The name states the judgement in words any project uses, and the reader is the general case. "Sanitization" names the removal, so it would teach a scrub that leaves the reference unresolved. "Subject not session" named this project artifact vocabulary instead of the judgement. | the skill directory |
| Pin the probe to `deepseek/deepseek-flash` at `low` | The role recommendation lists `opencode/deepseek-v4.1-flash-free` first and `opencode-go/deepseek-v4.1-flash` second; both returned `401 api_key_expired`. The startup default is the fallback rung. | this record; `.scratchpad/opencode-dispatch.3vSCWI/worker.log` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None | -- | -- |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The rule already existed as handover `20260810-03` and its acceptance criterion 4, and it failed anyway. The six remediated instances are the recurrence. | diagnosis | A carrier with no trigger at the moment of writing loses to a carrier a writer never opens. The principle carries the trigger words in its description, and the remediation shows the failure in place. |
| The handover rows are polluted but not unusable. The rationale column carries the decision, so a reader decodes the label. The code comment `option c` is unusable, because the label is the whole content. | evidence | The test separates the classes. "The reader cannot act" overstates the row case; "the reader must decode a dead reference" is exact. |
| The blind-reader probe split on the unresolvable label and not on task completion. One run answered `NONE` for the control, so the instrument is not reliable on a row that carries a rationale. | measurement | The probe is evidence for the label class only. A sharper instrument is open work, not a claim this record makes. |
| Commit bodies `2fa0ee82`, `cf4ab97b` and `f668c0d9` carry a planning-session reference and `option B`. `docs/adr/archive/20260730-adr-settled-worktree_rejection.md:17` carries a session id. | evidence | Recorded, not rewritten. A commit body is immutable history, and an archived ADR is a closed record. |
| The `opencode-go` key and the `opencode` free tier both returned `api_key_expired` (`401`), so the recommended reviewer model could not run. | environment | The probe fell back to the startup default, named above. The review ran on `deepseek/deepseek-flash` at `high` instead. |
| Two independent review rounds ran over the unit, one before and one after the first fix. Every defect row in `.scratchpad/review-report.md` and `.scratchpad/review2-report.md` is fixed before the delivery commit. | review | The rounds found the classification, evidence and edge defects the author had passed over, including a corrupted ledger header and a test that passed the face it claimed. |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md) | the new principle |
| `$AGENT_HOME/agent/skills/communication-principle-write-for-the-reader/` | the installed copy, identical to the repository |
| [`documentation_policy.md`](../../../docs/policies/documentation_policy.md) | the judgement leaves; a pointer and the fold-back procedure replace the subsection |
| [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md) | the Maintain row points at the skill |
| [`document.md`](../../../workflow/coding-agent/prompts/document.md) | Step 6 gains the design-document fold-back check, the procedure's observer |
| [`AGENTS.md`](../../../AGENTS.md) | the drafting list names the principle |
| [`AGENTS.md` (provider)](../../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the duplicate clause becomes a pointer, repo and installed copy |
| [`norm-ownership.tsv`](../../../scripts/lint/norm-ownership.tsv) | regenerated; 167 rows, 21 reviewed, 83 judgement, 40 model |
| [`20261004-02-plan-model_refresh_startup.md`](../../handovers/archive/20261004-02-plan-model_refresh_startup.md) | `option B of the three` becomes the chosen behaviour, stated |
| [`20261004-06-workflow-sidequest_runbook.md`](../../handovers/archive/20261004-06-workflow-sidequest_runbook.md) | `(option a)` removed; the row states the decision |
| [`20261015-18-workflow-add_the_read_back_prompt.md`](../../handovers/archive/20261015-18-workflow-add_the_read_back_prompt.md) | `Option B, prompt-shaped` becomes the prompt shape, named |
| [`test_dry_run_record.sh`](../../../tests/test_dry_run_record.sh) | `(option c)` becomes what the gate verifies |
| [`test_trace_build.sh`](../../../tests/test_trace_build.sh) | session id and roadmap pointer removed; the regression states the fact |
| [`knowledge_pi_config_cycle.sh`](../../../tests/knowledge/knowledge_pi_config_cycle.sh) | session id and handover name removed; the note states the change |
| [`AGENT_FEEDBACK.md`](../../AGENT_FEEDBACK.md) | the record-layer entry's steer names the principle instead of the retired rule |
| [`roadmap.md`](../../roadmap.md) | the M3.3.4 sub-row marked `[x]` |
