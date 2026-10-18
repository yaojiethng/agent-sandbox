---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the derived-data principle

## Objective

File the judgement that decides who may state a derived value, as a principle skill with no policy line behind it.

## Scope

The judgement generalizes the count rule to any value computed from data held elsewhere, which is the shape that covers totals, percentages and gate output quoted into prose. Its failure is silent staleness rather than ambiguity, so it is a separate unit from `communication-principle-one-addressing-axis`, which decides when a number earns its place.

No policy section states this judgement, so the skill stands alone the way `communication-principle-show-dont-describe` does. The provider layer gains one condensed bullet, because that layer is read every turn and a rule stated only in a skill an agent has not opened goes unapplied at reply time.

Ruled out of scope. The project has no gate that compares a document's quoted value against the artifact that owns it, and this unit does not add one. Whether a gate should exist is recorded as pending.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states the ownership frame rather than a necessity claim | `SKILL.md` opening and `The pattern` | Agent [x] |
| The failure is named as silent staleness | `Why` | Agent [x] |
| A value that is the fact itself is permitted | `Where the aggregate is the fact` | Agent [x] |
| The primary-data case is stated as the action | `Where the primary data is beside it` | Agent [x] |
| The durable form is named for a value many texts need | `Where many texts need the value` | Agent [x] |
| The provider layer carries the condensed rule | `AGENTS.md` derived-values bullet | Agent [x] |
| The installed copies match their sources | `diff -q` on both paths | Agent [x] |
| Every gate passes | `bash scripts/lint.sh`, ledger reconciled | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The judgement is a separate skill, not a section of the addressing skill | The two have different failure modes and different remedies. Ambiguity is repaired by one axis; staleness is repaired by a pointer or by the primary data. | `SKILL.md` opening |
| The frame is ownership, not necessity | A necessity claim makes a requirement on the reader that nothing observes. Ownership is a fact about the text, and the reader can check whether the source is named. | `SKILL.md` |
| A value nobody can derive from the text stays | A measurement or a gate result is primary data. Suppressing it would lose the only place the value exists. | `Where the aggregate is the fact` |
| No policy line is added | The judgement has no instruction a writer acts on in a policy's register, and a policy line with only a judgement is the defect this fold series removes. | this record, scope |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether a gate should reconcile a quoted value against its source | A stale copy in a record is caught by a reader or by nothing | add a check that re-derives a record's quoted counts and compares them, the shape the ledger regeneration already uses; leave it to the close checklist |

## Findings

| Finding | Type | Impact |
|---|---|---|
| This session produced the failure the rule names, repeatedly, by quoting a gate's output into prose | agent experience | "clean across 90 files" and "81 judgement" were restated as facts and both changed later; the table in the skill now carries that case so the habit is visible |
| The register at `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` is the worked remedy, and its churn is why the remedy exists | precedent | a value many texts need is derived from the rows, never typed into each record |
| A record that quotes a derived value has no owner, and the ledger's observer column says so | judgement | the class is `model` with observer `none`; a check would move it to `rule-gated`, which is the pending question |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` | new skill: the ownership frame, the substitutions, silent staleness, the primary-data case, the multi-text case, the other-artifact case |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the condensed derived-values bullet |
| `devlog/handovers/20261018-10-workflow-file_derived_data_principle.md` | this record |
