---
date: 2026-11-04
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the boundary-violation rule lives in SSOT

## Objective

Merge the stop-and-raise boundary-violation rule into `principle-single-source-of-truth`, retire `principle-delegation-over-machinery`, and route the check at the scope step.

## Scope

The M3.3.3 row **State the delegation judgement as a principle**. The operator approved the merge: the old skill's prescriptive "hand the question to the owner" is replaced by a scoping stop in SSOT; the old skill is retired; the scope prompt carries the routing line. The deferred task for merging `instruction-authoring` and `project-documentation` is filed in `roadmap_future.md` and is not worked here.

In scope: the SSOT description, leitwort and body; the retirement of the delegation skill; the scope prompt line; the roadmap row; the feedback recurrence; the deferred task.

Out of scope: the two-convention merge; the installed `$AGENT_HOME` copy, which the image reseeds; the historical discussion and the closed handovers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| SSOT is the home and states the stop-and-raise rule, the organization placement rule and `leitwort: SSOT`; the old skill directory is gone | `rg -n -e "leitwort: SSOT" -e "Stop and raise it to the operator" -e "organization rule"` in the SSOT skill; `test ! -d` the old directory | Accepted |
| SSOT no longer carries the sentence-kind step or the generic quadrant phrase | `rg -n -e "sentence's kind" -e "Diataxis quadrants"` in the SSOT skill prints nothing | Accepted |
| The scope prompt carries `## Check the boundary` and points at SSOT | `rg -n -e "Check the boundary" -e "principle-single-source-of-truth" workflow/coding-agent/prompts/scope.md` | Accepted |
| The roadmap row points at SSOT and names the supersession; the feedback recurrence uses the live name and preserves the old one | `rg -n -e "State the boundary-violation judgement" -e "20261104-04" devlog/roadmap.md`; `rg -n "principle-single-source-of-truth.*principle-delegation-over-machinery" devlog/AGENT_FEEDBACK.md` | Accepted |
| The deferred task exists and the Skill Ingestion membership row links it | `rg -n -e "Merge Instruction-Authoring and Project-Documentation" -e "merged instruction-writing surface"` in `devlog/roadmap_future.md` | Accepted |
| Every decision this iteration recorded is realized in the files | read `## Decisions` against the tree | Accepted |
| The old name remains only in historical records | `rg -n "principle-delegation-over-machinery"` and read each hit | Accepted |
| The tree passes the shape, lint and test gates | `bash scripts/check_document_shape.sh`, `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Merge the stop-and-raise rule into SSOT; create no new skill | SSOT is the law; the rule is its scoping gate. A separate skill would state the same law in a second place | the SSOT skill; this record |
| Retire `principle-delegation-over-machinery` | Its "hand the question to the owner" is a prescription. The operator wants a stop-and-raise rule, not a fix | this record; `devlog/roadmap.md` |
| Use `leitwort: SSOT` | The acronym is the term the domain already holds. The spelled-out name anchors it for a reader who does not know it | the SSOT skill |
| Place text by the organization rule, not the instruction-modality kind | The 2026-11-02 modality ADR demotes per-sentence classification. The organization rule picks the mode, then the corpus | the SSOT skill; `docs/adr/instruction_modality.md` |
| Route the check at the scope step | The code ladder reaches code changes only. The scope step reaches features, documents, skills and code | `workflow/coding-agent/prompts/scope.md` |
| File the two-convention merge as deferred | The conventions have different scopes, readers and release rules. The decision is separate from the SSOT merge | `devlog/roadmap_future.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The SSOT skill carried a mandatory "name the sentence's kind" step, against the 2026-11-02 modality ADR | defect, record | a per-sentence classification the ADR retired | removed in this iteration |
| The old skill's "a report that names both parties" read as build-a-report, against the skill-collision ADR | defect, record | it would rebuild a report the loader already prints | removed in the merge |
| The two authoring conventions both carry a placement rule | scope gap | the same placement rule exists in two places | deferred in `roadmap_future.md` |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md` | the stop-and-raise scoping rule, the organization placement rule, `leitwort: SSOT` |
| `src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/SKILL.md` | deleted; its judgement merged into SSOT |
| `workflow/coding-agent/prompts/scope.md` | the boundary check at the scope step |
| `devlog/roadmap.md` | the row points at SSOT and records the supersession |
| `devlog/AGENT_FEEDBACK.md` | the recurrence names the live principle and preserves the old name |
| `devlog/roadmap_future.md` | the deferred two-convention merge, linked from Skill Ingestion |
| `devlog/handovers/20261104-04-workflow-boundary_violation_ssot.md` | this record |
