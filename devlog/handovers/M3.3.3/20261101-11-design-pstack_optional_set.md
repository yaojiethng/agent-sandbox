---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Design
status: Closed
---

# Handover - the pstack set owes no edge and no declaration

## Objective

Re-read the pstack row under the opt-in store and close it if the relationship is clean, so the base stack stops carrying an obligation the provenance model no longer asks for.

## Scope

The roadmap row `The four pstack skills are optional, not base`, which asks that `teach`, `how`, `why` and `unslop` stay out of the base stack, arrive through the declared-dependency route as an optional module, and reconcile `unslop` against `writing-for-agents`.

**The relationship is clean, and the row closes.** Four measurements, each taken on the tree:

| Claim | Measurement |
|---|---|
| The set reaches no other project | none of the four names appears in `.agents/skills/`, `src/reasoning/agent/skills/`, the provider config source `src/reasoning/providers/pi/config/agent/skills/`, or `workflow/coding-agent/skills/`; they exist only in the installed home, and the image stages nothing from it |
| No tree artifact depends on one | the only live references are the `eval` skill citing the poteto-mode eval playbook by URL, and the store's single pstack edge, which is the tree's own fork of `principle-guard-the-context-window` |
| `unslop` does not compete with `writing-for-agents` | `unslop` carries `disable-model-invocation: true`, so it fires when the operator invokes it; `writing-for-agents` is model-invoked on a document task. The subjects differ and the triggers cannot collide |
| The set is coherent as a whole | `teach` invokes `how` and `why`, and `unslop` declares that it always applies, so the four are installed together and a subset problem does not arise |

**One premise is wrong, and this is where it gets corrected.** The row says the set "arrives through the declared-dependency route". It does not. [`.agents/registry/packages.json`](../../.agents/registry/packages.json) names two image payloads, `/opt/workflow/agent` and its coding-agent module, and neither is pstack. The set arrives as directories dropped into the installed home, which the image never stages and no manifest claims; [`resync.md`](../../.agents/prompts/resync.md) already states that the installed tree holds skills and files the image does not stage, and lists the family the four belong to.

Under the opt-in store, that costs nothing. An edge exists because someone maintains that artifact against an upstream, and not one of the four is maintained here; the store's pstack edge is the one tree skill that has the lineage, and it stays as it is.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row closes as the measured relationship, with the arrival route corrected rather than repeated | read the row in `devlog/roadmap.md`; `grep -c 'declared-dependency' devlog/roadmap.md` = `0` | accepted: the row closes with the four measurements, and states the installed home as the route |
| No live statement names the pstack row as an open subject for the module form | read the 2026-11-01 entry in `docs/adr/module_instruction_payload.md`; it names no roadmap row | accepted: the edge case says the subject is unoccupied, and names the reopening events instead |
| The four names remain in no repo layer | the four-ls check over `.agents/skills`, `src/reasoning/agent/skills`, the provider config source and `workflow/coding-agent/skills` returns `0` each | accepted: `0` in all four |
| The suite and the lint gates are clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | accepted: clean across 19 gates; 1433 tests across 104 files, 0 failed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The set stays installed, undeclared, and in no layer | it is one project's own dependency, the image stages none of it, and nothing in the tree reaches for it | the closed row |
| No edge and no package entry is owed | the store is opt-in bump data, and none of the four is maintained against upstream here | the closed row, and the store |
| The `unslop` overlap resolves by invocation mode, not by a mechanism | an operator-invoked corrector and a model-invoked authoring guide never answer one trigger | the closed row |
| The arrival route is the installed home, not the declared-dependency route | `packages.json` names two image payloads and pstack is not among them | the closed row, and the correction in it |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's arrival route contradicts the tree: the package manifest names two image payloads and neither is pstack | defect | a record that promises a declaration nothing makes reads as satisfied, so a later reader trusts an install the project does not control | fixed: the row records the installed home, and `resync.md` already states the model |
| `unslop` is operator-invoked, so the "two prose standards" the ADR feared cannot compete | finding | the overlap needed a mechanism nobody wanted, and it needed none | the closed row |
| The set is internally dependent, so a partial install would break it | finding | installing a subset is the risk, and it is not a risk this repository can create | the closed row |
| `eval` cites the pstack eval playbook by URL, which the six-word-run scan reports as a text overlap | finding | a citation is not a dependency; the set stays uninvoked from the tree | recorded here, so a later scan does not re-open it |

## Completed

| File | One-line change |
|---|---|
| `devlog/roadmap.md` | the pstack row closes as the measured relationship, and the parent row stops asserting it stays open |
| `docs/adr/module_instruction_payload.md` | the 2026-11-01 edge case stops pointing at a live roadmap row |
| `devlog/handovers/20261101-11-design-pstack_optional_set.md` | this record |
