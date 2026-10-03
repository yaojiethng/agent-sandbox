# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Write the prompt-and-skill authoring-guidelines convention: one convention document stating the authoring rules for workflow documents (prompts and skills) - structure, runbook versus advisor, subject scoping, and how to identify a workflow document. Wire it into the documents that reference workflow-document presentation rules so it is the canonical owner.

## Scope

The M3.2.1 roadmap row `Prompt and skill authoring guidelines convention`. This iteration writes the convention document and links it into its four consumers. It does not run any per-prompt quality pass or the `fanout` doc pass - those read against the convention and are separate tasks.

The convention grounds on the repository's actual prompt and skill set and draws levers from two external references the operator supplied (Claude skill-authoring best practices, mattpocock `writing-for-agents`). The operator confirmed naming (`prompt-authoring-conventions.md` reflects both prompts and skills) and that the external sources appear in the document.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | The convention document exists at `docs/development/prompt-authoring-conventions.md` and answers the four questions: structure, runbook vs advisor, subject scoping, workflow-document identification | read the document | Agent [x] |
| AC2 | The convention is a consumer of the model in `agent_workflow.md`, not a restatement of it: it links to the model and keeps the authoring bar | read Purpose; read `agent_workflow.md` | Agent [x] |
| AC3 | The four consumers link to the convention: `conventions.md` index row, `agent_workflow.md` skill/prompt sections, `documentation-pass.md`, the `/document` stub | read each file's link; resolve the path | Agent [x] |
| AC4 | The repository lint gate passes over the new and edited documents | `bash scripts/lint.sh` | Agent [x] |
| AC5 | The roadmap row is marked done with a Landed note and the handover is the sole reference for this work | read `devlog/roadmap.md` row 126 | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the deliverable convention document |
| [`docs/development/conventions.md`](../../docs/development/conventions.md) | index gained a "Prompt and skill authoring" row |
| [`docs/concepts/agent_workflow.md`](../../docs/concepts/agent_workflow.md) | keeps the model; the skill-files and prompt-templates sections link to the convention as the authoring bar |
| [`workflow/coding-agent/audits/documentation-pass.md`](../../workflow/coding-agent/audits/documentation-pass.md) | routes workflow-document prescriptive rules to the convention |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | the `/document` stub's deferred workflow-document presentation rules point at the convention |
| [`devlog/roadmap.md`](../roadmap.md) | row 126 marked done at close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Convention lives at `docs/development/prompt-authoring-conventions.md`, an authoring bar, not a model | `agent_workflow.md` owns the conceptual model (layers, loading, authority hierarchy); the convention owns how to write. A fact about the model lives in `agent_workflow.md`; a rule about writing lives here | convention Purpose |
| Name reflects both prompts and skills (`prompt-authoring-conventions.md`) | the roadmap row is "prompt and skill"; a name naming only prompts under-covers the skill half | operator-confirmed 2026-09-29 |
| External references appear in the document as source lineage | the conventions are this repository's own rules; the two references explain the reasoning and match what the repo already does | operator-confirmed 2026-09-29 |
| `agent_workflow.md` is the canonical owner of the consumer-never-authoritative model; the convention references it, not restates it | one rule one owner; the convention is a standalone authoring bar and links out for the model | convention Consumers-as-fast-paths; single-owner discipline |
| The convention grounds structure on the repository's actual prompt/skill set, not a fixed target skeleton | the quality passes refactor toward the bar, not toward a foreign shape; `iter`, `advisor`, `task-queue`, `fanout-run`, `document`, and the six repo skills are the primary source | convention Purpose + Structure |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The `write` tool dropped the trailing newline on the new convention file, failing MD047; lint caught it and the newline was appended | tool behaviour | current iteration - fixed; recurrence of the AGENT_FEEDBACK write-tool trailing-newline class |
| The model-recommendation table in `AGENTS.md` names a model and a thinking level but no provider, and providers disagree on capability (the opencode line rejects `reasoning_effort` where opencode-go accepts it, so the same model resolves to a version that fails dispatch). Raised by the operator (2026-09-29). | gap in the landed single-source-model convention | roadmap T1 - recorded as an open follow-on on row 87 |
| A fresh reviewer (glm-5.3-flash, operator override from the `_REVIEWER` recommendation) found eight defects in the first draft: the third-person rule contradicted the repo's imperative prompts; `documentation-pass.md` carried broken `../../docs/` links (pre-existing, corrected on the touched line); a scope-discipline sentence inverted `iteration_policy.md`; a task-queue characterisation named a non-goals section it does not have; external references lacked targets; the body order omitted the `> $@` line and Failure-modes/Invariants; container idioms; a mis-titled three-tests list. All eight fixed and confirmed by a second re-review (verdict: adoptable). | review | current iteration - fixed |

## Completed

| File | Change |
|---|---|
| `docs/development/prompt-authoring-conventions.md` | new convention document: purpose and scope; document-type identification (policy / reference / workflow + the three tests); the information hierarchy (in-file step / reference / disclosed, progressive disclosure, co-location, degrees of freedom); runbook vs advisor vs skill; structure (frontmatter, description, argument hint, skill frontmatter, body order); subject scoping + prompt-scope discipline + context pointers; consumers-as-fast-paths with no-op and sediment defences; naming; compliance |
| `docs/development/conventions.md` | added the "Prompt and skill authoring" index row linking to the convention |
| `docs/concepts/agent_workflow.md` | skill-files and prompt-templates subsections gained links to the convention as the authoring bar |
| `workflow/coding-agent/audits/documentation-pass.md` | prescriptive-rules pointer for skills and prompt templates routed to the convention (model still in `agent_workflow.md`); its `../../docs/` links corrected to `../../../docs/` (pre-existing broken links, fixed on the touched line) |
| `workflow/coding-agent/prompts/document.md` | the deferred workflow-document presentation rules now point at the convention |
| `devlog/roadmap.md` | row 126 marked `- [x]` with a Landed note; row 87 (single-source model) gained an open follow-on note that the table omits the provider |
| `devlog/handovers/20260929-04-workflow-prompt_authoring_conventions.md` | this handover |

## Deferred items

None - this iteration was self-contained.

## What's Next

Context: the task-queue primitive landed (handover `20260929-03`); its row is done. This iteration wrote the authoring convention it was sequenced after.

Next in the sequence: the `/task-queue` per-prompt quality pass (roadmap row 89) reads against the convention, then the other per-prompt quality passes (`/plan`, `/milestone-start`+`/milestone-close`, `/iter`). The `fanout` rename + doc pass (row 125) reads against the convention. These remain open; none were started here.

Roadmap maintenance ran at close: the M3.2.1 prompt-and-skill-authoring-guidelines-convention row is marked `- [x]` done.
