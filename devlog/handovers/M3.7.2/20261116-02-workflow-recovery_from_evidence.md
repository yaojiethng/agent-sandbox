---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - recover lost work, from requirements to the skill

## Objective

Derive what recovery must do from the recovery moments in the session record, settle those requirements in an ADR, and rewrite the recovery skill and runbooks against them.

## Scope

M3.7.2, the row **Recovery is the unit's claim, and the host draft repair is not a recovery**, a continuation of **The branch-preparation surface is one host flow**.

The requirements pass reads the pi session transcripts, the handovers and `AGENT_FEEDBACK.md` for every recovery-shaped moment: what the operator said, what the record claimed, what the repository held, what evidence decided it, and what the repair did. The study stays in `.scratchpad/` and is not committed. The durable output is the requirements in an ADR, and the skill, runbooks and prompt rewritten to satisfy them. The general procedure owns the sequence; where the evidence lives in pi and in this harness is a separate layer.

Out of scope: a new recovery class, a model home, a classifier, TLA+, and the other open M3.7.2 rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR states the requirements, each traced to a named incident, and the skill and runbooks satisfy every one. | read the ADR's trace column against the skill; a requirement with no carrier fails | Agent [x] |
| The skill leads with the intent and the triage sequence; `absent` requires the exhaustive search in the stated order, and the search names every source it checked. | read the skill and runbooks; `grep` the source list | Agent [x] |
| The evidence locator names pi's session JSONL, the task-queue worktrees and branches, the bundle/output channel, host checkpoints, and copy versus mount delivery, and is separate from the general procedure. | `grep` the locator; read the skill for the separation | Agent [x] |
| The duplicate is gone, the prompt points at the skill and locator, and the draft repair names `T11`. | `test ! -e .agents/skills/git-discipline/references/recovery.md`; `grep` the prompt and skill | Agent [x] |
| The requirements pass is not committed; the commit holds the ADR, skill, runbooks, locator, prompt, statechart and roadmap. | `git show --stat` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the file table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The durable output is an ADR of requirements; the requirements pass and its census are not committed. | The study is evidence for one decision, and the decision is what later work reads. | this handover; the ADR |
| The skill leads with the intent to recover lost work and a triage sequence, not with a class table. Class names survive only where a requirement needs them. | The operator's steering: minimise metadiscourse, state the intent, give the agent the tools. | this handover; the skill |
| The general procedure owns preserve, assess, recover, verify and record; a separate evidence-locator section names where pi and this harness keep the evidence. | Different runtimes and delivery modes hold different evidence; the procedure must not bake one runtime in. | this handover; the skill reference |
| The host draft repair is `T11`, never a recovery class or redirect. | The draft is the host flow's object; nothing was lost. | this handover; the skill and the ADR |
| No model home, classifier or TLA+ unless a requirement earns it. | The model I proposed was machinery ahead of the requirements; the requirements decide. | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-05-26 session records the operator saying "it should all be in reflog, why panic?", and the 2026-08-12 session searches the reflog only after the operator supplies it. The procedure does not first look where the work is likely to be. | design | recovery rebuilds work the object store holds | this iteration |
| The 2026-09-29 session recovers artifacts from session logs after a teardown; the 2026-08-12 session finds lost content in the output channel and bundle. Neither source is named by the current skill. | design | a real evidence source is invisible to the agent | this iteration |
| The 2026-09-12 session separates resuming a stopped session from recovering lost progress. The current skill treats recovery as the entry for any non-closed session. | design | resume is misclassified as loss | this iteration |
| The 2026-09-22 session asks the agent to confirm the loss before recreating. The current `absent` class has no confirmation step and no record of what was searched. | design | the agent can rebuild over recoverable work | this iteration |
| The duplicate `git-discipline/references/recovery.md` is cited by `workflow/coding-agent/prompts/recovery.md` as the model source, so it cannot be deleted before the skill carries the model. | record | the one-source goal breaks the prompt's provenance | this iteration |

## Completed

| File | One-line change |
|---|---|
| `docs/adr/recovery_procedure.md` | New ADR: eleven requirements, each traced to an incident, and the decision that governs the procedure |
| `workflow/coding-agent/skills/recovery/SKILL.md` | Leads with the intent and a six-step triage; the evidence search and the `T11` boundary |
| `workflow/coding-agent/skills/recovery/runbooks/partial.md` | Preserve first, then search the tree and stash and retrieve before retyping |
| `workflow/coding-agent/skills/recovery/runbooks/absent.md` | Exhaustive search and retrieve-before-rebuild, then the existing rebuild checks |
| `workflow/coding-agent/skills/recovery/references/evidence.md` | The pi and harness evidence locator, by runtime and delivery mode |
| `workflow/coding-agent/prompts/recovery.md` | Re-pointed from the duplicate reference to the skill and its locator |
| `.agents/skills/git-discipline/references/recovery.md` | Deleted; one source |
| `docs/reference/workflow_statechart.md` | Recovery rows name the evidence search; the `T11` note |
| `devlog/roadmap.md` | Marked the row with its outcome |
| `devlog/handovers/M3.7.2/20261116-02-workflow-recovery_from_evidence.md` | This record |
