---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire the norm ledger

## Objective

Delete the norm ledger and its gate, on the operator's decision that a hand-maintained per-sentence index over two documents costs more than the one number it produces.

## Scope

`scripts/check_norm_ownership.sh`, `scripts/lint/norm-ownership.tsv`, `scripts/lint/norm-judgements.tsv` and `tests/test_norm_ownership.sh` are deleted, and the lint gate set drops from eleven to ten. Every live carrier that described the mechanism is retargeted, and the two rows on the roadmap that had the ledger as their subject are resolved.

The ledger was read in full before it was deleted, and the measurement that settled the decision is recorded in `docs/adr/norm_kinds.md`: 99 rows, 22 naming an observer of which 16 are gates and 6 are review skills, 46 negations, 31 descriptions. `--generate` derived four cells and typed two, and the two it typed were the only ones that carried meaning. The observer check asked whether a named file exists, never whether it fires on the sentence. Editing one sentence turned its row to `UNCLASSIFIED` and the row count did not move, so the one visible metric could not see the loss.

---
[CORRECTION -- 2026-10-22: The measurement that settled the decision now names `docs/adr/norm_kinds.md`. The paragraph cited handover `20261022-14`, which `9b759dfb` created and `b197cee7` reverted, so the pointer named no record in this tree. No finding raised.]

---

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No ledger file remains | `ls scripts/lint/norm-ownership.tsv scripts/lint/norm-judgements.tsv` fails | Agent [x] |
| No live surface names the script | `grep -rln check_norm_ownership docs scripts tests workflow .agents AGENTS.md` prints nothing | Agent [x] |
| The gate set no longer carries it | `grep -c 'GATES=' scripts/lint.sh` and the umbrella summary naming ten gates | Agent [x] |
| The kind test survives in prose | `grep -c 'Norm kinds' docs/reference/agent_workflow.md` | Agent [x] |
| The ADR records the retirement | `grep -c 'The kind test stands' docs/adr/norm_kinds.md` | Agent [x] |
| The roadmap carries no orphan row | `grep -c 'regroup' devlog/roadmap.md` is 0 | Agent [x] |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] |
| The suite is clean | `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete the mechanism rather than demote it to a report | The report still needs the typed pair per sentence, so the maintenance survives and only the red build goes | `docs/adr/norm_kinds.md` |
| The kind test stays, as prose a reader applies | The test is the definition of a rule, and nothing in it depended on the ledger. It is stated in `docs/reference/agent_workflow.md` `## Norm kinds` | `docs/adr/norm_kinds.md` |
| The `--regroup` defect row is deleted rather than closed | Its subject no longer exists, and a closed row about a deleted tool is a reader's dead end | this record |
| The perturbed-observer idea is recorded as the alternative worth building | A measured classification is the only version that would not need a typed pair, and it cannot cover the 46 negations, so it is a different tool | `docs/adr/norm_kinds.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The mechanism was announced as generated while its two meaningful cells could only be typed | defect | a reader could not tell a derivation from a reading, which is the whole reason the file was trusted | deleted; recorded in `docs/adr/norm_kinds.md` |
| 46 of 99 rows asserted that nothing detects a breach, which no check can settle | defect | the gate's most common row type was unverifiable by construction, and the summary line presented it as coverage | recorded in the ADR's rationale |
| The census line was the one product, and it printed on every lint run | description | the return was real but small: one line per run, for a reclassification per edited sentence | recorded in the ADR's rejection of the demoted-gate alternative |
| `docs/development/instruction-surface-conventions.md`, `prompt-authoring-conventions.md` and a shipped principle skill described the mechanism as live | defect | each was a carrier of a claim that stops being true with the deletion | all three retargeted in this unit |

## Completed

| File | Change |
|---|---|
| `scripts/check_norm_ownership.sh` | deleted |
| `scripts/lint/norm-ownership.tsv` | deleted |
| `scripts/lint/norm-judgements.tsv` | deleted |
| `tests/test_norm_ownership.sh` | deleted |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the gate set drops to ten |
| [`docs/adr/norm_kinds.md`](../../docs/adr/norm_kinds.md) | a 2026-10-22 entry: the test stands and its instrument does not; the 10-17 entry's ledger clause becomes past tense |
| [`docs/development/instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md) | the paragraph describing the script is removed |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the clause naming the ledger as the observer of a judgement is removed |
| [`src/reasoning/providers/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md) | the example row that named the ledger's regeneration rule is removed |
| [`devlog/roadmap.md`](../roadmap.md) | the `--regroup` row is deleted, the merged-surface row loses the ledger's source set, and this unit is recorded closed |
